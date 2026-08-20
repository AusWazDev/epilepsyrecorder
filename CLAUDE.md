# Medical Event Recorder — Claude Code Context

> **Auto-loaded by Claude Code on every session start.**
> This file covers code context only — tech stack, key files, architecture, gotchas.
> **For the full derived architecture — capture model, all five record-creation
> sites, the two notification solutions, storage shape — see `docs/ARCHITECTURE.md`,
> which is regenerated from the code at each version bump.**
> For current status, blockers, and next steps → fetch the ClickUp handoff document:
> **"Project Context & Status — Claude Handoff Document"** (Team Space, workspace 90161564576)
> Keep this file updated when architecture or key patterns change.

---

## Project Identity

- **App name:** Medical Event Recorder (MER)
- **Developer:** Notiva
- **GitHub:** branch `MedicalEventRecorder`
- **Version:** 1.1.0+5 (unreleased). Last App Store release was 1.0.2. Never hardcode this — it is read at runtime from the platform package metadata by `lib/app_info.dart`
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
- `shared_preferences` — local data storage (no backend, no cloud)
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
    event_record.dart     — EventRecord model, SharedPreferences serialisation, CSV export
    backup.dart           — JSON backup envelope, parsing/validation, id-merge restore plan
  screens/
    home_screen.dart      — event list, Getting Started card (first use), Help link card (returning), splash redirect
    log_event_screen.dart — new event form
    history_screen.dart   — event history, CSV export
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
`AwesomeNotifications().initialize()` reassigns `UNUserNotificationCenter.delegate`
to itself and breaks the native locked-screen handler. `onActionReceived` also
returns immediately on iOS. **Do not "fix" either by removing the platform check.**

⚠️ **iOS creates event records in Swift**, not Dart —
`AppDelegate.handleQuickLogStart` writes `flutter.epilepsy_event_records_v1` in
`UserDefaults` directly, and `EndMEREventIntent` (the Live Activity button, in the
widget extension process) mutates it. Neither passes through `writeEventPayload`.
Anything added to the Dart write path is absent on the iOS quick-log path.

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

`ic_notification_large.png` is a white/flat icon on a transparent background. The blue circle background comes entirely from the notification's `color` property — **not** from the asset itself and **not** reliably from the channel `defaultColor` (Android caches channel settings; updates to an existing channel may not take effect).

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
- All events stored in SharedPreferences as one JSON array under `kEventStorageKey` — no SQLite, no cloud sync
- No user accounts, no analytics — privacy-first design
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
