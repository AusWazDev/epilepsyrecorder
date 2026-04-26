# Medical Event Recorder — Session Log

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
| CR-41 | Change | Sentry crash reporting — sentry_flutter added, SentryFlutter.init() wraps appRunner in main.dart, DSN hardcoded for test builds | TBD |

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
- After building, update CR-41 commit hash in this table
