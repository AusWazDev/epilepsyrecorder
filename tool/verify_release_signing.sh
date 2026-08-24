#!/usr/bin/env bash
#
# Verify what a Release build actually SIGNED — not what the project says it
# meant to.
#
# ── Why this exists ──────────────────────────────────────────────────────────
#
# Two defects reached hardware because every automated check in this repo is
# blind to build output:
#
#   * CODE_SIGN_ENTITLEMENTS was missing from Runner's RELEASE configuration for
#     nearly four months (CR-42, 4 May 2026 → 824cd16, 24 Aug 2026). Debug and
#     Profile had it. Runner.entitlements declared the App Group correctly the
#     whole time. So the app read a PRIVATE UserDefaults suite while the widget
#     extension read the real App Group container, and every end instruction
#     from the Live Activity button was silently lost.
#
#   * A deployment-target raise broke the Release link entirely (efae60d), and
#     `flutter analyze` + `flutter test` + subtree hashes all passed on it.
#
# `flutter analyze` and `flutter test` sign nothing and link nothing. The Swift
# guard tests read source text. The only artefact that could have shown either
# defect is the signed binary, and nothing looked at it.
#
# ── Usage ────────────────────────────────────────────────────────────────────
#
#   flutter build ios --release && tool/verify_release_signing.sh
#
#   tool/verify_release_signing.sh --app path/to/Runner.app
#   tool/verify_release_signing.sh --no-staleness      # deliberate, and noisy
#
# Exits non-zero on any failed assertion and names which one.

set -uo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
REPO="$(cd -- "$SCRIPT_DIR/.." && pwd -P)"

APP=""
CHECK_STALENESS=1
while [ $# -gt 0 ]; do
  case "$1" in
    --app)           APP="${2:-}"; shift 2 ;;
    --no-staleness)  CHECK_STALENESS=0; shift ;;
    -h|--help)       sed -n '2,40p' "${BASH_SOURCE[0]}"; exit 0 ;;
    *) echo "unknown argument: $1" >&2; exit 2 ;;
  esac
done

[ -n "$APP" ] || APP="$REPO/build/ios/iphoneos/Runner.app"
APPEX="$APP/PlugIns/MERWidget.appex"
RUNNER_BIN="$APP/Runner"
DART_BIN="$APP/Frameworks/App.framework/App"
APPEX_BIN="$APPEX/MERWidget"
PBXPROJ="$REPO/ios/Runner.xcodeproj/project.pbxproj"
RUNNER_ENTS="$REPO/ios/Runner/Runner.entitlements"

FAILURES=0
pass() { printf '  \033[32mPASS\033[0m  %s\n' "$1"; }
fail() { printf '  \033[31mFAIL\033[0m  %s\n' "$1"; FAILURES=$((FAILURES + 1)); }
note() { printf '        %s\n' "$1"; }

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

echo "Release signing verification"
echo "  app: ${APP#"$REPO"/}"
echo

# ── Preconditions ────────────────────────────────────────────────────────────
for f in "$RUNNER_BIN" "$APPEX_BIN" "$PBXPROJ" "$RUNNER_ENTS"; do
  if [ ! -e "$f" ]; then
    fail "0. artefact present"
    note "missing: ${f#"$REPO"/}"
    note "run: flutter build ios --release"
    echo; echo "FAILED (1 assertion) — nothing else could be checked."
    exit 1
  fi
done
pass "0. artefact and project files present"

