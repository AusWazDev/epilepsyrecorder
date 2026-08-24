# iOS Device Test Checklist — Medical Event Recorder

Complete every item on a physical device before uploading a build to App Store Connect.
Do not submit until all boxes are checked. No exceptions.

**Verified against the code on 22 August 2026 (AEST)** — `ios/Runner/AppDelegate.swift`,
`ios/MERWidget/`, `lib/services/notification_service.dart`, `lib/screens/home_screen.dart`,
`lib/services/backup_service.dart`, `lib/models/backup.dart`, `lib/models/event_record.dart`.
Where a step names a file and line, that is what the code does today, not what an audit
inferred. Re-verify the citations if those files change.

---

## Why this exists

Seven iOS notification failures are recorded. All seven were caught on a physical device,
by a person, before submission — none reached Apple. The process works; what has never
existed is a written form of it, so it depends on remembering.

Four of the seven shared one root cause: iOS notification handling depending on Dart
across a boundary that is unreliable in release builds on a locked device. CR-42 moved iOS
to a native Swift handler. **The last commit touching `AppDelegate.swift` or
`ios/MERWidget/` is `192ae40`, 6 May 2026** — the only later `ios/` change is `5966425`
(4 June 2026), which added an Info.plist export-compliance key and no notification code.
So this checklist confirms an unchanged design still holds. It is a regression check, not
a hunt for new bugs.

**Nothing here is testable on a simulator.** Lock-screen actions, Live Activity,
authentication policy and App Group reconciliation all require hardware.

---

## 0. Preflight — verify the build before touching a device

**Run this first. If it fails, stop: there is no point testing a build that is not the
build you think it is.**

```
flutter build ios --release && tool/verify_release_signing.sh
```

It must print `OK — all assertions passed.` and exit 0.

- [ ] `tool/verify_release_signing.sh` exits 0 against the build about to be tested

### Why this is step 0

Two defects reached hardware because **every automated check in this repo is blind to
build output**. `flutter analyze` and `flutter test` sign nothing and link nothing; the
Swift guard tests read source text.

| Defect | How long | What passed anyway |
|---|---|---|
| `CODE_SIGN_ENTITLEMENTS` missing from Runner's **Release** configuration, so the app was signed without the App Group while the widget extension had it | CR-42, 4 May 2026 → `824cd16`, 24 Aug 2026 — **nearly four months, including shipped 1.0.2** | analyze, tests, and the device checklist itself |
| The 16.2 raise broke the Release **link** outright | `efae60d`, hours | analyze, tests, subtree hashes |

The script asserts, on the built artefacts: the App Group Runner carries matches what
`Runner.entitlements` declares; **MERWidget carries the same group**, so the two cannot
drift apart — which is the actual defect, because an unentitled suite name does not fail,
it silently gets a private store; the application-identifier and team match the project; the
deployment floor agrees across `Info.plist`, both binaries and the Release configuration;
and Runner links `libc++.1.dylib`.

It also refuses to run against a stale artefact, and says which source file is newer. A
check that passes on yesterday's binary is worse than no check.

**This section is numbered 0 deliberately** — the sections below are referenced by number
from the Change Register, so renumbering them would invalidate those references.

---

## 1. When to run

Every iOS build that goes to App Store Connect. No exceptions for "Dart-only" changes —
the whole point of the failure history is that the Dart and native sides interact in ways
neither is visible from alone.

Run the full sequence, not a subset, whenever any of these change:

- `ios/Runner/AppDelegate.swift` or anything in `ios/MERWidget/`
- `ios/Podfile.lock` — a dependency moved
- `IPHONEOS_DEPLOYMENT_TARGET` or anything in `project.pbxproj`
- The Flutter SDK on the build machine (leaves no trace in the lock file — record it by hand)
- App Group or entitlements configuration
- `lib/services/notification_service.dart` — its iOS guards are what keep Dart out of the
  native path

## 2. Before you start — record these

Fill in every time. The iOS version being absent from past records is the single largest
gap this checklist closes.

