# ⭐ RESUME HERE — read this block before touching MER-176-U (written 24 Sep 2026 ~19:25 AEST)

**State at hand-off:** MER-176-U (2E364C3F-DA09-4B82-9EAD-21EDE359692D) is SHUT DOWN (orderly, 19:16). Seed content complete: 6 records.
Markers `CBE84F1D` present in BOTH suites. **(ii) has NOT run. The freeze has NOT happened.** Host restart pending (Waz).
Must-match hashes right now: main `04b5a8eb40791948768d5d42e5d673b6057a015449f141c24ffbd8a27b24a650` ·
private `19323e02bbe0559b82d34c89c5be26fb2b5678ece701815db9fa4f8ca9d774ca`.

**⛔ PRE-FLIGHT — runs FIRST, every session, before any rig work (added 24 Sep 2026 ~19:45, after resume attempt 2):**
`xcrun simctl list devices booted`. Shut down every device that is not the device under test (`xcrun simctl shutdown <UDID>`),
and REPORT what was found booted, by name and UDID, even when that is nothing. This is a CHECK, not a setting, on purpose:
the setting that preceded it (`ApplePersistenceIgnoreState`) failed without anyone noticing (see RESUME ATTEMPT 2). A check
that runs every time cannot fail silently. ⛔ Do NOT "fix" login boots by changing `CurrentDeviceUDID`. That does not stop a
boot, only changes which device boots. Pointed at the wrong device, a login would boot THE FIXTURE.

**Next session, in order:**
1. Confirm the host was restarted (`sysctl kern.boottime` after 24 Sep 19:16). Before booting, check swap and free memory, with only
   MER-176-U to be booted. Do not open Simulator.app first: it may restore MER-audit-SE3.
2. `xcrun simctl boot 2E364C3F-DA09-4B82-9EAD-21EDE359692D`. **EXPECT an uncontrolled BACKGROUND launch of 1.0.2** by liveactivitiesd
   restoring the three Live Activities (see FIXTURE CHECKS below). It is not ours. Record it.
3. **Immediately re-hash both MER plists** against the must-match values above, before doing anything else.
4. Screenshot (Lock Screen if reachable) before the launch.
5. **FOREGROUND** launch: `xcrun simctl launch 2E364C3F-DA09-4B82-9EAD-21EDE359692D au.com.notiva.medicaleventrecorder` (foreground
   by default, as at 13:43:37). **Confirm it was foreground from the LOG, not from the command:** deactivation reasons reaching 0, and
   the "Setting 2 notification categories" + requestAuthorization pair from applicationDidBecomeActive. A background launch never runs
   the timeout branch and would read as a false "the branch didn't fire".
6. (ii) prediction, written 24 Sep ~18:05 from source (1.0.2 `restorePersistentNotification` timeout branch, reached from
   `applicationDidBecomeActive`; Dart `_clearIfTimedOut` only removes): `flutter.mer_active_event` removed from main AND
   `mer_active_event` removed from private; `endLiveActivity()` called (ends EVERY MER activity); records untouched, so 6 records, with
   1B14D71F / 54605897 / CBE84F1D still `lt1`. **If the markers do NOT clear: STOP.** Do not relaunch or force it. That is a finding
   about 1.0.2, and the POSTINCIDENT clone is the undo.
7. Freeze as briefed: kill the app (no stale Dart cache); host copies + sha256 of both plists; marker file in the Data container;
   delete Library/Caches/io.sentry with a log line; shut down; clone. **Name the frozen clone so it cannot be confused with
   `MER-176-U-POSTINCIDENT-1737-NOT-FROZEN` (8E484F3D-67D5-4B5A-BA9B-D3E8BD2040F2), which is the post-incident rollback, NOT the fixture.**
8. The 1.0.2 SIGSEGV of 12:06:59 stays OPEN (see its entry). A clean freeze does not close it.

# FIXTURE CHECKS — these travel with the fixture and its clones (recorded 24 Sep 2026 from the 19:04 boot)

**1. BOOTING THIS FIXTURE (or any clone of it) TRIGGERS AN UNREQUESTED 1.0.2 LAUNCH.** Observed 24 Sep 19:04–19:06: liveactivitiesd
restored the three 1.0.2 Live Activities at boot and asked SpringBoard to open the app; SpringBoard bootstrapped it "with intent
background"; it ran didFinishLaunching only and was watchdog-killed. **So 180b does not start from the frozen state. It starts from the
frozen state plus one uncontrolled 1.0.2 launch, before the upgrade is installed.** ⛔ REQUIRED CHECK: re-verify both MER plist hashes
after EVERY boot, before doing anything else. A session that skips it will attribute a boot-time change to the upgrade.
(After the freeze, (ii) should have ended the activities, which may remove this trigger. That is UNVERIFIED until a post-freeze boot shows it.)

**2. "THE FIXTURE IS UNCHANGED" IS NOT TRUE AT CONTAINER LEVEL. VERIFY AGAINST TWO LISTS, NOT ONE.**
- **MUST MATCH on every check** (a mismatch is a finding):
  - `Library/Preferences/au.com.notiva.medicaleventrecorder.plist` (main suite: records + marker)
  - `Library/Preferences/group.au.com.notiva.medicaleventrecorder.plist` (private "App Group" suite: mirror + marker)
  - App Group container `5AB1F785…/Library/Preferences` stays EMPTY (variant U property)
