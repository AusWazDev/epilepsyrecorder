#!/usr/bin/env bash
#
# Upload an archive's dSYMs to Sentry, as a SEPARATE release step, after the
# archive exists and before the build is distributed.
#
# ── Why this is not a build phase any more ───────────────────────────────────
#
# Until 29 September 2026 (Brief 244) the Runner target ran "Upload dSYMs to
# Sentry" as a Release build phase, ending in `|| echo "warning: …"` so that a
# failed upload would not fail the build. On Xcode 26 it DID fail the build:
# `sentry-cli` prints `error: API request failed` when an upload fails, and
# Xcode fails an archive when a script phase prints `error:`, whatever it
# returns (Brief 238: "Command PhaseScriptExecution emitted errors but did not
# return a nonzero exit code to indicate failure" → ARCHIVE FAILED). So every
# archive depended on Sentry being reachable and the token being valid.
#
# The phase was removed. Nothing in the build contacts Sentry now. The symbols
# still have to reach Sentry, or crash reports from that build are unreadable,
# so the upload lives here, run deliberately, and it fails LOUDLY: this is the
# one place where a failed upload SHOULD stop someone.
#
# ── Usage ────────────────────────────────────────────────────────────────────
#
#   tool/upload_dsyms.sh                         # build/ios/archive/Runner.xcarchive
#   tool/upload_dsyms.sh --archive path/to/X.xcarchive
#   tool/upload_dsyms.sh --check                 # local checks only, no network
#
# Before anything is sent, it checks locally that every binary in the archive
# has a dSYM whose UUID matches, so the wrong symbols cannot be uploaded for a
# build. `--check` stops there.
#
# Credentials: `sentry-cli` reads its own config (~/.sentryclirc) or
# SENTRY_AUTH_TOKEN. This script never reads, prints or passes a token.
#
# Exits 0 only if every check passed and, without --check, the upload succeeded.

set -uo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
REPO="$(cd -- "$SCRIPT_DIR/.." && pwd -P)"

ARCHIVE="$REPO/build/ios/archive/Runner.xcarchive"
CHECK_ONLY=0
while [ $# -gt 0 ]; do
  case "$1" in
    --archive) ARCHIVE="${2:-}"; shift 2 ;;
    --check)   CHECK_ONLY=1; shift ;;
    -h|--help) sed -n '2,36p' "${BASH_SOURCE[0]}"; exit 0 ;;
    *) echo "unknown argument: $1" >&2; exit 2 ;;
  esac
done

SENTRY_CLI="${SENTRY_CLI:-/usr/local/bin/sentry-cli}"
SENTRY_ORG="bedlin-pty-ltd"
SENTRY_PROJECT="medical-event-recorder"

FAILURES=0
pass() { printf '  \033[32mPASS\033[0m  %s\n' "$1"; }
fail() { printf '  \033[31mFAIL\033[0m  %s\n' "$1"; FAILURES=$((FAILURES + 1)); }

echo "Archive: $ARCHIVE"
[ -d "$ARCHIVE" ] || { fail "archive not found"; exit 1; }
DSYMS="$ARCHIVE/dSYMs"
APPS="$ARCHIVE/Products/Applications"
[ -d "$DSYMS" ] || { fail "no dSYMs directory in the archive"; exit 1; }

VERSION=$(/usr/libexec/PlistBuddy -c 'Print :ApplicationProperties:CFBundleShortVersionString' "$ARCHIVE/Info.plist" 2>/dev/null)
BUILD=$(/usr/libexec/PlistBuddy -c 'Print :ApplicationProperties:CFBundleVersion' "$ARCHIVE/Info.plist" 2>/dev/null)
echo "Version: ${VERSION:-?} (${BUILD:-?})"

# Every Mach-O binary the archive ships, and the dSYM that must match it.
# Runner and MERWidget are the ones a crash report names most, so their
# absence is a failure, not a warning.
check_pair() {  # $1 = binary path, $2 = dSYM bundle name
  local bin="$1" dsym="$DSYMS/$2"
  if [ ! -f "$bin" ]; then fail "binary missing: ${bin#$ARCHIVE/}"; return; fi
  if [ ! -d "$dsym" ]; then fail "dSYM missing: $2"; return; fi
  local b d
  b=$(dwarfdump --uuid "$bin" 2>/dev/null | awk '{print $2}' | sort | tr '\n' ' ')
  d=$(dwarfdump --uuid "$dsym" 2>/dev/null | awk '{print $2}' | sort | tr '\n' ' ')
  if [ -n "$b" ] && [ "$b" = "$d" ]; then pass "$2 matches its binary (UUID $b)"
  else fail "$2 does NOT match its binary (binary: ${b:-none}; dSYM: ${d:-none})"; fi
}

APP="$APPS/Runner.app"
check_pair "$APP/Runner"                                 "Runner.app.dSYM"
check_pair "$APP/PlugIns/MERWidget.appex/MERWidget"      "MERWidget.appex.dSYM"
check_pair "$APP/Frameworks/App.framework/App"           "App.framework.dSYM"
if [ -d "$DSYMS/Flutter.framework.dSYM" ]; then
  check_pair "$APP/Frameworks/Flutter.framework/Flutter" "Flutter.framework.dSYM"
fi

if [ "$FAILURES" -gt 0 ]; then
  echo "$FAILURES check(s) failed. Nothing was uploaded."
  exit 1
fi

if [ "$CHECK_ONLY" -eq 1 ]; then
  echo "--check: local checks passed. Nothing was uploaded."
  exit 0
fi

[ -x "$SENTRY_CLI" ] || { fail "sentry-cli not found at $SENTRY_CLI"; exit 1; }

echo "Uploading to Sentry ($SENTRY_ORG / $SENTRY_PROJECT)…"
if "$SENTRY_CLI" debug-files upload --org "$SENTRY_ORG" --project "$SENTRY_PROJECT" "$DSYMS"; then
  pass "dSYMs uploaded for ${VERSION:-?} (${BUILD:-?})"
  exit 0
fi

fail "UPLOAD FAILED. Crash reports from this build will be unreadable until it is re-run."
exit 1
