import Flutter
import UIKit
import UserNotifications
import ActivityKit
import os.log
import awesome_notifications

@main
@objc class AppDelegate: FlutterAppDelegate {

  // ── SharedPreferences key prefix (Flutter uses "flutter." on iOS) ─────────
  //
  // NOTE the absence of a record-list key. Swift no longer reads or writes the
  // stored record list at all: Dart's main isolate is the only writer of it,
  // and this side posts facts to the capture inbox instead. A grep test under
  // ios/ asserts the key literal never reappears in Swift, so it is spelled
  // nowhere here — not even in a comment.
  private let kActiveEventKey  = "flutter.mer_active_event"

  // ── App Groups shared storage (used by MERWidget / EndMEREventIntent) ──────
  private let kAppGroupId      = "group.au.com.notiva.medicaleventrecorder"
  private let kSharedActiveKey = "mer_active_event"

  // The pre-inbox record mirror. Read once by Dart's reconciliation and then
  // deleted; never written. Kept only so the fold-in can find it.
  private let kLegacySharedRecords = "mer_records"

  // ── Capture inbox ─────────────────────────────────────────────────────────
  // One key per instruction, in the App Group so the widget extension can write
  // it too. Must match kInboxKeyPrefix in lib/models/capture_instruction.dart.
  private let kInboxPrefix = "mer_inbox_"

  // ── Unreadable-marker quarantine ──────────────────────────────────────────
  // PRESERVATION ONLY. Nothing in the field reads either key. They exist because
  // bytes are cheap and deleting an active marker we could not parse is
  // irreversible — that asymmetry is the whole justification and there is no
  // other. The os_log beside each write is a DEVELOPMENT reader: Console.app
  // over a cable, not durable across a reboot.
  //
  // Most-recent wins, so a second unreadable marker overwrites the first. That
  // is deliberate: the marker is one event at a time, the payload is two fields,
  // and unbounded growth on a store this path is already latency-sensitive about
  // buys completeness nobody reads. The COUNT is what tells a later reader
  // whether it recurred.
  private let kQuarantineKey      = "mer_active_quarantine"
  private let kQuarantineCountKey = "mer_active_quarantine_count"

  // ── Abandoned-event timeout ───────────────────────────────────────────────
  // Must equal _timeoutMins * 60 in lib/services/notification_service.dart. It
  // was an inline `30 * 60` compared in exact seconds while Dart compared
  // truncated minutes; a cross-language test now pins the two together, which
  // is the closest thing to one source across a language boundary.
  private let kActiveEventTimeoutSeconds: TimeInterval = 30 * 60

  // ── Live Activity staleness ───────────────────────────────────────────────
  // When the app stops being able to VOUCH for what the Live Activity says.
  // Deliberately NOT the same as the timeout above, and deliberately shorter.
  //
  // ⚠️ DO NOT "TIDY" THIS TO MATCH THE 30 ABOVE. They answer different
  // questions. 30 minutes decides when an event is ABANDONED, which is a data
  // question about the record. This decides when the DISPLAY should stop
  // asserting something the app can no longer confirm — and the app has been
  // unable to confirm it since the moment it was backgrounded.
  //
  // Why 10 and not 5: the duration buckets break at five minutes
  // (oneToFive/gt5), so a genuinely long event crosses five minutes routinely.
  // Staling there would mark almost every gt5 event stale while it was still
  // running, which trains the user to ignore the stale state — and a signal
  // that is usually wrong is worse than no signal, because it stops meaning
  // anything. 10 clears that boundary and still corrects the display a full
  // twenty minutes before the data gives up.
  private let kActivityStaleAfterSeconds: TimeInterval = 10 * 60

  // ── Live Activity dismissal deadline ──────────────────────────────────────
  // How long the notification-action path waits for ActivityKit to dismiss the
  // Live Activity before handing the action's completion handler back to iOS.
  //
  // ⚠️ NOT related to either constant above, and not a tidy-up candidate. Those
  // two are durations of an EVENT. This is a deadline on a single IPC
  // round-trip, and the only reason it exists is the asymmetry below.
  //
  // **On iOS 17+ an event ends in a process whose lifetime the system
  // guarantees.** `EndMEREventIntent.perform()` is async and awaits the
  // dismissal inline, so it always lands. **On 16.2-16.x the event ends inside a
  // notification-action callback whose window the app closes itself** by calling
  // the completion handler. Anything started and not waited for before that call
  // is lost when iOS suspends the process.
  //
  // Too short and the dismissal is lost again. Too long and iOS kills the app
  // instead of suspending it, which is worse. Three seconds is orders of
  // magnitude above a normal ActivityKit response and far inside any plausible
  // system limit. It is deliberately the same value as kCaptureChannelTimeout in
  // lib/services/ios_capture_bridge.dart: both bound one IPC hop on a path a
  // user is waiting on.
  private let kLiveActivityDismissDeadline: TimeInterval = 3

  // ── Notification identifiers ──────────────────────────────────────────────
  private let kPersistentId        = "1"
  private let kActivePersistentId  = "2"
  private let kFeedbackId          = "mer_feedback_native"
  private let kBtnStart            = "QUICK_LOG_START"
  private let kBtnEnd              = "QUICK_LOG_END"
  private let kCategoryNormal      = "MER_NORMAL"
  private let kCategoryActive      = "MER_ACTIVE"

  // ── Navigation ────────────────────────────────────────────────────────────
  private let kPendingOpenLatest = "mer_open_latest_event"

  /// The id of the event a tapped feedback notification NAMED, handed to Dart
  /// on the next foreground.
  ///
  /// ⭐ A NEW KEY, NOT A REPURPOSED ONE, 23 September 2026. `kPendingOpenLatest`
  /// keeps its name, its meaning and its BOOL type. Widening it would make an
  /// upgrade ambiguous in the one direction that matters: a flag written by the
  /// CURRENT shipping build carries no id, and the new build must be able to
  /// tell that from an id it simply has not read yet.
  ///
  /// ⚠️ UNPREFIXED, deliberately, and matching kPendingOpenLatest rather than
  /// kActiveEventKey. Both live entirely inside Swift's own namespace — written
  /// here, read here, returned to Dart over the channel — so
  /// `shared_preferences` never sees either one. This is NOT a new published
  /// Dart storage key, and that is what makes it a small commitment.
  ///
  /// ⛔ Distinct from Android's `mer_open_event_id`, which IS a
  /// `shared_preferences` key and reaches Dart as `flutter.mer_open_event_id`.
  /// Same idea, different transport, and naming them alike would invite a
  /// reader to assume one mechanism where there are two.
  private let kPendingOpenEventId = "mer_pending_open_event_id"

