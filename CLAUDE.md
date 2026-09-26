# Medical Event Recorder — Claude Code Context

> **Auto-loaded by Claude Code on every session start.**
> This file covers code context only — tech stack, key files, architecture, gotchas.
>
> ⭐ **NOT FOR: anything the documents below are authoritative for.** This file is a working index and a gotcha list. **Architecture → `docs/ARCHITECTURE.md`** (already deferred to below, and that deferral is correct — it is the authority, not this file). **Schema → `docs/DATA-MODEL.md`. Design, layout and UX → `docs/design-audit/AUDIT.md`. Session history → `STATUS.md`. How chat, the CLI and the developer divide work, what escalates, and when a brief stops → `docs/WORKING-AGREEMENT.md`** (approved 10 Sep 2026; process, not code context, which is why it is not in this file). ⛔ **Working across machines — confirming state before work another machine may have moved → `docs/WORKING-AGREEMENT.md` §2B rule (h).** Read it before the first edit of a session on any host but the one that made the last commit.
> ⛔ **Where this file and one of those disagree, THAT document governs and this one is the stale copy.** Several blocks below restate their content; a restatement is a convenience copy that nothing re-derives.
>
> **For the full derived architecture — capture model, all five record-creation
> sites, the two notification solutions, storage shape — see `docs/ARCHITECTURE.md`,
> which is regenerated from the code at each version bump.**
> **Pre-release test and submission checklists live in `docs/`:**
> `docs/iOS Device Test Checklist.md` — run on a physical device before every App Store
> Connect upload, and `docs/Store Submission Checklist.md` for Windows/Partner Center.
> The iOS one is verified against the code and cites file:line; treat those citations as
> stale once the files it names change.
> For current status, blockers, and next steps → fetch the ClickUp handoff document:
> **"Project Context & Status — Claude Handoff Document"** (Team Space, workspace 90161564576)
> Keep this file updated when architecture or key patterns change.

---

## ⭐ STALE-CLAIM SWEEP BASELINE — 23 September 2026