# ── 0b. Staleness. A check that passes on yesterday's binary is worse than none ──
if [ "$CHECK_STALENESS" -eq 1 ]; then
  # project.pbxproj and Podfile are deliberately NOT in this set. `pod install`
  # rewrites the pbxproj with byte-identical content on every run — both
  # AwesomePodFile.rb and the libc++ post_install hook call project.save — so its
  # mtime is noise and would fail this check constantly. It needs no mtime proxy:
  # assertions 1-5 read what those two files DECLARE and compare it against what
  # the binary CARRIES, which is content-based and strictly stronger.
  #
  # For the rest, mtime is the only signal available, and it errs safe: a false
  # failure costs a rebuild, whereas a false pass is the thing this exists to
  # prevent.
  # Each source set is compared against the artefact it actually produces.
  #
  # A Dart-only change does NOT relink the Swift binary — nothing in ios/
  # changed, so Xcode leaves Runner alone and only App.framework is rebuilt.
  # Comparing lib/ against Runner therefore reported STALE on every Dart-only
  # build, which was a false failure on a correct artefact. Found the first time
  # this script met a Dart-only pass. A check that cries wolf gets disabled, so
  # this one is mapped properly instead.
  SWIFT_NEWER="$(find "$REPO/ios/Runner" "$REPO/ios/MERWidget" \
    -newer "$RUNNER_BIN" -print -quit 2>/dev/null)"
  DART_NEWER=""
  if [ -e "$DART_BIN" ]; then
    DART_NEWER="$(find "$REPO/lib" "$REPO/pubspec.yaml" \
      -newer "$DART_BIN" -print -quit 2>/dev/null)"
  else
    DART_NEWER="$APP/Frameworks/App.framework/App (missing)"
  fi
  NEWER="$SWIFT_NEWER$DART_NEWER"
  if [ -n "$NEWER" ]; then
    fail "0b. artefact is newer than its sources"
    [ -n "$SWIFT_NEWER" ] && note "newer than Runner: ${SWIFT_NEWER#"$REPO"/}"
    [ -n "$DART_NEWER" ] && note "newer than App.framework: ${DART_NEWER#"$REPO"/}"
    note "the build is STALE — rebuild before trusting any assertion below"
  else
    pass "0b. artefact is newer than its sources"
  fi
else
  fail "0b. staleness check SKIPPED by --no-staleness"
  note "assertions below may describe a binary that is not the current source"
fi

# ── Expectations read from the project, so the script cannot drift from it ────
read -r EXP_TEAM EXP_BUNDLE EXP_TARGET <<EOF
$(python3 - "$PBXPROJ" <<'PY'
import sys
src = open(sys.argv[1]).read()
OPEN = 'buildSettings = {'
found = []
i = 0
while True:
    i = src.find('name = Release;', i)
    if i == -1: break
    o = src.rfind(OPEN, 0, i)
    body = src[o + len(OPEN): src.rfind('};', o, i)]
    found.append(body)
    i += 1
def get(body, key):
    for line in body.split('\n'):
        line = line.strip()
        if line.startswith(key + ' = '):
            return line[len(key) + 3:].rstrip(';').strip('"')
    return ''
app = [b for b in found
       if get(b, 'PRODUCT_BUNDLE_IDENTIFIER') == 'au.com.notiva.medicaleventrecorder']
if len(app) != 1:
    print('MULTIPLE_OR_NONE MULTIPLE_OR_NONE MULTIPLE_OR_NONE'); sys.exit(0)
b = app[0]

# The Runner target does NOT set IPHONEOS_DEPLOYMENT_TARGET; it inherits from the
# project-level Release configuration, which is the one with no bundle id. Only
# MERWidget sets it per-target. Reading the target config alone yields nothing,
# which is how the first version of this script reported target=NONE.
target = get(b, 'IPHONEOS_DEPLOYMENT_TARGET')
if not target:
    project_level = [x for x in found if not get(x, 'PRODUCT_BUNDLE_IDENTIFIER')]
    if len(project_level) == 1:
        target = get(project_level[0], 'IPHONEOS_DEPLOYMENT_TARGET')

print(get(b, 'DEVELOPMENT_TEAM') or 'NONE',
      get(b, 'PRODUCT_BUNDLE_IDENTIFIER') or 'NONE',
      target or 'NONE')
PY
)
EOF

EXP_GROUP="$(/usr/libexec/PlistBuddy -c 'Print :com.apple.security.application-groups:0' "$RUNNER_ENTS" 2>/dev/null || echo NONE)"

echo
note "expected, from the project: team=$EXP_TEAM  bundle=$EXP_BUNDLE  target=$EXP_TARGET"
note "expected group, from Runner.entitlements: $EXP_GROUP"
echo

ents() { # $1 = bundle path, $2 = output file
  codesign -d --entitlements :- "$1" 2>/dev/null > "$2" || true
}
ent_get() { /usr/libexec/PlistBuddy -c "Print $2" "$1" 2>/dev/null || echo ""; }

ents "$APP"   "$TMP/runner.plist"
ents "$APPEX" "$TMP/appex.plist"

