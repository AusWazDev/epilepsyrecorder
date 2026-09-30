# iOS Device Test Checklist — Medical Event Recorder

Complete every item on a physical device before uploading a build to App Store Connect.
Do not submit until all boxes are checked. No exceptions.

**Verified against the code on 24 August 2026 (AEST)** — `ios/Runner/AppDelegate.swift`,
`ios/MERWidget/`, `lib/services/notification_service.dart`, `lib/screens/home_screen.dart`,
`lib/screens/your_data_screen.dart`, `lib/services/backup_service.dart`,
`lib/models/backup.dart`, `lib/models/event_record.dart`, `lib/models/capture_inbox.dart`,
`lib/services/ios_capture_bridge.dart`.

**Steps cite function and file names, not line numbers.** Line numbers in this document
rotted three times in one week. Where a line number is genuinely unavoidable, the step says
what it points at so you can find it again after it moves.

---

## Why this exists

Seven iOS notification failures are recorded. All seven were caught on a physical device,
by a person, before submission — none reached Apple. The process works; what has never
existed is a written form of it, so it depends on remembering.

**Where the seven live, and what "instance #2" means.** Steps below cite individual failures
by number. **That numbering exists only as narrative in the Change Register — there is no
table of the seven anywhere, in this repository or outside it, and the numbers are not
independently citable.** They are kept because each one is the reason a specific step exists,
and dropping them would sever a step from its motivation. But do not go looking for a
register you can check them against, and do not treat a number as verifiable: if a step's
rationale matters, read the Change Register entry, and if it cannot be found there, the step
should be justified afresh rather than by its number.

Four of the seven shared one root cause: iOS notification handling depending on Dart across
a boundary that is unreliable in release builds on a locked device. CR-42 moved iOS to a
native Swift handler.

**The native implementation held stable from 6 May 2026 (`192ae40`) until 24 August 2026,
and on that day it changed substantially. It will not be stable again for this release.**

Earlier versions of this document said the last commit touching `AppDelegate.swift` or
`ios/MERWidget/` was `192ae40`, and concluded that the checklist "confirms an unchanged
design still holds. It is a regression check, not a hunt for new bugs."

**That premise is void.** On 24 August 2026 the native capture path was rewritten around a
capture inbox, the deployment target was raised, the App Group entitlement was fixed on
Release, and two sub-17 surface defects were repaired. So:

**This checklist is now a hunt for new bugs.** Treat every step as unproven. A step that
passed in May is not evidence about this build.

That is not a reason to distrust the changes — it is why the run matters. Three of the
defects fixed on 24 August had been live since 4 May and were invisible to `flutter
analyze`, `flutter test`, the Swift guard tests, and to this checklist as it then stood.
Two of them were found only because a person picked up the one handset that could reach the
code.

**Nothing here is testable on a simulator.** Lock-screen actions, Live Activity,
authentication policy, App Group access and the capture inbox all require hardware.

---

## 0. Preflight — verify the build before touching a device

**Run this first. If it fails, stop: there is no point testing a build that is not the
build you think it is.**

```
flutter build ios --release && tool/verify_release_signing.sh
```

It must print `OK — all assertions passed.` and exit 0.

- [ ] `tool/verify_release_signing.sh` exits 0 against the build about to be tested
- [ ] Before archiving for App Store Connect, read §12: on Xcode 26 the Sentry dSYM phase can
  fail the archive
  ⭐ *Updated 29 Sep 2026 (Brief 244): the phase has been removed, so the archive no longer
  contacts Sentry. The upload is now a separate step, `tool/upload_dsyms.sh`, required at
  Sign-off.*
- [ ] Before archiving on the Mac, run the host pre-flight in §13, and meet its go/no-go figures

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
from the Change Register, so renumbering them would invalidate those references. New
material goes at the end, as §10 and §11.

---

## 1. When to run

Every iOS build that goes to App Store Connect. No exceptions for "Dart-only" changes —
the whole point of the failure history is that the Dart and native sides interact in ways
neither is visible from alone.

Run the full sequence, not a subset, whenever any of these change:

- `ios/Runner/AppDelegate.swift` or anything in `ios/MERWidget/`
- `ios/Podfile` or `ios/Podfile.lock` — a dependency or the platform floor moved
- `IPHONEOS_DEPLOYMENT_TARGET` or anything in `project.pbxproj`
- The Flutter SDK on the build machine (leaves no trace in the lock file — record it by hand)
- App Group or entitlements configuration
- `lib/services/notification_service.dart` — its iOS guards are what keep Dart out of the
  native path
- `lib/models/capture_inbox.dart`, `lib/models/capture_instruction.dart` or
  `lib/services/ios_capture_bridge.dart` — the instruction schema and the drain are a
  contract between Swift and Dart, and a change to either half can only be tested together

## 2. Before you start — record these

Fill in every time. The iOS version being absent from past records is the single largest
gap this checklist closes.

| Field | Value |
|---|---|
| Date (AEST/AEDT) | |
| Version + build | |
| Device model | |
| **iOS version** | |
| **Tier** | 16.2–16.x / 17.0+ |
| Build type | release / ad-hoc / TestFlight |
| Flutter SDK version on build machine | |
| Tester | |

**Check Settings → Notifications → Medical Event Recorder → Show Previews.** Record the
value.

**BELIEVED, NOT TESTED.** The app tells users that with Show Previews at anything other than
"Always", starting an event from the lock screen **requires a password** rather than starting
instantly, and that it is not blocked outright. That claim appears in `help_screen.dart` and
in the on-screen nudge — **which is the app asserting it, not evidence that it is true.**
Nothing in the record shows it confirmed on a device.

It is also not the app's decision to make. The "Log Event Now" action is registered with
`options: []` in `registerNativeNotificationCategories` — no `.authenticationRequired` — so
whatever happens is iOS policy responding to the Show Previews setting. The app neither
requests authentication nor suppresses it.