| Field | Value |
|---|---|
| Date (AEST/AEDT) | |
| Version + build | |
| Device model | |
| **iOS version** | |
| Build type | release / ad-hoc / TestFlight |
| Flutter SDK version on build machine | |
| Tester | |

**Check Settings → Notifications → Medical Event Recorder → Show Previews.** Record the
value. This does **not** make the lock-screen action unreachable when it is not "Always" —
per the app's own copy (`lib/screens/help_screen.dart:106`, `:226`, `:271`), starting an
event from the lock screen then **requires a password** instead of starting instantly.
Test at least once with Show Previews set to "Always"; testing the password-gated variant
as well is worthwhile, because that is the default users arrive at.

- [ ] Show Previews value recorded: ______________

## 3. The core sequence

Run in order, on a real device, on a release or ad-hoc build. Not a debug build.

### 3.1 Launch → the standing notification is posted

Force-quit the app, then launch it.

The notification is posted from `applicationDidBecomeActive`
(`AppDelegate.swift:81-91` → `restorePersistentNotification`, line 115) on a 1-second
trigger, so **it appears about a second after launch while the app is still in the
foreground**, as a banner (`willPresent` returns `[.alert, .sound]`, line 202). It is
**silent** (`content.sound = .none`, line 367) and its body reads "Long-press this
notification to log an event".

This is **not** an Android-style ongoing or foreground-service notification. iOS has no
such thing here: it is an ordinary local notification that stays in Notification Centre,
the user can dismiss it, and there is no way to prevent that. On every foreground the
previous copy is removed and re-posted (`removeDeliveredNotifications`, line 361).

- [ ] Notification appears shortly after launch, silently, with body "Long-press this notification to log an event"
- [ ] Background the app — notification still present in Notification Centre
- [ ] Long-press it — the "Log Event Now" action is offered

### 3.2 Lock screen capture without unlocking

Lock the device. From the Lock Screen, **long-press** the MER notification and tap
"Log Event Now". A record must be created.

The action carries `options: []` (`AppDelegate.swift:168-172`) — no
`.authenticationRequired` — so authentication here is governed by the Show Previews
setting, not by the app. The record is created with defaults: duration `lt1`, type
`seizure`, severity `mild`, empty feelings, triggers and notes (`handleQuickLogStart`,
lines 250-259).

- [ ] Record created without unlocking (with Show Previews = Always)
- [ ] Password demanded? Y / N — and Show Previews value at the time: ______________

### 3.3 Live Activity appears and the timer runs

On **iOS 16.2+** a Live Activity appears on the Lock Screen with a live timer counting up.
Gate verified: `@available(iOS 16.2, *)` on `MERActivityAttributes`, `MERLiveActivity` and
`MERLockScreenView`, plus `if #available(iOS 16.2, *)` in `MERWidgetBundle`
(`MERWidget.swift:8`). The MERWidget target's own deployment target is 16.2.

**On iOS 16.2 to 16.x the Live Activity appears with NO end button.** That button is gated
`if #available(iOS 17.0, *)` in both the lock-screen view (`MERLiveActivity.swift:88`) and
the Dynamic Island trailing region (`:25`). This is expected, not a bug — do not report it
as one. In that band the "Event in progress" notification is what ends the event, and both
surfaces are present at once, because `handleQuickLogStart` starts the Live Activity at
16.2+ **and** schedules the active notification whenever the device is below 17
(`AppDelegate.swift:286-297`).

- [ ] Live Activity present with a running timer
- [ ] Below iOS 17: end button correctly absent, and an "Event in progress" notification is also present
- [ ] N/A (device below 16.2)

### 3.4 End the event

Two mechanisms, by iOS version:

- **iOS 17+** — the Live Activity's "Event Ended" button, an App Intent running in the
  widget extension process. `EndMEREventIntent` is `@available(iOS 16.0, *)` but conforms
  to `LiveActivityIntent` only at `@available(iOS 17.0, *)`
  (`EndMEREventIntent.swift:86-87`), so 17 is the real gate.