**Recorded so the NEXT sweep is a DIFF rather than a fresh count**, which is the only way a
recurring check gets cheaper instead of being skipped.

    swept                      23 September 2026, by script
    denominator                756 lines
    mechanical candidates       26
      rule PROSE, not claims   -11   (the file's own rules ABOUT absence, not absence claims)
      genuine claims re code    15
        dated and verified      13   ⭐ LEFT AS THEY ARE — they are the control that makes the
                                      two stale ones legible
        corrected this pass       2   the `condition.dart` line, and the `StorageBoot.outcome`
                                      sentence below

⚠️ **THE INSTRUMENT'S KNOWN BIAS, RECORDED WITH THE RESULT.** The script decides whether a claim
is dated by looking **only UPWARD, 12 lines**. A claim whose date sits BELOW it scores as
undated — `event_record.dart`'s column count does exactly that. ⛔ **So this sweep
OVER-REPORTS undated claims and cannot under-report them.** That is the safe direction for a
resolution instrument, and it is stated here rather than left for the next reader to rediscover.

⭐ **What counts as a claim, since the classification is the judgement:** an assertion about the
CODE that nothing re-derives — an absence (*"nothing reads X"*), or a count (*"17 columns"*).
**The file's prose ABOUT absence is not a claim and was excluded**; eleven candidates were
dropped on that ground.

---

### ⛔ A DATE ON A CLAIM MUST MEAN *LAST VERIFIED*. A CORRECTION DATE IS NOT ONE

⚠️ **Added 24 September 2026. This is a PRECONDITION for the sweep above, not a footnote to it.**

**MEASURED, in `docs/claude-ai-project-instructions.md`: of 6 MER architecture premises, exactly
TWO carry a date — and both got one only because they were CORRECTED** (premise 1 on 23 September
2026, premise 4 on 24 September 2026). ⛔ **So a date there currently marks *"was found wrong"*,
not *"was checked"* — two opposite signals wearing the same notation.**

⭐ **THE DEFECT IS NOT THE UNDATED CLAIM. IT IS THAT AN UNDATED CLAIM AND A NEVER-VERIFIED ONE
ARE INDISTINGUISHABLE**, while a corrected claim reads as the best-attested thing on the page
when it is merely the most recently wrong.

**1. MUST: advance a claim's date when it is VERIFIED, whatever the outcome.** A re-read that
CONFIRMS a claim is exactly the event a date should record. **A claim nobody re-read keeps its
old date, and that is the point.**

**2. MUST: notate a correction distinctly from a verification.** This corpus already has the
vocabulary — `CORRECTED <date>` with the superseded wording quoted — **so the two must not be
collapsed into one bare date.**

**3. MUST NOT: run an age sweep over claims whose dates do not yet mean this.** ⛔ **It would rank
the corrected claims as freshest and leave the never-checked ones merely undated** — ordering the
corpus by how recently it was wrong, and calling that confidence.

⚠️ **WHICH IS WHY THE AGE SWEEP IS NOT BUILT YET**, and the sequencing is deliberate: **fix what
a date MEANS before scaling a mechanism that reads dates.** ⭐ **And note the sweep baseline above
declares its corpus as ONE FILE** — the scope class the workspace rules have already recorded
twice. **A mechanism scaled across a mis-scoped corpus inherits both defects at once.**

## Project Identity

- **App name:** Medical Event Recorder (MER)
- **Developer:** Notiva
- **GitHub:** branch `MedicalEventRecorder`
- **Version:** read it from `pubspec.yaml`, or at runtime from `lib/app_info.dart`. ⚠️ **The number is deliberately NOT stated here.** This line read `1.1.0+5` from June until 28 August 2026, when live was `1.1.0+49` — while the same sentence said *never hardcode this*. A file nothing re-derives is the wrong place for a value that moves every build. Last App Store release recorded as **1.0.2** (Apple and Play, as at 20 Aug 2026) — that one is a release fact, not a build number, and still needs checking against the console before any submission.
- **Owner:** Waz (wjl25) — Windows PC primary

## Package / Bundle IDs — CRITICAL

| Platform | ID | Notes |
|---|---|---|
| Android `applicationId` | `au.com.notiva.medicaleventrecorder` | Must match Google Play registration exactly — no underscores |
| Android `namespace` | `au.com.notiva.medical_event_recorder` | Internal R class only — do NOT change without updating all source files |
| iOS Bundle ID | `au.com.notiva.medicaleventrecorder` | Set in Xcode project, must match App Store Connect |
| Apple App ID | `au.com.notiva.medicaleventrecorder` | Registered 29 Apr 2026 — Team ID B7LWF6Z674 |
| Google Play package | `au.com.notiva.medicaleventrecorder` | Registered 29 Apr 2026 — cannot be changed after first publish |

**Before every build:** confirm `applicationId` in `android/app/build.gradle.kts` matches the Google Play package name exactly.

---

## Tech Stack

- Flutter (Dart, SDK >=3.4.0 <4.0.0) — Android, iOS, Windows, macOS, Web
- `sqflite` / `sqflite_common_ffi` — **the primary store since schema v1**
- `shared_preferences` — the fallback store, the cross-process capture inbox, and small flags (disclaimer and walkthrough versions). No longer the event store.
- `share_plus` / `file_selector` / `cross_file` / `path_provider` — CSV export and JSON backup
- `url_launcher` — external links (privacy policy, terms, support)
- `awesome_notifications` ^0.11.0 — Android quick-log notification. **NOT used on iOS or Windows**
- `sentry_flutter` ^9.0.0 — crash reporting, `sendDefaultPii = false`
- `package_info_plus` — runtime version and Sentry release, so neither can drift from pubspec
- `msix` — Windows Store packaging

---

## Project Structure

```
lib/
  app_info.dart           — runtime version/build/package from package_info_plus; Sentry release
  constants.dart          — app-wide constants (kDisclaimerVersion, storage keys, URLs)
  main.dart               — entry point; binding, Sentry, NotificationService.init(), runApp()
  models/
    event_record.dart     — EventRecord model, serialisation, CSV export (17 columns, marker v6)
                            ⚠️ **CORRECTED 8 Sep 2026 — this read *"(16 columns, marker v4)"*.** Both numbers were wrong. Counted from the header block
                            in `buildCsv` (17 names, all distinct) and read from `kCsvShapeVersion` in `event_record.dart`, not from any document.
    event_store_sqlite.dart — SqliteEventStore, the DDL, and every migration v2..v9
    storage_boot.dart     — picks the store at boot: SQLite, or shared_preferences on a fallback launch
    storage_migration.dart — the one-way drain from the shared_preferences array into SQLite
    capture_inbox.dart    — the cross-process inbox the iOS native path and the Android isolate write into
    capture_instruction.dart — parses what those paths leave behind
    (ios_capture_bridge.dart is NOT here — see services/ below)
                            ⚠️ **CORRECTED 8 Sep 2026 — this block listed *"ios_capture_bridge.dart — the Swift-side handoff"* under `models/`.**
                            It lives at `lib/services/ios_capture_bridge.dart` and **never existed at the `models/` path** (`git log --diff-filter=D` returns
                            empty). Reconciled BOTH directions: **13 named here, 12 on disk, 12 matching, 1 misfiled, 0 on disk that this block fails to name.**
    vocabulary.dart       — the DDL, seeds and rules for event types, observations and triggers; isShippedHidden, isMisdecodedTwin, setActive, renameEntry
    vocabulary_store.dart — Vocabularies: the cached lists every picker reads
    medication_note.dart  — the exceptions-only medication stream (missed / late / changed)
    condition.dart        — condition + condition_observation; the "What you track" screen
                            ⚠️ **CORRECTED 23 September 2026 — this read *"TABLES ONLY, no UI, zero rows"*.**
                            `conditions_screen.dart` has a live Add control (`_add()`, a `TextField` and an
                            Add button) and is reached from the drawer as **"What you track"**. ⭐ The no-UI
                            half was TRUE WHEN WRITTEN; the zero-rows half was never a property of the code
                            at all, only of one device on one day — **a row count is not a fact about a
                            repository.** Date is when the claim was CHECKED, not when the screen landed.
    duration_format.dart  — duration labels and the seconds/bucket split
    backup.dart           — JSON backup envelope (schema 2), parsing/validation, id-merge restore plan
  screens/
    home_screen.dart      — event list, Last Event card, overflow menu, splash redirect
    log_event_screen.dart — the single-page form (edit path for a COMPLETE record)
    event_wizard_screen.dart — the guided flow: four steps then a summary. Edit path for incomplete records
    walkthrough_screen.dart — first-run, five steps (four on Windows). Flag stores a version
    history_screen.dart   — event history, filter sheet, search, CSV export
    medication_screen.dart — the medication deviation list
    vocabulary_screen.dart — "Your lists": hide and unhide vocabulary entries
    your_data_screen.dart — export / back up / restore
    about_screen.dart     — APP card, LINKS card, LEGAL card, APP DATA (reset) card
    disclaimer_screen.dart — versioned disclaimer accept gate
    help_screen.dart      — How to use guide; Quick Log Notification setup with live permission status
  services/
    ios_capture_bridge.dart   — the Swift-side handoff: the `readCaptureInbox` / `deleteCaptureInbox` method channel. **Moved here in this document 8 Sep 2026; the file never moved**
    notification_service.dart — Android quick-log notification (awesome_notifications); SilentAction buttons; background-isolate SharedPreferences
    backup_service.dart       — backup/restore UI flows, reminder counter
  theme/                  — app theme, colours, typography
  widgets/                — shared widgets (app icon widget etc.)
assets/
  Blue_background_with_MER.png     — Windows Store box art, in-app reference
  Blue_background_without_MER.png  — in-app icon, iOS/launcher fallback
  Transparent_with_MER.png         — iOS + Android splash
  Transparent_without_MER.png      — Android adaptive icon foreground
  (SVG sources in web/)
```

---

## Key Architecture Decisions

### Quick-log notification — TWO SOLUTIONS, SPLIT BY PLATFORM

⚠️ **iOS does NOT use awesome_notifications.** Since CR-42 (May 2026) iOS
notifications are native Swift: `ios/Runner/AppDelegate.swift` owns
`UNUserNotificationCenter`, plus an ActivityKit Live Activity and an App Intent
in `ios/MERWidget/`. `notification_service.dart:60` returns early on iOS because
`awesome_notifications` reassigns `UNUserNotificationCenter.delegate` to itself and
breaks the native locked-screen handler. `onActionReceived` also returns immediately
on iOS. **Do not "fix" either by removing the platform check.**

⚠️ **CORRECTED 29 Aug 2026 — the Dart guard is necessary but NOT sufficient, and it
is not `initialize()` that steals the delegate.** The reassignment is in the plugin's
Swift **constructor**, which `GeneratedPluginRegistrant` runs on every iOS launch
whether or not Dart ever calls `initialize()`:
`AwesomeNotifications()` → `activateiOSNotifications()` → an observer on
`UIApplication.didFinishLaunchingNotification` → `delegate = self`. UIKit posts that
notification **after** `didFinishLaunchingWithOptions` returns, so the assignment in
`didFinishLaunching` cannot be the last word. There is a main-queue reassignment at
the end of `didFinishLaunching` and another in `applicationDidBecomeActive`. Assume
the delegate is contested. Full chain with file:line in `docs/ARCHITECTURE.md` §5.

⚠️ **CORRECTED 29 Aug 2026 — this said "iOS creates event records in Swift" and
that is FALSE. It inverted the single-writer property.** Swift no longer reads or
writes the stored record list at all. `AppDelegate.handleQuickLogStart`,
`handleQuickLogEnd` and `EndMEREventIntent` each post a **fact** to the capture inbox
(`writeInboxStart` / `writeInboxEnd`, one `mer_inbox_<uuid>` key per instruction in
the App Group), and **Dart's main isolate is the only writer of the record list**. The
cross-process read-modify-write was removed, not relocated — `AppDelegate.swift`
carries a DO-NOT-REINTRODUCE note where the record-list key used to be.

⚠️ **SUB-CORRECTION, 8 September 2026 — the 29 August text above is ANNOTATED, NOT REWRITTEN.
It records what was concluded on that date and stays readable as written.** Two things in it
are imprecise, both found by reading `ios/` rather than by rereading the correction:

**1. It names THREE write sites. There are FOUR.** `handleQuickLogStart`,
`handleQuickLogEnd` and `EndMEREventIntent` are named; **`endActiveEventFromApp` is absent**,
and it posts an END fact through the same `writeInboxEnd`. Derived by enumerating every caller
of the inbox writers, not from the names already written down. Four sites across two processes
— `Runner` and the `MERWidget` extension.

**2. "a DO-NOT-REINTRODUCE note" is a PARAPHRASE, not a quotation.** No such phrase exists
anywhere in `ios/`: `reintroduce`, `never write` and `no longer write` each return **0** across
all **8** Swift files, and the control on that search — the inbox writers, same reader —
returns **13**, so the apparatus was live and the zero is real. **The note exists in
substance**, at `AppDelegate.swift:24-26`, worded:

> *"The pre-inbox record mirror. Read once by Dart's reconciliation and then deleted; never
> written. Kept only so the fold-in can find it."*

⭐ **A POINTER IS ONLY AS GOOD AS ITS TARGET, AND NOTHING IN THE POINTERS-OVER-RESTATEMENT RULE
VERIFIES THE TARGET.** Preferring a pointer to a restatement avoids duplication that rots
independently — and it silently inherits whatever the target gets wrong, so an imprecise target
propagates to every document that cites it instead of staying in one place. ⛔ **The evidence is
in this repository, one day old, and it rotted TWICE WHILE BEING FIXED.**
`ARCHITECTURE.md` cited `CLAUDE.md:78` for the `log_event_screen` role on 8 September 2026.
Hours later the line was at `:82` and `:78` pointed at `duration_format.dart`, moved by an
edit to this file's own header. The pointer was corrected to `:82` — and the corrections
made in the SAME script run, two blocks higher up this file, pushed it to `:87`. ⛔ **Three
positions in one day, the third caused by the edit that fixed the second.**
**Do not cite a line number across documents at all. Cite a SYMBOL or a QUOTED PHRASE.**
Verifying the target at write time is not enough here: the pointer above was verified when
written and was wrong within the hour, because what invalidates it is an edit somewhere else
entirely. ⭐ **§3 of `ARCHITECTURE.md` already states this rule for code citations — *"CITED BY
SYMBOL, NOT LINE NUMBER"*, after three of six line numbers went wrong within days. The rule
existed and was not applied to cross-document pointers**, which is the local-correctness-does-
not-propagate class in the workspace rules.

⚠️ **iOS end-of-event has three surfaces, none reliable cold on every tier.** See
`docs/ARCHITECTURE.md` §5 for the matrix and the established boundary: `didReceive` is
**not entered for a notification response while the app is cold**, measured on 26.6 and
16.7.15. Do not add a capture or end path that depends on it reaching us cold.

⚠️ **Windows has no notification path at all.** `init()` returns before any
channel is created. Capture on Windows is in-app only.

- `awesome_notifications` v0.11.0 — **Android only**, uses `SilentAction` (fires without opening the app)
- Channel key `mer_active_v2` — v2 forced recreation after `defaultColor` + `NotificationImportance.Default` changes
- `locked: false` — notification is in the standard (non-system) section so it shows expanded by default; can be swiped away but restores on next app open via `_restoreNotification()`
- `@pragma('vm:entry-point')` required on BOTH the class AND the static callback
- Notification permission denied → app still loads (try-catch in `init()`); Help screen shows orange status + link to Android notification settings via `showNotificationConfigPage()`
- Large icon: `drawable/ic_notification_large.png` (flat PNG from mipmap-xxhdpi, not adaptive icon)
- Small icon: `resource://drawable/ic_launcher_foreground` with `defaultColor: 0xFF0D4F82`

### Android notification icon — REQUIRED pattern for every new notification

`ic_notification_large.png` is a **full-bleed blue rounded square with the white glyph inside** — byte-identical to `mipmap-xxhdpi/ic_launcher.png` (md5 `12a2fce3`), 144x144, 96.3% opaque, edge pixels `#0C4F82`. It carries its own background; nothing tints it. An earlier version of this note claimed it was a white glyph on transparent whose blue came from the `color` property. That was wrong, and it contradicted the line four bullets above which correctly calls it a flat PNG from mipmap-xxhdpi.

The `color` property is still required, for a different reason: it tints the **small** icon, `resource://drawable/ic_launcher_foreground`, which genuinely is a white glyph on a transparent background (32% opaque, transparent corners). The channel `defaultColor` cannot be relied on for that — Android caches channel settings and updates to an existing channel may not take effect.

**Every `NotificationContent` on Android must include all three of these:**

```dart
notificationLayout: NotificationLayout.BigText,
largeIcon:          'resource://drawable/ic_notification_large',
color:              const Color(0xFF0D4F82),
```

Omitting any one of these produces either no icon, a black circle, or incorrect rendering. This has been re-discovered twice — do not omit these fields when adding or modifying any notification in `notification_service.dart`.

**Android navigation from notification tap (background isolate → HomeScreen):**
- Tapping a feedback notification body sets `mer_open_latest_event = true` in SharedPreferences (done in `onActionReceived` *before* the `AwesomeNotifications().initialize()` call to minimise latency)
- `HomeScreen._handleResume()` polls for the flag (8 × 250ms, max 2s) after resume
- `HomeScreen.initState` cold-start block does the same poll
- Do NOT use a fixed delay — it loses the race against the background isolate init

### Disclaimer versioning
- `kDisclaimerVersion` in `constants.dart` — bump this string to re-prompt all users
- Stored as `disclaimerAcceptedVersion` in SharedPreferences (NOT a boolean)
- `_SplashRedirect` in `home_screen.dart` reads this key — **do not revert to boolean**

### Data storage
- ⚠️ **CORRECTED 28 Aug 2026 — this line read "no SQLite" and was FALSE.** Events are stored in **SQLite** (`SqliteEventStore`), chosen at boot by `StorageBoot`, which falls back to the shared_preferences store only when the database cannot be opened. Schema version is `kSqliteSchemaVersion` in `models/event_store_sqlite.dart` — **v9** as at 28 Aug 2026, with tables `event`, `event_type`, `observation`, `event_observation`, `trigger_option`, `event_trigger`, `medication_note`, `condition`, `condition_observation`, `schema_meta`. See `docs/DATA-MODEL.md` §0, which is regenerated at every schema bump.
- `epilepsy_event_records_v1` (`kEventStorageKey`) still exists and **stays in place** — it is the drained inbox the iOS native path and the Android background isolate write into. Never remove it.
- No backend, no cloud sync, no user accounts, no analytics — privacy-first design
- `EventRecord.fromMap` returns **nullable**; a bad timestamp yields null and that record is skipped, so one unreadable record cannot cost the whole history
- `writeEventPayload` keeps a rollback copy under `kEventRollbackKey` — **never on iOS**, deliberately, because the native write path bypasses it and a stale copy would be a data-loss mechanism. The guard carries a DO NOT REMOVE comment
- JSON backup/restore (`models/backup.dart`): versioned envelope, merge-by-id, never replaces

### CSV export
- `history_screen.dart` uses `share_plus` — works cross-platform including Windows
- No file path dependencies — uses system share sheet

---

## Toolchain — BOTH MACHINES ALIGNED 23 September 2026

Windows and the Mac now build from the same SDK. Before this they did not, and two toolchains
were building one release: Windows was on 3.41.3 / Dart 3.11.1, the Mac on 3.41.7 / 3.11.5.

    Flutter 3.41.7 · Dart 3.11.5 · framework cc0734ac71 · engine 59aa584fdf

**Pinned by TAG, not by `flutter upgrade`** — `git -C <flutter sdk> checkout 3.41.7`. An upgrade
takes the newest stable, which overshoots the moment one is released; a tag is the only way to
land on a stated version. The SDK sits in detached HEAD as a result, so `flutter --version`
reports `channel [user-branch] • unknown source`. That is expected and does not affect the four
fields above.

⛔ **THE ROLLBACK POINT IS THE ONLY THING BETWEEN THIS AND A ONE-WAY DOOR. Windows was at
Flutter SDK commit `48c32af0345e9ad5747f78ddce828c7f795f7159` (tag `3.41.3`) before the move.**
To go back: `git -C <flutter sdk> checkout 48c32af0345e9ad5747f78ddce828c7f795f7159`, then
`flutter --version` to rebuild the tool. ⭐ **This is an IDENTITY, not a state** — it names which
commit the SDK was, which is stable and cannot rot, unlike a claim about what any tree currently
looks like.

⚠️ **What the alignment did NOT do, measured rather than assumed.** It changed **nothing** in this
machine's test output: all twelve `a11y_batch_render_comparison` cases came back byte-identical
and the suite stayed at 995 passing / 0 failing. ⛔ **So the SDK version was never the cause of
the Windows/Mac difference in that file, and the "SDK skew" explanation carried from Brief 148
onward is dead.** Full record, with the prediction written before the run:
`C:\dev\Claude outputs\Brief-151-prediction-2026-09-23.md`.

## Build Commands

```powershell
# Windows MSIX (store submission)
flutter build windows --release
# Then package via msix config in pubspec.yaml

# Android (AAB for Play Store)
flutter build appbundle --release

# iOS (IPA for App Store — requires Mac + Xcode)
flutter build ipa --release
```

### ⛔ iOS BUILD HYGIENE — A SIMULATOR BUILD POISONS THE NEXT DEVICE BUILD

⚠️ **`build/native_assets/ios/` is NOT keyed by device versus simulator — both are `ios`.** So
`flutter build ios --simulator` followed by `flutter build ios --release` in the same tree hands
the DEVICE app the **simulator-platform** native-assets frameworks, and the device build reuses
them without rebuilding.

**The symptom is not a build failure. It is silent data loss at runtime.**
`objective_c.framework` fails `dlopen` with *"have 'iOS-simulator', need 'iOS'"*, that throws
inside `StorageBoot.init()`'s **outer** `try`, and the app falls back to the shared_preferences
store — **showing only the pre-migration records, with no user-facing indication.** Measured
7 September 2026: **42 of 58 records visible, 16 invisible.**

**1. AFTER ANY SIMULATOR BUILD, BEFORE BUILDING FOR DEVICE:**

```bash
flutter clean
flutter pub get      # clean removes .dart_tool/package_config.json,
                     # so --no-pub fails outright without this
flutter build ios --release --no-pub
```

**2. BEFORE ANY DEVICE INSTALL, VERIFY THE MACH-O PLATFORM:**

```bash
APP=build/ios/iphoneos/Runner.app
for FW in objective_c sqlite3; do
  vtool -show-build "$APP/Frameworks/$FW.framework/$FW" | grep platform
done
# MUST report  platform IOS
# IOSSIMULATOR means the build is bad — do NOT install it
```

`lipo -info` reporting `x86_64 arm64` on a **device** build is the giveaway: a device framework
has no business carrying an x86_64 slice. Bundle size is a secondary tell — 27.8 MB correct
against 29.7 MB poisoned.

⛔ **DO NOT "FIX" IT WITH `lipo -extract arm64` PLUS RE-SIGNING. IT DOES NOT WORK.** The arm64
slice is **itself a simulator arm64 slice**, and `dlopen` rejects on **platform, not
architecture** — so extracting arm64 fails identically. Signature-only re-signing installs
cleanly and still falls back. **Both were tried on 7 September 2026; both failed.**

⭐ **There is NO separate signing defect.** With a clean cache Xcode signs these frameworks
correctly with `TeamIdentifier=B7LWF6Z674` and **no manual signing step is needed at all.** The
adhoc signature and the wrong platform were both symptoms of the one stale-cache cause.

⚠️ **The fallback is silent.** Nothing in `lib/` reads `StorageBoot.outcome` or
`StorageBoot.isSqlite`, so nothing surfaces it — the only signal leaves the device to Sentry
(`main.dart:49`, issue `MEDICAL-EVENT-RECORDER-9`). **After any device install, confirm the
record count on the home screen against the database before trusting the build.**

⛔ **HALF-CORRECTED 23 September 2026, and the surviving half is the interesting one.** The
sentence above is preserved as written. **`StorageBoot.outcome` IS read and IS surfaced:**
`home_screen.dart`'s `_storageFellBack` reads it, and the build renders `_StorageFallbackBanner`
on it. ⚠️ **`StorageBoot.isSqlite` still has ZERO readers, checked 23 September 2026.**

⭐ **SO THE DISTINCTION THAT MATTERS IS *WHEN* THE FAILURE HAPPENS, NOT WHETHER IT IS SURFACED.**
`outcome` is set once at boot and, by its own getter's comment, *"never changes again"* — so the
banner reports a BOOT-TIME fallback and is **structurally incapable** of reporting a store failure
that happens later. ⛔ **A load that throws after a successful boot is still silent**, which is the
case Brief 91 measured. **That is why this line is annotated rather than deleted: the warning it
gives is still true of the case it was written about.**

### ⛔ A SIMULATOR CHECK IS A DEBUG CHECK — THE BUILD CONFIGURATION IS PART OF THE FIXTURE

⚠️ **Recorded 24 September 2026. Filed beside the build-hygiene rule above because both are
simulator traps and a reader who meets one should meet the other — but they are different
defects: that one is a stale CACHE, this one is the SDK silently choosing a different
CONFIGURATION.**

⛔ **FLUTTER CANNOT BUILD A RELEASE FOR THE SIMULATOR, AND IT DOES NOT WARN — IT SWITCHES.**
Read from the SDK source at the pinned 3.41.7, not inferred:

- `packages/flutter_tools/lib/src/commands/build_ios.dart` —
  `defaultBuildMode = environmentType == EnvironmentType.simulator ? BuildMode.debug : BuildMode.release`
- and asking for one anyway is a hard stop, not a fallback:
  `if (environmentType == EnvironmentType.simulator && !buildInfo.supportsSimulator)
  throwToolExit('<MODE> mode is not supported for simulators.')`
- where `BuildInfo.supportsSimulator` is `isEmulatorBuildMode(mode)`, and
  `packages/flutter_tools/lib/src/build_info.dart` defines that as **`mode == BuildMode.debug`**.

⭐ **SO EVERY SIMULATOR OBSERVATION IS AN OBSERVATION OF THE DEBUG CONFIGURATION**, whatever tag
is checked out. **On this project the two configurations have already differed in a way that
decided a behaviour:**

    at 1.0.2, Runner/Debug and Runner/Profile referenced Runner.entitlements.
    Runner/RELEASE DID NOT.  MERWidget referenced its own on all three.

**Measured in the SIGNED BINARY, not the project file** — `824cd16`, 24 August 2026 — and the
commit says why: *"the project file looked fine at a glance for four months."* Every Release
build from `17a0a4b` (CR-42, 4 May 2026) signed without
`com.apple.security.application-groups`, while the widget extension had it.

⭐ **AND AN UNENTITLED SUITE NAME DOES NOT FAIL.** iOS backs it with a private plist inside the
app's own container, so the app and the extension read and write two stores that look identical
from inside each process. `EndMEREventIntent`'s end instructions were unreachable and
`readLegacySharedRecords` always returned empty — *"a clean result that could not have been
anything else."*

⛔ **THEREFORE A SIMULATOR RUN OF 1.0.2 WOULD HAVE SHOWN THE CROSS-PROCESS PATH WORKING.** It was
entitled — in Debug. **A debug build of a release tag is not the release.**

**1. MUST: name the configuration beside any iOS observation.** *"On the simulator"* means
*"in Debug"*, and it should be written that way, the same way the Windows-green rule requires
naming the host.

**2. MUST: settle anything that depends on signing, entitlements, App Group, obfuscation or AOT
on a DEVICE build in RELEASE.** ⭐ `tool/verify_release_signing.sh` (added `b6d16fe`,
24 August 2026) exists for exactly this and reads the signed binary rather than the project.

**3. MUST NOT: carry a simulator result forward as evidence about a shipped build**, and
MUST NOT read a passing simulator check as covering the configuration that ships.

⭐ **SAME FAMILY AS WINDOWS-GREEN AND THE ONE-EM-PER-GLYPH FONT: a harness quietly substituting
its own conditions for the ones that ship.** ⛔ **The axis is what differs each time — there the
HOST, here the CONFIGURATION — and the substitution is made by the SDK, in one line, with no
output.** Ask what the harness is standing in for, not only whether it is working.

---

## Signing & Build Credentials

| Item | Value |
|------|-------|
| Certificate file | `C:/Users/wjl25/Documents/MedicalEventRecorder.pfx` |
| Publisher identity | `CN=520D1E31-3542-4059-8124-5366ECCA4994` |
| Identity name | `Notiva.MedicalEventRecorder` |
| MSIX output | `build/windows/x64/runner/Release/medical_event_recorder.msix` |

> Certificate password stored separately — do not commit to repo.

---

## Git Workflow

- Branch: `MedicalEventRecorder`
- Remote: `origin` (GitHub)
- PowerShell on Windows — standard git commands work fine
- **Signing keys are gitignored** (`*.jks`, `*.keystore`, `*.pfx`) — never stage these

---

## Store Submission URLs

| Store | Console |
|-------|---------|
| Microsoft Partner Center | partner.microsoft.com/dashboard |
| Apple App Store Connect | appstoreconnect.apple.com |
| Google Play Console | play.google.com/console |

---

## Key Constants (constants.dart)

| Constant | Purpose |
|----------|---------|
| `kDisclaimerVersion` | Bump to re-prompt disclaimer on next launch |
| `kCompanyName` | "Notiva" |
| `kWebsiteUrl` | notiva.com.au |
| `kPrivacyUrl` | notiva.com.au/medical-event-recorder/privacy/ |
| `kContactUrl` | notiva.com.au/contact/ |
| `kSupportEmail` | Support email address |

---

## Working Rules — formatting

### ⛔ `dart format` IS NEVER RUN ON THIS CODEBASE. FLAT PROHIBITION, NO EXCEPTIONS.

**This codebase's alignment is HAND-MAINTAINED**, and the formatter destroys it.
Column-aligned named arguments are used deliberately throughout —
`tooltip:   'Hide this event',` beside `color:     MERColours.onSurfaceMuted,`
— and several comments in the source refer to that alignment as the thing
being preserved.

⛔ **The prohibition covers the whole file, not the part you edited.**
`dart format` reformats a file, not a range, so running it to tidy one
insertion rewrites everything around it.

**WHAT IT COST, 17 September 2026.** One `dart format lib/screens/home_screen.dart`,
run to tidy a hand-added `Flexible`, produced **197 insertions and 240
deletions** in a file whose changeset should have been about twenty lines. The
diff was unreviewable and the intended change was invisible inside it.

⭐ **Recovered because a pre-change file copy existed** — the file was restored
from it and the edit redone by hand, so the committed diff is the change alone.
⚠️ **That recovery is the only reason this is a formatting note rather than a
lost afternoon**, and it is the same backup discipline the control-substitution
rule already requires.

**1. MUST NOT: run `dart format`, `flutter format`, or an editor's format-on-save
against anything in this repository.** If an IDE is doing it automatically, turn
it off before editing.

**2. MUST: hand-format to match the surrounding block.** Match the alignment
that is there. If a block is column-aligned, align to it; if it is not, do not
introduce alignment.

**3. MUST: copy a file before any bulk or scripted edit**, so an unintended
rewrite is recoverable. Not `git checkout` — that discards uncommitted work in
the same file, which has already cost one re-do.

---

## Working Rules — verification

### ⛔ A WIDGET TEST'S TEXT WIDTHS ARE NOT REAL TEXT WIDTHS

⚠️ **The `flutter_test` font is MONOSPACED AT ONE EM PER GLYPH.** `iiiii` and `WWWWW` measure
**identically** — 66.3 logical at `fontSize: 13` — and every measurement advances exactly
`fontSize + 0.25` per character, across sizes 10, 13 and 24 and four different strings.
**12 of 12**, in `test/test_font_width_test.dart`.

⭐ **SO A STRING'S LAID-OUT WIDTH IN A WIDGET TEST IS A FUNCTION OF ITS LENGTH AND NOTHING ELSE.**
On this project that inflated real widths by roughly **1.8x** at 13 px.

**WHAT IT COST, 9 September 2026.** A 🔴 finding was recorded, committed, pushed, and a fix was
briefed — home's app-bar title *"clipped on every phone narrower than 416 logical, 41 px lost at
375"*. ⛔ **The real render at 375 has 127 logical points of CLEAR SPACE.** The whole thing came
from `kAppName` being 22 characters and 22 x 13 = **286**, which was read as a text width.

⛔ **AND IT SURVIVED EVERY CHECK THE PROJECT HAD**, because none of them was about the input: the
geometry was measured correctly, the model fitted four independent points exactly, the boundary was
predicted before sweeping and confirmed at 1 px, and three platforms agreed. **A wrong input
produces a perfectly self-consistent set of wrong numbers, and consistency is what usually reads as
proof.**

**1. MUST: treat a widget test as authoritative for POSITION, CONSTRAINT and PROPORTION — and for
nothing that turns on how wide a glyph is.** Margins, offsets, centring, whether a constraint is
exceeded, void proportions, tap-target sizes from padding: all sound. ⛔ **Any width, threshold or
overflow amount that depends on rendered text: not sound.**

**2. MUST: get real text widths from a real render.** Either load the platform font into the
harness with `FontLoader`, or measure from a **framebuffer** capture at a known DPR — `adb
screencap` or a simulator screenshot, which are geometry-honest. ⚠️ **NOT `PrintWindow`**, for the
separate reason in the capture rule above.

**3. MUST: name the font when reporting any width.** A threshold without a font is a number without
units.

⭐ **THE SHAPE, AND IT IS DISTINCT FROM THE OTHER TWO INSTRUMENT FAILURES HERE.** §13(al) was an
instrument measuring the wrong pixels. §13(aj)'s frames were the wrong subject. **This was the RIGHT
instrument measuring the RIGHT property on a SUBSTITUTE INPUT that the harness supplied silently.**
⛔ **Ask what the harness is standing in for, not only whether the harness is working.**

⚠️ **AND THE AMENDMENT THAT MAKES THIS RULE AND THE CAPTURE RULE POINT OPPOSITE WAYS ON PURPOSE,
added 9 September 2026.**

⛔ **WHERE A CLAIM TURNS ON GLYPH WIDTH, THE REAL RENDER IS AUTHORITATIVE AND THE WIDGET TEST IS
NOT.** That is the exact inverse of the rule below, which says geometry comes from widget tests and
appearance from captures — and both are right, because they govern **different properties**:

    PROPERTY                                    AUTHORITY
    position, offset, centring, margin          widget test   (a capture cannot; see the rule below)
    constraint, overflow, proportion, void      widget test
    tap-target size derived from padding        widget test
    HOW WIDE A RENDERED STRING IS               THE REAL RENDER   <-- inverted
    colour, type, whether copy reads well       the real render / capture

⭐ **THE TEST THAT TELLS THEM APART: does the number change if the FONT changes?** If yes, a widget
test cannot answer it as configured. **If no, the widget test is authoritative and a capture is
not.**

⚠️ **A REAL RENDER HERE MEANS A FRAMEBUFFER — `adb screencap`, a simulator screenshot, or a device
capture at a known DPR.** ⛔ **NOT `PrintWindow`**, which fails the separate way recorded below.

⛔ **DO NOT READ THIS AS "PREFER CAPTURES WHEN UNSURE".** It is a narrow inversion for one property.
⭐ **Two rules pointing opposite ways is not a contradiction — it is what it looks like when the
question is "which instrument is honest about THIS quantity" rather than "which instrument is
better".**

⚠️ **Full history in `docs/design-audit/AUDIT.md` §13(ay) (retracted), §13(as) and §13(au).**

⛔ **AND LOADING THE REAL FONT DOES NOT FIX AN APP-BAR MEASUREMENT. Added 13 September 2026, after
it defeated three probes in a row.**

`FontLoader('Roboto')` registers a family **named** `Roboto`. It corrects a widget whose style
resolves to that family — `MERTheme`'s `textTheme` styles carry no family, so they inherit
`Typography`'s, which on Android **is** `Roboto`, and those measurements do become real. ⛔ **It
does nothing for a `TextStyle` that names no family and inherits none**, which is what MER's
app-bar title and subtitle are: an explicit `TextStyle(fontSize: 13, …)` inside `AppBar.title`,
under a `titleTextStyle` that also names none. Those resolve to the ENGINE default, which in the
harness is the one-em-per-glyph font, loader or no loader.

**So a widget test can report an app-bar overflow that no device has**, with the real font sitting
loaded in the same process. Measured: the disclaimer's title Row reported a **90.2 px** overflow at
375x667 and system scale 2.0 with Roboto loaded, and needs **232.2 of a 343 slot** when the same
strings are laid out free in Roboto — clear by 110.8.

**TWO PRACTICAL RULES, both cheap:**

1. **To settle a width claim, lay the string out FREE and compare against the slot.** A
   `TextPainter` with an explicit `fontFamily`, `layout()`, read `.width`. ⛔ **Do not read it off
   the rendered paragraph**: one that has already ellipsised reports the SLOT width, not its own,
   so the number looks plausible and says nothing. That cost two probes.
2. **Remember the app bar is CLAMPED.** `app_bar.dart` wraps `AppBar.title` in
   `MediaQuery.withClampedTextScaling(maxScaleFactor: _kMaxTitleTextScaleFactor)` — **1.34**. At
   system scale 2.0 an app-bar title renders at 1.34x, not 2x. Any 200% figure for that slot that
   assumes 2x is wrong before the font is even considered.

⭐ **This is the same class as the rule above and it is filed here rather than only in the finding,
because the finding is where it was learnt and this is where the next person writing a widget test
will be looking.** Full history: `AUDIT.md` §13(bx)'s annotation of 13 September 2026.

### ⛔ A CONTROL PROVES AN APPARATUS IS LIVE ONLY IF THE FAILURE IT PRODUCES IS ATTRIBUTABLE

⚠️ **A control that reports "it failed" without showing WHICH assertion fired is not much better
than a control that has never failed.** Added 13 September 2026, from C1's own control run — filed
here beside the font rule because both are cases of an instrument that reported confidently while
measuring something other than the question.

**WHAT HAPPENED.** Four superseded colour values were substituted into the real tokens in a single
run, to prove the new colour test could actually fail: two text pairs and two fills. The run went
red and was read as four controls discharged. ⛔ **It was three.** `outline` threw first, and the
first `expect` to throw ends the test — so the text substitution was **silently masked** and
produced no output of its own. It was confirmed live only by re-running it alone.

⭐ **THE SHAPE: at test granularity, a control that fired and a control that was masked have
IDENTICAL output — a red test.** The harness reports per test, the control is per assertion, and
nothing in between says which. **A red run is evidence that at least one substitution was live. It
is not evidence about any particular one**, and it reads exactly like evidence about all of them.

**1. MUST: run multiple substitutions separately, or make them fail separately.** One substitution
per run is the cheap form. `expect(..., reason:)` on every assertion, or a soft-assert that collects
rather than throws, is the form that keeps them in one run.

**2. MUST: quote the assertion text the control produced, not the run's verdict.** *"the suite went
red"* is a claim about the suite. **The claim being made is about the substituted value**, and only
the failing assertion's own message carries it.

**3. MUST NOT: infer from a red run that every substitution in it was live.** Treat the unnamed ones
as unproven, the same way this project treats an unadjudicated hit.

⭐ **Same family as the positive-control rule for null results in the workspace rules — a control
whose output cannot be attributed is unfalsifiable in the same way a null without a control is.**
The difference, and it is why this needed its own entry: there the apparatus returns *nothing* and
the danger is believing the corpus is clean; here the apparatus returns *something*, and the danger
is believing it came from where you meant it to.

### ⛔ AN INSTRUMENT THAT CAN ONLY UNDER-REPORT IS NOT SAFE BY DEFAULT — MAKE THE NULL THE LOUD CASE

⚠️ **Three instrument failures, 18 September 2026, all inside one pass over §13's status table.**
⭐ **Recorded as ONE CLASS on purpose: separately they read as three typos, and the third would
never have been written down at all.** ⛔ **All three UNDER-reported, silently, and one surfaced as
a FALSE CLOSURE — a live finding presented as resolved, which is the direction that costs most.**

    #   THE INSTRUMENT            WHAT IT DID
    1   the status-marker match   matched CLOSED and FIXED INSIDE THEIR OWN NEGATIONS. §13(bd)
                                  reads "NONE OF THESE IS CLOSED" and "STILL NOT FIXED", and
                                  scored as resolved.  The token matched; the claim was its opposite
    2   the row generator         matched ^### \(([a-z]{1,2})\) and produced 90 ROWS AGAINST 91
                                  HEADINGS, with nothing in the output saying so.  (h-ii) is the one
                                  heading whose label is not one or two bare letters
    3   the positive control      FAILED TWICE FOR ITS OWN REASONS — once mangling a phrase that
                                  lives in CLAUDE.md rather than AUDIT.md, once mangling one already
                                  in the flagged set.  Both runs read as "apparatus dead" and were
                                  WRONG ABOUT THE APPARATUS

⛔ **THE RULE THEY SHARE.** **Where a search backs a claim of RESOLUTION, the null must be the LOUD
case** — a count that does not reconcile, a row that does not exist, a control that did not move.
⭐ **An instrument whose failure mode is silence returns the same output as a clean corpus**, and a
clean corpus is what the reader was hoping for, so nothing in the reading resists it.

**1. MUST: assert the reconciliation, never eyeball it.** Print the denominator beside the result
and **fail the run when the two sides differ.** ⭐ **The one-line repair for #2 was available the
whole time:** `grep -c '^### ('` against `grep -c '^> | \*\*('`, compared, non-zero exit on
mismatch. **It would have caught the gap before the table was ever read.**

**2. MUST: check what a match ASSERTS, not only that it occurred.** A marker search for CLOSED /
FIXED / RESOLVED is a search for the word, and the word appears in its own negation. ⚠️ **Where a
mechanical match cannot tell an assertion from its denial, it may enumerate candidates but must not
set a status** — the adjudication stays manual, which is the enumeration-versus-judgement line the
workspace rules already draw.

**3. MUST: bias a resolution instrument toward OVER-reporting.** ⛔ **A false OPEN costs a second
look. A false CLOSED costs the finding.** Those are not symmetric and the instrument should not
treat them as though they were.

⭐ **AND THE COROLLARY, WHICH IS THE THIRD FAILURE'S WHOLE LESSON: A CONTROL NEEDS ITS OWN
CONTROL.** ⛔ **A control drawn from the population under test can fail for the very reason the
test does.** Control #3 was meant to prove a sentence-integrity check was live; it was drawn
without checking that its target was (a) in the file at all and (b) **currently reporting as
intact**. A control aimed at an already-flagged sentence cannot move the count, so it proves
nothing while looking exactly like a discharged control.

**PRACTICAL FORM, and it is two cheap assertions:** before trusting a control, assert that the
substitution **actually applied** (`mangled != original`), and that its target was in the
**passing** set beforehand. **Then report the DELTA the control produced, not the run's verdict** —
`newly reported: 1` is a claim about the control; *"the run went red"* is a claim about the run.

⚠️ **This extends the rule immediately above rather than replacing it.** That one says a control's
failure must be ATTRIBUTABLE. **This one says the control must be CAPABLE OF FAILING in the first
place** — and a control that was never capable of it is indistinguishable, in its output, from an
apparatus that is dead.

*Full instances: `docs/design-audit/AUDIT.md` §13(bd) and the derivation note beneath §13's status
table.*

### ⛔ CAPTURES ANSWER "HOW DOES IT LOOK". THEY DO NOT ANSWER "WHERE IS IT" OR "HOW BIG IS IT"

⚠️ **Geometry comes from widget tests. Appearance comes from captures. Do not cross them.**

**The capture pipeline on this project has produced FOUR false findings, all on 8 September 2026,
all with corroboration that looked like data:**

    1. false NEGATIVE  the walkthrough's navigation was "missing" -- the window was sized past
                       the working area, so the client bottom was off-screen and the capture
                       photographed the desktop there
    2. false POSITIVE  SetForegroundWindow failed silently and the frame was another
                       application entirely; a row-scan reported "76 rows of real content"
    3. false FINDING   a DPI-dependent horizontal offset, committed as a red-flag defect with a
                       "SETTLED" claim. FLUTTERVIEW's clientRect equals the parent's, so the
                       embedder is correct and the offset was a PrintWindow artefact
    4. false DETAIL    text described as clipped mid-word at a width where a widget test shows
                       zero overflow

⭐ **THE SHAPE IS THE SAME EVERY TIME: a capture measures the SCREEN or a COMPOSITED SURFACE, and
neither is the widget tree.** Occlusion, window position, DPI scaling, child-window compositing and
z-order all sit between the layout and the pixels. **A widget test has none of them.**

**1. MUST: take every geometric figure from a widget test.** Margins, offsets, widths, tap targets,
overflow, void proportions, whether something is centred, whether something clips. ⛔ **If a number
would change when a window moves, a capture cannot establish it.**

**2. MUST: use captures for appearance only** — colour as rendered, type as rendered, whether a
thing looks like what it is, whether copy reads well, whether two elements are distinguishable.
⭐ **These are the questions a widget test cannot answer, which is why captures are still worth
taking.**

**3. MUST: state which instrument a finding rests on.** The scope statement's basis rule already
requires naming the capture basis; this extends it — **a finding that cites a capture for a
geometric claim is wrong by construction.**

**4. MUST NOT: treat reading a frame as independent confirmation of a measurement from the same
frame.** ⛔ **Reading a frame tests its SUBJECT — is this the right screen — and cannot test its
GEOMETRY.** The Gmail frame was caught by eye because the subject was visibly wrong; a
correctly-subjected frame with wrong geometry looks exactly right. **Subject and geometry are two
properties and the eye checks only one.**

⭐ **AND THE DISCRIMINATION RULE, learned from the same incident: a prediction must discriminate
between hypotheses, not merely be falsifiable.** The DPI-96 test was offered as decisive because it
could have failed. **Both rival hypotheses — "the app lays out wrong at high DPI" and "PrintWindow
mis-scales at high DPI" — predicted the same outcome**, so its success chose neither. ⛔ **Before
running a test, ask what the RIVAL predicts. If both predict the same result, the test cannot
settle it.**

⚠️ **Full history in `docs/design-audit/AUDIT.md` §13(aj), §13(al) and §13(am).**

*Added 8 September 2026. Both rules are here because a check PASSED and the result was
wrong — that is the shared shape, and it is why neither is a style preference.*

### ⛔ TEST HARNESS — ONE PREFS-DEPENDENT TEST PER PROCESS, OR THE MEASUREMENTS ARE FICTION

⚠️ **This heading read *"ONE STATE PER PROCESS"* until 8 September 2026 (evening). "State" was the
wrong unit — see MUST 1 below.**

⚠️ **`SharedPreferences.setMockInitialValues` does NOT take effect once an instance
exists earlier in the same file.** The plugin caches its instance for the life of the
process, and a Dart test FILE is one process. So the second `setMockInitialValues` in a
file is accepted, returns normally, and **changes nothing** — every later test reads the
FIRST test's preferences.

**The symptom is not a test failure. It is a uniform set of measurements that looks
exactly as convincing as a correct one.** Nothing throws, nothing is skipped, every
`expect` passes. **A wrong number and a right number are the same shape on the screen.**

**Measured 8 September 2026 — two configurations, both producing convincing wrong
numbers:**

    seven home-screen states in ONE test   -> all seven identical      WRONG
    one test each, ONE file                -> prefs-driven states identical  WRONG
    one state per PROCESS (one per file)   -> states differ            CORRECT

⭐ **The first failure was caught only because "all seven identical" was implausible for
states that were meant to differ.** ⛔ **Had two of the seven happened to be genuinely
similar, nothing would have flagged it.** Implausibility is not a check.

**1. MUST: one prefs-dependent TEST per test PROCESS.** One `setMockInitialValues` per
file, called before any code touches `SharedPreferences`.

> ⛔ **CORRECTED 8 September 2026 (evening). This MUST read, until that date:**
>
> > *"**1. MUST: one preference state per test PROCESS.** One `setMockInitialValues` per
> > file, called before any code touches `SharedPreferences`. More than one state means
> > more than one file."*
>
> ⚠️ **THAT WAS WRITTEN FROM THE SYMPTOM, NOT THE MECHANISM, and it is narrower than the
> truth in the one direction that matters.** *"More than one state means more than one
> file"* implies the trigger is **how many STATES** a file uses. It is not. The trigger is
> **how many TESTS in the file depend on prefs at all** — which the mechanism paragraph
> above already says correctly: `setMockInitialValues` *"does NOT take effect once an
> instance exists earlier in the same file."* **Once. Not once per state.**
>
> ⭐ **SO A FILE WITH TWO PREFS-DEPENDENT TESTS IS ALREADY BROKEN, EVEN IF BOTH SET THE
> IDENTICAL STATE.** The second test does not get the state it asked for; it gets whatever
> the first test left, and if the first test's body changed anything the second reads that
> instead.
>
> **EVIDENCE, 8 September 2026 — six tests needed THREE files:**
>
>     rate tests 1-4 + record tests 5, 5b, ONE file   -> 5 and 5b read the count as -1
>     rate tests 1-4 | record tests 5 + 5b, TWO files -> 5 passed, 5b STILL read -1
>     rate 1-4 | record 5 | record 5b, THREE files    -> all six passed
>
> ⛔ **All three files set the SAME two prefs keys to the SAME values.** Under the old
> wording that is "one state", so one file should have sufficed. **It took three.**
>
> ⚠️ **And note how it presented: not as a failure of the thing being tested, but as a
> HELPER returning -1** — the "Total saved" figure could not be found, because the screen
> was not showing what the test had asked for. **Two rounds were spent rewriting that
> helper, including once by geometry, before the process boundary was the suspect.** The
> rule was in this file the whole time and its own title pointed at states.

**The practical test: count the tests in the file that touch `SharedPreferences` at all. If
it is more than one, split the file** — do not count states, and do not reason about
whether the states are the same.

**2. MUST: prove the states differ before reading the numbers.** Assert that at least two
measurements are NOT equal, as a negative control on the harness itself. A harness that
can only return one answer must fail loudly, not quietly agree with itself.

**3. MUST NOT: trust a measurement set in which every value matches.** Treat it as a
harness fault until proven otherwise. Re-run one state in isolation and compare.

### ⛔ AND THE SAME TRAP FOR SQLITE: `inMemoryDatabasePath` IS SHARED PER PROCESS

⚠️ **`inMemoryDatabasePath` is ONE database for the whole test process, not one per
`openDatabase`.** Rows written by an earlier test in the same file are still there in the next
one, and nothing in the name says so.

**The symptom is a plausible number, not a failure.** Measured 23 September 2026: a fixture that
inserted twelve rows asserted twelve and got **13** — the extra was the previous test's surviving
unreadable row. ⭐ **THE CONTROL IS WHAT CAUGHT IT. Without an assertion on the STARTING count,
"13" would have been read as a result** — and the test it fed was about how many rows survive a
delete, so a wrong denominator would have produced a confident wrong answer about data loss.

**1. MUST: clear the table in the fixture** — `await db.delete('event')` after opening — **or**
assert the starting count before acting. Both is better, and costs one line.

**2. MUST: state the isolation before reporting any number** taken from that store. A row count
without it is not interpretable by a reader.

**3. MUST NOT: assume `openDatabase(inMemoryDatabasePath)` returns a fresh database.** It does
not.

⭐ **SAME CLASS AS THE PREFS RULE ABOVE, DIFFERENT MECHANISM, WHICH IS WHY IT IS RECORDED
SEPARATELY.** There the plugin caches an instance for the process; here the DATABASE ITSELF is
process-scoped. ⛔ **A reader who knows the prefs rule will not infer this one** — they are two
libraries with one shared consequence, and the consequence is the part that looks like a result.

### ⛔ A `testWidgets` BODY RUNS ON A FAKE CLOCK. REAL I/O AWAITED INSIDE ONE NEVER COMPLETES

⚠️ **PROMOTED HERE 23 September 2026, AFTER THE THIRD OCCURRENCE. The count is the argument —
without it this reads as advice.** Origin: the Change Register
(`{OneDrive root}\Projects\App Dev\Claude\Medical Event Recorder — Change Register.md`, the
17 September 2026 `updated_at` entry), which records it in these words:

> ⚠️ **THREE PREFS-DEPENDENT TESTS IN ONE FILE HUNG FOR SIX AND A HALF MINUTES.** A `testWidgets`
> body runs on a FAKE CLOCK, and real I/O awaited inside one waits on a future that clock never
> reaches. **Both the rule and the fix were already written down and were re-learned.**

⛔ **THAT ENTRY IS ITSELF THE SECOND OCCURRENCE — it says so in its own last sentence.** The third
was 23 September 2026, when the Brief 135R reproduction hung for 45 seconds on
`databaseFactory.openDatabase` and had to be diagnosed from scratch. ⭐ **THE FIRST TWO WERE BOTH
RECORDED IN A FILE NOTHING AUTO-LOADS.** The Register is read when someone goes looking; this file
is read every session. The rule was never missing — it was never where a session would meet it.
**That is the whole reason for the promotion, and it is the same shape as the two promotions in
the workspace rules.**

**THE MECHANISM.** `fakeAsync` overrides timers and microtasks. A completion that arrives by a
**port message** — a background isolate, a plugin's platform thread — is a real event-loop event
the fake clock never services, so the `await` waits forever. The prefs store completes through
microtasks and is fine; `databaseFactoryFfi` runs SQLite in an isolate and is not.

**1. MUST: put real I/O in `setUp`, not in the test body.** `setUp` runs on the real clock.
⚠️ **`setUp`, not `setUpAll`, wherever the fixture is state the tests must not share** —
`inMemoryDatabasePath` is one database per process, per the rule above.

**2. MUST: wrap any real-I/O observation inside the body in `tester.runAsync`.** It lends the real
clock to one call. ⭐ **This changes WHEN code runs, never WHAT is driven** — taps, pumps and
lifecycle events stay on the fake clock, which is the point of the harness.

**3. MUST: use `databaseFactoryFfiNoIsolate` when the WIDGET UNDER TEST does its own database
I/O.** Moving the test's own I/O off the fake clock does nothing for the app's: a `HomeScreen`
load runs inside `pumpWidget`. The in-process factory completes through microtasks, which the fake
clock does flush.

⛔ **AND THE ONE THAT IS NOT A FAKE-CLOCK PROBLEM AT ALL, found 23 September 2026 and recorded
here because it presents identically.** `EventStore.serialise` is a **STATIC queue shared by both
stores**. A `save` left in flight when a `testWidgets` test ends has its continuation stranded in
that test's disposed zone, so **the tail of the queue never completes and every later `serialise`
call — in any later test, on either store — blocks forever.** Measured: `openDatabase` and
`db.delete` returned; `SqliteEventStore.save` did not.
⚠️ **This was WRONGLY REFUTED earlier the same day** on the reasoning that `serialise` stores
`result.then((_) {}, onError: (_) {})`, "a future that always completes". **That guarantees the
wrapper completes only if the INNER future does.** ⭐ **The queue has no timeout and no reset.**
**Separate processes, separate statics** — which the one-prefs-test-per-process rule already
forces, and is a second independent reason for it.

### ⛔ `HomeScreen`'S FIRST LOAD NEVER COMPLETES WITHOUT A MOMENT OF REAL TIME — AND THEN IT REFUSES TO SAVE

⚠️ **Recorded 26 September 2026, from the Tier A restore test. A landmine for every widget test
that pumps `HomeScreen` against a store.**

**THE SYMPTOM IS A SUCCESS MESSAGE.** Pump `HomeScreen` on the fake clock, `pumpAndSettle`, and
drive a flow that saves. The flow completes and says so, and nothing reaches storage. Measured:
a restore showed its *"Restored …"* snackbar with the failed-write banner up and the restored
record absent from the database.

**THE MECHANISM, as far as it was measured.** The initial load does not finish, so `_loadState`
never reaches `LoadState.completed`, and `persistEvents` **withholds every write** by design
(`from != LoadState.completed`). The store queue is blocked behind the unfinished load: a save
started after `pumpAndSettle` stayed pending through ten 200 ms pumps. One real-clock yield,
`tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)))` then
`pumpAndSettle`, and the same save completed.

⛔ **WHAT IN THE LOAD NEEDS REAL TIME WAS NOT IDENTIFIED.** The yield is a workaround whose
mechanism is unknown, not an understood fix. `settleReal()` in
`test/support/restore_vocabulary_contract.dart` lends the real clock; it does not explain why the
load needs it.

⚠️ **THE EXISTING HARNESS ESCAPES THIS ONLY BY ACCIDENT.** `history_clobber_contract.dart`'s first
assertion after the pump happens to be a `tester.runAsync` storage read, and that is the yield.
It is load-bearing there and says so nowhere. **Remove or move that read and every persist in
that test is silently withheld.** Its assertions do not notice, because none of them needs a
`HomeScreen` persist to land.

**1. MUST: after pumping `HomeScreen`, lend the real clock once before driving anything that
saves.**

**2. MUST: assert the write LANDED, not only that the flow finished.** The failed-write banner
(`_FailedWriteBanner`, private, matched by type name) must be absent, or read the row back. ⛔ **A
success snackbar is not evidence of a save.**

**3. MUST NOT: read a green `HomeScreen` test as covering a persist** unless it does one of the
two above.

### ⛔ A FAKE FILE PICKER MUST SERVE A REAL FILE — `XFile.fromData` DECODES AS LATIN-1

⚠️ **Recorded 26 September 2026.** In `cross_file` 0.3.5+2, `XFile.fromData(...).readAsString()`
**ignores its `encoding` argument** and returns `String.fromCharCodes(bytes)`: a Latin-1 decode
of UTF-8. A fake picker built that way silently corrupts every non-ASCII value in the file it
serves, and **a test whose fixtures are ASCII cannot see it**, which is the case for
`restore_outcomes_test.dart`'s fake today.

**1. MUST: serve a fake picker's file from disk** (`XFile(path)`, written in `setUp` on the real
clock). Reading it is real I/O, so lend the real clock until the next screen is up.