**Do not assert either outcome.** Record what the device actually does, at the recorded Show
Previews value, and note whether it matches the app's copy. If it does not, the Help screen
is wrong and that is a defect in its own right.

- [ ] Show Previews value recorded: ______________

**Which tier is this device?** The deployment target is **16.2**, so there are exactly two:

| Tier | Live Activity | End button on it | Notification end path |
|---|---|---|---|
| **16.2–16.x** | Yes | **No** | **Yes — the only way to end an event** |
| **17.0+** | Yes | Yes | No — no active notification is scheduled |

- [ ] Tier recorded, and every step below read for that tier

## 3. The core sequence

Run in order, on a real device, on a release or ad-hoc build. Not a debug build.

### 3.1 Launch → the standing notification is posted

Force-quit the app, then launch it.

The notification is posted from `applicationDidBecomeActive` via
`restorePersistentNotification` → `showPersistentNormalNotification`, on a 1-second trigger,
so **it appears about a second after launch while the app is still in the foreground**, as a
banner (`willPresent` returns `[.alert, .sound]`). It is **silent** (`content.sound = .none`)
and its body reads "Long-press this notification to log an event".

This is **not** an Android-style ongoing or foreground-service notification. iOS has no such
thing here: it is an ordinary local notification that stays in Notification Centre, the user
can dismiss it, and there is no way to prevent that. On every foreground the previous copy
is removed and re-posted (`removeDeliveredNotifications` at the top of
`showPersistentNormalNotification`).

Its category is `MER_NORMAL`, which carries **only** the "Log Event Now" action — see
`registerNativeNotificationCategories`. There is no End action on this notification, on any
iOS version.

- [ ] Notification appears shortly after launch, silently, with body "Long-press this notification to log an event"
- [ ] Background the app — notification still present in Notification Centre
- [ ] Long-press it — "Log Event Now" is offered, and **no** End action is offered

### 3.2 Lock screen capture without unlocking

Lock the device. From the Lock Screen, **long-press** the MER notification and tap
"Log Event Now". A record must be created.

The action carries `options: []` in `registerNativeNotificationCategories` — no
`.authenticationRequired` — so authentication here is governed by the Show Previews setting,
not by the app.

`handleQuickLogStart` writes a **start instruction** into the capture inbox rather than
writing the record list. The record is materialised in Dart by the drain, with defaults:
duration `lt1`, type `seizure`, severity `mild`, empty feelings, triggers and notes.

- [ ] Record created without unlocking (with Show Previews = Always)
- [ ] Password demanded? Y / N — and Show Previews value at the time: ______________

### 3.3 Live Activity appears and the timer runs

A Live Activity appears on the Lock Screen with a live timer counting up, on **every**
supported device — the deployment target is 16.2 and ActivityKit is unconditional there.
The `#available(iOS 16.2, *)` gates that used to wrap this were removed when the target was
raised; if you are looking for them, that is why they are gone.

The timer is bounded to `startDate + merActiveEventTimeoutSeconds` (30 minutes), not 24
hours. An abandoned event's Live Activity will not read "32:55" and climbing.

**On 16.2–16.x the Live Activity appears with NO end button.** That button is gated
`#available(iOS 17.0, *)` in both the lock-screen view and the Dynamic Island trailing
region of `MERLiveActivity.swift`, and `EndMEREventIntent` conforms to `LiveActivityIntent`
only under the same gate. This is expected, not a bug — do not report it as one. In that
tier the "Event in progress" notification (category `MER_ACTIVE`) is what ends the event,
and both surfaces are present at once, because `handleQuickLogStart` always starts the Live
Activity and additionally calls `scheduleActiveNotification` in the `else` of its 17.0 gate.

**After ten minutes without the app running, the Live Activity goes stale rather than
lying.** `staleDate` is set on the `ActivityContent` in `startLiveActivity` from
`kActivityStaleAfterSeconds`, and `MERLockScreenView` renders `context.isStale`: the label
becomes "Event may still be running", the climbing timer is replaced by a static start
time, and the background desaturates to slate. On the Dynamic Island the expanded region
reads "May still be running", the compact trailing number disappears, and the minimal glyph
desaturates.

- [ ] Live Activity present with a running timer
- [ ] 16.2–16.x: end button correctly absent, and an "Event in progress" notification is also present
- [ ] 17.0+: end button present on the Live Activity, and **no** "Event in progress" notification
- [ ] Leave an event running 10+ minutes without foregrounding — the Live Activity goes stale, not blank, and stops showing a climbing timer

### 3.4 End the event

**Two mechanisms, one per tier. There is no third.**

| Tier | Mechanism | Where it runs |
|---|---|---|
| **17.0+** | The Live Activity's "Event Ended" button | `EndMEREventIntent.perform()`, in the **widget extension process** |
| **16.2–16.x** | The "Event Ended" action on the "Event in progress" notification | `handleQuickLogEnd`, in the **app process** |

There is **no in-app End button on iOS** — `_ActiveEventBanner` is built with
`showEndButton: !Platform.isIOS` and `_endActiveEvent` returns immediately on iOS with the
comment "iOS: Live Activity owns event end". So on 16.2–16.x the notification action is the
only way to end an event, and on 17.0+ the Live Activity button is.

**Both mechanisms now write the same thing to the same place.** Each writes an **end
instruction** into the capture inbox — one key per instruction, prefix `mer_inbox_` — and
neither touches the record list. The whole-list read-modify-write that used to differ between
them is gone. That is why there is no longer a "these two write to different places" warning
here.

**Which device can test which:** 17.0+ needs a device on 17 or later. **16.2–16.x is
reachable only on a 16.x handset** — at the time of writing, Paula's iPhone 8 on 16.7.15 is
the only one. The temptation is to test on whichever phone is easier to reach; that phone
cannot exercise the sub-17 tier at all, and the sub-17 tier is where both surface defects of
24 August lived.