- **Below iOS 17** — the "Event Ended" action on the "Event in progress" notification,
  handled by `handleQuickLogEnd` in the app process (`AppDelegate.swift:300`).

These two write to **different places**, which is why step 3.5 exists. The App Intent
writes only to the App Group suite (`EndMEREventIntent.swift:53`); `handleQuickLogEnd`
writes to both the App Group and standard `UserDefaults` (`AppDelegate.swift:337-340`).

There is **no in-app End button on iOS** — `showEndButton: !Platform.isIOS`
(`home_screen.dart:508`) and `_endActiveEvent` returns immediately on iOS (`:185`). So
below iOS 17 the notification action is the only way to end an event.

- [ ] Event ended — mechanism used: Live Activity button / notification action
- [ ] "Event ended · Xm Ys" feedback notification appears — record the elapsed string shown: ______________

### 3.5 Open the app — the event carries the correct duration

**This is the step that matters most, and it is easy to run in a way that proves nothing.**
It exercises the App Group to standard `UserDefaults` reconciliation, the failure that
produced instance #6.

**Run an event longer than five minutes before ending it.** Duration is stored as one of
three buckets — under 60 seconds gives `lt1`, under 300 gives `oneToFive`, otherwise `gt5`
(`AppDelegate.swift:316`, `EndMEREventIntent.swift:34`) — and `handleQuickLogStart`
already writes `lt1` when the record is created (`AppDelegate.swift:253`).
`EventRecord.fromMap` also falls back to `lt1` (`event_record.dart:122`). **So for any
event under a minute, a total reconciliation failure is invisible: the default, the
fallback and the correct answer are all "< 1 minute".** Over five minutes, the stored
value has to change for the test to pass.

What the tester sees is the duration label on the event: "< 1 minute", "1–5 minutes" or
"> 5 minutes" (`event_record.dart:19-28`). Cross-check it against the precise elapsed
string on the feedback notification from step 3.4.

**Two reconciliation paths exist and both need testing:**

1. **Opened from the app icon** — `syncFromSharedIfNeeded` on foreground
   (`AppDelegate.swift:85`, defined at 97). This path is **conditional**: it only acts when
   standard still has an active event and the shared suite does not (line 104).
2. **Opened by tapping the feedback notification** — an **unconditional** sync in
   `didReceive` (`AppDelegate.swift:216-235`), whose own comment says it exists "regardless
   of whether `syncFromSharedIfNeeded` ran with the right conditions".

- [ ] Event ran longer than 5 minutes — actual elapsed: ______________
- [ ] Path 1, app icon: duration shown ______________ expected "> 5 minutes"
- [ ] Path 2, feedback notification tap: duration shown ______________ expected "> 5 minutes"
- [ ] The event opens directly to its log screen when reached via the notification

### 3.6 Force-quit and reopen — notification restored

Force-quit while no event is active. Reopen. `applicationDidBecomeActive` re-runs
`restorePersistentNotification`, so the standing notification should be re-posted.

- [ ] Standing notification present again after force-quit and relaunch

## 4. Consecutive-use check

Instance #2 worked once and failed on the second consecutive use in a session, and was
only found because someone tried twice. Instance #4 was the iOS lock-screen session
throttle blocking a start-then-end within one lock session.

Run 3.2 through 3.5 twice in a row without unlocking between them. A single pass proves
less than it appears to.

- [ ] Run 1 passed
- [ ] Run 2 passed — notes: ______________

## 5. Recovery — the 30-minute auto-clear

Untested, and it is the only recovery if an event cannot be ended, which matters most
below iOS 17 where the notification action is the sole end mechanism. An active event
older than 30 minutes is discarded on the next foreground: both suites are cleared, any
Live Activity is ended, and the standing notification is restored
(`AppDelegate.swift:122-130`).

- [ ] Start an event, leave it over 30 minutes, foreground the app — the event is cleared and the standing notification returns
- [ ] The record remains in history with its start time intact

## 6. v1.1.0 additions — first release only

New surface no prior test covers.

### Backup

