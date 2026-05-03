# Medical Event Recorder — Session Log

---

## Session: 3 May 2026 — Mac (Claude Code CLI)

**MER v1.0.1 SUBMITTED to Apple App Store** ✅
- Submitted 3 May 2026 — Waiting for Review
- Submission ID: `063bcd45-6947-491e-b34b-b17b9e89e1e7`
- Version 1.0.1, Build 2
- iPhone + iPad (TARGETED_DEVICE_FAMILY = "1,2")
- iPad screenshots uploaded (6 × 2048×2732 from Danny's iPad)

**What was done:**
- Bumped version to `1.0.1+2` in pubspec.yaml. Commit `6168af4`.
- Changed `TARGETED_DEVICE_FAMILY` from `1` to `"1,2"` across all Xcode configurations (Debug/Profile/Release). Commit `6168af4`.
- Built IPA with `flutter build ipa --release` (23.3MB)
- Uploaded via Xcode Organizer → App Store Connect → Distribute App
- Created v1.0.1 in App Store Connect, uploaded 6 iPad Pro 13" screenshots
- Answered export compliance: None of the algorithms (no custom encryption)
- Submitted for App Store review

**Next:**
- Await Apple review result (email to apps@notiva.com.au, up to 48 hours)
- Update Change Register on Windows with session commits
- Complete TestFlight internal testing setup — add Waz and Paula as Users in App Store Connect, then add to NOTIVA Internal group
- Update Notiva privacy policy with Sentry disclosure

---

## Session: 29 April 2026 — Mac (Claude Code CLI)

**MER v1.0.0 SUBMITTED to Apple App Store** ✅
- Submitted 29 April 2026 — under review (up to 48 hours)
- Bundle ID: `au.com.notiva.medicaleventrecorder`
- Version 1.0.0, Build 1
- iPhone only for v1.0 (iPad deferred to v1.0.1)
- Distribution certificate: Apple Distribution: NOTIVA (B7LWF6Z674)
- IPA built via `flutter build ipa --release`, uploaded via Xcode Organizer

**What was done:**
- Fixed DEVELOPMENT_TEAM — unified all configurations to Notiva `B7LWF6Z674`. Commit `0e6bd04`.
- Changed TARGETED_DEVICE_FAMILY from "1,2" to "1" (iPhone only). Commit `0e6bd04`.
- Created Apple Distribution certificate for Notiva in Xcode
- Built App Store IPA (23.3MB) — `flutter build ipa --release`
- Resolved export compliance — no custom encryption (None of the algorithms)
- Set App Information: Category (Medical), Content Rights
- Submitted for App Store review

**Next:**
- Await Apple review result (email to apps@notiva.com.au, up to 48 hours)
- Update Change Register with today's commits
- Plan v1.0.1: iPad support (TARGETED_DEVICE_FAMILY = "1,2"), iPad screenshots, lock-screen-without-unlock (Phase 5)

---

## Session: 29 April 2026 — Windows

**MER v1.0.0 PUBLISHED on Microsoft Store** ✅
- Store ID: `9PMJ09CDSL6K`
- Published 29 April 2026 — live and available to customers
- Email confirmed: "Your submission for the app Medical Event Recorder has been processed."
- URL: https://apps.microsoft.com/detail/9PMJ09CDSL6K

---

## Session: 26 April 2026 (evening) — Windows (Claude Code CLI)

**What was done:**

- **MS Store tax/payout banner resolved** — ticket #2604210030008414 cleared. Blocker removed.
- **DEF-37: Quick Log Notification section hidden on Windows** — Help screen was showing the notification section on Windows (mobile-only feature). Wrapped `_Section` in `Platform.isWindows` guard. Commit `b289a26`.
- **MSIX signing fixed** — `msix` package passes certificate password through cmd.exe where `!`, `%`, `[` are mangled, causing silent fallback to test cert. Fix: `sign_msix: false` in pubspec.yaml, sign manually with `signtool.exe` via PowerShell. Signing password removed from pubspec.yaml permanently. Commit `8801097`.
- **Microsoft OpenJDK 21 installed** — required by `sentry_flutter` transitive `jni` dependency for Windows compilation. Build-time only, not in MSIX.
- **MER MSIX v1.0.0.0 built and submitted to MS Store for certification** — Store ID: `9PMJ09CDSL6K`. Signed with `CN=520D1E31-3542-4059-8124-5366ECCA4994`. Submitted 26 April 2026.
- **Change Register updated** — entries 41–42 added (DEF-37, MSIX build/signing).
- **ClickUp updated**.

**Tested:**
- Windows smoke test (exe) — all functions confirmed ✅
- Norton 360 flagged as suspicious (expected for self-signed new exe — not an issue for Store version) ✅

**Next:**
- Await MS Store certification result for MER (email to apps@notiva.com.au)
- Await MS Store certification result for SoundFind (email to apps@uniquegames.com.au)
- Await illion CSC-207240 — unblocks Google Play and Apple for both apps

---

## Session: 26 April 2026 (afternoon) — Mac (Claude Code CLI)

**What was done:**

- **DEF-36: Reverted iOS notification action type to Default** — `SilentBackgroundAction` (added in commit `368bb34`) was confirmed unreliable in release builds on a locked device. Background Dart isolate does not execute consistently in release mode. Reverted both buttons (`Log Event Now` and `Event Ended`) to `ActionType.Default` for iOS. Requires FaceID/unlock but works 100% reliably. Lock-screen-without-unlock deferred to Phase 5 (`UNNotificationServiceExtension`). Commit `9877054`.
- **Installed clean release build** on Wazza's iPhone 15 Pro Max via `xcodebuild` + `xcrun devicectl` (DerivedData path required — flutter build path lacks proper framework signing).
- **Confirmed working:** Both notification buttons work after FaceID unlock. Active event banner shows/clears correctly.

**Tested on device:**
- Wazza's iPhone 15 Pro Max (iOS 26.3.1) — full notification flow confirmed with Default action type ✅

**Next (Windows session):**
- Add Change Register entry for DEF-36 (commit `9877054`)
- Update pending entries from previous session (DEF-35, CR-36, CR-37, CR-38)
- Take iOS App Store screenshots from Wazza's iPhone 15 Pro Max (connected via USB)
- See ClickUp handoff doc for screenshot spec and screen list

**Phase 5 backlog (future release):**
- Lock-screen-without-unlock via `UNNotificationServiceExtension` — proper native iOS extension that runs in its own process, independent of Flutter app lifecycle

---

## Session: 26 April 2026 — Mac (Claude Code CLI)

**What was done:**

- **DEF-35: iOS background isolate crash** — `SharedPreferencesPlugin` not registered in awesome_notifications background isolate. Fixed by adding `SharedPreferencesPlugin.register(...)` and `import shared_preferences_foundation` to `AppDelegate.swift`. Commit `52b41b9`.
- **CR-36: Active Event Banner** — HomeScreen now shows a red "Event in progress" banner above the Record Event button when `mer_active_event` is set in SharedPreferences. Shows start time, elapsed duration, and one-tap End Event button. Banner clears when event is ended via app or notification. Commit `a42594f`.
- **CR-37: iOS Help screen notification instructions** — "QUICK LOG NOTIFICATION" section in HelpScreen is now platform-aware. iOS: long-press instructions + Show Previews → Always path. Android: existing instructions unchanged. Commit `a42594f`.
- **CR-38: iOS feedback notification wording** — Confirmation shown after "Log Event Now" now says "Long-press the notification to end the event" on iOS. Commit `fc01e97`.

**Tested on device:**
- Wazza's iPhone 15 Pro Max (iOS 26.3.1) — full notification flow confirmed ✅
- Paula's iPhone (iOS 16.7.15) — notification flow confirmed, UI sizing confirmed ✅

**Next (Windows session):**
- Add Change Register entries for DEF-35, CR-36, CR-37, CR-38 (commits above)
- Take iOS App Store screenshots from Wazza's iPhone 15 Pro Max (connected via USB)
- See ClickUp handoff doc for screenshot spec and screen list

---

## Pending Change Register Entries (add on Windows)

| ID | Type | What | Commit |
|----|------|------|--------|
| DEF-35 | Defect fix | iOS background isolate crash — SharedPreferencesPlugin not registered | `52b41b9` |
| CR-36 | Change | Active Event Banner on HomeScreen | `a42594f` |
| CR-37 | Change | iOS Help screen notification instructions (platform-aware) | `a42594f` |
| CR-38 | Change | iOS feedback notification wording | `fc01e97` |
| DEF-36 | Defect fix | Revert iOS notification action type to Default — SilentBackgroundAction unreliable in release builds | `9877054` |
| CR-41 | Change | Sentry crash reporting — sentry_flutter added, SentryFlutter.init() wraps appRunner in main.dart, DSN hardcoded for test builds | `cab928b` |

Also note earlier commits not yet in Change Register:

| What | Commit |
|------|--------|
| iOS setup — awesome_notifications deployment target 15.0, Podfile, AppDelegate | `f693b57` |
| Add quick-log notification service + Help screen | `b5980de` |

## TODO — Next Windows Session
- Update Notiva privacy policy (notiva-site) with Sentry disclosure — same pattern as SoundFind privacy update (short version callout, new Sentry section, rights section). Commit and deploy to notiva.com.au.
- Add DEF-36 and CR-41 to MER Change Register (OneDrive doc)
- Update ClickUp handoff doc

## Notes for Mac Claude

- `sentry_flutter: ^9.0.0` added to `pubspec.yaml`
- `main.dart` updated — DSN hardcoded, `SentryFlutter.init()` wraps `appRunner`
- Run `flutter pub get` then build and side-load to iPad as normal
- No `--dart-define` needed, no dSYM upload — dSYM upload is for final App Store build only
- CR-41 commit hash updated: `cab928b`
- Confirmed working on Wazza's iPhone 15 Pro Max ✅ — ready to install on iPad when available