- [ ] Event ended — tier and mechanism used: ______________
- [ ] "Event ended · Xm Ys" feedback notification appears — record the elapsed string shown: ______________
- [ ] **16.2–16.x only:** the Live Activity **disappears immediately** on ending from the notification — it does not keep counting, and it does not go stale ten minutes later
- [ ] **16.2–16.x only:** tapping "Open MER to add details" opens **the event's edit screen**, not the dashboard

The last two boxes are the two defects fixed on 24 August 2026 and verified once, on one
handset. Both were invisible for three months and three weeks because nothing had run this
tier on hardware. Re-check them on every build.

### 3.5 Open the app — the event carries the correct duration

**This is the step that matters most, and it is easy to run in a way that proves nothing.**

**Run an event longer than five minutes before ending it.** Duration is stored as one of
three buckets by `bucketFromSeconds` in `lib/models/capture_inbox.dart` — under 60 seconds
gives `lt1`, under 300 gives `oneToFive`, otherwise `gt5`. That mapping exists in exactly one
place now; it used to be duplicated in three.

`handleQuickLogStart` creates the record at `lt1`, and `EventRecord.fromMap` also falls back
to `lt1` for an unreadable value. **So for any event under a minute, a total failure of the
end path is invisible: the default, the fallback and the correct answer are all
"< 1 minute".** Over five minutes, the stored value has to change for the test to pass.

A middle bucket is better still. An event of two to four minutes must read **"1–5 minutes"**,
which neither the default nor the fallback can produce — so it discriminates in both
directions.

What the tester sees is the duration label on the event: "< 1 minute", "1–5 minutes" or
"> 5 minutes" (`durationLabel` in `event_record.dart`). Cross-check it against the precise
elapsed string on the feedback notification from 3.4.

**What actually happens between ending and seeing the duration:**

1. Swift wrote an end instruction into the App Group inbox. It did **not** write the record.
2. On foreground, `_loadRecords` in `home_screen.dart` runs
   `reconcileLegacySharedRecords`, then `drainInbox` with `IosChannelInboxTransport`.
3. The transport calls `readCaptureInbox` over the method channel, because **Dart cannot
   read the App Group** — `shared_preferences` reads `UserDefaults.standard` filtered to the
   `flutter.` prefix.
4. `applyInbox` merges by id and applies the duration; the main isolate writes the list.
5. Only after a **confirmed write** does the transport call `deleteCaptureInbox`. A failure
   leaves the keys in place and replays next foreground, which is safe because every
   instruction is idempotent.

**Two arrival paths, and both need testing** — not because they reconcile differently any
more, but because they are different code paths into the same drain:

1. **Opened from the app icon** — the drain runs inside `_loadRecords`.
2. **Opened by tapping the feedback notification** — the drain runs, *and* the app must land
   on the event's edit screen. On 17.0+ that is a cold start consuming the durable
   `mer_open_latest_event` flag; on 16.2–16.x the app is usually already alive and the same
   flag is consumed by the resume-time drain. Both routes converge on `_openLatestEvent`.

- [ ] Event ran longer than 5 minutes — actual elapsed: ______________
- [ ] Path 1, app icon: duration shown ______________ expected "> 5 minutes"
- [ ] Path 2, feedback notification tap: duration shown ______________ expected "> 5 minutes"
- [ ] The event opens directly to its **edit screen** when reached via the notification
- [ ] Separately, a 2–4 minute event reads **"1–5 minutes"** — the discriminating case
- [ ] The edit screen is **not** opened twice by one notification tap

### 3.6 Force-quit and reopen — notification restored

Force-quit while no event is active. Reopen. `applicationDidBecomeActive` re-runs
`restorePersistentNotification`, so the standing notification should be re-posted.

That same no-active-event branch now also calls `endLiveActivity` as a safety net, so a
Live Activity stranded by a failed dismissal is reaped on the next foreground. You will
normally see nothing from this, which is the point.

- [ ] Standing notification present again after force-quit and relaunch
- [ ] No Live Activity remains on the Lock Screen once no event is active

## 4. Consecutive-use check

Instance #2 worked once and failed on the second consecutive use in a session, and was only
found because someone tried twice. Instance #4 was the iOS lock-screen session throttle
blocking a start-then-end within one lock session.

Run 3.2 through 3.5 twice in a row without unlocking between them. A single pass proves less
than it appears to.

This matters more than it used to. The inbox is drained and its keys deleted only after a
confirmed write, so a second capture arriving before the first has drained is a real
sequence, not a contrived one.

- [ ] Run 1 passed
- [ ] Run 2 passed — notes: ______________
- [ ] Both events present, with distinct ids and correct durations

## 5. Recovery — the 30-minute auto-clear

Still untested on hardware, and it is the only recovery if an event cannot be ended — which
matters most on 16.2–16.x, where the notification action is the sole end mechanism.

An active event older than `kActiveEventTimeoutSeconds` (30 minutes) is discarded on the next
foreground by `restorePersistentNotification`: both suites are cleared, any Live Activity is
ended, and the standing notification is restored.

- [ ] Start an event, leave it over 30 minutes, foreground the app — the event is cleared and the standing notification returns
- [ ] The record remains in history with its start time intact
- [ ] Record the duration the abandoned event ends up with: ______________

**That last box is not a formality.** See §11 — resolving an abandoned event by opening the
app and resolving it by tapping "Event Ended" are believed to produce different data for the
same event.

## 6. v1.1.0 additions — first release only

New surface no prior test covers.

### The Your data screen

Export, backup and restore no longer sit on the home menu. They moved behind **Your data**
(`your_data_screen.dart`, reached from the home menu, which is now History · Your data ·
About · Help). Every step below routes through that screen, not the old flat menu.