**2. MUST: include a non-ASCII value in any fixture that goes through a file read.** An
ASCII-only fixture proves nothing about decoding.

⭐ **A fake built to behave like the real thing exposed this. A fake built to make the test pass
would have hidden it.** The finding itself, and its shape-match to the corrupted records in
`AUDIT.md` §13(bf), is in `STATUS.md`, session of 26 September 2026.

### ⛔ EVERY REPRODUCTION CARRIES AN EXPLICIT `timeout`, SO A HANG ARRIVES AS A LOCATED FAILURE

⚠️ **Standing rule from 23 September 2026, and it earned that on its FIRST outing.**

A hung test is the worst possible output: it produces **no verdict, no location and no
attribution**, it holds the suite open, and it leaves orphaned `dart` and `flutter_tester`
processes behind that the next run inherits. ⭐ **A timeout converts all of that into an ordinary
red with a line number.**

```dart
}, timeout: const Timeout(Duration(seconds: 45)));
```

**1. MUST: give every reproduction and every long-running widget test an explicit `Timeout`.**

**2. MUST: print step markers through the body**, so the marker trail says where it stopped.
⭐ **On its first run this located a hang to a single statement with no bisection at all** — the
last marker printed named the line, and on its second it separated `openDatabase` from `save`
inside one fixture.