On iOS the backup sheet offers exactly **Share** and **Cancel**. "Save to a file" is
deliberately absent — see section 9. Share reaches Files, so a backup can still be put
anywhere the user chooses.

- [ ] The sheet shows **only** "Share" and "Cancel" — no "Save to a file", and no disabled or greyed-out item
- [ ] Back up via **Share** — the sheet appears and a `.json` file is produced
- [ ] Share to **Files** specifically, and confirm the saved file opens and is valid JSON — this is the path that replaces "Save to a file"
- [ ] Open the backup file and confirm its `appVersion` field reads the expected `version+build` (`backup.dart:23-24`)
- [ ] Confirm cancelling the share sheet does **not** reset the reminder count (`backup_service.dart:83`)

### Restore

Restore's file picker is `openFile`, which `file_selector_ios` does implement, so this
path works on iOS.

- [ ] Restore a good backup — the confirm dialog shows the event count and a date range before anything is written (`backup_service.dart:266-290`)
- [ ] Restore a deliberately corrupted file — refused cleanly, existing data untouched
- [ ] Restore on a clean install — records appear correctly
- [ ] Restore a backup whose events are all already present — reports nothing new to restore and offers no Restore button

### Backup reminder banner

The banner requires **10 or more events since the last backup**
(`kBackupReminderThreshold`, `constants.dart:39`). With fewer, it will not appear for any
reason, and the suppression steps below prove nothing. Set that up first.

Suppression is a mutually-exclusive `else if` chain (`home_screen.dart:479-511`):
notifications-off, then the iOS Show Previews nudge, then an active event, then the
reminder. Anything earlier in the chain hides the reminder.

- [ ] With 10+ events since backup, the banner appears
- [ ] Banner absent during an active event — guaranteed by chain precedence (`home_screen.dart:503`)
- [ ] Banner absent after a **cold start** from a notification action — `_openedFromNotification` is set on that path only (`home_screen.dart:82`)
- [ ] **Warm** path: with the app already running, tap the feedback notification, close the log screen **without saving**, and record whether the banner appears: ______________

That last box is the one to watch. `_handleNativeCall` handles the warm iOS
`openLatestEvent` (`home_screen.dart:104-108`) and does **not** set
`_openedFromNotification`; `_loggedThisSession` is only set when a log screen actually
saves (`:272`) or the in-app quick log runs (`:238`), and a native lock-screen capture
does neither, because Swift writes the record. So the banner can appear immediately after
a native capture on the warm path. Record what happens rather than assuming either result.

### Version and Sentry

- [ ] About screen shows the expected version (`about_screen.dart:79`)
- [ ] Splash shows the version, not an ellipsis (`main.dart:173` — `versionLabel` renders "…" until `AppInfo.load()` completes)
- [ ] Cold start from a notification action still opens promptly — confirms `AppInfo.load()` staying off the capture path (`main.dart:23`)
- [ ] **Sentry release** — not observable on the device. Trigger an event, then confirm the release reads `package@version+build` in the Sentry dashboard. It is stamped in `beforeSend` (`main.dart:32-35`), so nothing on screen reflects it.

## 7. iOS version coverage — the open gap

The Runner target's `IPHONEOS_DEPLOYMENT_TARGET` is **15.0** and the Podfile declares
`platform :ios, '15.0'`; the MERWidget extension is 16.2. The record contains no test of
the CR-42 design on iOS 15, 16, 17 or 18 — only 26.x. Record each version as it is
covered:

| iOS version | Device | Date | Result |
|---|---|---|---|
| 26.x | | | |
| 18.x | | | |
| 17.x | | | |
| 16.x | | | |
| 15.x | | | |

**Future change, not pending for this release:** raising `IPHONEOS_DEPLOYMENT_TARGET` to
17.0 is **deferred to v1.2.0**. It would narrow this gap from four major versions to two
and retire the below-17 active-notification end path entirely. v1.1.0 deliberately ships
with the iOS native notification code unchanged, which is what makes this run a clean
regression check — bundling a deployment-target raise into it would forfeit that.

