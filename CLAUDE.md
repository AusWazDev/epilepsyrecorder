# Medical Event Recorder — Claude Code Context

> **Auto-loaded by Claude Code on every session start.**
> This file covers code context only — tech stack, key files, architecture, gotchas.
>
> ⭐ **NOT FOR: anything the documents below are authoritative for.** This file is a working index and a gotcha list. **Architecture → `docs/ARCHITECTURE.md`** (already deferred to below, and that deferral is correct — it is the authority, not this file). **Schema → `docs/DATA-MODEL.md`. Design, layout and UX → `docs/design-audit/AUDIT.md`. Session history → `STATUS.md`.**
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
    condition.dart        — condition + condition_observation. TABLES ONLY, no UI, zero rows
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

## Working Rules — verification

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

---

## Change Register

All code changes logged in:
`C:\Users\wjl25\OneDrive\Projects\App Dev\Claude\Medical Event Recorder — Change Register.md`