**3. MUST NOT: rewrite a test until it completes.** ⛔ **Changing the test to avoid a hang
converts a possible real deadlock into silence** — and on 23 September 2026 the hang that looked
like a harness artefact turned out, on its second appearance, to be a genuine one in a static
queue. **Diagnose it, then decide.**

⛔ **AMENDMENT, 23 September 2026 — A `Timeout` CANNOT FIRE WHEN THE CLOCK THAT WOULD FIRE IT IS
THE ONE BEING BLOCKED. The rule above is necessary and is NOT sufficient.**

`Timeout` protects against a hang in REAL time. It is **worthless against a fake-clock
deadlock** — and `testWidgets` bodies are exactly where those live. A `tester.runAsync` that
awaits a future started in the fake-clock zone blocks the test in the real zone while the fake
clock stops being pumped, so the future can never advance **and neither can the timer meant to
end it.** Measured: a `Timeout(Duration(seconds: 60))` sat on such a test and **400 seconds of
silence followed**, with no output at all.

**4. MUST: print markers that reach the terminal in REAL time, and bound the run from OUTSIDE.**
A marker is only useful if it is visible before the process ends. ⚠️ **Do not read a running
test's output through a filter that buffers** — a `flutter test … | Select-String …` pipeline
holds everything until the pipeline completes, so a hung run shows **zero bytes** and the marker
trail added to find the hang is itself invisible. Write to a file and tail it.