## 8. Known constraints — not bugs, do not "fix"

- **iOS 26 demands authentication for the Live Activity "Event Ended" button** despite
  `authenticationPolicy` being `.alwaysAllowed` (`EndMEREventIntent.swift:10`). System
  policy. Note that this property governs the **end** intent only — it has no bearing on
  starting an event from the lock screen, which is governed by Show Previews.
- **Lock-screen session throttle** limits consecutive actions within one lock session.
- **Show Previews not "Always"** means starting from the lock screen requires a password.
  It does not block the action. Surfaced to users in the Help screen.
- **Live Activity has no end button below iOS 17.** Expected; see 3.3.
- **No in-app End button on iOS.** Expected; see 3.4.
- **No "Save to a file" in the backup sheet on iOS.** Intended; see 9. Share reaches
  Files, which is the iOS equivalent.
- **`awesome_notifications` must never initialise on iOS.** Its `initialize()` resets
  `UNUserNotificationCenter.delegate` to itself and breaks the native handler. There are
  **two** `initialize()` call sites in `notification_service.dart` and each has its own
  guard: line 63 in `init()`, guarded at line 60 with the reason in the comment at 56-59;
  and line 125 in the background isolate's `onActionReceived`, guarded at line 111.
  Further iOS early-returns sit at lines 258, 294 and 318, with an inverse guard at 188.
  `AppDelegate` also re-asserts `UNUserNotificationCenter.current().delegate = self` on
  every foreground (line 83) as a second line of defence. Locate these rather than
  trusting the line numbers — they have moved before.
- **Windows has no notification path at all.** Capture there is in-app only.

## 9. Why the backup sheet has no "Save to a file" on iOS

**Fixed 22 August 2026. This is intended behaviour, not a missing feature — do not
"restore" the option.**

`file_selector` ships no save-dialog implementation for iOS. `FileSelectorIOS` implements
`openFile` and `openFiles` only, so `getSaveLocation` falls through to the
platform-interface default, which delegates to `getSavePath` and raises
`UnimplementedError`. `backupSaveAs` reaches that call on iOS because it skips its Android
branch (`backup_service.dart:118`), and nothing catches it: the `try`/`catch` there covers
the Android branch only.

The sheet now suppresses the option at the point it is built
(`if (!Platform.isIOS)` in `showBackupOptions`) rather than catching the throw, because an
option that appears and then fails is worse than one that never appears — and there is no
iOS save dialog to fall back to, so a caught error could only become an apology. This is
the same guard `showExportOptions` has always had (`models/event_record.dart:494`); the
backup sheet was written later and did not inherit it.

**Nothing is lost.** Share reaches Files on iOS, so the user still chooses where the backup
lands, which is the actual requirement.

Platform support for `getSaveLocation`, checked against the resolved packages:

| Platform | Save dialog | Reached by this app? |
|---|---|---|
| iOS | **No** — `file_selector_ios` implements open only | No longer — option hidden |
| Android | **No** — `file_selector_android` implements open and directory only | No — `backupSaveAs` returns from its own Downloads branch first |
| Windows | Yes | Yes |
| macOS | Yes | Yes |
| web | Yes | Not a shipped target |
| Linux | Yes | No `linux/` target in this repo |

So the plugin gap is iOS **and** Android; only iOS ever reached it, because Android
short-circuits to `/storage/emulated/0/Download` before the call.

Restore is unaffected on every platform — it uses `openFile`, which iOS and Android both
implement. Share is unaffected: it goes through `share_plus`, not `file_selector`.

---

## Sign-off

Not passed until every core step passes on the target device. **A failure at step 3.5 is
release-blocking regardless of everything else** — it means the stored record is wrong
rather than absent, and a wrong duration in a medical record is worse than a missing one.

Tester: ______________ Date: ______________ Version: ______________ Result: Pass / Fail

Record the outcome in `STATUS.md` and the Change Register, **including the iOS version**.

Before submitting — confirm:
> "I have completed every item on this checklist on a physical device, on a release or
> ad-hoc build, and recorded the iOS version."
