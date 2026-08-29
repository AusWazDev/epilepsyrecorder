# Medical Event Recorder — Claude Code Context

> **Auto-loaded by Claude Code on every session start.**
> This file covers code context only — tech stack, key files, architecture, gotchas.
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
    event_record.dart     — EventRecord model, serialisation, CSV export (16 columns, marker v4)
    event_store_sqlite.dart — SqliteEventStore, the DDL, and every migration v2..v9
    storage_boot.dart     — picks the store at boot: SQLite, or shared_preferences on a fallback launch
    storage_migration.dart — the one-way drain from the shared_preferences array into SQLite
    capture_inbox.dart    — the cross-process inbox the iOS native path and the Android isolate write into
    capture_instruction.dart — parses what those paths leave behind
    ios_capture_bridge.dart — the Swift-side handoff
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

## Change Register

All code changes logged in:
`C:\Users\wjl25\OneDrive\Projects\App Dev\Claude\Medical Event Recorder — Change Register.md`