⛔ **AND THE RULE'S OWN AUTHOR DID NOT FOLLOW IT THE SAME AFTERNOON — THE COUNT IS THE
ARGUMENT.** This rule was promoted to this file in the morning of 23 September 2026, off the
back of a 45-second hang. A reproduction written that same afternoon, by the same session, was
committed with **no `Timeout` and no markers**, hung, and cost the 400 seconds above before
either was added. ⭐ **That is the third time this file has recorded a rule being broken in the
act of writing about it** — see the recursion note in the workspace rules. **Attention to a rule
is not compliance with it, and the moment of promoting one is evidently not a moment of immunity
to it.**

### ⛔ ATTRIBUTION IS NOT VERIFICATION. A PROVENANCE MARKER SAYS WHERE A CLAIM CAME FROM, NEVER WHETHER IT IS TRUE

⚠️ **This corrects the provenance scheme itself, 23 September 2026.** `[read]`, `[report]`,
`[VERIFY]` and `[console]` record a claim's SOURCE. They are useful and they stay. ⛔ **What they
do not do, and were never able to do, is make the claim true** — and the scheme reads as though
they do, which is the defect.

⭐ **A SOURCED WRONG CLAIM IS WORSE THAN AN UNSOURCED ONE, because it survives scrutiny LONGER.**
An unattributed number invites the question "where did that come from?". An attributed one has
already answered it, so the reader moves on. **The marker satisfies the instinct that would
otherwise have checked.**

