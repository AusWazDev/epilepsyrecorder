# Medical Event Recorder — Claude Code Context

> **Auto-loaded by Claude Code on every session start.**
> This file covers code context only — tech stack, key files, architecture, gotchas.
> For current status, blockers, and next steps → fetch the ClickUp handoff document:
> **"Project Context & Status — Claude Handoff Document"** (Team Space, workspace 90161564576)
> Keep this file updated when architecture or key patterns change.

---

## Project Identity

- **App name:** Medical Event Recorder (MER)
- **Developer:** Notiva
- **GitHub:** branch `MedicalEventRecorder`
- **Version:** 1.0.0+1 (locked for store submission)
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

- Flutter (Dart) — cross-platform (Android, iOS, Windows, macOS, Web)
- `shared_preferences` — local data storage (no backend, no cloud)
- `share_plus` — CSV export
- `url_launcher` — external links (privacy policy, support)
- `msix` — Windows Store packaging

---

## Project Structure

```
lib/
  constants.dart          — app-wide constants (kDisclaimerVersion, URLs, company name)
  main.dart               — entry point, calls NotificationService.init() before runApp()
  models/
    event_record.dart     — EventRecord model, SharedPreferences serialisation
  screens/
    home_screen.dart      — event list, Getting Started card (first use), Help link card (returning), splash redirect
    log_event_screen.dart — new event form
    history_screen.dart   — event history, CSV export
    about_screen.dart     — APP card, LINKS card, LEGAL card, APP DATA (reset) card
    disclaimer_screen.dart — versioned disclaimer accept gate
    help_screen.dart      — How to use guide; Quick Log Notification setup with live permission status
  services/
    notification_service.dart — awesome_notifications persistent quick-log notification; SilentAction buttons; SharedPreferences cross-isolate storage
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

### Quick-log notification
- `awesome_notifications` v0.11.0 — iOS uses `ActionType.Default` (prompts FaceID/unlock, then logs reliably); Android uses `SilentAction` (fires without opening app)
- Channel key `mer_active_v2` — v2 forced recreation after `defaultColor` + `NotificationImportance.Default` changes
- `locked: false` — notification is in the standard (non-system) section so it shows expanded by default; can be swiped away but restores on next app open via `_restoreNotification()`
- `@pragma('vm:entry-point')` required on BOTH the class AND the static callback
- Notification permission denied → app still loads (try-catch in `init()`); Help screen shows orange status + link to Android notification settings via `showNotificationConfigPage()`
- Large icon: `drawable/ic_notification_large.png` (flat PNG from mipmap-xxhdpi, not adaptive icon)
- Small icon: `resource://drawable/ic_launcher_foreground` with `defaultColor: 0xFF0D4F82`

### Disclaimer versioning
- `kDisclaimerVersion` in `constants.dart` — bump this string to re-prompt all users
- Stored as `disclaimerAcceptedVersion` in SharedPreferences (NOT a boolean)
- `_SplashRedirect` in `home_screen.dart` reads this key — **do not revert to boolean**

### Data storage
- All events stored in SharedPreferences as JSON — no SQLite, no cloud sync
- No user accounts, no analytics — privacy-first design

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
