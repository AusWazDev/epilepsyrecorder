# Medical Event Recorder — Session Log

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

Also note earlier commits not yet in Change Register:

| What | Commit |
|------|--------|
| iOS setup — awesome_notifications deployment target 15.0, Podfile, AppDelegate | `f693b57` |
| Add quick-log notification service + Help screen | `b5980de` |