**THE INSTANCE — not restated here; it is recorded in full at the Windows-green rule below, in
the paragraph beginning "HOW THE WRONG NUMBER GOT HERE".** In short: a figure carried a CORRECT
attribution and a WRONG value, and landed in this file's own rule about unmeasured claims. The
entry even said the number was "recorded here as its finding and not as a measurement taken on
this machine" — a precise, honest statement of provenance, beside a number nothing had checked.

**1. MUST: treat a provenance marker as metadata, never as evidence.** `[report]` means chat said
it. It does not mean it is so.

**2. MUST: mark a claim's VERIFICATION STATE separately from its source**, and say plainly when a
figure is unverified — *"the Mac's figure, not measured here"* is the honest form, and it should
read as a caveat rather than as a credential.

**3. MUST NOT: let a number into a RULE without measuring it**, whatever its provenance. A rule
carrying an inflated figure invites the whole rule to be dismissed once the figure is checked,
which costs more than the number was ever worth.

⭐ **SAME FAMILY AS THE NULL-RESULT CONTROL RULE in the workspace file** — there, a null needs a
positive control because "nothing found" and "did not look" produce identical output. Here, a
verified claim and a merely-sourced one read identically. ⛔ **In both cases the output is the
same shape and only one of them means anything.**

### ⛔ `pump()` AND `pumpWidget()` REUSE THE ELEMENT TREE — STATE YOU BELIEVE YOU RESET SURVIVES