# ── 1. Runner carries exactly the declared group ──────────────────────────────
R_GROUPS="$(ent_get "$TMP/runner.plist" ':com.apple.security.application-groups' | sed -n 's/^ *\(group\..*\)$/\1/p')"
R_COUNT="$(printf '%s\n' "$R_GROUPS" | grep -c . || true)"
if [ "$R_COUNT" = "1" ] && [ "$R_GROUPS" = "$EXP_GROUP" ]; then
  pass "1. Runner carries exactly one App Group: $R_GROUPS"
else
  fail "1. Runner App Group entitlement"
  note "expected exactly: $EXP_GROUP"
  note "signed binary has: ${R_GROUPS:-<absent>} (count=$R_COUNT)"
  note "this is the four-month defect: check CODE_SIGN_ENTITLEMENTS on Runner/Release"
fi

# ── 2. MERWidget carries the SAME group — drift is the actual defect ──────────
W_GROUPS="$(ent_get "$TMP/appex.plist" ':com.apple.security.application-groups' | sed -n 's/^ *\(group\..*\)$/\1/p')"
if [ -n "$W_GROUPS" ] && [ "$W_GROUPS" = "$R_GROUPS" ]; then
  pass "2. MERWidget carries the same group as Runner"
else
  fail "2. Runner and MERWidget App Groups agree"
  note "Runner:    ${R_GROUPS:-<absent>}"
  note "MERWidget: ${W_GROUPS:-<absent>}"
  note "if these differ the two processes read different stores and nothing errors"
fi

# ── 3. application-identifier and team ───────────────────────────────────────
R_APPID="$(ent_get "$TMP/runner.plist" ':application-identifier')"
R_TEAM="$(ent_get "$TMP/runner.plist" ':com.apple.developer.team-identifier')"
if [ "$R_APPID" = "$EXP_TEAM.$EXP_BUNDLE" ] && [ "$R_TEAM" = "$EXP_TEAM" ]; then
  pass "3. application-identifier and team match the project: $R_APPID"
else
  fail "3. application-identifier / team"
  note "expected: $EXP_TEAM.$EXP_BUNDLE  team=$EXP_TEAM"
  note "signed:   ${R_APPID:-<absent>}  team=${R_TEAM:-<absent>}"
  note "a team-prefix change makes in-place upgrade impossible (0xe80000be)"
fi

# ── 4. MinimumOSVersion == Release target, and both binaries agree on minos ───
MIN_OS="$(/usr/libexec/PlistBuddy -c 'Print :MinimumOSVersion' "$APP/Info.plist" 2>/dev/null || echo NONE)"
minos() { vtool -show-build-version "$1" 2>/dev/null | awk '/minos/ {print $2; exit}'; }
R_MINOS="$(minos "$RUNNER_BIN")"
W_MINOS="$(minos "$APPEX_BIN")"
if [ "$MIN_OS" = "$EXP_TARGET" ] && [ "$R_MINOS" = "$EXP_TARGET" ] && [ "$W_MINOS" = "$EXP_TARGET" ]; then
  pass "4. deployment floor consistent at $EXP_TARGET (Info.plist, Runner, MERWidget)"
else
  fail "4. deployment floor consistency"
  note "Release IPHONEOS_DEPLOYMENT_TARGET: $EXP_TARGET"
  note "Info.plist MinimumOSVersion:       $MIN_OS"
  note "Runner minos:                      ${R_MINOS:-<none>}"
  note "MERWidget minos:                   ${W_MINOS:-<none>}"
  note "a partial raise ships an app and an extension with different floors"
fi

# ── 5. Runner links libc++ ───────────────────────────────────────────────────
if otool -L "$RUNNER_BIN" 2>/dev/null | grep -q 'libc++\.1\.dylib'; then
  pass "5. Runner links libc++.1.dylib"
else
  fail "5. Runner links libc++.1.dylib"
  note "Sentry compiles C++ but declares libc++ only in pod_target_xcconfig, so"
  note "CocoaPods never propagates it. The Podfile post_install adds -lc++"
  note "explicitly; without it the Release link fails on undefined C++ symbols."
  note "If this fails but the build succeeded, the flag was dropped silently."
fi

echo
if [ "$FAILURES" -eq 0 ]; then
  echo "OK — all assertions passed."
  exit 0
fi
echo "FAILED ($FAILURES assertion(s)). Do not archive or install this build."
exit 1