- **EXPECTED TO CHANGE on a boot** (observed written by the 19:04 boot's background launch; a change here is NOT tampering):
  - `Library/Preferences/group.awn.0be43e74.plist` (awesome_notifications lifecycle bookkeeping; 9b6288bf… ↔ 22b11abb…)
  - `Library/Saved Application State/au.com.notiva.medicaleventrecorder.savedState/` (and contents)
  - `Library/Caches/au.com.notiva.medicaleventrecorder/com.apple.metal/functions.list`, `libraries.list`
  - directory mtimes: `Library/Preferences/`, the `com.apple.metal/` directory
  - ctime-only (xattr `com.apple.runningboard.can-suspend-locked`): `com.apple.metal/functions.data`, `libraries.data`
- **ANYTHING ELSE that changes is UNCLASSIFIED**: adjudicate it before proceeding. Do not fold it into either list silently.
  (`Library/Caches/io.sentry` is deleted at the freeze by design, and that deletion is logged.)

---

# Brief 176 — variant U fixture provenance log (MER-176-U, 2E364C3F-DA09-4B82-9EAD-21EDE359692D)

Every action against the simulator, in order. Times local (AEST), 24 Sep 2026.

- 11:40:57  worktree ~/dev/mer-102-worktree created, detached at 192ae40 (1.0.2+3)
- worktree-only changes: Runner CODE_SIGN_ENTITLEMENTS removed (Debug + Profile; Release never had it);
  Sentry DSN blanked to ''. Built binary: Runner/Runner.debug.dylib carry no application-groups; MERWidget does.
- 11:48:56  `flutter build ios --simulator --debug` done (7m05s cold)
- ~11:53  simulator MER-176-U created (iPhone 17 Pro, iOS 26.3), booted, 1.0.2 installed
  (Data container 6AF194C4-3D1E-406C-A2D2-9FD88700FF69; real App Group container 5AB1F785-…, created at install, empty)
- ~11:58  `simctl launch` 1.0.2 (pid 21814). Notification permission alert.
- 12:03  "Allow" tapped by cliclick (first two clicks landed outside the device, see report). authorizationStatus=2 confirmed
  in BulletinBoard/VersionedSectionInfo.plist; app posted MER_NORMAL notification 356A-192B at 12:03:28.
- 12:05–12:12  Device ▸ Lock / Home via menu; cliclick long-presses and drags on Lock Screen and Home — none registered.
- 1.0.2 process later absent from launchctl (terminated/suspended by the system; not by us).
- 12:38:31  ⚠️ SUBSTITUTION: `simctl push` of a SYNTHETIC notification, category MER_NORMAL, body
  "SYNTHETIC (simctl push, Brief 176) — long-press to log an event". Not posted by 1.0.2.
  Baseline before gesture: app Library/Preferences = group.awn.0be43e74.plist only (sha256 9b6288bf…f6b5);
  Shared/AppGroup/5AB1F785…/Library/Preferences empty.
- ⚠️ UNPLANNED, by the developer, by hand: long-press did not register (by cliclick or by hand); a small upward drag surfaced the
  original 12:03 notification beside the synthetic one; a drag RIGHT on a notification opened the app.
  SpringBoard log 12:45:10.433: "Received response to 356A-192B for action com.apple.UNNotificationDefaultActionIdentifier"
  → i.e. the ORIGINAL app-posted notification, DEFAULT action, foreground launch (pid 27384). QUICK_LOG_START did not fire.
  1.0.2 left on the disclaimer, NOT accepted.
- 12:46:27  post-launch state: see report 176-unplanned-launch.
- 12:46–13:00  Brief 180a read-only analysis (awn source: delegate taken in didFinishLaunch via
  didFinishLaunchingNotification; _originalNotificationCenterDelegate never assigned; custom actions share the swallow path).
- 13:0x  Brief 181a: lldb attach/detach to pid 27384 (1.0.2, on the disclaimer, still unaccepted).
  UNUserNotificationCenter.current().delegate = <Runner.AppDelegate: 0x108506710> (same object as UIApplication delegate);
  applicationState = 0 (active). Log: deactivation reasons -> 0 at 12:45:24.913, then didBecomeActive body
  (Setting 2 categories 12:45:24.914, requestAuthorization 12:45:24.918). No deactivation since.
- 13:02:32  pre-gate baseline: app Library/Preferences = group.awn.0be43e74.plist only (sha256 f355e4b8…23fd);
  Shared/AppGroup/5AB1F785…/Library/Preferences empty.

## WRITTEN PREDICTIONS (recorded 13:02, BEFORE running)

181b WARM (1.0.2 in memory, delegate = MER's AppDelegate, action QUICK_LOG_START):
  handleQuickLogStart runs. Standard plist au.com.notiva.medicaleventrecorder.plist appears in the app's own
  Library/Preferences with flutter.epilepsy_event_records_v1 (one record: uppercase UUID id, "…Z" whole-second timestamp,
  duration "lt1") and flutter.mer_active_event. AND, the gate: group.au.com.notiva.medicaleventrecorder.plist appears in
  the app's OWN Library/Preferences (mer_records + mer_active_event), while Shared/AppGroup/5AB1F785…/Library/Preferences
  stays EMPTY. If the group plist lands in Shared/AppGroup instead, variant U is invalid: STOP.

181c COLD on 1.0.2 (process killed first, same QUICK_LOG_START):
  SpringBoard logs a response for action QUICK_LOG_START; Runner cold-launches in BACKGROUND (not foreground);
  awn logs "The action content doesn't contain any awesome information"; handleQuickLogStart does NOT run:
  standard plist and both group plists byte-identical to the post-181b state (no second record, active marker unchanged);
  no applicationDidBecomeActive (no 'Setting 2 categories'+'requestAuthorization' pair after the launch).
  Falsified if a second record appears or the active marker changes.

181d COLD at HEAD (upgraded build, process killed, QUICK_LOG_START):
  capture log shows 'post-launch delegate stolen=YES' (awn did take it), then 'didReceive action=QUICK_LOG_START'
  (the 0bb8aa7 reclaim won), and an inbox start instruction mer_inbox_* lands in the REAL App Group container.
  Lower confidence than 181b/c (inference from one foreground Debug launch). The alternative outcomes — stolen=YES with
  no didReceive line, or neither line — would each mean the reclaim does not settle it, and are equally reportable.

## 181b — THE GATE, WARM (result read 13:14:57)

⭐ Gate satisfied by a WARM-launch action, DELIBERATELY, because the cold path is swallowed by Backlog 26.
⚠️ Route substitutions: SYNTHETIC notification via `simctl push` (payload push-181b.apns, category MER_NORMAL, not posted by
1.0.2); acted on via a BANNER PULL-DOWN on the Home Screen, not the Lock Screen, because long-press does not register in this
Simulator (by cliclick or by hand). Gesture performed by the developer, by hand.
Timeline (device log): 13:10:08–10 Home pressed, 1.0.2 (pid 27384) backgrounded, still in memory · 13:11:41.603 SpringBoard
adds push request 5DEC-A6A7 · 13:12:26.963 banner expanded · 13:13:00.343 "Received response to 5DEC-A6A7 for action
QUICK_LOG_START" · 13:13:00.719 "Launch application in background for notification response QUICK_LOG_START" (process resumed,
not relaunched) · 13:13:01.319 Runner requests Live Activity C0BA0B4D-9C68-41C0-ADE3-CA5A26662FCB.
⚠️ DELAY, reported by the developer: the pushed notification took a long time to surface. The command's issue time is NOT
recoverable here (no host simctl log line, no shell history entry); what IS known: surfaced 13:11:41.603, ≤ 91 s after Home.
Watch for it in 181c.
Result — matches the written prediction:
  app Library/Preferences/au.com.notiva.medicaleventrecorder.plist        NEW  sha256 3786f383…e384
  app Library/Preferences/group.au.com.notiva.medicaleventrecorder.plist  NEW  sha256 12e8ef2c…ebdb   ← THE GATE: private plist, app's own container
  app Library/Preferences/group.awn.0be43e74.plist  sha256 9b6288bf…f6b5 (back to the pre-12:45 value; currentlifeCycle=Background)
  Shared/AppGroup/5AB1F785…/Library/Preferences   still EMPTY; no MER group plist anywhere else on the device.
  One Swift record: id 38DBC0EA-BB56-4C91-9898-EBEE47DA8B38 (uppercase), timestamp "2026-09-24T03:13:00Z" (UTC, whole
  seconds), duration "lt1", referralRequired false; mer_active_event in BOTH suites; main-key string == mer_records string.
"Event in progress" seen by the developer = the LIVE ACTIVITY (MERLiveActivity.swift:19/76), NOT a MER_ACTIVE notification:
  1.0.2 on iOS 17+ skips scheduleActiveNotification (AppDelegate.swift:291–293); Runner posted no notification request after
  13:13; DeliveredNotifications.plist holds no MER_ACTIVE. Still independent evidence handleQuickLogStart ran.
IN-FLIGHT EVENT: 38DBC0EA… started 13:13:00 local, now active. 1.0.2's 30-min abandon rule will clear both active keys and
end the Live Activity on the first foreground after 13:43:00 — account for it in the seed.

## QUEUED (not run now) — the inherited active marker after upgrade, as a deliberate REPLAY case
Decision 13:1x: option (a) — let 38DBC0EA… be abandoned by 1.0.2's own 30-min rule during seeding. (b)'s question is
queued as a later test that REPLAYS the bytes observed at 13:13 (marker {"id":"38DBC0EA-…","startIso":"2026-09-24T03:13:00Z"},
record shape above) — labelled a replay of an observation, not a construction. To establish when reached:
  1. Does HEAD read mer_active_event from the real group only, or also the private plist?
  2. If real-group only: what does an upgraded user with an inherited 1.0.2 active marker experience — stuck, lost, handled?
  3. Generalised: after upgrade the private plist is a dead letter box. Benign for mer_records; is it for the marker?
  Pointer only, not analysed: the 13:13 observation shows 1.0.2 wrote the marker to BOTH the private suite AND the standard
  suite (flutter.mer_active_event), and HEAD reads the standard copy too — so the case is "standard present, real group
  absent", which is the exact guard of HEAD's clearStaleActiveStateIfEnded. Establish its effect then, not now.

## 181c — THE THEFT, COLD, ON 1.0.2
13:19:34  `simctl terminate` 1.0.2 (pid 27384 gone; no MER process in launchctl). Live Activity C0BA0B4D… left orphaned (expected).
13:19:49  pre-181c baseline (post-181b state): au.com.notiva.medicaleventrecorder.plist=3786f383…  group.au.com.notiva.medicaleventrecorder.plist=12e8ef2c…  group.awn.0be43e74.plist=9b6288bf…   ; real group Preferences file count = 0
Payload push-181c.apns (SYNTHETIC, category MER_NORMAL). Prediction as written at 13:02.
Gesture by the developer, by hand: banner pull-down, Home Screen, app dead. Result read 13:23:04 — MATCHES the written prediction.
Timeline (device log): 13:21:08.140 push request 85F8-D8A6 surfaces · 13:21:54 banner expanded · 13:22:34.577 "Received
response to 85F8-D8A6 for action QUICK_LOG_START" · 13:22:34.695 "Launch application in BACKGROUND" → new pid 31648 ·
13:22:40.170 process up · 13:22:41.527 "Setting 2 notification categories" = AppDelegate.swift:47–48 (delegate = self, then
register) in didFinishLaunching · 13:22:43.830 [AWESOME NOTIFICATIONS] "The action content doesn't contain any awesome
information" (9.3 s after the tap) · nothing after: no requestAuthorization, no Live Activity request, no notification request,
deactivation reasons never reach 0 (never active → applicationDidBecomeActive never ran → delegate never restored).
State: au.com.notiva…plist 3786f383… UNCHANGED · private group plist 12e8ef2c… UNCHANGED (no second record, marker unchanged)
· real group Preferences still 0 files · group.awn plist 22b11abb… (currentlifeCycle=Terminated — awn's own bookkeeping).
⭐ First OBSERVATION of the theft on a CUSTOM action (QUICK_LOG_START), cold, background, 1.0.2: swallowed silently.
Delay: the push command's issue time did not reach this session (the `!` output was not visible to me); surfaced 13:21:08.140.

## 180b prep (during the wait for 13:43; touches neither the fixture nor the main tree)
13:24:17  second worktree ~/dev/mer-head-worktree, detached at 099792c (contains 2017fd6). ⚠️ SUBSTITUTION: Sentry DSN blanked
in lib/main.dart in that worktree only — labelled like the synthetic notification: it does not touch storage, and it is
still a substitution. Build: flutter pub get, pod install, flutter build ios --simulator --debug (running in background).
Main tree ~/dev/epilepsyrecorder: unchanged (git status clean), at 099792c.
13:31:43  HEAD build done (450 s incl. pub get + pod install). Runner.app 1.1.1+62; Runner AND MERWidget carry application-groups
(entitled, as shipping). DSN absent from flutter_assets/kernel_blob.bin (no "ingest.us.sentry.io", no DSN key). Main tree clean.

## (a) — abandon of the 13:13 in-flight event by 1.0.2's own 30-min rule
13:43:34 simctl terminate (pid 31648, the 181c background process). Pre-launch: au.com.notiva.medicaleventrecorder.plist=3786f383… group.au.com.notiva.medicaleventrecorder.plist=12e8ef2c… group.awn.0be43e74.plist=22b11abb… 
13:43:37 simctl launch 1.0.2 FOREGROUND.
Result: pid 35741. 13:43:45.399 restorePersistentNotification timeout branch (removes 2 delivered, re-adds 356A-192B) ·
13:43:45.979 "Ending activity: C0BA0B4D…" · 13:43:46.006 dismissed. Standard suite now holds ONLY flutter.epilepsy_event_records_v1;
private group suite ONLY mer_records (both mer_active_event keys removed). Record string byte-identical to 13:13 in BOTH
(de556bb9… / 6e5c53c8… are the new file hashes; content unchanged apart from the removed marker). 38DBC0EA stays "lt1": abandoned.

## SEED (1.0.2 itself, never defaults write)
13:44:38
disclaimer 1.0 'I Understand and Agree' tapped by cliclick
⭐ OBSERVED: 1.0.2's home screen shows the Swift record 38DBC0EA as "24 Sep 2026 · 03:13" — the UTC wall time. It was logged
at 13:13 AEST. 1.0.2 displays Swift-written ("…Z") records 10 h off in this zone. Verify after upgrade that HEAD shows 13:13.
13:44:57
tap 'Record Event' (in-app quick record #1)
[{"id":"db67f0f6-2c39-4180-9f91-6afb97eee7dc","timestamp":"2026-09-24T13:44:58.113234","duration":"lt1","feelings":[],"referralRequired":false,"notes":"","eventType":"seizure","severity":"mild","triggers":[]},{"id":"38DBC0EA-BB56-4C91-9898-EBEE47DA8B38","timestamp":"2026-09-24T03:13:00.000Z","duration":"lt1","feelings":[],"referralRequired":false,"notes":"","eventType":"seizure","severity":"mild","triggers":[]}]
mirror unchanged since 13:13: True
13:45:21 tap 'Record with details' (in-app record #2, to carry '/' in notes)
13:45:50 wizard: Absence episode, 1–5 minutes, Moderate, feelings 'Tired and weary' + 'Confused'
  ⚠️ CORRECTION: the line above is WRONG — those 5 taps never executed (shell quoting error, cliclick rejected the arguments); screen verified unchanged. Redone below.
13:46:23 wizard (verified on screen): Absence episode, 1–5 minutes, Moderate, feelings 'Tired and weary' + 'Confused'
13:49:05 trigger 'Poor sleep'; referral 'Yes'; notes entered via simctl pbcopy + Cmd+V + iOS "Allow Paste" (keystroke typing by
  cliclick dropped characters, cleared with Cmd+A/Delete first): "seed 176: aura/visual disturbance, lasted 2/3 min"; 'Save event' tapped.
  first 'Save event' tap did not save (count stayed 2, no error logged); tapped again at 13:51:01
14:00:40 in-app record #2 SAVED BY THE DEVELOPER BY HAND ("Save event"; my cliclick input had stopped registering at ~13:50 —
  not worked around). Record #2: id 7bc759e6-…, absence, oneToFive, moderate, referralRequired TRUE, feelings with EMOJI
  ("😴 Tired and weary","😵 Confused"), triggers ["Poor sleep"], notes "seed 176: aura/visual disturbance, lasted 2/3 min".
Record #3 DROPPED by decision (two Dart records suffice; Swift starts must come last).
⚠️ READ, NOT TESTED: 1.0.2 Dart never calls prefs.reload() — a Dart save after a warm Swift start in the same process would
  overwrite the Swift record. Kept marked as read-only reasoning until something demonstrates it.
au.com.notiva.medicaleventrecorder: 38331
14:03:22 terminate (pid 35741) → relaunch FOREGROUND (fresh Dart cache; delegate restored by didBecomeActive) — a killed app is cold and cold QUICK_LOG_START is swallowed (181c)
14:05:23 lldb: delegate=<Runner.AppDelegate 0x10e006520>, state active; Device ▸ Home via menu (warm, in memory). Payloads push-seed{1,2,3}.apns (SYNTHETIC).

## Swift quick-log starts — attempt 1 (NO STARTS HAPPENED)
14:07:45.915 / 14:07:46.284 / 14:07:46.749  three synthetic pushes (push-seed1/2/3) posted back to back: AB79-24BA, 901E-ACB4,
  CCD4-E22B. SpringBoard: "Not alerting on post" for them; one banner presentable dismissed 14:08:00.
Device reading 14:09–14:10: NO "Received response" for any of the three; NO Runner activity; all three still in
  DeliveredNotifications; plists unchanged since 14:00 / 13:43 (3 records, no active marker); MER-audit-SE3 no MER activity.
⛔ STRUCK: a message of the form "done — 3 starts, actions taken one at a time…" was received here. It was NOT a first-hand
  account: it was a template drafted in advance, in the past tense, by the relaying chat, and pasted. It is an UNSOURCED CLAIM,
  not testimony; there is no conflicting account. The device reading above stands alone. Fixture untouched.
Rule from here: no pre-written observations — observations are asked for, never supplied.
Redo protocol: one start at a time; device read between each step; confirmed on disk before the next.
14:20:13 lldb attach to SUSPENDED pid 38331 hung mid-expression (process traced, SXs); SIGINT ineffective; SIGTERM to lldb/
  debugserver took pid 38331 down with it. MER plists verified unchanged after (e9617879… / 6e5c53c8…). Lesson: do not lldb-evaluate a
  suspended app. Relaunched FOREGROUND as pid 40191 (2026-09-24 14:19:46), didBecomeActive confirmed from the log (not lldb), then Device ▸ Home: warm.

## Swift quick-log starts — attempt 2, one at a time
14:45:17 re-verify (no lldb): pid 40191 alive (same process since 14:19:47, backgrounded 14:20:11); plists e9617879…/6e5c53c8…,
  3 records, no active marker; delegate MER's BY INFERENCE (didBecomeActive 14:19:52.557; awn assigns only in didFinishLaunch,
  once per process; pid unchanged) — not a fresh read.
Start 1, step 1: developer ran push-seed1.apns. Developer's words, verbatim: "run, visually verified the notification appear at
  the top of MER-176-U". Device: exactly ONE new request since 14:45:17 — 1CB8-FDF9 (identifier 70C28C8C-9D5B-444C-953D-BDC047B5369A),
  added 14:46:59.083, category MER_NORMAL, body "SYNTHETIC seed-start-1 …" (read from DeliveredNotifications by identifier);
  SpringBoard logged "Not alerting on post" for it. ⚠️ The stale AB79-24BA (242AEFC4-…, from 14:07) carries the IDENTICAL body
  text, so the banner text cannot distinguish them. Which request is acted on will be read from the response line afterwards.
Start 1, step 2 (developer, by hand): 16:39:24.222 SpringBoard "Received response to 1CB8-FDF9 for action QUICK_LOG_START" — the
  NEW push (70C28C8C…), not the stale AB79-24BA · 16:39:24.405 "Launch application in background" → same pid 40191 RESUMED (elapsed
  2:24:52 at read), not relaunched · 16:39:25.423 Runner "Requesting an activity" · no awesome_notifications line.
  Delegate at the action = MER's AppDelegate — evidenced by handleQuickLogStart's effects (records written, Live Activity requested)
  with no awn swallow line, same pid, no relaunch.
16:44:23 SCREENSHOT artefacts-181/181-seed-start1-step2-postaction.png (sha256 bc7a2c7b21f8c9a7…), taken BEFORE any log/plist read.
  Shows Lock Screen: Live Activity "Event in progress 4:59" with red "Event Ended"; stack: idle notification + stale SYNTHETIC
  seed-start-3/-2/-1 (14:07 batch, "2h ago"). Consistent with disk: 16:39:24 → 16:44:23 = 4:59 elapsed; acted-on 1CB8 absent (removed).
Plists after start 1: main a470c088… / private 01a697dc…; 4 records; mirror string == main string; real group still EMPTY.
  NEW Swift record 1B14D71F-56C5-46BF-960D-A053F46FBE6F, "2026-09-24T06:39:24Z" (whole-second Z), lt1; marker in BOTH suites.
  ⭐ Swift's JSONSerialization rewrite of the WHOLE list: Dart's "aura/visual … 2/3 min" now "aura\/visual … 2\/3 min" (escaped);
  emoji "😴"/"😵" emitted raw UTF-8; Dart timestamps ("…14:00:40.835454", "…03:13:00.000Z") carried verbatim; key order re-shuffled.
⚠️ "Event Ended" on the Live Activity is NOT a planned step (plan is (ii): abandon). In U it runs the entitled widget intent, which
  reads the REAL group (empty) → no duration written; the standard + private markers survive.
Start 2, step 1: developer ran push-seed2.apns himself via `!` ("Notification sent"). No observation stated yet.
  Device: SpringBoard added C987-65AF at 16:47:44.064; in DeliveredNotifications as identifier 027AE588-7356-470B-A633-E9ABE293EBB7,
  body "SYNTHETIC seed-start-2 …" — a NEW delivery, distinct from the stale 901E-ACB4 (54CBA2D4-…, identical text).
  (33CFD4DA-… in the store is the 12:38 Brief-176 synthetic, not new — previously unmapped.) pid 40191 still alive; start-1 marker
  1B14D71F in flight.
  Developer's words, verbatim: "The Ebent in Progress banner from the previous manual event start and a new notification
  'SYNTHETIC see-start-2 (simcit push) - pull down, tap Log Event Now". Consistent with the device (start-1 Live Activity up; new
  027AE588 delivered). Text alone cannot distinguish it from stale 901E-ACB4.
Start 2, step 2 (developer, by hand). Developer's words, verbatim: "Two banners, both the original event and a second banner for
  the new event". 16:51:57 SCREENSHOT artefacts-181/181-seed-start2-step2-postaction.png (sha256 1b32732c2578fe49…), taken before
  reading: TWO Live Activities, "Event in progress 12:33" and "0:50", each with "Event Ended". Consistent with disk: start 1
  16:39:24→16:51:57 = 12:33; start 2 16:51:07→16:51:57 = 0:50.
  Device: 16:51:07.255 "Received response to C987-65AF for action QUICK_LOG_START" — the NEW push (027AE588…), not stale 901E ·
  background launch → same pid 40191 resumed · 16:51:07.637 Runner "Requesting an activity" · no awn line → delegate MER's.
  Plists: main e314eeba… / private 1c27108d…; 5 records; mirror == main; real group still EMPTY. New Swift record
  54605897-4306-45E7-90E5-754ECCBBD869 "2026-09-24T06:51:07Z" lt1. Marker in BOTH suites now 54605897 (start 1's 1B14D71F replaced;
  1B14D71F's record stays lt1, never ended). "\/" escaping preserved through the second Swift rewrite.
  ⭐ OBSERVED 1.0.2 behaviour: a second start does not end the first Live Activity — two run at once; the first is no longer
  referenced by any active marker.

## iOS DEFECT REGISTER FOR THIS RUN (all on the Lock Screen / Live Activity surface)
  D1 OBSERVED  entitlement: shipped 1.0.2 app is unentitled → "App Group" writes land in a private plist; the entitled widget reads
               the real group → Live Activity "Event Ended" records no duration. (181b gate; archive signature.)
  D2 OBSERVED  Backlog 26: cold QUICK_LOG_START swallowed by awesome_notifications' delegate theft in 1.0.2 (181c). HEAD: 0bb8aa7
               reclaim present, unverified (181d pending).
  D3 OBSERVED  1.0.2 displays Swift "…Z" records at UTC wall time (13:13 AEST shown as 03:13). Verify HEAD shows 13:13 after upgrade.
  D4 READ, NOT OBSERVED — recorded 24 Sep 2026 ~16:55 AEST, from source only (192ae40 and 099792c), NOT tested on MER-176-U by decision:
     "The banner a user taps is not necessarily the event they end."
     Chain (identical in 1.0.2 and HEAD): Button(intent: EndMEREventIntent()) passes NO parameter — the tapped activity's
     ContentState.eventId never reaches the intent (MERLiveActivity.swift 1.0.2:26/89, HEAD:49/164); the intent keys everything off
     the App Group mer_active_event marker (EndMEREventIntent.swift 1.0.2:23–26, HEAD:47–50) and then ends EVERY MER activity
     (1.0.2:64, HEAD:116). A start neither refuses nor ends a prior activity (1.0.2 and HEAD startLiveActivity; HEAD
     handleQuickLogStart has no already-active guard) and overwrites the marker — observed at start 2 (two activities, marker = newer).
     WEAKEST LINK: reachability of two concurrent activities.
       · 1.0.2 (shipping) on 17+: REACHABLE — the start branch leaves the idle "Log Event Now" notification up (AppDelegate.swift
         1.0.2:289–292; observed in both screenshots). But the END is broken by D1: marker absent from the real group → NO duration
         to either event; one tap ends BOTH banners. Shipping consequence = both events lose their duration, NOT mis-attribution.
       · Variant U: same as shipping (U reproduces the unentitled app).
       · HEAD (entitled): the end WOULD write seconds against the marker's (newer) event and orphan the older one — the stated
         consequence. But every HEAD start calls scheduleActiveNotification, which removes kPersistentId ("Log Event Now") before
         posting the active notification, and HEAD's only other activity start (restorePersistentNotification, :467) runs only when
         no activity exists. So MER itself offers no second Lock Screen start while an event is live at HEAD. Remaining HEAD routes
         are UNVERIFIED: a MER_NORMAL notification surviving from elsewhere (e.g. synthetic), or a 1.0.2 Live Activity surviving the
         app update alongside a first HEAD start.
  ⛔ D1 ↔ D4 COUPLING (developer's position, recorded 24 Sep ~17:05 AEST): "D1 and D4 ship together or neither ships."
     Reason: in shipping, D1 writes NO duration, so D4 never surfaces. Fixing D1 alone makes the marker readable, and one tap then
     writes a REAL duration against the WRONG event and leaves the other unended — a gap (record says nothing) becomes a falsehood
     (record says something untrue) in a medical history a clinician may read. The D1 fix is what creates it.
     ⚠️ FACT BEARING ON IT: the D1 fix HAS ALREADY LANDED — 824cd16 (24 Aug 2026) is in HEAD 099792c. The next release as the tree
     stands ships D1 fixed and D4 unfixed. What limits the falsehood at HEAD today is only D4's weakest link: HEAD's start removes
     "Log Event Now" (scheduleActiveNotification), so MER offers no second Lock Screen start while an event is live.
     Evidence on a combined fix (NOT a recommendation, nothing written): the widget view already reads context.state (startIso at
     MERLiveActivity.swift HEAD:58/88/119); ContentState carries eventId AND startIso in both builds; EndMEREventIntent is a plain
     AppIntent + LiveActivityIntent (HEAD:8/156) instantiated with no arguments. Passing the tapped activity's eventId/startIso and
     ending only that activity would remove the intent's dependence on the marker. It would NOT remove the need for D1's fix: the
     end is still delivered as a mer_inbox_* instruction in the App Group, which the app must be entitled to read.
  ⚠️ PROVENANCE CORRECTION to the D1 label: D1's MECHANISM is OBSERVED (181b: private plist in the app's own container; archive
     signature lacks application-groups). D1's CONSEQUENCE — "Event Ended records no duration" — is READ, not observed: Event Ended
     has never been pressed on MER-176-U. D2 observed for 1.0.2 only (HEAD pending, 181d). D3 observed. D4 read.

## QUEUE — case (b) upgraded from completionist to LOAD-BEARING (24 Sep ~17:05)
  Case (b) (upgrade mid-event: a 1.0.2 Live Activity + marker surviving into HEAD) is the only plausible USER route into D4 at HEAD.
  Not to be dropped as an edge case. The synthetic-push route into D4 is OUR APPARATUS, not a user path, and must never be written up
  as one. Unverified: whether ActivityKit activities survive an app update at all.
Start 3: developer ran push-seed3.apns himself via `!`. ⚠️ DEVIATION FROM PROTOCOL: the action was taken WITHOUT the step-1 report /
  step-2 prompt — 17:18:12.868 SpringBoard adds 55E5-4461 (identifier 524368F1-4CF6-4400-9DE8-B18643C064C4, NEW — not stale
  541B9177) · 17:18:25.633 "Received response to 55E5-4461 for action QUICK_LOG_START" (12.8 s later) · 17:18:25.670 background launch
  → same pid 40191 · 17:18:25.986 Runner "Requesting an activity" · no awn line → delegate MER's. No first-hand observation was given
  for this start; none is recorded.
  17:18:55 SCREENSHOT artefacts-181/181-seed-start3-postaction-unprompted.png (sha256 0232cc964429c629…), taken before reading:
  THREE Live Activities "39:31", "27:48", "0:30". Consistent with disk: 16:39:24 / 16:51:07 / 17:18:25 → 17:18:55.
  Plists: main 04b5a8eb… / private 19323e02…; 6 records; mirror == main; real group EMPTY. New Swift record
  CBE84F1D-AEF1-44A2-A238-CB8E4FC9910D "2026-09-24T07:18:25Z" lt1; marker (both suites) = CBE84F1D. "\/" and raw emoji preserved.
SEED CONTENT COMPLETE: 6 records = 4 Swift (38DBC0EA abandoned+Dart-normalised ".000Z"; 1B14D71F, 54605897, CBE84F1D whole-second Z,
  never ended) + 2 Dart (db67f0f6, 7bc759e6 with "\/" notes, emoji, referral true). (ii): abandon on the first foreground after
  17:48:25 (30 min after the LAST start).

## ⛔ UNEXPLAINED HOST EVENT DURING THE (ii) WAIT — PROVENANCE GAP 17:19:15 → 17:50:41 (recorded 24 Sep ~17:55 AEST, new session 206fc201)
This is a property of the fixture and travels with it. The fixture is NOT clean because its plist bytes match.
File continuity: this file is the durable copy at ~/dev/_rescue/2026-09-24-claude-502-scratchpad/…/PROVENANCE-176.md. Before this
  entry it was byte-identical to the /private/tmp original (sha256 836e2e1a…255b1d, 27786 bytes); the /tmp original is left as-is.
LAST CONFIRMED READ of the fixture: 17:19:12–17:19:15 (plists 04b5a8eb… / 19323e02…, 6 records, marker CBE84F1D in both suites,
  real group EMPTY), after the 17:18:55 screenshot (three Live Activities). After that, the prior session (485359ca) read only
  source in ~/dev/mer-102-worktree, and from 17:31:25 it ran a background wait for 17:48:30. (ii) was NEVER started: no kill, no relaunch.
THE EVENT, from on-disk timestamps (not from any log yet):
  17:37:49  MER-176-U data/var/run/com.apple.coresimulator.audio.plist rewritten.
  17:37:51  MER-176-U device.plist rewritten, state = 1 (SHUTDOWN). Same second: the prior session's blocking command was SIGKILLed
            (exit 137 at 17:37:51.931). The session ended there.
  17:38:12  Simulator.app relaunched (new pid 61018). CoreSimulatorService (pid 1815, up since 7 Sep 18:00) did NOT restart.
  17:38:57  MER-audit-SE3 (B66C68DF) BOOTED, state 3. No command in the record did this; attributed to nobody.
  Host: uptime 17 days at 17:49, so NO REBOOT. 1-/5-/15-min load averages at 17:49: 108.77 / 245.78 / 230.24.
  The developer reports not touching the simulators since. That is recorded as the developer's statement.
STATE FOUND 17:50:41 (read-only; no simctl, no launch, no kill):
  main  au.com.notiva.medicaleventrecorder.plist        04b5a8eb40791948768d5d42e5d673b6057a015449f141c24ffbd8a27b24a650  mtime 17:18:30
  priv  group.au.com.notiva.medicaleventrecorder.plist  19323e02bbe0559b82d34c89c5be26fb2b5678ece701815db9fa4f8ca9d774ca  mtime 17:18:30
  group.awn.0be43e74.plist 9b6288bf…f6b5 mtime 14:20:12 · real group 5AB1F785…/Library/Preferences still EMPTY
  6 records, ids and order identical to the 17:19 read; mirror == main; marker CBE84F1D in BOTH suites; "\/" and raw emoji intact.
  pid 40191 GONE. MER-176-U SHUT DOWN (no launchd_sim).
WHAT CAN BE ESTABLISHED: both MER plists are byte-identical to 17:19 and were last written at 17:18:30. 1.0.2's timeout branch did
  not run, because it removes both marker keys and they are present. The app process did not survive. The device went from booted
  to shutdown at ~17:37:51.
WHAT CANNOT BE ESTABLISHED (as of this entry):
  · What shut MER-176-U down, and whether the shutdown was orderly or forced.
  · Whether 1.0.2 was foregrounded between 17:19:15 and 17:37:51. Plist identity does NOT exclude it: a foreground before 17:48:25
    takes the non-timeout branch, which writes no defaults.
  · The state of everything outside the two MER plists: the three Live Activities (whether they survive a sim shutdown at all),
    DeliveredNotifications, BulletinBoard, and awn's own store (its plist was not touched, which says nothing about the rest).
  · Whether (ii) as planned is still possible. It assumed a live, backgrounded pid 40191 with three activities up; neither holds now.
    Booting the device to find out is itself a state change to the fixture.
HOST DIAGNOSIS (step 4, after the entry above; host logs only, nothing on the simulator touched):
  FORCED LOGOUT, NOT A RESTART. kern.boottime = 7 Sep 17:45:35, no reboot since. WindowServer (pid 13150) was killed by watchdogd:
  "monitoring timed out for service … is_alive_func returned unhealthy : Display 69734464 not ready" (spin 17:37:38.210–17:37:43.786,
  .ips 17:37:48). loginwindow 17:37:48.288: "Window Server exited, closing down the session immediately", directLogoutReason
  WindowServerExited. Console session 11:05–17:37; new console login 17:38. Thermal pressure Moderate; MacBookAir9,1, 8 GB, load ~245.
  SAME failure earlier today: WindowServer .ips 11:04:54 + watchdog spin 11:05:03 (the 11:05 console login). It is RECURRING on this host.
  CoreSimulatorService pid 1815 did NOT restart. MER-176-U was already "current state: Shutdown" at 17:37:51.945 (CoreSimulatorService).
  No orderly-shutdown record for MER-176-U was found. Most likely the session teardown killed the device's processes, but that is INFERENCE.
  Simulator.app relaunched 17:38:12 by loginwindow PersistentAppsSupport (macOS "reopen windows at login"), then state restoration.
  MER-audit-SE3 boot 17:38:57: no log line found attributing it. Probably Simulator.app window restoration, but INDETERMINATE.
⛔ PROVENANCE CORRECTION to line 15 ("1.0.2 process later absent … terminated/suspended by the system; not by us"): WRONG.
  ~/Library/Logs/DiagnosticReports/Runner-2026-09-24-121920.ips: 1.0.2 (3), pid 21814, device 2E364C3F (MER-176-U), launched 11:57:51,
  CRASHED 12:06:59 with EXC_BAD_ACCESS / SIGSEGV (KERN_INVALID_ADDRESS). Cause not analysed. This was during the Lock/Home/cliclick
  attempts of 12:05–12:12. It precedes the gate (181b), so the records are not affected, but it is an unexamined 1.0.2 crash on this device.

## POST-INCIDENT CLONE + GAP MEASUREMENT (24 Sep 18:03–18:08 AEST, session 206fc201)
CLONE (NOT the frozen fixture; this is the post-incident state, unmodified, as the logout left it):
  18:03:33–18:03:46  `simctl clone` MER-176-U (Shutdown, never booted since 17:37:51) → "MER-176-U-POSTINCIDENT-1737-NOT-FROZEN",
  UDID 8E484F3D-67D5-4B5A-BA9B-D3E8BD2040F2. Carries main 04b5a8eb40791948… / private 19323e02bbe0559b….
  Full-device sha256 manifests in ~/dev/_rescue/2026-09-24-claude-502-scratchpad/: source PRE-clone (11643 files, manifest
  sha256 e84fd8f12797b627…) == source POST-clone (the clone did not change the source). Clone == source except device.plist (name/UDID)
  and one file NOT copied by simctl: datacom.apple.modelcatalog/tokenStore/0968BEF9-… (named for the host bootSessionUUID; a host token,
  not app data).
GAP MEASUREMENT: Data container 6AF194C4 (65 entries, files AND directories, so that deletions would show too):
  ZERO entries with mtime after 17:19:15. Newest mtime 17:18:30 (the two MER plists). No SQLite / -wal / -shm exists in the container.
  App Group container 5AB1F785: zero entries after 17:19:15 (mtime or ctime).
  Two entries have ctime after 17:19:15: Library/Caches/…/com.apple.metal/functions.data + libraries.data, ctime 17:37:50, mtime 12:45:21,
  xattr com.apple.runningboard.can-suspend-locked. That is a metadata change during process teardown, not a data write. Their content
  was never hashed before the event, so "unchanged content" is NOT established for these two. They are a Metal shader cache, not app data.
DEVICE UNIFIED LOG, read OFFLINE from a copy of the device's own log store (no boot; MER-176-U-log.logarchive, minimal Info.plist added,
  "partial metadata" warning):
  Control: the 17:18:25 Runner[40191] lines (response, "Requesting an activity", activity 3EABFE8B) ARE present, so Runner's
  Default-level lines are captured. Coverage 17:18–17:37 is continuous (1768–3627 lines per minute, no empty minute).
  17:19:15 → 17:37:50: ZERO lines from pid 40191 or Runner, no "Received response", no "Launch application", nothing naming MER.
  17:37:50.109 launchd_sim: "System shutdown initiated by kernel - launchd got a SIGTERM" → 17:37:50.260 MER UIKitApplication service
  removed → 17:37:50.680 SpringBoard / 17:37:50.742 liveactivitiesd: pid 40191 connection invalidated (exited). Exit signal not logged.
  Other device writes in the gap are iOS system daemons only (Photos, geod, aps, Mail, widgets, routined …), none from MER.
CONCLUSION, in the narrower words: the fixture's DATA integrity through the gap is ESTABLISHED BY MEASUREMENT. Nothing in the app Data
  or App Group container was written after 17:18:30. The remaining gap is in our knowledge of PROCESSES, and it is smaller than it was:
  no MER process activity is logged from 17:19:15 until teardown at 17:37:50. What is still NOT established: anything MER did below
  Default log level; the exit signal; the state of the three Live Activities after a device shutdown; the two Metal cache files' content.
  The device-level state DID change: the process is gone, the device was shut down by a forced host logout, and system daemons wrote
  files throughout the gap.
HOST at 17:37 (from the watchdog stackshot): 885 processes, 8 GB Intel MacBook Air. TWO simulators booted (MER-176-U AND MER-audit-SE3;
  SE3's pids precede MER-176-U's, so it had been up since before MER-176-U booted). Claude desktop's Virtualization VM ~1.1 GB, SimMetalHost
  (MER-176-U) 724 MB, WebKit 462 MB, Claude renderer 453 MB, WindowServer 440 MB, Dropbox 322 MB, OneDrive 266 MB. Swap at 18:07:
  2.46 of 3.07 GB used.
  18:08:13 MER-audit-SE3 shut down (simctl shutdown). `defaults write com.apple.iphonesimulator ApplePersistenceIgnoreState -bool YES`
  (prior value: unset; revert with `defaults delete com.apple.iphonesimulator ApplePersistenceIgnoreState`). NOT VERIFIED that this
  stops a login from booting a device: Simulator.app is still relaunched by loginwindow, and CurrentDeviceUDID = B66C68DF (SE3).
  All three MER devices Shutdown at 18:08. MER-176-U plists re-hashed 18:08: unchanged.

## ⛔ OPEN — 1.0.2 SIGSEGV on MER-176-U, 24 Sep 2026 12:06:59 AEST (opened 24 Sep ~18:10)
  Report: ~/Library/Logs/DiagnosticReports/Runner-2026-09-24-121920.ips (copy in ~/dev/_rescue/2026-09-24-claude-502-scratchpad/).
  1.0.2 (3), pid 21814, launched 11:57:51, EXC_BAD_ACCESS / SIGSEGV KERN_INVALID_ADDRESS at 0x12f5fda98. Happened during the 12:05–12:12
  Lock/Home/cliclick attempts. CAUSE UNKNOWN, NOT ANALYSED. It is outside the seed's gate and does not affect the records. It is an
  unexplained crash of the app under test, days before a release. Status: OPEN.

## RESUME ATTEMPT — (ii) on MER-176-U (original). STOPPED BEFORE THE LAUNCH (24 Sep 19:04–19:11 AEST)
Decision (Waz, via chat): resume (ii) on the ORIGINAL, not the clone. It rests on a BOUNDED gap 17:19:15 → 17:37:50, bounded by:
  (1) a container-wide sweep of files AND directories, mtime and ctime: nothing in the app Data or App Group container written after 17:18:30;
  (2) an offline read of the device's own log store: no app lines 17:19:15 → 17:37:50. ⭐ CONTROL: the same log DOES contain Runner[40191]'s
      own lines at 17:18:25 (response, "Requesting an activity", activity 3EABFE8B), and the minute-by-minute coverage is continuous. The
      absence claim is worth something only because the same log demonstrably captures this app's lines immediately before the window.
  Still unknown: sub-Default activity, the 17:37 exit signal, content of the two Metal cache files (not app data).
  Rollback = MER-176-U-POSTINCIDENT-1737-NOT-FROZEN (8E484F3D…).
19:04:09 host before boot: swap 1604/3072 MB used, 48% free, load 2.6, no simulator booted. Plists re-hashed 04b5a8eb… / 19323e02….
19:04:30 `simctl boot` MER-176-U ONLY (Simulator.app not opened) → bootstatus Finished 19:05:51. Swap then 2402/3072 MB.
19:06:18 SCREENSHOT artefacts-181/176-postboot-prelaunch.png (sha256 a53a1c5babcaef48…): Home Screen, Dynamic Island empty. No Live
  Activity visible on that surface. The Lock Screen was not captured.
⛔ UNPLANNED APP LAUNCH CAUSED BY THE BOOT ITSELF (nobody requested it):
  19:04:54.653 liveactivitiesd "Restored activities: 82C24452…, C63A9B39…, 3EABFE8B…" (3EABFE8B = start 3's activity, created 07:18:26Z).
  19:04:55.984 "Starting activity" for the reloaded activities → 19:04:56.271 liveactivitiesd "Launching au.com.notiva.medicaleventrecorder"
  → requests to SpringBoard to open the app (19:04:56, 19:04:58, 19:05:37) → 19:05:37.045 "Bootstrapping app … with intent BACKGROUND".
  19:05:38–39 SpringBoard CoverSheetActivities "Activity started" for all three (platter target MER).
  Runner pid 65836 up 19:06:02 · 19:06:07.151 "Setting 2 notification categories" (didFinishLaunching) · deactivation reasons never reach 0
  (never active, so applicationDidBecomeActive never ran, so the timeout branch did not run) · 19:06:15.161 SpringBoard WATCHDOG termination
  "watchdog provision violated" (the host was starved at the time; that link is INFERENCE). No host crash report written.
  After it: main 04b5a8eb… / private 19323e02… UNCHANGED (mtime 17:18:30), markers CBE84F1D present in both suites.
  group.awn.0be43e74.plist 9b6288bf… → 22b11abb… (19:06:15, awn's lifecycle bookkeeping; same value as in 181c). Also written: Saved
  Application State, com.apple.metal/*.list.
OBSERVATION, own scope: three ActivityKit activities of 1.0.2 SURVIVED A SIMULATOR DEVICE SHUTDOWN (forced, via host logout) + reboot, and
  their restoration at boot made liveactivitiesd background-launch the app.
  ⛔ SCOPE: this is NOT case (b). Case (b) is survival across an APP UPDATE, a different lifecycle, and it remains UNTESTED. This
  observation must not be read as "activities survive" in any argument about the release blocker.
  Consequence for the rollback: booting POSTINCIDENT-1737 (or any clone of this state) will presumably do the same background launch.
  That is untested, and should be expected.
19:10:55 swap 3014/4096 MB used (the OS grew swap from 3 to 4 GB). STOPPED before the foreground launch per the stop rule. Device left
  BOOTED, app NOT running, markers present.

## DEFERRED PATH — ORDERLY SHUTDOWN (24 Sep 19:13–19:16 AEST)
19:13:35 Dropbox and OneDrive still running; swap 3272/4096 MB used. Waz chose the deferred path: no launch tonight; Mac to be
  restarted; fresh boot in a new session.
19:16:08 `xcrun simctl shutdown` MER-176-U, REQUESTED from the host (returned 19:16:10; state 1). This is the ORDERLY shutdown, to
  contrast with 17:37:51, which nobody requested and which followed the forced host logout.
  ⚠️ NOTE ON THE EVIDENCE: the device's own log shows the SAME line for both: 19:16:09.750 launchd_sim "System shutdown initiated by
  kernel - launchd got a SIGTERM", identical in wording to 17:37:50.109. So the DEVICE log cannot tell orderly from forced. The
  difference is established HOST-side only (a requested simctl command here, a forced logout at 17:37). Read the 17:37 entry above
  accordingly: that line does not by itself show the 17:37 shutdown was forced.
19:16 re-hash after shutdown: main 04b5a8eb40791948768d5d42e5d673b6057a015449f141c24ffbd8a27b24a650 · private
  19323e02bbe0559b82d34c89c5be26fb2b5678ece701815db9fa4f8ca9d774ca (both mtime 17:18:30, UNCHANGED through the boot and the
  uncontrolled background launch) · group.awn.0be43e74.plist 22b11abb19abf9c280f989ff2419e0bba1377c0108978fb1190dd1ed3b982c21 (19:06:15).
(ii) has NOT run. The freeze has NOT happened. Markers CBE84F1D are still present in both suites.

## RESUME ATTEMPT 2 — STOPPED AT STEP 1, HOST CHECK (24 Sep 2026 19:41–19:43 AEST, new session)
Host restarted: kern.boottime 19:33:03 (after the 19:16 shutdown). Checks were read-only. No simctl boot, no launch, nothing quit.
19:41:49  uptime 9 min · load 48.63 / 359.83 / 262.03 · swap 853/2048 MB used · 6092 pages free (~24 MB) · memory_pressure
  free 49% · 8 GB. 19:42:22: load 42.20 / 328.56 / 254.08 · swap 856/2048 MB · free 48% · swapouts since boot 610575, swapins 397390.
⛔ UNREQUESTED BOOT AT LOGIN: MER-audit-SE3 (B66C68DF) was already BOOTED, device.plist written 19:34. Simulator.app (pid 442) started
  19:33:29, which is login-item / reopen-at-login timing. ApplePersistenceIgnoreState = 1 (set 18:08) did NOT stop it. CurrentDeviceUDID
  is still B66C68DF. The 18:08 entry recorded this as NOT VERIFIED; it has now failed.
Dropbox (pid 765 and others) and OneDrive (pid 764) auto-started. They were NOT quit, because the stop was taken first.
Fixture untouched (Shutdown), hashed read-only 19:42: main 04b5a8eb… · private 19323e02… (both mtime 17:18:30) · group.awn 22b11abb…
  (19:06:15) · real group Preferences 0 files. All UNCHANGED from 19:16.
Stopped per the brief: the numbers are poor on a freshly restarted host, and a second simulator is up that nobody booted.

## REMEDIATION AFTER ATTEMPT 2 (approved by Waz via chat) + RE-MEASUREMENT (24 Sep 2026, same session)
⚠️ HOST CLOCK STEP, applies to EVERY time in this entry and in "RESUME ATTEMPT 2" above: the host clock ran FAST after the 19:33 boot
  and was stepped BACK by ≥ 2 m 48 s. Evidence: a wait loop exited reading 19:51:00, and the next command read 19:48:12. At 19:48:53
  `sntp time.apple.com` gave offset +0.028 s (correct from then on). The size of the error at each earlier reading is NOT known;
  up to ~3 min fast. It does not reorder anything below. No `timed` log line for the step was found.
(fast clock) 19:44:17–19:44:21  `xcrun simctl shutdown` MER-audit-SE3 (B66C68DF), rc 0.
(fast clock) 19:44:21–19:44:29  Dropbox and OneDrive quit via AppleScript `quit`, rc 0. Afterwards the Dropbox FileProvider extension
  was still running (it had gone by the re-measurement); OneDrive Sync Service helper (pid 764) and StandaloneUpdaterDaemon (pid 1085)
  are STILL running. Neither was killed.
Login-item check: System Events login items = "OneDrive Sync Service", "Dropbox". Simulator is NOT a login item. No Simulator
  LaunchAgent in ~/Library/LaunchAgents. So nothing was removed. A loginwindow log query for "simulator" in 19:33:00–19:34:30 returned
  no lines. The 19:33:29 relaunch of Simulator.app is UNATTRIBUTED from the log; the 17:38 relaunch yesterday was PersistentAppsSupport.
(fast clock) 19:47:58  ⛔ ApplePersistenceIgnoreState REVERTED: `defaults delete com.apple.iphonesimulator ApplePersistenceIgnoreState`.
  Before 1, after "does not exist" (unset, its value before 18:08). DEMONSTRABLY INEFFECTIVE: it was set during the 19:33 login, and
  SE3 was booted anyway (device.plist 19:34, Simulator.app 19:33:29). ⛔ It must NEVER be cited as a control. It was reverted so that
  no future reader counts a setting that did not work as protection.
REJECTED, with the reasons recorded: changing CurrentDeviceUDID (it changes WHICH device boots, not WHETHER one does; pointed wrongly,
  it boots the fixture). Changing the global "reopen windows at login" setting (a machine-wide preference; not ours to change for a
  test rig). REPLACED BY: the PRE-FLIGHT check at the top of the RESUME block.
RE-MEASUREMENT, correct clock, no simulator booted:
  19:48:12  load 3.35 / 106.55 / 171.06 · swap 172/1024 MB used · memory_pressure free 58% · 5577 pages free
  19:48:42  load 2.49 / 96.48 / 165.17 · swap 172/1024 MB used · free 59% · 4089 pages free · swapouts since boot 809881 (static
            across the 30 s), swapins 719334
  Top CPU at 19:48:42: biomesyncd 45.7%, mobileassetd 42.5% (post-boot system daemons), then Terminal and diskimagesiod.

## RESUME ATTEMPT 3 — (ii) and the freeze (24 Sep 2026, same session; GO from Waz via chat)
⚠️ CLOCK: every host time BEFORE 19:48 tonight is ±3 min (see the clock-step note above). All times from 19:48 on are sntp-correct.
  Device-log times are the simulator's, and it takes the host clock, so the same caveat applies to device-log times before 19:48 tonight.
  Last night's times (before the 19:33 restart) are NOT affected.
19:54:44  PRE-FLIGHT: booted devices = NONE (no launchd_sim). Simulator.app pid 442 (from the 19:33 login) open, no device.
  Host: load 2.17 / 30.71 / 109.07 · swap 172/1024 MB · free 58%. Pre-boot manifest of Data container 6AF194C4: 65 entries
  (40 files hashed), same entry count as the 18:05 gap sweep. Real group Preferences 0 files. Plists 04b5a8eb… / 19323e02… / awn 22b11abb….
19:54:54–19:54:56  `xcrun simctl boot` MER-176-U ONLY. Re-hash IMMEDIATELY (19:54:56): 04b5a8eb… / 19323e02… MATCH.
19:56:11  bootstatus finished. Re-hash: MATCH.
⛔ EXPECTED BACKGROUND LAUNCH DID NOT HAPPEN. Device log 19:55:07.596 liveactivitiesd "Restored activities:" — an EMPTY list (last night
  19:04:54.653 it listed 82C24452, C63A9B39, 3EABFE8B). No "Launching au.com.notiva…", no Runner process. UNCLASSIFIED (device-level;
  in neither FIXTURE CHECKS list). ADJUDICATED from the device's own log, not inferred:
⛔ PROVENANCE CORRECTION to the 19:04–19:16 entries above: last night's record MISSED A SECOND UNCONTROLLED LAUNCH, and the ending of all
  three activities. Read tonight from the device log:
    19:09:36.217  liveactivitiesd "Ending activity 82C24452… for XPC participant content source process(target: com.apple.chronod)"
    19:09:36.244  liveactivitiesd "Launching au.com.notiva.medicaleventrecorder" → 19:09:36.370 SpringBoard "Bootstrapping … with
                  intent background" → Runner pid 66201: didFinishLaunching only ("Got 2 … Setting 3 notification categories"
                  19:09:55.525, then "Setting 2 notification categories" 19:09:55.532); deactivation reasons 0 → 1024 → 3072, never back to 0
                  (never active, so no applicationDidBecomeActive and no timeout branch) → 19:10:14.983 SpringBoard WATCHDOG
                  "watchdog provision violated", process exited.
    19:09:51.187  "Ending activity C63A9B39…", same source (chronod)
    19:10:06.192  "Ending activity 3EABFE8B…", same source (chronod)
  So all three 1.0.2 activities were ENDED BY THE SYSTEM (content source chronod, NOT Runner, NOT by us) ~3–4 min after the 19:06:15
  watchdog kill. That is why tonight's boot restores none and launches nothing. WHY chronod ended them is NOT established. The line
  "19:10:55 … app NOT running" stands (pid 66201 had exited 19:10:14). The 19:16 hashes show pid 66201 wrote neither MER plist;
  group.awn mtime stayed 19:06:15.
  Consequences: FIXTURE CHECKS #1 ("booting triggers an unrequested 1.0.2 launch") is OUT OF DATE for the current state. It held
  while the activities existed. The post-freeze note ("(ii) should have ended the activities") is moot: they were already gone.
(ii) PREDICTION, AMENDED BEFORE RUNNING (20:0x, from the finding above; the 18:05 source reading is unchanged): foreground launch →
  applicationDidBecomeActive → 1.0.2 restorePersistentNotification timeout branch → flutter.mer_active_event removed from main AND
  mer_active_event removed from private; endLiveActivity() called, but with NO activities to end, so the 13:43-style "Ending activity"
  line is NOT expected and its absence is NOT a failed prediction; records untouched: 6 records, with 1B14D71F / 54605897 / CBE84F1D still
  lt1. ⛔ STOP rule unchanged: if the markers do not clear, STOP, and do not relaunch.
20:01:22  SCREENSHOT screenshots/176-attempt3-postboot-prelaunch.png (sha256 734c5d25dd63b9f2c1399bcc849f00169e284fad9353a0f5b2f06d6fd933302d):
  Home Screen page 1, Dynamic Island empty. Consistent with there being no activities. Lock Screen not captured.
20:01:38  pre-launch re-hash: 04b5a8eb… / 19323e02… / awn 22b11abb… MATCH.
20:01:38  `xcrun simctl launch` 1.0.2 → pid 3633.
FOREGROUND CONFIRMED FROM THE DEVICE LOG (not from the command): 20:01:39.378 SpringBoard "Bootstrapping … with intent
  foreground-interactive" · deactivation reasons 32 → 0 at 20:01:45.430 · then the didBecomeActive pair: "Setting 2 notification
  categories" 20:01:45.430 + "Requesting authorization with options 7" 20:01:45.434 · then the timeout-branch signature seen at 13:43:
  "Removing 2 delivered notifications" + "Adding notification request 356A-192B" 20:01:45.951. No watchdog, and the process stayed alive.
(ii) RESULT, read 20:02:53 — MATCHES THE AMENDED PREDICTION:
  main  au.com.notiva.medicaleventrecorder.plist        cf9c5eec210476d88162d27773b0d4e723c4d42834cf8ec6946d4f07272c943c  mtime 20:01:47
        keys now: flutter.disclaimerAcceptedVersion, flutter.epilepsy_event_records_v1. REMOVED: flutter.mer_active_event
        (was {"id":"CBE84F1D-AEF1-44A2-A238-CB8E4FC9910D","startIso":"2026-09-24T07:18:25Z"}). No other key added or changed.
  priv  group.au.com.notiva.medicaleventrecorder.plist  d850600fc64685b73f68628bea45bd2d620107eac68ac75d477d5f6a32894f85  mtime 20:01:47
        keys now: mer_records. REMOVED: mer_active_event.
  Records: 6 in both suites; mirror == main; record strings BYTE-IDENTICAL to the pre-(ii) plists (compared against the untouched
  POSTINCIDENT clone, whose plists hash 04b5a8eb… / 19323e02…). CBE84F1D / 54605897 / 1B14D71F all still "lt1": ABANDONED, not ended.
  Real group 5AB1F785…/Library/Preferences: still 0 files.
  endLiveActivity(): no liveactivitiesd "Ending activity" line and no activity request, as amended (nothing to end). Its CALL is
  therefore NOT observed; it is inferred from the timeout branch having run (the removed/re-added notifications and both markers gone).
  group.awn.0be43e74.plist → f355e4b8… (the 13:02 pre-gate foreground value; awn lifecycle bookkeeping).
OTHER CONTAINER CHANGES from this planned foreground launch (pre-boot manifest vs 20:02 read; 65 → 64 entries):
  expected (FIXTURE CHECKS list): com.apple.metal/*.list + dir, *.data ctime, Saved Application State, Library/Preferences dir mtime.
  io.sentry/* rewritten, and io.sentry/lastInForeground.timestamp DELETED (by the SDK). Moot: io.sentry is deleted at the freeze.
  ⚠️ NOT IN EITHER LIST before tonight, now classified as expected-on-LAUNCH: Library/Caches/async.log (0 bytes, 20:01:46) and
  Library/Caches/SentryCrash/Medical Event Recorder/Data/CrashState.json (20:01:46). SentryCrash is NOT deleted by the freeze brief;
  it stays and is in the manifest's expected-to-change list.