⚠️ **THREE FALSE RESULTS FROM THIS IN ONE DAY, 23 September 2026.** Flutter reuses elements
across pumps where the widget type and key match, so a new `pumpWidget` in the same test is a
REBUILD, not a fresh start. Expansion state, scroll offsets, controllers, `initState` work and
anything a `State` holds can carry into the next iteration — **especially in a loop over sizes or
text scales, where each pass looks like a clean run and is not.**

    the Brief 143 retraction        a finding withdrawn outright
    the Brief 145 nudge-card lever  the lever measured was not the one being set
    Brief 147's test 3              measured a COLLAPSED screen on every EVEN pass

⭐ **THE SHAPE: every pass produces a number, every number is plausible, and the alternating ones
are wrong.** Nothing errors. A loop that reports twelve results and got six of them from a
surviving expansion state is indistinguishable, by its output, from twelve clean measurements.

**1. MUST: assert the state you believe you set, BEFORE measuring it.** One `expect` that the
section is expanded, the list is at the top, the toggle is off. ⛔ **Setting state and measuring
state are two operations, and the gap between them is where the previous iteration lives.**

**2. MUST: force a real teardown between iterations when the subject holds state** — pump a
different widget (`SizedBox.shrink()`), or give the widget a distinct `Key` per pass so the
element cannot be reused. A `setUp`-per-case (`setUp`, not `setUpAll`) is the blunter form.

**3. MUST NOT: read a loop's results as independent measurements** unless one of the above is in
place. Treat an alternating or suspiciously uniform pattern as a harness fault until proven
otherwise — the same posture the prefs and `inMemoryDatabasePath` rules above take.

⭐ **SAME FAMILY AS THOSE TWO, DIFFERENT MECHANISM, WHICH IS WHY IT IS FILED SEPARATELY.** There a
plugin caches an instance and a database is process-scoped; here the FRAMEWORK reuses the tree.
⛔ **A reader who knows both of those will not infer this one.**

### ⛔ WINDOWS GREEN IS NOT A COMPLETE GREEN. THE MAC IS AUTHORITATIVE FOR PLATFORM-GATED BEHAVIOUR

⚠️ **Recorded 23 September 2026.** A widget test renders on the HOST. The CLI host here is
Windows, so **every `Platform.isWindows` branch is the one the Windows suite exercises, and the
other side of every one of those conditionals is never rendered.** A test covering gated
behaviour does not fail on Windows — **it passes, on the branch the host happens to be.**

**THE DENOMINATOR, measured 23 September 2026: 62 platform conditionals across 9 files in
`lib/`** — `constants`, `event_record`, `storage_boot`, `help_screen`, `home_screen`,
`walkthrough_screen`, `backup_service`, `ios_capture_bridge`, `notification_service`. That is
the surface on which a Windows green says nothing.

⛔ **THIS HAS ALREADY COST A REAL DEFECT, AND THE TEST THAT PINS IT SAYS SO IN ITS OWN HEADER —
written BEFORE the divergence recurred.** `help_section_spacing_test.dart`:

> ⛔ **THIS TEST IS ONLY VALID BECAUSE THE PLATFORM CONDITIONAL IS GONE, AND A FUTURE READER WHO
> RE-INTRODUCES ONE MUST KNOW THAT.** The defect it pins was **invisible to this test's own
> harness**. The fourth gap sat inside `if (Platform.isWindows)`, and the CLI host IS Windows —
> so a widget test rendered the branch that was already correct, measured `12, 12, 12, 12`, and
> reported uniform. On Android the same screen measured **12, 12, 12, 0**.

⭐ **THE RULE AND THE FIX WERE THE SAME CHANGE THERE**: removing the guard leaves one code path,
so the test exercises what Android runs. `help_no_platform_gap_test` exists to stop the guard
coming back quietly.

⚠️ **AND IT RECURRED ANYWAY. As at 23 September 2026 the two machines disagree, live:** this
suite reports **982 passing, zero failing**, while the Mac reports **nine failures** at the same
commit across `a11y_batch_render_comparison`, `drawer_contents` and `help_section_spacing`.

**THE NINE, BROKEN DOWN — corrected 23 September 2026, and the original wording is quoted below
rather than deleted.** Of the nine, **three were SDK skew** and **six were the app rendering
differently**. Of those six, **ONE was a real user-facing defect** — a RenderFlex overflow from
150% text scale on narrow widths — **four were the spacing test measuring outer render boxes
rather than painted boundaries**, and **one was a correct census difference**.

> ⛔ **THIS LINE READ, until 23 September 2026:** *"**six of them a real accessibility defect**
> (the Mac's finding, recorded here as its finding and not as a measurement taken on this
> machine; Windows cannot see it, which is the whole point)."*

⛔ **HOW THE WRONG NUMBER GOT HERE IS THE PART WORTH KEEPING, because an UNMEASURED CLAIM REACHED
A RULE ABOUT UNMEASURED CLAIMS.** The six came from chat, was written into this file the same
hour, and was **attributed rather than verified** — the entry even says so, in the words now
quoted above, and the attribution was treated as sufficient. ⚠️ **It is not.** Naming a claim's
source records where it came from; it does nothing about whether it is true, and a sourced wrong
number reads *more* authoritative than an unsourced one, not less. Brief 145 Part B later
withdrew the underlying flush-cards claim outright: `_StatusBand` carries a 12px margin and every
PAINTED gap measures 12.0 — so four of the six were an instrument reading the wrong boundary,
which is this file's most-recorded failure shape, committed inside the entry describing it.

⭐ **THE RULE IS UNCHANGED AND WAS NEVER IN DOUBT.** The Windows suite cannot see behind a
`!Platform.isWindows` guard. Only the evidence was overstated — which is exactly the correction
that has to be visible, because a rule carrying an inflated number invites the whole rule to be
dismissed when the number is checked.

⚠️ **AND A SECOND INSTANCE ARRIVED THE SAME DAY, IN THE OPPOSITE FAILURE MODE — record both,
because the two look nothing alike.** The Mac's `settings_nudge_card_layout_test` (7c46068)
passes there and fails **all 12 of its cases** here with `Found 0 widgets with text
"Notifications are off"`: the nudge card sits behind `Platform.isAndroid`, so Windows renders no
card at all.

    gated behaviour RENDERED DIFFERENTLY on the host   -> silent FALSE PASS   (help_screen)
    gated behaviour ABSENT on the host                 -> loud FAIL           (nudge card)

⭐ **The loud one is the safe one.** A test for a widget the host cannot render fails on its
finder and is impossible to miss; a test for a widget the host renders on the *other branch*
passes and is impossible to notice. ⛔ **So a platform-gated test failing on Windows is not
necessarily a defect, and a platform-gated test PASSING on Windows is not necessarily coverage.**
Neither verdict means what it appears to.

⭐ **AMENDMENT, 23 September 2026 — WHAT A PLATFORM-GATED TEST SHOULD ASSERT. This is an
amendment to the entry above rather than a rule of its own, and the distinction is the reason it
was needed: everything above DESCRIBES the two failure modes and none of it PRESCRIBES what to
write instead.** ⚠️ The gap surfaced because Brief 149 is implementing the prescription on the
Mac while the description already sat in this file — a description that had been read several
times without anyone noticing it answered a different question.

**A platform-gated test asserts WHAT THE PLATFORM SHOULD DO, not what one platform does.**

⛔ **NEVER A SKIP — A SKIPPED TEST CANNOT FAIL.** A `skip:` on the host that cannot render the
behaviour converts a loud failure into silence, which trades the one failure mode this file
calls *safe* for the one it calls dangerous. It also reads, in a green run, exactly like
coverage.

    where the gated behaviour CAN render    -> the behavioural assertions
    where it CANNOT                         -> assert its ABSENCE, and that the
                                               screen is correct without it

⭐ **BOTH BRANCHES MUST BE CAPABLE OF FAILING.** An absence assertion that would pass on any
screen at all is not a test — "the nudge card is not here" must fail if the card appears where
it should not, and the *"correct without it"* half is what stops the absence branch degenerating
into an assertion that nothing is on screen. ⛔ **Two branches, two live assertions; a branch that
can only pass is the skip it was written to avoid, wearing an `expect`.**

**1. MUST NOT: report "the suite is green" as a release signal from Windows alone.** Say which
host. A green here means *"green on the branches Windows renders."*