The screen presents two cards, deliberately distinguished because they are the two actions
that look alike and are not: **Export a spreadsheet** ("It cannot be read back into the
app") and **Back up** ("It is not a spreadsheet file"). Restore sits on the backup card.

- [ ] Home menu shows History · Your data · About · Help — no flat data actions
- [ ] Your data shows both cards, and the export card says a spreadsheet cannot be read back in
- [ ] Export is still reachable from History as well (`showExportOptions` from the history screen)

### Backup

On iOS the backup sheet offers exactly **Share** and **Cancel**. "Save to a file" is
deliberately absent — see §9. Share reaches Files, so a backup can still be put anywhere
the user chooses.

- [ ] The sheet shows **only** "Share" and "Cancel" — no "Save to a file", and no disabled or greyed-out item
- [ ] Back up via **Share** — the sheet appears and a `.json` file is produced
- [ ] Share to **Files** specifically, and confirm the saved file opens and is valid JSON — this is the path that replaces "Save to a file"
- [ ] Exactly **one** file is shared — no stray companion file containing only descriptive text
- [ ] Open the backup file and confirm its `appVersion` field reads the expected `version+build` (`buildBackupJson` in `backup.dart`)
- [ ] Confirm cancelling the share sheet does **not** reset the reminder count — only `ShareResultStatus.success` counts, per `backupCountsAsTaken`

### Restore

Restore's file picker is `openFile`, which `file_selector_ios` does implement, so this path
works on iOS. It is opened with a **UTI type group**, not a bare extension list — an
extensions-only `XTypeGroup` throws `ArgumentError` on iOS, which is what made "restore does
nothing on iOS".

- [ ] Restore a good backup — the confirm dialog (`_confirmRestore`) shows the event count and a date range before anything is written
- [ ] Restore a deliberately corrupted file — refused cleanly, with a **visible message**, and existing data untouched
- [ ] Restore on a clean install — records appear correctly
- [ ] Restore a backup whose events are all already present — reports nothing new to restore and offers no Restore button

### The six failure surfaces

`reportUserFacingFailure` was added on six paths that previously failed silently — three in
`event_record.dart` (CSV export and share) and three in `backup_service.dart` (backup,
share and restore). **A tester will now see messages where previously they saw nothing.**

Do not treat a visible error as a regression by itself. "Nothing happened" *was* the symptom
of a real defect on these paths, and a message is the fix, not a new fault. Record the
message text and judge whether it is accurate.

- [ ] Force a failure on a data path (for example, cancel or deny at the OS level) and record what is shown: ______________
- [ ] The message is accurate, and the app is still usable afterwards

### Banners

`_FailedWriteBanner` **stacks above** the banner chain rather than joining it. The chain
is exclusive, so putting the unsaved-write warning inside it would hide whichever banner it
displaced — including the active-event banner, whose End button is the only way to end an
event on Android. Data at risk and an event in progress are both worth showing.

The exclusive chain below it is, in order: **notifications off** → **iOS Show Previews
nudge** → **active event** → **backup reminder**. The advisory backup reminder yields to the
unsaved warning through `_showBackupReminder`, which requires `!_writeFailed`.

The reminder also requires **10 or more events since the last backup**
(`kBackupReminderThreshold` in `constants.dart`). With fewer it will not appear for any
reason, and the suppression steps prove nothing. Set that up first.

- [ ] With 10+ events since backup, the banner appears
- [ ] Banner absent during an active event — chain precedence
- [ ] Unsaved-write warning appears **above** an active-event banner, not instead of it
- [ ] Banner absent after opening the log screen from a notification — `_openedFromNotification` is now set by `_openLatestEvent`, so this holds on **both** cold start and warm resume

That last box changed on 24 August 2026. It used to hold on cold start only, and this
document previously asked the tester to record what happened on the warm path because the
answer was genuinely unknown. It is now expected to be suppressed on both.

### Version and Sentry

- [ ] About screen shows the expected version (`AppInfo.version`)
- [ ] Splash shows the version, not an ellipsis — `AppInfo.versionLabel` renders "…" until `AppInfo.load()` completes
- [ ] Cold start from a notification action still opens promptly — confirms `AppInfo.load()` staying off the capture path
- [ ] **Sentry release** — not observable on the device. Trigger an event, then confirm the release reads `package@version+build` in the Sentry dashboard. It is stamped in `beforeSend` in `main.dart`, so nothing on screen reflects it.

## 7. Version coverage

The deployment target is **16.2** — project-level Release configuration, with MERWidget's own
three configurations also at 16.2, and `platform :ios, '16.2'` in the Podfile.

**iOS 15.0–16.1 cannot install this build.** Rows for those versions have been removed
rather than left as unreachable checkboxes.

### What is verified

| Coverage | Device | OS | Build | Date |
|---|---|---|---|---|
| **17.0+ cross-process end path** — Live Activity button → `EndMEREventIntent` → inbox → drain → record | Wazza's iPhone (iPhone 15 Pro Max) | iOS 26.6 | `824cd16` | 24 Aug 2026 |
| **16.2–16.x full tier** — notification start, notification end, Live Activity dismissal, feedback notification routing, duration bucket | Paula's iPhone (iPhone 8) | iOS 16.7.15 | `468fb23` | 24 Aug 2026 |
| **Android** | Teclast P30 tablet | Android 15 / API 35 | | |

### What has no coverage

| Gap | Note |
|---|---|
| **iOS 17.x** | Never tested. The 17.0 gates are the tier boundary, and 17.x is the version where they first take effect |
| **iOS 18.x** | Never tested |
| **Android below API 35** | No device |
| **Android phone form factor** | Only a tablet has ever been used. Layout, notification presentation and the shade differ |
| **EMUI** | Never exercised. Huawei's notification handling is the most common source of Android quick-log reports |

Record each version as it is covered:

| iOS version | Device | Date | Result |
|---|---|---|---|
| 26.x | Wazza's iPhone | 24 Aug 2026 | 17.0+ path pass |
| 18.x | | | |
| 17.x | | | |
| 16.7.15 | Paula's iPhone | 24 Aug 2026 | 16.2–16.x tier pass |
| Other 16.x | | | |

**The gap is now two major versions, not four.** Raising the target to 16.2 removed 15.0–16.1
from the matrix by making them uninstallable. A further raise to **17.0** is **not** planned:
it would delete `handleQuickLogEnd` and the entire notification end path, which is the only
way a 16.2–16.x user can close an event, and it is also the obvious remedy for the
dismissed-Live-Activity gap. See the Change Register before proposing it again.

## 8. Known constraints — not bugs, do not "fix"

- **iOS 26 demands authentication for the Live Activity "Event Ended" button** despite
  `authenticationPolicy` being `.alwaysAllowed` on `EndMEREventIntent`. System policy. Note
  that this property governs the **end** intent only — it has no bearing on starting an
  event from the lock screen, which is governed by Show Previews.
- **Lock-screen session throttle** limits consecutive actions within one lock session.
- **Show Previews not "Always"** means starting from the lock screen requires a password.
  It does not block the action. Surfaced to users in the Help screen.
- **Live Activity has no end button below iOS 17.** Expected; see 3.3.
- **No in-app End button on iOS.** Expected; see 3.4.
- **No "Save to a file" in the backup sheet on iOS.** Intended; see §9. Share reaches Files,
  which is the iOS equivalent.
- **`awesome_notifications` must never initialise on iOS.** Its `initialize()` resets
  `UNUserNotificationCenter.delegate` to itself and breaks the native handler. There are
  **two** `initialize()` call sites in `notification_service.dart` — one in `init` and one in
  the background isolate's `onActionReceived` — and each has its own iOS guard with the
  reason in the comment above it. Three further iOS early-returns sit in
  `restoreNotification`, `_showNormal` and `_showActive`, the last two carrying the comment
  "Swift owns iOS persistent notification". `applicationDidBecomeActive` in
  `AppDelegate.swift` also re-asserts `UNUserNotificationCenter.current().delegate = self`
  on every foreground as a second line of defence. **Locate these by name rather than
  trusting any line number** — they have moved repeatedly, which is why
  `test/checklist_citations_test.dart` now fails if any name here stops existing.
- **Windows has no notification path at all.** `NotificationService.init()` returns before
  any channel is created. Capture there is in-app only.
- **A stale Live Activity is correct behaviour, not a bug.** With the app killed, nothing can
  end or update an activity. `staleDate` is the only mechanism iOS provides, and the stale
  rendering says what is known — an event was started — rather than asserting it is still
  running. Expected after ten minutes without foregrounding.

## 9. Why the backup sheet has no "Save to a file" on iOS

**Fixed 22 August 2026. This is intended behaviour, not a missing feature — do not
"restore" the option.**

`file_selector` ships no save-dialog implementation for iOS. `FileSelectorIOS` implements
`openFile` and `openFiles` only, so `getSaveLocation` falls through to the
platform-interface default, which delegates to `getSavePath` and raises
`UnimplementedError`. `backupSaveAs` reaches that call on iOS because it skips its Android
branch, and nothing catches it: the `try`/`catch` there covers the Android branch only.

The sheet now suppresses the option at the point it is built (`if (!Platform.isIOS)` in
`showBackupOptions`) rather than catching the throw, because an option that appears and then
fails is worse than one that never appears — and there is no iOS save dialog to fall back
to, so a caught error could only become an apology. This is the same guard
`showExportOptions` has always had; the backup sheet was written later and did not inherit
it.

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

## 10. What this checklist does NOT cover

**Read this before treating a completed run as proof.** Every item here is a path that
exists in the shipped app and has never been exercised on hardware, or has been exercised
only in a way that could not have failed.

| # | Not covered | Why it matters |
|---|---|---|
| 1 | **Reconciliation against a divergent pre-inbox state.** `reconcileLegacySharedRecords` folds a legacy App Group record mirror into the store, taking the mirror's duration only where the store still holds its `lt1` default. **That branch has never run.** Wazza's iPhone spent its one attempt during the period when the app had no App Group entitlement, so it read an empty private suite and took the "no mirror" branch — a clean result that was the only result available. Paula's iPhone had no pre-inbox state at all: its previous build predated the App Group by a week | The merge rules are the least tolerable code to have wrong, and they run **once per device**, unobservably, on an upgrade |
| 2 | **The foreground reap in `restorePersistentNotification`.** It only runs when the dismissal deadline expires or the process dies before ActivityKit responds. Neither happened in testing — **and a successful catch does not exercise the net** | It is the fallback for the one failure mode of the 3.4 fix |
| 3 | **`mer_active_event` mirroring across processes.** Very likely fixed by the entitlement, since `EndMEREventIntent` clears the shared active key and the app can now read it. **Not verified** | A stale active key is what strands an event |
| 4 | **The abandoned-event duration.** Confirmed on both platforms: an event running 30+ minutes and cleared by the timeout keeps `lt1` — "< 1 minute". **Wrong data, and indistinguishable from a real short event.** Backlog; the fix is a nullable or unknown duration, which the schema does not currently have | A wrong duration in a medical record is worse than a missing one |
| 5 | **Devices carrying a `6AXX9KX39T`-signed build.** They hit `0xe80000be` on the next install — the application-identifier must match for an in-place upgrade — and **the only route through is uninstall-then-install, which destroys the container.** Check the installed app's team prefix before installing on any unfamiliar device | Silent data loss during what looks like a routine update |
| 6 | **iOS 17.x and 18.x.** See §7 | The 17.0 gates first take effect on 17.x, and nothing has run there |

- [ ] Read, and none of the above has silently become the thing you are relying on

## 11. The abandonment divergence — under test

**Suspected, not yet confirmed. Do not record a result here until it is observed.**

An abandoned event can be resolved two ways, and they are believed to produce **different
data for the same event**:

| Resolution | Path | Expected duration |
|---|---|---|
| **Open the app** | `restorePersistentNotification` sees an active event older than 30 minutes, clears both suites and ends the Live Activity. It writes **no end instruction** | `lt1` — the default the record was created with |
| **Tap "Event Ended"** | `mer_active_event` is still set, so `handleQuickLogEnd` computes real elapsed from it and writes an end instruction carrying `seconds` | The real elapsed — `gt5` for anything over five minutes |

If that holds, **the same event yields different stored data depending only on how the user
happens to resolve it** — and the difference is not a rounding error, it is `< 1 minute`
against `> 5 minutes`.

Note also that on 16.2–16.x the "Event Ended" action remains available on the active
notification indefinitely, so a user who ignores an event for an hour and then taps it gets
the correct duration, while a user who opens the app first gets `lt1`. The two orders are
equally natural.

| Field | Result |
|---|---|
| Date tested | |
| Device / iOS | |
| Elapsed before resolution | |
| Duration recorded via **open the app** | |
| Duration recorded via **"Event Ended"** | |
| Divergence confirmed? | Y / N |

- [ ] Result recorded above, or the row left blank because the test has not run

If confirmed, this belongs in the Change Register as a data-correctness defect, not a
surface one, and it interacts with §10 item 4 — both are the same underlying gap, that the
schema has no way to say "duration unknown".

---

## 12. The Sentry dSYM phase CAN fail an archive — Xcode 26

⛔ **Recorded 29 September 2026 (Briefs 238 and 242), measured on Xcode 26.3 (17C529).** Read
this before any Release archive for App Store Connect.

The Runner target's **"Upload dSYMs to Sentry"** phase (`sentry-cli debug-files upload`, Release
only) ends in `|| echo "warning: Sentry dSYM upload failed …"`, so its exit code is always 0.
**Xcode 26 fails the archive anyway** when a script phase *prints* `error:`, whatever it
returns. `sentry-cli` prints `error: API request failed` on any failed upload. Observed:

```
error: API request failed
    1: [7] Couldn't connect to server (Failed to connect to 127.0.0.1 port 9 …)
warning: Sentry dSYM upload failed - check auth token in ~/.sentryclirc
Command PhaseScriptExecution emitted errors but did not return a nonzero exit code to indicate failure
** ARCHIVE FAILED **
```

That run redirected Sentry to a dead local port on purpose (to avoid uploading for a build that
would not ship). **The same failure follows from anything that makes the upload fail:** no
network, an expired or revoked token, or a Sentry incident. So a TestFlight archive currently
depends on Sentry being reachable and the token being valid.

⚠️ **SUPERSEDED, quoted from the Brief 226 Part C report (chat, 28 September 2026; never in this
repo):** *"the Sentry dSYM phase fails softly (`|| echo "warning…"`), so it can't block a build."*
**False on Xcode 26.** The `|| echo` controls the exit code, and Xcode reads the log.

⭐ **IMPLEMENTED 29 September 2026 (Brief 244): OPTION 3.** The "Upload dSYMs to Sentry" build
phase is removed from the Runner target, so **no build step contacts Sentry**, and an archive
cannot fail for a Sentry reason by construction. The upload is `tool/upload_dsyms.sh`, run after
the archive exists and before distribution. First it checks locally that every binary in the
archive has a dSYM with a matching UUID; then it uploads, and **it fails loudly** (non-zero, "UPLOAD
FAILED") where the old phase was meant to fail softly. `--check` runs the local checks only. The
step is a required box at Sign-off. The text below is left as it was written; its "NOT
implemented" is superseded for option 3 only.

**Options for making the phase unable to block a release. NOT implemented: each is a production
project change and belongs in its own brief.**
1. **Keep `error:` out of the phase's output.** Capture `sentry-cli`'s stderr and re-emit it
   reworded (for example, prefix it `warning:` or `sentry-cli said:`), keeping the soft exit.
   This is the smallest change. Its risk is that a real upload failure becomes easier to miss.
2. **Gate the upload behind an explicit opt-in**, for example a variable the release run sets
   deliberately, off by default. Test and provisioning archives then never touch Sentry. Its
   risk is that a release forgets to set it and ships without symbols.
3. **Move the upload out of the build entirely:** archive first, then run
   `sentry-cli debug-files upload` against the archive's `dSYMs/` as a separate, visible release
   step. That decouples the archive from Sentry completely. Its cost is one more step in the
   release procedure.

**Two related facts from the same export (Brief 242), for whoever does the next upload:**
- The App Store profile for `au.com.notiva.medicaleventrecorder` was regenerated **by
  `xcodebuild -exportArchive -allowProvisioningUpdates`**, not by opening Signing &
  Capabilities (that pane shows development signing only). New profile:
  `c05df5d0-3e4a-463d-98dc-4017e8f5e739`, created 29 Sep 2026, carrying the App Group. The
  old `46ab2a99…` (28 Apr 2026, no App Group) was removed by Xcode.
- The same export logged *"Your session has expired. Please log in."* from an App Store
  Connect account check, while provisioning still succeeded. **An upload from Xcode will need
  the account signed in again first.**

---

## 13. Archive host pre-flight — the Mac (8 GB Intel)

⚠️ **First written into this repo 29 September 2026 (Brief 246).** It was drafted in Brief 233
Part C (28 September 2026) and existed only in a chat report until then. It is corrected here
before its first appearance in the file (see step 2).

**Why this exists:** this host had two WindowServer watchdog logouts on 24 September 2026 under
swap pressure. An AOT Release archive is the heaviest thing it does. Measured on 29 September
2026, the archive takes about 4 minutes (3 min 47 s, Brief 244) with peak swap 330–530 MB.

1. **Simulators:** `xcrun simctl list devices booted` must print nothing. Shut down anything
   booted and say what was found. Quit Simulator.app, which reopens at login.
2. **Quit what the thresholds require, not a fixed list.** Dropbox and OneDrive can be quit
   (OneDrive is installed twice, as `/Applications/OneDrive.app` and
   `/Applications/OneDrive.localized/OneDrive.app`, so quit both), along with browsers and
   anything else not needed.
   ⛔ **Claude desktop is CONDITIONAL.** Quit it only if **both** of these hold:
   (a) the session is **not** being run from it (check the session's parent processes; on
   29 September 2026 the CLI ran from Terminal), **and** (b) the memory thresholds in step 5
   **fail with it running**.
   **Superseded wording** (Brief 233 C, 28 September 2026, chat only): *"**Quit:** Dropbox and
   OneDrive (their idle helpers can stay), Claude **desktop** (its VM held about 1.1 GB on
   24 Sep), browsers, Messages, and anything else not needed."*
   **Why it changed, measured:** quitting it unconditionally is what the developer saw as
   "Claude desktop keeps closing". Its own log shows clean quits at exactly this session's quit
   commands (28 Sep 23:59:31; 29 Sep 18:41:32 and 19:31:28), and no crash, jetsam kill or Crashpad
   dump since 24 September (Brief 246). **And the quit was not needed:** both passing pre-flights
   on 29 September were measured WITH it running (52% free / 216 MB swap; 52% free / 384 MB swap).
   With it quit, the archive ran at lowest 51–53% free and peak swap 328–530 MB. Claude desktop
   and its VM held about 1.76 GB resident on 29 September. ⚠️ **An archive run WITH it running
   has not been measured.** If the thresholds pass with it running, run the archive and record
   the figures, which settles it.

   ⛔ **SUPERSEDED 29 September 2026 (Brief 258): the whole of step 2 above, including its
   CONDITIONAL rule for Claude desktop.** It is left as written. The rule that replaces it:

   > **Claude desktop is NEVER quit, by any session, for any reason.** It is the developer's
   > control channel, and quitting it to finish a step removes the developer's ability to direct
   > the work. **Under memory pressure a session may quit ONLY:** simulators and emulators
   > (shut down, and quit Simulator.app), Xcode, build daemons (Gradle, Kotlin and Dart or Flutter
   > daemons, `xcodebuild`), and processes the session itself started. **If the thresholds in
   > step 5 still fail after those, the session STOPS and REPORTS** the figures and what is using
   > the memory. It quits nothing else: not Claude desktop, not sync clients, not browsers, not
   > any other app. Those are the developer's to quit, or a restart is.

   **Why:** the conditional rule still allowed a quit, and the developer had raised each one.
   Claude desktop's own log records four quits by this session, each a clean `willQuit`:
   **28 Sep 23:59:31** (Brief 238 A1), **29 Sep 18:41:32** (Brief 238 A6), **19:31:28** (Brief 244
   B1), all under the older unconditional wording, and **21:05:39** (Brief 252 C4), under the
   conditional rule above, triggered at 42% free, 2,033 MB swap and a 5 minute load of 141.8. The
   fifth `willQuit` that day, 05:43:31, was an auto-update and not this session. The rule is also
   recorded in the Mac's global `~/.claude/CLAUDE.md`, so it reaches sessions that never read this
   file.
3. **Stop:** no Spotlight indexing burst (`mds_stores` near idle) and no Time Machine backup
   running (`tmutil status`).
4. **Devices:** no device that could be REGISTERED. A connected device that is already registered
   is fine (check the development profile's `ProvisionedDevices`), but Xcode may still try to
   prepare it for development, so keep it locked or away if you want no device interaction.
5. **Go/no-go**, all four measured after steps 1–3:

   | Check | Command | GO if | Why |
   |---|---|---|---|
   | Free disk | `df -h ~` | ≥ 10 GB | About 5 GB needed (about 1 GB of output plus up to 4 GB of swap), × 2 margin |
   | Free memory | `memory_pressure` → free percentage | ≥ 45% | The healthy host read 52–59% on 29 Sep |
   | Swap in use | `sysctl vm.swapusage` | ≤ 1,000 MB | The 24 Sep failures came at 2.4–3.3 GB |
   | 1-minute load | `uptime` | ≤ 4 | Healthy readings were 1.3–3.3 |

   If swap is over 1,000 MB after quitting, **restart the Mac and re-measure.** Do not start on a
   degraded host.
6. **Keep the Mac awake:** run the archive under `caffeinate -dimsu`.

---

## Sign-off

Not passed until every core step passes on the target device. **A failure at step 3.5 is
release-blocking regardless of everything else** — it means the stored record is wrong
rather than absent, and a wrong duration in a medical record is worse than a missing one.

**A run on one tier is not a run.** 16.2–16.x and 17.0+ take different end paths through
different processes, and every defect found on 24 August 2026 lived in exactly the tier that
had never been tested. Record which tier this run covered, and do not treat the other as
covered by it.

Tester: ______________ Date: ______________ Version: ______________

Tier: 16.2–16.x / 17.0+ Result: Pass / Fail

Record the outcome in `STATUS.md` and the Change Register, **including the iOS version and
the tier**.

**Symbols (added 29 September 2026, Brief 244). The build no longer uploads them itself, so
skipping this step ships a build whose crash reports cannot be read.**

- [ ] `tool/upload_dsyms.sh --archive <the archive being distributed>` exited 0 and printed
  `dSYMs uploaded for <version> (<build>)`, **for the same archive that is uploaded to App Store
  Connect**. dSYMs from any other build will not match.

  ⚠️ **UNTESTED UNTIL THIS BOX IS DONE, recorded 29 September 2026 (Brief 244).** The script's
  local half is tested: `--check` passed 4/4 on a real archive, and a control with a swapped dSYM
  failed. **Its network half has never run:** whether `sentry-cli` authenticates with the token
  in `~/.sentryclirc` and the upload is accepted. That was withheld on purpose, so a non-release
  build would not create a phantom Sentry release. **The first real upload is this box, on the
  shipping archive.** If it fails, it fails here, loudly, before the build goes out. The archive
  can no longer be blocked by it. The only successful upload recorded in this repo is the old
  build phase's first run, 6 May 2026 (1.0.2). That phase ran on every Release build, so the
  Release builds of 7 and 23 September 2026 would have run it too, but whether they uploaded is
  not recorded. **Treat the token as unverified.**

  ⭐ **ANNOTATION, 30 September 2026 (Brief 306): THE NETWORK HALF HAS NOW RUN, ONCE**, against
  1.1.1 (65), with `tool/upload_dsyms.sh --archive build/ios/archive/Runner.xcarchive`. The
  paragraph above is left as written. What it did: `sentry-cli` authenticated from
  `~/.sentryclirc` with no prompt, and its pre-upload query reported **3 of 4 missing**. The
  **3 were sent** (Runner, App, MERWidget), and the **1 was already held** (Flutter, whose engine
  UUID the 1.0.3 (5) rig's dSYMs had carried to Sentry on 29 September). The script exited 0 and
  printed `dSYMs uploaded for 1.1.1 (65)`.

  ⛔ **AND WHAT THE CLI CANNOT DO, as at 30 September 2026: no read-only server-side check is
  available to it without a credential.** `debug-files upload --no-upload` never contacts the
  server (it prints `skipping upload.` and makes no missing-files query). `debug-files find`
  and `debug-files check` are local only. The Sentry API needs the token, which a session must
  not read. The Sentry MCP needs an OAuth sign-in. **So the script's exit 0 is the uploader's
  own report, and verifying ARRIVAL is a MANUAL step:**

  - [ ] On Sentry's Debug Files page for bedlin-pty-ltd / medical-event-recorder, each UUID the
    archive carries is listed. The listing must show them as recent against older entries, so a
    present file can be told from an absent one. For 1.1.1 (65) this read was made on
    30 September 2026, and the result is in `docs/BUILD-LEDGER.md` row 65.

  ⚠️ dSYMs are matched to crashes by UUID, not scoped to a release. "Uploaded for a build" means
  the UUIDs that build carries.

**App Store Connect upload (added 30 September 2026, Brief 305). This step did not exist
before: until this date the Sign-off section had no App Store Connect upload step at all, and
its only "upload" box was the dSYMs above.**

- [ ] The IPA reached App Store Connect, and the delivery UUID and route are recorded in the
  build's row in `docs/BUILD-LEDGER.md`.

  **Routes actually used, builds 1–65** (from `STATUS.md` and the ledger, read 30 September 2026):

  | Build | Route recorded |
  |---|---|
  | 1.0.0 (1), 1.0.1 (2), 1.0.2 (3) | Xcode Organizer |
  | 1.0.3 (4) | `xcrun altool`; how it authenticated is not recorded |
  | 1.0.3 (5), 1.1.1 (64) | altool with the API key (Brief 268) |
  | 1.1.1 (65) | see ledger row 65 |

  ⛔ **As at 30 September 2026, no upload route is recorded that works without a credential at
  run time. Both recorded routes need one: altool needs the API key, Organizer needs a live
  signed-in Apple ID session.** So the CLI cannot upload unattended. That is a standing fact
  about this project, written here so it is not rediscovered each release.

  **Where the API key's identifiers live, by location only:** the ASC Key ID and Issuer ID are
  in `OneDrive/Projects/App Dev/Claude/Dev Environment Reference.md` (as `STATUS.md` records).
  As at 30 September 2026 they appear nowhere in this repository, and no key material is
  tracked. Do not copy them into it: the repository is public.

  ⚠️ **SINGLE POINT OF FAILURE: the `.p8` key is Mac-only and single-copy by design** (as
  recorded in `STATUS.md`). If this Mac's copy is lost, the altool route is gone until a new
  key is issued in App Store Connect.

  ⛔ **THE XCODE SESSION EXPIRES, AND NOTHING SAYS SO UNTIL THE UPLOAD.** Two sightings, both
  of *"Your session has expired. Please log in."* in an export log: §12 (Brief 242,
  29 September 2026) and Brief 301's export of 1.1.1 (65) (30 September 2026). ⭐ **PROVISIONING
  SUCCEEDS WHILE THE UPLOAD WOULD FAIL.** `xcodebuild -exportArchive
  -allowProvisioningUpdates` still produced a signed IPA both times, so the build completes,
  the export succeeds, and nothing announces the problem until an Organizer upload is tried.
  **Remedy: sign in to Xcode (Settings → Accounts) before any Organizer upload.** As at
  30 September 2026 this is recorded as a recurring condition here and nowhere else.

  ⛔ **DIAGNOSTIC: A LAPSED DEVELOPER PROGRAM LICENSE AGREEMENT BLOCKS BOTH ROUTES, AND NEITHER
  SAYS WHY.** Recorded here as a diagnostic, not as current state.
  - **The condition:** a lapsed Developer Program License Agreement blocks the App Store Connect
    API **and** the Xcode Organizer route, and neither announces the reason.
  - **The symptom to look for:** both upload routes failing, with no explanatory message. That
    is the tell.
  - **First check when that symptom appears:** the agreement, in App Store Connect, before
    debugging signing or profiles.
  - **Occurrence on record:** blocking as at 20 August 2026 (`STATUS.md`: the lapsed agreement
    *"was blocking the entire App Store Connect API — including the Xcode Organizer route,
    which fails for the same reason and does not announce why."*).
  - ⭐ **Reported resolved by the developer, 30 September 2026 [report — developer; not
    observable from the repo]. The agreement renews, so this is a recurring condition, not a
    closed one.**

Before submitting — confirm:
> "I have completed every item on this checklist on a physical device, on a release or
> ad-hoc build, and recorded the iOS version and the tier. I have read §10 and I am not
> relying on anything listed there."