  /// The `userInfo` key both feedback notifications carry.
  ///
  /// ⚠️ DUPLICATED as a literal in EndMEREventIntent.swift, which is a separate
  /// target — the same boundary that already forces MERActivityAttributes.swift
  /// and the inbox schema to be duplicated. Any change here must be mirrored
  /// there, and test/notification_fallback_routing_test.dart checks both.
  private let kNotificationEventIdKey = "mer_event_id"
  private var navChannel: FlutterMethodChannel?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)

    // SharedPreferencesPlugin is deliberately NOT registered on the background
    // engine any more.
    //
    // It was added by 52b41b9, when the iOS quick-log path still ran through
    // Dart in a background isolate and needed `SharedPreferences.getInstance()`
    // to work there. Pass A moved iOS capture entirely into Swift, and
    // `onActionReceived` in notification_service.dart returns at its first line
    // on iOS, so nothing Dart-side reads preferences on this path. Dart also
    // never calls `setListeners` on iOS — `init()` returns before it — so
    // awesome_notifications never creates a background engine here and this
    // callback is not invoked at all.
    //
    // Removed rather than left as a harmless no-op because it is the plugin
    // whose startup cost was suspected of consuming the notification action's
    // window, and a reader finding it here would reasonably conclude the
    // background isolate is still a live path on iOS. It is not.
    //
    // NOTE what this does NOT remove, and cannot: `GeneratedPluginRegistrant`
    // above and the engine boot inside `super.application(...)` below both run
    // on EVERY cold launch, including one serving a notification action, and
    // both must complete before `didReceive` is delivered. That is the real
    // startup cost on this path, it registers shared_preferences among
    // everything else, and the app does not run without it. The fix for the
    // window is the ordering inside handleQuickLogEnd, not this line.
    SwiftAwesomeNotificationsPlugin.setPluginRegistrantCallback { registry in
      SwiftAwesomeNotificationsPlugin.register(
        with: registry.registrar(forPlugin: "io.flutter.plugins.awesomenotifications.AwesomeNotificationsPlugin")!)
    }

    let result = super.application(application, didFinishLaunchingWithOptions: launchOptions)

    UNUserNotificationCenter.current().delegate = self
    registerNativeNotificationCategories()

    if let controller = window?.rootViewController as? FlutterViewController {
      let channel = FlutterMethodChannel(
        name: "au.com.notiva.mer/navigation",
        binaryMessenger: controller.binaryMessenger
      )
      channel.setMethodCallHandler { [weak self] call, result in
        switch call.method {
        case "getPendingOpenLatest":
          let key   = self?.kPendingOpenLatest ?? ""
          let flag  = UserDefaults.standard.bool(forKey: key)
          UserDefaults.standard.removeObject(forKey: key)
          result(flag)
        // The persisted half of the carrier. Read only after
        // `getPendingOpenLatest` has said a tap is pending, and consumed as it
        // is read, exactly like the flag.
        //
        // ⭐ A STALE ID CAN NEVER BE CONSUMED, and it is worth saying why rather
        // than trusting it. The id is only ever written in the same breath as
        // the flag, and the tap branch REMOVES it when there is no id — so
        // "id present" implies "flag present". If the app dies between draining
        // the flag and draining the id, the leftover id is unreachable: nothing
        // reads it without a flag, and the next tap either overwrites it or
        // clears it.
        case "getPendingOpenEventId":
          let key = self?.kPendingOpenEventId ?? ""
          let id  = UserDefaults.standard.string(forKey: key)
          UserDefaults.standard.removeObject(forKey: key)
          result(id)
        case "getShowPreviewsSetting":
          // ⛔ EXACTLY ONE REPLY, ON EVERY PATH — 23 September 2026. Listed in
          // Brief 146 as the second skippable reply site and fixed here.
          //
          // The reply sat inside `getNotificationSettings`' completion, so a
          // completion that never ran meant `result` was never called. A
          // Flutter method channel has no timeout anywhere in its chain —
          // `_DefaultBinaryMessenger.send` awaits a bare `Completer` completed
          // only from the reply callback — so that is not a slow call or a
          // failed call. It is a Dart future that never completes and never
          // errors, for the life of the process.
          //
          // ⭐ THE LATCH IS NOT BELT AND BRACES, IT IS REQUIRED. With a
          // fallback in play the system completion may still arrive
          // afterwards, and replying twice to one channel call is itself a
          // crash. Both paths hop to the main queue before touching
          // `answered`, so the flag needs no lock.
          //
          // ⭐ "other" IS THE CONSERVATIVE FALLBACK, not an arbitrary default.
          // Dart reads this as `setting == 'always'`, so "other" makes Help
          // show its previews-may-not-appear row. A fallback of "always" would
          // tell the user previews are shown when nothing confirmed it —
          // reassurance is the direction that costs privacy.
          var answered = false
          let reply: (String) -> Void = { value in
            if answered { return }
            answered = true
            result(value)
          }
          UNUserNotificationCenter.current().getNotificationSettings { settings in
            let value = settings.showPreviewsSetting == .always ? "always" : "other"
            DispatchQueue.main.async { reply(value) }
          }
          // If the system never answers, the channel still does.
          DispatchQueue.main.asyncAfter(deadline: .now() + 5) { reply("other") }
        case "restoreNotification":
          DispatchQueue.main.async { self?.restorePersistentNotification() }
          result(nil)
        case "endActiveEvent":
          // The in-app End button. Swift owns the whole teardown so that no
          // fourth writer of the end instruction exists — see
          // endActiveEventFromApp.
          DispatchQueue.main.async {
            // ⛔ NO SELF, STILL A REPLY — 23 September 2026. This read
            // `self?.endActiveEventFromApp { result(nil) }`, where a nil `self`
            // short-circuits the whole expression: the method is never invoked,
            // so the completion that calls `result` never runs, and NOTHING
            // ELSE EVER CALLS IT.
            //
            // ⚠️ A channel reply is not optional. A Flutter method channel has
            // no timeout anywhere in its chain — `_DefaultBinaryMessenger.send`
            // awaits a bare `Completer` completed only from the reply callback
            // — so a skipped `result` is not a slow call or a failed call. It
            // is a Dart future that never completes and never errors, for the
            // life of the process.
            //
            // ⭐ WHETHER `self` CAN ACTUALLY BE NIL HERE IS NOT CLAIMED, and
            // deliberately was not investigated: establishing it costs more
            // than closing it, and the answer would not change this code.
            //
            // ⭐ NOTE THE CONTRAST WITH THE CALLEE, which already had this
            // right: `endActiveEventFromApp` guards its own weak capture with
            // `guard let self = self else { completion(); return }`. The
            // discipline existed one frame down and had not reached the call
            // site — so this is the local-correctness-does-not-propagate class,
            // not an oversight about weak references.
            guard let self = self else {
              result(nil)
              return
            }
            self.endActiveEventFromApp { result(nil) }
          }
        case "readCaptureInbox":
          result(self?.readInboxEntries() ?? [:])
        case "deleteCaptureInbox":
          self?.deleteInboxKeys(call.arguments as? [String] ?? [])
          result(nil)
        case "readLegacySharedRecords":
          // The pre-inbox record mirror, read once by Dart's reconciliation.
          // Read-only: nothing in Swift writes this key any more.
          let shared = UserDefaults(suiteName: self?.kAppGroupId ?? "")
          result(shared?.string(forKey: self?.kLegacySharedRecords ?? ""))
        case "clearLegacySharedRecords":
          // Retire the mirror so nothing can later read it as a source of truth.
          //
          // ⛔ SUPERSEDED 21 September 2026. The line below read:
          //     "Called only after Dart confirmed the merged write."
          // That was TRUE of one of its three callers and FALSE of the other
          // two. Dart calls this from `reconcileLegacySharedRecords` at three
          // places, and only one of them follows a write:
          //
          //   · the mirror key was ABSENT or empty  — no write, nothing to fold
          //   · the fold found NOTHING NEW          — no write, the two agreed
          //   · the merged list was PERSISTED       — the write this described
          //
          // ⭐ WHAT IS NOW TRUE OF ALL THREE: Dart calls this only when the READ
          // WAS COMPLETE — the payload decoded as a List, every element produced
          // a record, and nothing threw. Completeness of the read, not absence
          // of change and not a successful write, is what earns the delete.
          //
          // ⚠️ THE ASYMMETRY THAT MAKES THIS LOAD-BEARING: `removeObject` below
          // is irreversible and each device runs this path exactly once, on its
          // first launch after upgrading from 1.0.2. The Dart-side flag can be
          // re-set; the App Group value cannot be recovered once removed.
          if let group = self?.kAppGroupId,
             let key = self?.kLegacySharedRecords,
             let shared = UserDefaults(suiteName: group) {
            shared.removeObject(forKey: key)
            shared.synchronize()
          }
          result(nil)
        default:
          result(FlutterMethodNotImplemented)
        }
      }
      navChannel = channel
    }

    // ⚠️ THE DELEGATE IS STOLEN AFTER THIS FUNCTION RETURNS. Backlog 26.
    //
    // The assignment at line 132 above is not enough, and the reason is not
    // ordering inside this function — it is that the theft happens out of band,
    // in the window between this function returning and the notification action
    // being delivered.
    //
    // GeneratedPluginRegistrant.register (first line of this function) reaches
    // SwiftAwesomeNotificationsPlugin.AttachAwesomeNotificationsPlugin, which
    // constructs AwesomeNotifications(). Its init calls activateiOSNotifications(),
    // which registers an observer for UIApplication.didFinishLaunchingNotification
    // whose handler — AwesomeNotifications.didFinishLaunch — does
    // `UNUserNotificationCenter.current().delegate = self`.
    //
    // UIKit posts that notification AFTER application(_:didFinishLaunchingWithOptions:)
    // returns. So the sequence on a cold launch is:
    //
    //   1. our delegate = self                    (line 132)
    //   2. this function returns
    //   3. UIApplication.didFinishLaunchingNotification posted
    //   4. AwesomeNotifications takes the delegate      ← we are no longer it
    //   5. didReceive delivered → goes to AwesomeNotifications
    //
    // "iOS guarantees didFinishLaunching completes before didReceive" was read as
    // ruling this out. It does the opposite: step 3 lives inside exactly the
    // window that guarantee describes.
    //
    // And the action is not forwarded on. AwesomeNotifications' own didReceive
    // hands off to `_originalNotificationCenterDelegate`, which is DECLARED at
    // AwesomeNotifications.swift:504 and ASSIGNED NOWHERE — it is read in seven
    // places and is always nil. Every branch therefore ends at
    // `completionHandler()`. The action is swallowed silently: no crash, no log,
    // and our didReceive never entered. That is the measured signature.
    //
    // Why warm works: applicationDidBecomeActive reassigns the delegate, and it
    // is the ONLY place that ever restores it. A cold launch serving a
    // background action never becomes active, so nothing restores it.
    //
    // This block runs on the next main-queue turn — after the launch stack
    // unwinds, therefore after step 4 — and takes the delegate back before the
    // action is dispatched. The os_log records who held it, so a failed test can
    // be told apart from a lost race.
    DispatchQueue.main.async { [weak self] in
      guard let self = self else { return }
      let stolen = UNUserNotificationCenter.current().delegate !== self
      os_log("post-launch delegate stolen=%{public}@",
             log: Self.captureLog, type: .default, stolen ? "YES" : "no")
      UNUserNotificationCenter.current().delegate = self
    }

    return result
  }

  override func applicationDidBecomeActive(_ application: UIApplication) {
    super.applicationDidBecomeActive(application)
    UNUserNotificationCenter.current().delegate = self
    registerNativeNotificationCategories()
    clearStaleActiveStateIfEnded()
    UNUserNotificationCenter.current().requestAuthorization(
      options: [.alert, .sound, .badge]
    ) { [weak self] _, _ in
      DispatchQueue.main.async { self?.restorePersistentNotification() }
    }
  }

  // ── Shared storage sync ───────────────────────────────────────────────────
  // DELETED, not bypassed. This copied the whole record list from the App Group
  // over the store, keyed by the record-list key. It was safe
  // only because its guard happened to be true when the mirror was fresh, and
  // it was one guard change away from the ungated version below it.
  //
  // What it existed for — an event the widget extension ended while the app was
  // not running — is now an `end` instruction in the inbox, applied by the drain
  // with the record list read and written by Dart alone.
  //
  // The active-state half it also did is kept, because that is a single key
  // where last-write-wins is the correct semantics for "what is running now".
  //
  // ── WHY THIS DELETES WITHOUT PRESERVING, AND WHY THAT IS SAFE ─────────────
  // The rule is: no site deletes an active marker without first preserving what
  // it could not read. This site satisfies it by an INVARIANT rather than by a
  // call, and the body is deliberately unchanged.
  //
  // Both marker copies are written in ONE place, from ONE value, inside one
  // guarded block — see handleQuickLogStart. The extension writes neither. So
  // the standard copy this function deletes is always byte-identical to the App
  // Group copy, and its guard `standardActive != nil && sharedActive == nil` is
  // reached only after something else cleared the shared copy — which, on that
  // path, is EndMEREventIntent, and EndMEREventIntent preserves before it
  // clears. Either the shared copy still exists, or it was preserved. Nothing
  // unique is ever lost here.
  //
  // ⛔ AND THE INVARIANT IS PINNED, because a scan cannot see an invariant:
  // test/ios_active_marker_preserve_test.dart asserts exactly one write site per
  // key. If that pin ever goes red, THIS function becomes lossy — with nothing
  // else going red to say so.
  //
  // ⚠️ NOT widened to parse. Its guard is the SUCCESS signature for
  // extension-ended events, so an unconditional preserve here would flood the
  // quarantine with readable markers from normal operation and overwrite the
  // rare unreadable one under most-recent-wins. The note above at "Deliberately
  // here and not in clearStaleActiveStateIfEnded" already refused to widen this
  // function once, for the same reason: two unrelated jobs and a name that lies.
  private func clearStaleActiveStateIfEnded() {
    guard let shared = UserDefaults(suiteName: kAppGroupId) else { return }
    let standard = UserDefaults.standard

    let sharedActive   = shared.string(forKey: kSharedActiveKey)
    let standardActive = standard.string(forKey: kActiveEventKey)

    if standardActive != nil && sharedActive == nil {
      standard.removeObject(forKey: kActiveEventKey)
      standard.synchronize()
      endLiveActivity()
    }
  }

  /// ⭐ CHECKED 21 September 2026 and found SAFE AS WRITTEN, recorded rather than
  /// left silent. Its two removals sit inside a successful `if let` chain AND a
  /// timeout test, so it can only ever delete a marker it has just parsed. It
  /// never reaches an unreadable one, and therefore needs no preserve.
  private func restorePersistentNotification() {
    let defaults = UserDefaults.standard
    if let activeRaw = defaults.string(forKey: kActiveEventKey),
       let data = activeRaw.data(using: .utf8),
       let active = try? JSONSerialization.jsonObject(with: data) as? NSDictionary,
       let startIso = active["startIso"] as? String,
       let startDate = ISO8601DateFormatter().date(from: startIso) {
      if Date().timeIntervalSince(startDate) >= kActiveEventTimeoutSeconds {
        defaults.removeObject(forKey: kActiveEventKey)
        defaults.synchronize()
        if let shared = UserDefaults(suiteName: kAppGroupId) {
          shared.removeObject(forKey: kSharedActiveKey)
          shared.synchronize()
        }
        endLiveActivity()
        showPersistentNormalNotification()
      } else {
        if #available(iOS 17.0, *) {
          // iOS 17+: the Live Activity is AN end-event UI — restore it if gone.
          if Activity<MERActivityAttributes>.activities.isEmpty,
             let eventId = active["id"] as? String {
            startLiveActivity(eventId: eventId, startIso: startIso)
          }
        }

        // …but not the ONLY one, and that was the defect.
        //
        // This call used to sit in an `else`, so on iOS 17+ NOTHING was posted
        // while an event was running. The design assumed the Live Activity was
        // the end surface there and that recovery would bring it back. But the
        // Live Activity is user-dismissible and MER_ACTIVE was the only other
        // notification carrying an End action. Dismiss the Live Activity and
        // every route was gone: the event could not be ended at all, and the
        // 30-minute timeout then wrote a record with a NULL duration. Wrong
        // data rather than missing data, on the primary platform, shipped.
        //
        // ONE LINK OF THAT CHAIN IS NOW GONE. It used to read "…and
        // _endActiveEvent returns early on iOS so the home banner has no End
        // button". Backlog item 25 gave the banner a real End button on every
        // platform, routed through the endActiveEvent channel case, so the app
        // is no longer a dead end once foregrounded. This call still matters —
        // it is what puts an end action back on the LOCK SCREEN, which the
        // in-app button cannot reach.
        //
        // Posting unconditionally here gives a second surface that does not
        // share the first one's fate:
        //   * cannot double-post — the identifier is fixed
        //     (kActivePersistentId) and scheduleActiveNotification removes the
        //     delivered copy before adding, so a re-post replaces;
        //   * cannot fire spuriously — this branch is inside `if let activeRaw`
        //     and past the timeout check, so an event is genuinely active and
        //     younger than kActiveEventTimeoutSeconds;
        //   * is off the capture path — restorePersistentNotification is called
        //     from applicationDidBecomeActive and the restoreNotification
        //     channel case, never from handleQuickLogStart or handleQuickLogEnd.
        //
        // ⚠️ WHAT THIS DOES NOT FIX. The End action here is delivered through
        // didReceive, and didReceive is NOT entered when the app is cold —
        // established by breadcrumb on 26.6 and by the same signature on
        // 16.7.15. So this makes a dismissed notification recoverable WHILE THE
        // APP IS WARM. That is the difference between "no route" and "a route
        // that works when the app is running". Worth having; not the whole
        // answer.
        showPersistentActiveNotification(startIso: startIso)
      }
    } else {
      // No active event in either store, so any Live Activity still on screen is
      // stranded. A safety net, NOT the fix — the fix is the deadline in
      // endLiveActivity(completion:). This catches the case where that deadline
      // expired, or where the process died before the dismissal landed, and it
      // costs one no-op ActivityKit query on a launch with nothing running.
      //
      // Deliberately here and not in clearStaleActiveStateIfEnded: that function
      // reconciles the app's stale copy against the App Group, and its guard
      // `standardActive != nil && sharedActive == nil` describes the 17+ shape
      // where the extension ended the event. It cannot see the sub-17 shape,
      // where the app ended it and cleared both keys. Widening it would give one
      // function two unrelated jobs and a name that lies; this branch already
      // computes exactly the condition the reap needs.
      endLiveActivity()
      showPersistentNormalNotification()
    }
  }

  // ── Live Activity helpers ─────────────────────────────────────────────────

  private func startLiveActivity(eventId: String, startIso: String) {
    let attributes = MERActivityAttributes()
    let state      = MERActivityAttributes.ContentState(eventId: eventId, startIso: startIso)
    // staleDate, not nil, and set to the STALENESS window rather than the
    // abandonment timeout — see kActivityStaleAfterSeconds.
    //
    // Setting this is necessary but not sufficient: an earlier pass set it and
    // counted the item done, and the device still showed "Event in progress"
    // with a live timer at 33 minutes, because MERLiveActivity never read
    // context.isStale. staleDate that nothing renders is working and
    // unobservable. The rendering is in MERLiveActivity.swift.
    //
    // This is the only mechanism that works with the app killed: nothing in MER
    // can update or end an activity from a dead process, so the display has to
    // correct itself. It still does NOT clear the state, which waits for a
    // foreground — see restorePersistentNotification.
    let staleAt = ISO8601DateFormatter().date(from: startIso)?
      .addingTimeInterval(kActivityStaleAfterSeconds)
    let content    = ActivityContent(state: state, staleDate: staleAt)
    _ = try? Activity<MERActivityAttributes>.request(attributes: attributes, content: content)
  }

  /// Ends every running Live Activity, optionally holding a caller's execution
  /// window open until it has actually happened.
  ///
  /// ## Why this takes a completion handler
  ///
  /// **On iOS 17+ an event ends in a process whose lifetime the system
  /// guarantees** — `EndMEREventIntent.perform()` is async and awaits the
  /// dismissal inline, so it always lands. **On 16.2-16.x the event ends inside
  /// a notification-action callback whose window the app closes itself** by
  /// calling the completion handler, after which iOS is free to suspend.
  ///
  /// This function used to be fire-and-forget for every caller. On the sub-17
  /// path that lost the race every time: the Live Activity kept counting until
  /// `staleDate` flipped it to the stale rendering ten minutes later. Reported
  /// from a real iPhone 8 on 16.7.15 — the first hardware test of that tier.
  ///
  /// So callers that own a closing window pass `completion` and get it back only
  /// once the dismissal has resolved, or the deadline has passed. Callers on an
  /// ordinary foreground pass nothing and keep the fire-and-forget behaviour,
  /// which is correct there precisely because nothing is about to suspend them.
  private func endLiveActivity(completion: (() -> Void)? = nil) {
    guard let completion = completion else {
      Task {
        for activity in Activity<MERActivityAttributes>.activities {
          await activity.end(nil, dismissalPolicy: .immediate)
        }
      }
      return
    }

    // `handedBack` is only ever touched on the main queue, by both the deadline
    // and the dismissal, so the two cannot both hand the window back.
    var handedBack = false
    let handBack = {
      if handedBack { return }
      handedBack = true
      completion()
    }

    // The completion handler MUST be called. If ActivityKit is slow or wedged,
    // iOS terminating the app is a worse outcome than a Live Activity that
    // outlives its event — and staleDate still corrects that display.
    DispatchQueue.main.asyncAfter(deadline: .now() + kLiveActivityDismissDeadline) {
      handBack()
    }

    Task {
      for activity in Activity<MERActivityAttributes>.activities {
        await activity.end(nil, dismissalPolicy: .immediate)
      }
      DispatchQueue.main.async { handBack() }
    }
  }

  // ── Native category registration ──────────────────────────────────────────
  private func registerNativeNotificationCategories() {
    let startAction = UNNotificationAction(
      identifier: kBtnStart,
      title: "Log Event Now",
      options: []
    )
    // ⚠️ ASYMMETRY IS DELIBERATE: End requires authentication, Start does not.
    //
    // This looks like an oversight. It is not. The two actions carry different
    // options because the risk is not symmetric and because CONTINUITY ACROSS
    // TIERS points different ways for each.
    //
    // **End — .authenticationRequired.** On iOS 17+ ActivityKit already refuses
    // to run EndMEREventIntent on a locked device and demands Face ID, ignoring
    // the .alwaysAllowed policy the intent requests. Declaring the same
    // requirement here makes 16.2-16.x behave the SAME way instead of diverging.
    //
    // Before this, ending from a locked device did nothing at all, silently:
    // the notification was dismissed by the UI, the handler never ran, no end
    // instruction was written, neither notification posted, the Live Activity
    // kept counting, and the record kept its lt1 default. Wrong data, on the
    // only end path this tier has. `options: []` means "deliver in the
    // background, no authentication needed", and with no
    // .authenticationRequired there is no prompt-and-defer path — so iOS had
    // nowhere to park the action and dropped it.
    //
    // The verified 17+ behaviour is the model: **iOS declines to start work it
    // cannot finish, rather than starting it in a state where it silently
    // cannot.** That is obtained by declaration, not by luck.
    //
    // **Start stays background, unchanged.** Recording without opening the app
    // is what makes MER usable mid-episode, and on 17+ a lock-screen start
    // already records without unlocking. Adding .foreground or
    // .authenticationRequired here would make the tiers DIVERGE rather than
    // converge, and it would gate the capture path — which nothing is allowed
    // to do.
    //
    // The asymmetry matches where the harm sits: **a spurious start is a stray
    // record the user can delete; a missed end is a duration that no longer
    // exists.**
    let endAction = UNNotificationAction(
      identifier: kBtnEnd,
      title: "Event Ended",
      options: [.authenticationRequired]
    )
    let normalCategory = UNNotificationCategory(
      identifier: kCategoryNormal,
      actions: [startAction],
      intentIdentifiers: [],
      options: []
    )
    let activeCategory = UNNotificationCategory(
      identifier: kCategoryActive,
      actions: [endAction],
      intentIdentifiers: [],
      options: []
    )
    UNUserNotificationCenter.current().setNotificationCategories(
      [normalCategory, activeCategory]
    )
  }

  // ── UNUserNotificationCenterDelegate ─────────────────────────────────────

  override func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    willPresent notification: UNNotification,
    withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
  ) {
    completionHandler([.alert, .sound])
  }

  /// One line, on entry to the notification-action handler. Deliberately kept
  /// after the diagnostic breadcrumbs were removed.
  ///
  /// The native capture path has NO telemetry otherwise: nothing in Swift
  /// reports to Sentry, and on a background delivery the Dart isolate that owns
  /// Sentry may not be running. When the locked-device end failure was
  /// investigated, six hypotheses were argued from source and five were wrong,
  /// because nothing could answer the first question — is this method even
  /// entered? One instrumented run answered it.
  ///
  /// This is what remains of that instrumentation, and it is the cheap half.
  /// `os_log` writes to an in-memory ring buffer: no file, no cfprefsd, no
  /// plugin, nothing that can fail or block, and nothing on the capture path to
  /// slow down. The UserDefaults breadcrumbs are gone because they wrote to a
  /// store on the path they were measuring.
  ///
  /// To read it: attach the device, Console.app, filter subsystem
  /// `au.com.notiva.mer`. Note that `log show` on the Mac CANNOT see device
  /// logs — there is no --device option — so this needs either a live Console
  /// session or a sysdiagnose from the handset.
  private static let captureLog = OSLog(subsystem: "au.com.notiva.mer",
                                        category: "capture")

  override func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    didReceive response: UNNotificationResponse,
    withCompletionHandler completionHandler: @escaping () -> Void
  ) {
    let notifId = response.notification.request.identifier

    // Entry marker. See captureLog: this is the one thing that answers "was the
    // handler reached", which took an instrumented run to establish once and
    // should not need another.
    os_log("didReceive action=%{public}@ notif=%{public}@",
           log: Self.captureLog, type: .default, response.actionIdentifier, notifId)

    switch response.actionIdentifier {
    case kBtnStart:
      handleQuickLogStart(completion: completionHandler)
    case kBtnEnd:
      handleQuickLogEnd(completion: completionHandler)
    case UNNotificationDefaultActionIdentifier
         where notifId == kFeedbackId || notifId == "mer_feedback_intent":
      // The wholesale copy that used to be here is DELETED, not bypassed. It
      // read the App Group mirror and overwrote the whole record list with it,
      // ungated — no merge, no staleness check. Dart never wrote that mirror, so
      // it was stale by design: end an event natively, ignore this notification,
      // log five events in-app, tap it days later, and the five were destroyed.
      // Restore two hundred from a backup first and it was two hundred.
      //
      // Nothing replaces it. The duration the extension recorded arrives as an
      // `end` instruction in the inbox and is applied by the drain, which is the
      // only thing that writes the record list.
      //
      // ── OWNERSHIP, NOT MERELY STALENESS ──
      //
      // ⛔ THIS CLEAR WAS UNCONDITIONAL UNTIL 21 SEPTEMBER 2026 AND THAT WAS A
      // DATA-LOSS PATH. The comment it replaces said what is deleted here is "a
      // duplicate of a value already adjudicated". That is true of the event
      // this notification describes. It is NOT true of a different event
      // started since, and nothing here compared the two.
      //
      // The sequence, every step reachable:
      //   1. end event A — showFeedbackNotification posts under kFeedbackId,
      //      and NOTHING ever removes it (see the note on that function)
      //   2. start event B — the marker is written to BOTH suites
      //   3. tap A's still-present notification, which invites exactly that
      //      with "Open MER to add details"
      //   4. this line deleted B's app-suite copy, leaving the App Group copy
      //
      // Nothing recovered it. clearStaleActiveStateIfEnded wants
      // `standardActive != nil && sharedActive == nil` and this is the mirror
      // image, so it does not fire. restorePersistentNotification reads nil,
      // takes its else branch, and ends B's Live Activity and replaces its
      // notification WHILE B IS STILL RUNNING. endActiveEventFromApp reads nil
      // and writes no end instruction. The 30-minute timeout lives in that same
      // else-less branch and needs the same key, so not even the wrong-duration
      // fallback fired. B lost its duration outright.
      //
      // ⭐ THE RULE: AN OPERATION THAT CLEARS STATE ON BEHALF OF AN EVENT MUST
      // ESTABLISH THAT THE STATE BELONGS TO THAT EVENT.
      //
      // ⚠️ IT CANNOT BE ESTABLISHED BY IDENTITY HERE. The notification carries
      // no event id — `userInfo` is set nowhere in ios/ — so there is nothing to
      // compare A's identity against. Giving it one is a payload change and a
      // separate piece of work; it would also fix the navigation target below,
      // which opens the LATEST event rather than this notification's event.
      //
      // ⭐ SO OWNERSHIP IS ESTABLISHED STRUCTURALLY INSTEAD, and it needs no
      // payload. The App Group copy is written in exactly one place (:828, with
      // the app-suite copy, from one value) and cleared in exactly four —
      // EndMEREventIntent, restorePersistentNotification's timeout branch,
      // handleQuickLogEnd and endActiveEventFromApp. Every one of those four
      // ends or abandons the event. Therefore:
      //
      //     the App Group copy is PRESENT  ⟹  an event is LIVE
      //     the App Group copy is ABSENT   ⟹  the app-suite copy is residue
      //
      // and residue is the only thing this site was ever meant to clear.
      //
      // ⛔ THE SUCCESSFUL PATH IS UNCHANGED, which is the point. On 17+ the
      // extension cleared the shared copy before posting the feedback, so the
      // guard is true and the delete happens exactly as before. On 16.2-16.x
      // handleQuickLogEnd cleared both, so the guard is true and the delete is
      // the no-op it already was. Only the stale-tap case behaves differently.
      //
      // ⚠️ NO SUITE, NO DELETE. If the App Group cannot be opened, ownership
      // cannot be established, and the fail-safe direction is to leave the
      // marker alone — the same discipline as clearStaleActiveStateIfEnded,
      // which returns rather than guessing. A marker left behind is corrected on
      // the next foreground; a marker deleted is not.
      //
      // Pinned by test/ios_feedback_tap_ownership_test.dart, which fails on the
      // unguarded form.
      let standard = UserDefaults.standard
      if let group = UserDefaults(suiteName: kAppGroupId),
         group.string(forKey: kSharedActiveKey) == nil {
        standard.removeObject(forKey: kActiveEventKey)
        standard.synchronize()
      }
      // BOTH, deliberately. The flag is durable; the channel call is immediate.
      // Whichever arrives first wins, and consumption is idempotent on the Dart
      // side, so both arriving does not open the edit screen twice.
      //
      // This used to be an either/or on channel availability — and **the branch
      // that worked was the one that assumed failure.** On 17+ the event ends in
      // the widget extension, so the app usually is not running, navChannel is
      // nil, the flag is written, and initState's post-frame read consumes it.
      // On 16.2-16.x the app serviced the END action itself, so it is alive,
      // navChannel is non-nil, and only the transient call was made — sent to an
      // engine still paused, because didReceive runs BEFORE
      // applicationDidBecomeActive. Nothing durable was left behind, and iOS had
      // no resume-time consumer, so the tap landed on the dashboard instead of
      // the event's edit screen.
      //
      // Same asymmetry as endLiveActivity(completion:): on 17+ the work happens
      // somewhere the system keeps alive, and on 16.2-16.x it happens in a window
      // the app is about to close.
      //
      // ⭐ AND THE ID NOW TRAVELS, 23 September 2026. The notification names its
      // event in `userInfo`; both signals carry it, because either one can be
      // the one that lands. A carrier on only one path is a carrier that works
      // intermittently, which is worse than none — it makes the failure look
      // like a fluke rather than a design.
      //
      // ⛔ THE `else` IS LOAD-BEARING. A tap with no id MUST clear the key.
      // Without that, an id left by an earlier tap is read as this tap's id and
      // the no-id case opens a RECORD — the exact defect this work removes,
      // restored by omission. That is a one-line hole and it would be invisible.
      //
      // ⚠️ A tap can legitimately carry no id: a notification posted by the
      // CURRENT shipping build has no `userInfo` at all, and one posted by this
      // build after an UNREADABLE active marker has no id to attach. Both must
      // reach History, never a record. `kPendingOpenLatest` is untouched by all
      // of this — same name, same meaning, same BOOL.
      let taggedId = response.notification.request.content
        .userInfo[kNotificationEventIdKey] as? String
      standard.set(true, forKey: kPendingOpenLatest)
      if let taggedId, !taggedId.isEmpty {
        standard.set(taggedId, forKey: kPendingOpenEventId)
      } else {
        standard.removeObject(forKey: kPendingOpenEventId)
      }
      standard.synchronize()
      // ⚠️ "openLatestEvent" IS A WIRE NAME THAT NO LONGER DESCRIBES THE
      // BEHAVIOUR, 23 September 2026. This call no longer means "open the latest
      // event"; it means "a notification was tapped, and here is the event it
      // named, or nil". The string is KEPT because it is referenced outside the
      // two ends that implement it — test/ios_feedback_tap_ownership_test.dart
      // pins it as part of the untouched-navigation control — so renaming it is
      // not the single-commit, two-site change it looks like. The matching
      // comment is at the Dart end, in _handleNativeCall.
      navChannel?.invokeMethod("openLatestEvent", arguments: taggedId)
      completionHandler()
    default:
      completionHandler()
    }
  }

  // ── Capture inbox ─────────────────────────────────────────────────────────
  //
  // One key per instruction. NEVER an array append: appending to a JSON array is
  // itself a read-modify-write, which is the whole thing being removed.
  //
  // Kept deliberately small and duplicated in EndMEREventIntent.swift rather
  // than shared, because Runner and MERWidget are separate targets and sharing
  // a new file means editing project.pbxproj. The project already duplicates
  // MERActivityAttributes.swift across the same boundary for the same reason.
  // Any change here must be mirrored there — a schema test on the Dart side
  // pins the shape both must produce.
  //
  // Schema, matching lib/models/capture_instruction.dart:
  //   start : { "v": 1, "kind": "start", "id": <string>, "at": <ISO8601> }
  //   end   : { "v": 1, "kind": "end",   "id": <string>, "at": <ISO8601>,
  //             "seconds": <int >= 0> }
  //
  // `v` must decode as an int: NSNumber(value: 1) does, a Double would defer.
  // `id` is written exactly as generated — UUID().uuidString is UPPERCASE and
  // must stay that way, because merge-by-id is exact string equality and records
  // already in the wild carry both cases.

  /// Writes one instruction with a direct `UserDefaults` call — no plugin, no
  /// channel, no Flutter engine.
  ///
  /// ## ⚠️ DO NOT MOVE THIS TO A DIFFERENT CONTAINER
  ///
  /// When the sub-17 notification end path was found to fail silently on a
  /// locked device, the obvious remedy was proposed and investigated: move the
  /// inbox and the active-event key into the App Group, on the belief that the
  /// shared container carries a more available data-protection class.
  ///
  /// **It cannot work, for two independent reasons.**
  ///
  /// 1. **The inbox is already here.** This function has always written the App
  ///    Group suite, and `handleQuickLogStart` has always written the
  ///    active-event key to BOTH suites. The write that failed on a locked
  ///    device was already an App Group write. If the container were the reason,
  ///    it would already have worked.
  /// 2. **The two containers carry the same protection class.** Neither
  ///    `Runner.entitlements` nor `MERWidget.entitlements` requests
  ///    `com.apple.developer.default-data-protection`, and no `NSFileProtection`
  ///    key appears anywhere in `ios/`. Both containers therefore take the
  ///    system default. An App Group container is not more available by virtue
  ///    of being shared, and the handset had been unlocked since boot, so both
  ///    were readable regardless.
  ///
  /// Encryption was never the blocker. What blocks is the cost of getting ready
  /// to write — engine boot, plugin registration, plist decode — inside the
  /// short window iOS grants a notification action on a cold background launch.
  ///
  /// `synchronize()` is gone deliberately. It has been deprecated since iOS 12,
  /// the OS flushes without it, and it is the one call on this path that can sit
  /// waiting on `cfprefsd` while the window runs out. Losing a flush costs at
  /// worst a replay: the keys are idempotent and the drain deletes them only
  /// after a confirmed write.
  private func writeInboxInstruction(_ payload: [String: Any]) {
    guard let shared = UserDefaults(suiteName: kAppGroupId),
          let data = try? JSONSerialization.data(withJSONObject: payload),
          let json = String(data: data, encoding: .utf8) else { return }
    shared.set(json, forKey: "\(kInboxPrefix)\(UUID().uuidString)")
  }

  private func writeInboxStart(id: String, at iso: String) {
    writeInboxInstruction([
      "v": NSNumber(value: 1),
      "kind": "start",
      "id": id,
      "at": iso,
    ])
  }

  private func writeInboxEnd(id: String, at iso: String, seconds: Int) {
    writeInboxInstruction([
      "v": NSNumber(value: 1),
      "kind": "end",
      "id": id,
      "at": iso,
      "seconds": NSNumber(value: max(0, seconds)),
    ])
  }

  /// Every inbox entry, for the drain. Enumerated by prefix over
  /// `dictionaryRepresentation()` — there is deliberately no index key, because
  /// an index would be a read-modify-write again.
  private func readInboxEntries() -> [String: String] {
    guard let shared = UserDefaults(suiteName: kAppGroupId) else { return [:] }
    var out: [String: String] = [:]
    for (key, value) in shared.dictionaryRepresentation()
    where key.hasPrefix(kInboxPrefix) {
      if let json = value as? String { out[key] = json }
    }
    return out
  }

  /// Deletes exactly the keys Dart acked, and nothing else. Called only after
  /// Dart confirmed the write that consumed them.
  private func deleteInboxKeys(_ keys: [String]) {
    guard let shared = UserDefaults(suiteName: kAppGroupId) else { return }
    for key in keys where key.hasPrefix(kInboxPrefix) {
      shared.removeObject(forKey: key)
    }
    shared.synchronize()
  }

  /// Moves an unreadable active marker aside instead of deleting it.
  ///
  /// Called on the FAILURE branch only, immediately before a clear. The re-read
  /// is deliberate: `activeRaw` binds in the first clause of the `if let` chain
  /// and is out of scope by the time we reach the clear, and the key is
  /// untouched until then, so re-reading returns exactly what is about to be
  /// destroyed.
  ///
  /// A nil re-read means the chain failed at its FIRST clause — the key was
  /// absent or not a string — and there is nothing to preserve. It returns
  /// without writing, because an empty quarantine entry would manufacture
  /// evidence of a loss that did not happen.
  ///
  /// ⛔ BUDGET: one read, one set, one count set, one os_log. NO synchronize.
  /// Sites 1 and 3 are on the notification-action path, where `writeInboxInstruction`
  /// already records that `synchronize()` "can sit waiting on cfprefsd while the
  /// window runs out". Nothing here may block that window.
  private func preserveUnreadableMarker(from site: String, key: String) {
    let standard = UserDefaults.standard
    guard let raw = standard.string(forKey: key), !raw.isEmpty else { return }
    guard let shared = UserDefaults(suiteName: kAppGroupId) else { return }

    let count = shared.integer(forKey: kQuarantineCountKey) + 1
    shared.set(raw,   forKey: kQuarantineKey)
    shared.set(count, forKey: kQuarantineCountKey)

    os_log("preserved unreadable active marker site=%{public}@ count=%{public}d",
           log: Self.captureLog, type: .default, site, count)
  }

  // ── Action handlers ───────────────────────────────────────────────────────

  private func handleQuickLogStart(completion: @escaping () -> Void) {
    let standard = UserDefaults.standard
    let shared   = UserDefaults(suiteName: kAppGroupId)
    let now  = Date()
    let id   = UUID().uuidString
    let isoNow = ISO8601DateFormatter().string(from: now)

    // Post a START fact. No record is built and no list is read: the seven
    // defaults this used to invent — lt1, empty feelings, empty triggers, no
    // referral, empty notes, seizure, mild — are the drain's business now, so a
    // queued instruction materialises with whatever the defaults are when it is
    // applied rather than whatever they were when it was written.
    writeInboxStart(id: id, at: isoNow)

    // Mark active event in both suites
    let active: NSDictionary = ["id": id, "startIso": isoNow]
    if let encoded = try? JSONSerialization.data(withJSONObject: active),
       let str = String(data: encoded, encoding: .utf8) {
      standard.set(str, forKey: kActiveEventKey)
      shared?.set(str, forKey: kSharedActiveKey)
    }
    standard.synchronize()
    shared?.synchronize()

    // Live Activity, unconditional at the 16.2 deployment target.
    startLiveActivity(eventId: id, startIso: isoNow)

    // Posted on EVERY version now, including 17+, where this used to be skipped
    // with the comment "Live Activity button handles end — no active
    // notification needed".
    //
    // An event started from the Lock Screen had exactly ONE surface on 17+ — the
    // Live Activity — and it is user-dismissible. Dismiss it without opening the
    // app and there was no way to end the event at all: the 30-minute timeout
    // closed it with a NULL duration. 0753410 made the notification come back on
    // foreground, which only helps once you foreground. This gives a second
    // surface from the moment of capture.
    //
    // ── The history, because this looks like a reversal and is not quite one ──
    //
    // 368bb34 (26 Apr 2026) suppressed the iOS START FEEDBACK notification
    // because it "was stacking on top and obscuring the action button" of the
    // "Event in progress" notification. That was TWO NOTIFICATIONS stacking, in
    // the awesome_notifications era — it touched only Dart and predates CR-42
    // moving iOS to native Swift.
    //
    // This is not that condition. scheduleActiveNotification removes BOTH
    // delivered identifiers before adding, so exactly one MER notification is
    // ever up. What 17+ now gets is a Live Activity PLUS one notification, which
    // is what 16.2-16.x has shipped since CR-42 with no stacking complaint on
    // record.
    //
    // It is still a trade, not a correction. The judgement that the Live
    // Activity was sufficient has been weakened three times since: it is
    // dismissible, it cannot be restored while the app is cold, and its End
    // button demands Face ID on iOS 26. Two imperfect surfaces beat one that can
    // vanish.
    //
    // ⚠️ On 17+ this notification's End action is the LESS reliable of the two.
    // It routes through didReceive, which is NOT entered when the app is cold —
    // measured on 26.6 and on 16.7.15. The Live Activity's button runs in the
    // widget extension and works cold, after authentication. So this surface is
    // reliable for VISIBILITY and unreliable for ENDING until cold delivery is
    // fixed.
    let fmt = DateFormatter()
    fmt.dateFormat = "h:mm a"
    scheduleActiveNotification(startTimeStr: fmt.string(from: now), completion: completion)
  }

  /// Ends an event from the notification action, on 16.2-16.x.
  ///
  /// ## Order is the fix, and it is deliberate: WRITE, then NOTIFY, then the rest
  ///
  /// iOS grants a notification action a short window on a cold background launch
  /// and the app closes that window itself. Before this ordering, the two things
  /// a user depends on — the record and the feedback — came LAST, after the
  /// active-key clears and the ActivityKit dismissal. On a locked device the
  /// process died partway and the user got nothing at all: no "Event ended", no
  /// standing notification, no duration, and a Live Activity still counting. The
  /// record kept its `lt1` default, which is wrong data rather than missing data.
  ///
  /// So: the instruction is written first, then both notifications are posted,
  /// and only then does anything that can hang get a turn. If the process is
  /// killed after the notify step, the user has been told and the duration has
  /// landed. Nothing below the notify step is load-bearing for correctness —
  /// each of it is re-done on the next foreground.
  private func handleQuickLogEnd(completion: @escaping () -> Void) {
    let standard = UserDefaults.standard
    var elapsedStr = ""
    // Set ONLY inside the if let body below, so it distinguishes "the chain
    // succeeded" from "the marker was there and would not parse". The clear at
    // the end of this function is unconditional and must stay that way — the
    // banner clears in every case — so this is what decides whether the marker
    // is moved aside first.
    var endedCleanly = false
    // Hoisted for one reason only: the feedback notification is posted BELOW the
    // `if let`, where `eventId` is out of scope. Nil carries the same meaning as
    // endedCleanly == false — the marker did not read — and the notification is
    // posted either way.
    var endedEventId: String?

    if let activeRaw = standard.string(forKey: kActiveEventKey),
       let data = activeRaw.data(using: .utf8),
       let active = try? JSONSerialization.jsonObject(with: data) as? NSDictionary,
       let eventId = active["id"] as? String,
       let startIso = active["startIso"] as? String,
       let startTime = ISO8601DateFormatter().date(from: startIso) {

      let endTime = Date()
      let secs = max(0, Int(endTime.timeIntervalSince(startTime)))
      let m = secs / 60, s = secs % 60
      elapsedStr = m == 0 ? "\(s)s" : (s == 0 ? "\(m)m" : "\(m)m \(s)s")

      // Post an END fact carrying SECONDS, not a bucket. The
      // lt1/oneToFive/gt5 mapping used to be computed here, and identically in
      // two other places; it is now bucketFromSeconds in capture_inbox.dart,
      // once. max(0, …) above means the value can never be the negative that
      // the schema defers on.
      //
      // Note what is NOT read: the record list. Everything needed is in the
      // active-event key, which is why the whole read-modify-write is gone
      // rather than relocated.
      writeInboxEnd(id: eventId, at: ISO8601DateFormatter().string(from: endTime),
                    seconds: secs)
      endedCleanly = true
      endedEventId = eventId
    }

    // ── 2. NOTIFY ──
    // Both requests are handed to usernotificationsd here, before anything that
    // can wait on cfprefsd or ActivityKit. Copy, timing, identifiers and
    // categories are unchanged; only their position moved. Once `add` lands, the
    // daemon owns the schedule and fires it even if this process dies.
    showFeedbackNotification(elapsed: elapsedStr, eventId: endedEventId)
    showPersistentNormalNotification()

    // ── 3. EVERYTHING ELSE ──
    // The App Group suite is opened HERE and not at the top of the function:
    // nothing above this line needs it, and opening it is one of the calls that
    // can wait. Clearing the active keys is idempotent — if this does not flush
    // before the process dies, the next foreground clears it again via
    // restorePersistentNotification, at the cost of one stale "Event in
    // progress" notification. That is a visible, self-correcting cost, which is
    // the trade this whole ordering makes: never lose the record or the
    // feedback, and let the tidying be retried.
    //
    // MOVED ASIDE, NOT DELETED. If the chain above did not complete, the marker
    // is preserved before this clear. The banner still clears exactly as before
    // — that half of the original trade was legitimate and is not reversed.
    if !endedCleanly {
      preserveUnreadableMarker(from: "handleQuickLogEnd", key: kActiveEventKey)
    }
    standard.removeObject(forKey: kActiveEventKey)
    UserDefaults(suiteName: kAppGroupId)?.removeObject(forKey: kSharedActiveKey)

    // Hands the action's window back to iOS only once the Live Activity is
    // actually gone, or the deadline passes — see endLiveActivity(completion:).
    // Last, because it is the only step whose failure the user can already see.
    endLiveActivity(completion: completion)
  }

  /// Ends the active event from the in-app banner. Backlog item 25.
  ///
  /// ── Why this exists at all ──
  ///
  /// Every iOS end surface requires an unlock: the notification's End action
  /// carries `.authenticationRequired` by our own choice, and the Live Activity's
  /// intent demands Face ID on iOS 26 by the system's. Once that is true, "in-app
  /// needs the app open" is a tap count rather than a category difference, and
  /// the in-app route is the only one that depends on nothing fragile — not
  /// `didReceive` reaching us cold, not ActivityKit, not a notification surviving
  /// dismissal, not an OS version gate.
  ///
  /// The state it is built for: **16.2-16.x, notification dismissed, app cold.**
  /// `LiveActivityIntent` needs 17, so the card there is display-only; the
  /// notification is the only End action and `didReceive` is not entered cold.
  /// That user opened the app, saw a banner saying an event was running, and was
  /// offered nothing — the event then ran to `kActiveEventTimeoutSeconds` and
  /// wrote a record with a wrong duration. Wrong data on a medical record.
  ///
  /// ── No fourth writer ──
  ///
  /// The end instruction has three implementations already, all deliberate:
  /// Dart's `writeEndInstruction` (Android), `writeInboxEnd` here, and an inline
  /// copy in `EndMEREventIntent` (a separate target, so it cannot share code —
  /// see the comment there). Dart does NOT build a payload for this path and
  /// does NOT apply the end itself. It invokes the channel, Swift writes through
  /// the SAME `writeInboxEnd` the notification action uses, and Dart drains it
  /// through the `readCaptureInbox`/`deleteCaptureInbox` transport that already
  /// exists. No schema change, no transport change, no new writer.
  ///
  /// ── ⚠️ THE ORDER IS DELIBERATELY THE REVERSE OF handleQuickLogEnd'S ──
  ///
  /// That function clears the active keys FIRST and dismisses the Live Activity
  /// LAST, because its process is about to be suspended: get the fact and the
  /// feedback to their daemons before the window shuts, and let the next
  /// foreground retry the tidying.
  ///
  /// It leaves a hazard this path must not copy. If the process dies between the
  /// key-clear and the dismissal, NOTHING ever ends that Live Activity:
  /// `clearStaleActiveStateIfEnded` requires `standardActive != nil &&
  /// sharedActive == nil`, and `restorePersistentNotification` only enters its
  /// body inside `if let activeRaw`. With both keys nil neither branch is
  /// reachable, and `staleDate` corrects the DISPLAY only. The card sits there
  /// marked stale until the user swipes it.
  ///
  /// Here the app is foreground and alive, so there is no window to race and no
  /// reason to take that risk. Dismiss first, THEN clear.
  ///
  /// ── No feedback notification ──
  ///
  /// `showFeedbackNotification` is deliberately not called. The user is looking
  /// at the screen; posting "Event ended · 5m — Open MER to add details" to
  /// someone already in MER is exactly what 368bb34 removed. The banner
  /// disappearing and the record appearing is the confirmation.
  private func endActiveEventFromApp(completion: @escaping () -> Void) {
    let standard = UserDefaults.standard
    // Same discriminator as handleQuickLogEnd. Captured by the escaping closure
    // below, which is where the clear happens.
    var endedCleanly = false

    // 1. THE FACT, first, as on every other capture path.
    if let activeRaw = standard.string(forKey: kActiveEventKey),
       let data = activeRaw.data(using: .utf8),
       let active = try? JSONSerialization.jsonObject(with: data) as? NSDictionary,
       let eventId = active["id"] as? String,
       let startIso = active["startIso"] as? String,
       let startTime = ISO8601DateFormatter().date(from: startIso) {

      let endTime = Date()
      let secs = max(0, Int(endTime.timeIntervalSince(startTime)))
      writeInboxEnd(id: eventId, at: ISO8601DateFormatter().string(from: endTime),
                    seconds: secs)
      endedCleanly = true
    }
    // An unreadable or absent marker still tears down below. The banner is
    // showing, so something is up on screen; leaving it there because the JSON
    // did not parse would be the worse failure.
    //
    // ⭐ That reasoning still stands and the teardown is unchanged. What it did
    // NOT address is that the marker was the only evidence the event was
    // running, so the teardown now moves it aside first — see the clear below.

    // 2. DISMISS, and wait for it. See the order note above.
    endLiveActivity { [weak self] in
      guard let self = self else { completion(); return }

      // 3. CLEAR BOTH. More than EndMEREventIntent does — it can only reach the
      //    App Group copy, which is why clearStaleActiveStateIfEnded exists.
      //
      //    MOVED ASIDE, NOT DELETED. The re-read inside preserveUnreadableMarker
      //    happens HERE, at deletion time rather than at decision time, because
      //    this clear runs inside the endLiveActivity completion. That is
      //    DELIBERATE: for a move-aside the value that matters is the one about
      //    to be destroyed, not the one read a moment earlier.
      if !endedCleanly {
        self.preserveUnreadableMarker(from: "endActiveEventFromApp",
                                      key: self.kActiveEventKey)
      }
      standard.removeObject(forKey: self.kActiveEventKey)
      UserDefaults(suiteName: self.kAppGroupId)?.removeObject(forKey: self.kSharedActiveKey)

      // 4. Back to the idle surface. This also removes both delivered
      //    identifiers, so the "Event in progress" notification cannot outlive
      //    the event it describes.
      self.showPersistentNormalNotification()

      completion()
    }
  }

  // ── Notification builders ─────────────────────────────────────────────────

  func showPersistentNormalNotification(completion: (() -> Void)? = nil) {
    UNUserNotificationCenter.current().removeDeliveredNotifications(
      withIdentifiers: [kPersistentId, kActivePersistentId]
    )
    let content = UNMutableNotificationContent()
    content.title = "Medical Event Recorder"
    content.body = "Long-press this notification to log an event"
    content.sound = .none
    content.categoryIdentifier = kCategoryNormal
    let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
    let request = UNNotificationRequest(
      identifier: kPersistentId, content: content, trigger: trigger
    )
    // ⭐ A NO-OP WHEN THIS WAS WRITTEN, 23 September 2026, AND FIXED ANYWAY.
    // ⛔ This is NOT a live defect that shipped. Every one of the four callers
    // of this function passes no `completion`, so `completion?()` did nothing
    // and could not reach a notification-response handler off the main thread.
    //
    // ⚠️ AND IT IS NOT DEAD CODE EITHER — do not remove it. The parameter is
    // public API of this function; the moment a caller passes a completion it
    // inherits `66717c9`'s crash exactly, because
    // `add(_:withCompletionHandler:)` calls back on an arbitrary queue.
    //
    // ⭐ THE FILE NOW HAS ONE RULE RATHER THAN THREE CASES. `endLiveActivity`
    // was always right, `scheduleActiveNotification` was corrected by
    // `66717c9`, and this was the last one left — and one of three being
    // different is how the next reader learns the wrong pattern.
    UNUserNotificationCenter.current().add(request) { _ in
      DispatchQueue.main.async { completion?() }
    }
  }

  func showPersistentActiveNotification(startIso: String) {
    let timeStr: String
    if let date = ISO8601DateFormatter().date(from: startIso) {
      let fmt = DateFormatter()
      fmt.dateFormat = "h:mm a"
      timeStr = fmt.string(from: date)
    } else {
      timeStr = startIso
    }
    scheduleActiveNotification(startTimeStr: timeStr, completion: nil)
  }

  private func scheduleActiveNotification(startTimeStr: String, completion: (() -> Void)?) {
    UNUserNotificationCenter.current().removeDeliveredNotifications(
      withIdentifiers: [kPersistentId, kActivePersistentId]
    )
    let content = UNMutableNotificationContent()
    content.title = "Event in progress · \(startTimeStr)"
    content.body = "Tap \"Event Ended\" when the event is over"
    content.sound = .none
    content.categoryIdentifier = kCategoryActive
    let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
    let request = UNNotificationRequest(
      identifier: kActivePersistentId, content: content, trigger: trigger
    )
    // ⛔ MAIN QUEUE, AND IT IS THE COMPLETION HANDLER THAT REQUIRES IT, NOT
    // THIS CLOSURE'S BODY.
    //
    // `completion` here IS the `didReceive` completion handler: the chain is
    // didReceive -> handleQuickLogStart(completion:) -> here. UNUserNotification
    // Center's `add(_:withCompletionHandler:)` calls back on an ARBITRARY
    // internal queue, so invoking it directly delivered a notification-response
    // completion off the main thread.
    //
    // ⚠️ THAT IS SENTRY MEDICAL-EVENT-RECORDER-7: NSInternalInconsistency
    // Exception "Call must be made on main thread", EXC_CRASH / SIGABRT, 12
    // events across 2 install ids on build 38. Unchanged since `17a0a4b`
    // (4 May 2026) — the silence since is the path being rare, not fixed.
    //
    // ⭐ THE END PATH ALREADY DOES THIS. `endLiveActivity(completion:)` reaches
    // its completion only through `DispatchQueue.main.asyncAfter` and
    // `DispatchQueue.main.async`, and says so: "handedBack is only ever touched
    // on the main queue". START simply never got the same treatment.
    UNUserNotificationCenter.current().add(request) { _ in
      DispatchQueue.main.async { completion?() }
    }
  }

  /// ⚠️ NOTHING EVER REMOVES THIS NOTIFICATION. Recorded 21 September 2026, not
  /// fixed here, and deliberately not fixed here.
  ///
  /// `showPersistentNormalNotification` and `scheduleActiveNotification` remove
  /// only kPersistentId and kActivePersistentId, so this one survives in
  /// Notification Center until the user swipes it. That is what let a feedback
  /// notification for event A be tapped after event B had started — see the
  /// ownership guard in the didReceive default-action branch.
  ///
  /// ⛔ REMOVING IT IS NOT A SUBSTITUTE FOR THAT GUARD, which is why the guard
  /// went in first. A notification with a short life can still outlive its
  /// event: this request carries a 2-second trigger, so B can start inside the
  /// delivery window and be tapped on immediately.
  ///
  /// ⚠️ AND THE OBVIOUS PLACE TO CLEAR IT IS A TRAP. Adding kFeedbackId to
  /// showPersistentNormalNotification's removal list would fire at
  /// handleQuickLogEnd:937 — one line after this request is made and before it
  /// is delivered — so it would remove nothing there while looking correct, and
  /// would only work from the other callers. It belongs in
  /// scheduleActiveNotification, at the START of the next event, and wants its
  /// own change with its own test.
  ///
  /// ⭐ [eventId] RIDES ALONG AND NOTHING ELSE MOVES, 23 September 2026. Title,
  /// body, sound, identifier, category and trigger are byte-for-byte what they
  /// were. `userInfo` is not presented by the system — not shown, not spoken,
  /// not summarised, not used for grouping — so this is invisible to the user
  /// by construction rather than by inspection.
  ///
  /// ⚠️ NIL IS A REAL CASE, not a defensive one. This function is called
  /// UNCONDITIONALLY at the end of handleQuickLogEnd, including when the active
  /// marker would not parse and no end instruction was written. There is no id
  /// to attach then, the notification is still posted, and the tap must reach
  /// History rather than a record — which is exactly what an absent id does.
  private func showFeedbackNotification(elapsed: String, eventId: String?) {
    let content = UNMutableNotificationContent()
    content.title = elapsed.isEmpty ? "Event ended" : "Event ended · \(elapsed)"
    content.body = "Open MER to add details"
    content.sound = .default
    if let eventId, !eventId.isEmpty {
      content.userInfo = [kNotificationEventIdKey: eventId]
    }
    let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 2, repeats: false)
    let request = UNNotificationRequest(
      identifier: kFeedbackId, content: content, trigger: trigger
    )
    UNUserNotificationCenter.current().add(request)
  }
}