**2. MUST: treat the Mac as authoritative for anything behind a platform conditional** — layout,
spacing, text scale, semantics, notification behaviour, storage fallback.

**3. MUST: prefer deleting the conditional over testing both sides of it.** One code path is
testable from either host; two are testable from neither alone.

⭐ **THE SHAPE, AND IT IS THE ONE THIS FILE KEEPS RECORDING: the check ran, the output was
well-formed, and it measured something adjacent to the question.** Same family as the
one-em-per-glyph font and the `PrintWindow` captures — a harness silently substituting its own
conditions for the ones that ship. ⛔ **Ask what the harness is standing in for, not only whether
it is working.**

### ⚠️ `git stash` AND `pubspec.lock` — A FLUTTER COMMAND CAN STRAND A STASH

⚠️ **Recorded 23 September 2026. A warning, not an incident: the work was recovered intact.**

**`flutter analyze`, `flutter test` and `flutter pub get` all run `pub get` and can REWRITE
`pubspec.lock`** — transitive packages get new patch versions without anyone asking. So this
sequence fails:

    git stash                      # park a change to compare against HEAD
    flutter analyze <file>         # <-- writes pubspec.lock
    git stash pop                  # ⛔ "local changes would be overwritten by merge"

⛔ **The pop is REFUSED and the stash is KEPT** — git says so, and the work is recoverable with
`git checkout pubspec.lock && git stash pop`. ⚠️ **But the failure arrives while the working
tree looks empty**, which is the moment it reads as lost.

**1. MUST: `git checkout pubspec.lock` before `git stash pop`** if any Flutter command ran in
between. It is generated, and this project does not commit dependency drift as a side effect of
running a checker.

**2. MUST NOT: stash in order to compare against HEAD when a Flutter command is part of the
comparison.** ⭐ **Use `git show HEAD:<path>` or `git diff` instead** — neither touches the
working tree, and the question "was this lint here before?" is answerable without stashing at
all.

⭐ **WHY IT IS HERE AND NOT ONLY IN A BRIEF:** the trap is invisible until the pop fails, the
stash-pop pair is what a careful person reaches for precisely when they are being careful, and
`pubspec.lock` is touched by the very commands used to check a change is safe.

### ⛔ ANNOTATION VERIFICATION — A SENTENCE CAN BE BROKEN WITH ZERO DELETIONS

⚠️ **Inserting into the middle of a sentence splits it in two while deleting nothing.**
Every word survives, in order. **Word counts pass. Deletion counts pass. `git diff
--stat` shows insertions only.** The document now contains a rewrite presented as an
annotation.

**The symptom is not a failed check. It is a passing one.** Happened 8 September 2026 on
`AUDIT.md` §8, where an annotation landed mid-sentence and every count-based check
reported clean.

**1. MUST: compare each affected original sentence AS A WHOLE, whitespace-normalised,
before and after.** Nothing else catches it — not word counts, not deletion counts, not
character deltas, not `diff --stat`.

**2. MUST: run a positive control on the comparison itself.** Deliberately mangle one
known sentence and confirm the check REPORTS it. A comparison that returns zero breaks
because it is not looking is indistinguishable from one that returns zero because there
are none.

**3. MUST: adjudicate every flag before believing it — the naive check has KNOWN
false-positive classes, and this list will grow**, all confirmed 8 September 2026 on real edits where the text was
byte-identical:

    markdown HEADINGS   no terminal punctuation, so a heading glues to the sentence
                        after it; inserting between them dissolves the false join
    BOLD terminators    a sentence ending `.**` defeats a `(?<=[.!?])\s+` lookbehind,
                        so it glues to the next sentence.  Split on `(?<=[.!?])\**\s+`
    BLOCKQUOTE markers  a `>` continuation line changes the leading-token count without
                        changing a word.  Strip `^\s*>+\s?` before comparing
    TABLE rows          a whole table has no terminal punctuation and normalises to ONE
                        pseudo-sentence, so any cell edit flags the entire table
    BULLET runs         same cause: a run of bullets with no full stops normalises to one
                        pseudo-sentence that spans SECTIONS, so an edit anywhere after it
                        changes where it ends and flags the whole run

**Strip heading lines and blockquote markers, split on `(?<=[.!?])\**\s+`, and hand-check
what survives.** ⭐ **A flag is a candidate, not a finding** — the same rule this project
already applies to null results.

### ⛔ DRIVE THE COMPOSITION, NOT THE UNIT — WHERE THE DEFECT LIVES IN THE WIRING, A UNIT TEST PASSES

⚠️ **Recorded 24 September 2026, from Brief 166.** The pre-migration backup — the user's entire
history in plaintext — was being written to the Documents directory, which OneDrive's Known
Folder Move redirects into cloud sync on Windows.

⛔ **THE FUNCTION THAT WRITES IT CANNOT BE WRONG ABOUT WHERE IT WRITES.**
`writeMigrationBackup(Directory dir, String? rawJson)` takes the destination **as a parameter**.
The decision is made one frame up, at its single call site in `StorageBoot.init()`. **The fix was
one argument** (`9eed24f`, 24 September 2026; the Documents call had stood since `9461f27`,
25 August 2026).

⭐ **SO A TEST OF THE HELPER WOULD HAVE PASSED AGAINST BOTH VERSIONS, BY CONSTRUCTION** — hand it
a directory, it writes there, green, before and after. It would pin the helper and not the
decision, and it would have read exactly like coverage of the defect.

**1. MUST: ask WHICH FRAME OWNS THE DECISION before choosing what a test drives.** ⭐ **The tell
is cheap and mechanical: if the value under test arrives as a PARAMETER, the function taking it
is not where the defect can be.** Follow it up until you reach the frame that chooses it.

**2. MUST: drive the real entry point wherever the behaviour is a composition of choices.**
`test/migration_backup_destination_test.dart` drives `StorageBoot.init()` with two distinct
directories, so *"which one did it choose"* is answerable.

**3. MUST NOT: read a green unit test as coverage of a call-site defect.** It is evidence about
the unit and says nothing about the wiring — which is where the last two defects in this area
both were.

⭐ **SECOND INSTANCE, SAME DAY AND SAME FILE, IN THE PLACEMENT DIMENSION RATHER THAN THE TEST
ONE.** Brief 175d's migration-recovery check had to live in `StorageBoot.init()` too: putting it
inside `migrateJsonToSqlite` — the obvious place — would have skipped it on exactly the launches
that reach the insert path, because that function returns `alreadyMigrated` early when the state
says so. ⛔ **The composition decided the behaviour there as well, and the obvious placement was
a live bug.**

⚠️ **THIS RULE ALREADY EXISTED IN THAT TEST'S OWN HEADER, WHICH IS THE ARGUMENT FOR PROMOTING IT
HERE.** The header says the test drives the real call site *"and would pass against the old code,
which is exactly the failure this test exists to avoid."* ⭐ **A test header is read by whoever
opens that test — never by whoever is about to write the next one.** Same reason the fake-clock
rule was promoted out of the Change Register.

⭐ **KINSHIP, NAMED SO THIS IS NOT READ AS NOVEL: the workspace rules' *derived scope is not the
same as complete coverage*** — a check derived from an artefact says nothing about anything
downstream of it. ⛔ **This is that shape one level down and pointing UPWARD: a test derived from
a function says nothing about the frame that CALLS it.** Filed separately because the tell is
different and is specific to test design — a parameter, not a payload boundary.

### ⛔ STRING MATCHING IS ACCEPTABLE WHEN THE OUTPUT IS A LABEL. THE SAME MATCHER EMITTING TEXT FAILS OPEN

⚠️ **Recorded 24 September 2026, from Brief 175b.** This project treats matchers with suspicion
everywhere else — the marker search that matched CLOSED inside its own negation, the range
substitution that fabricated endpoints. ⭐ **Here one was accepted deliberately, and the reason
generalises.**

**THE INSTANCE, read from `sqflite_common` 2.5.8 `lib/src/exception.dart`.** `getResultCode()`
lowercases the raw native message, `indexOf`s three prefixes — `'(sqlite code '`, `'(code '` and
iOS's `'code='` — `int.tryParse`s what follows, and **returns `int?`**. On a miss it returns
`null`. It is string matching on a message that can embed bound arguments, one of which is
`notes`, free text the user typed.

⭐ **AND IT IS SAFE TO BUILD ON, BECAUSE OF WHAT A NO-MATCH EMITS.** An unrecognised message
yields **no code** — nothing of the message escapes through an `int`. ⛔ **The identical matcher
returning a `String` would, on the same miss, emit the input it failed to classify**: the raw
message, with the user's text in it, into a crash report. **Same patterns, same coverage, same
author — opposite failure direction, decided entirely by the return type.**

**1. MUST: judge a matcher by what a NO-MATCH produces, before judging its patterns.** Nothing,
or the input? That is the question the pattern list cannot answer.

**2. MUST: make the unmatched case the closed one wherever the output leaves the device, or
reaches a user, or is acted on.** A classifier that emits a LABEL fails closed by construction:
an unrecognised input simply is not labelled.

**3. MUST NOT: substitute a matcher's coverage for its failure direction.** ⭐ **Coverage bounds
how OFTEN it fires. The output type bounds what a MISS COSTS** — and only the second one is a
safety property.

⭐ **AND THE RELATED RULE, DELIBERATELY NOT RESTATED HERE — "EXPORTED" IS NOT "REACHABLE".** The
reason that classifier is rebuilt from categorical accessors at all is that `sqflite_common`
exports only the abstract `DatabaseException` (`sqlite_api.dart`, a `show` clause naming exactly
that one type), while `message` is declared on `SqfliteDatabaseException`, which is not exported.
⛔ **Confirm what a type EXPOSES before designing around it; do not infer it from the name.**
**IT IS NOT RESTATED HERE BECAUSE IT IS ALREADY WRITTEN TWICE, AND THE TWO SAY DIFFERENT
THINGS** — checked rather than assumed when this pointer was written: the generalised rule sits
on `_categoricalValueFor` in `lib/main.dart`, and the package fact with the cost it accepts —
that the human-readable SQLite text does not survive — sits on `categoricalDatabaseErrorText` in
`lib/models/event_store_sqlite.dart`. Both cited by symbol, not by line, per the rule above.

⭐ **KINSHIP: *bias a resolution instrument toward OVER-reporting*.** ⛔ **That rule chooses which
error to PREFER once both are possible. This one asks whether the dangerous error is possible AT
ALL** — and that is a property of the output type, not of the patterns.

---

## Change Register

All code changes logged in:
`C:\Users\wjl25\OneDrive\Projects\App Dev\Claude\Medical Event Recorder — Change Register.md`
