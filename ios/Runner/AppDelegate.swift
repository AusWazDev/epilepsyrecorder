import Flutter
import UIKit
import UserNotifications
import ActivityKit
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
        case "getShowPreviewsSetting":
          UNUserNotificationCenter.current().getNotificationSettings { settings in
            DispatchQueue.main.async {
              result(settings.showPreviewsSetting == .always ? "always" : "other")
            }
          }
        case "restoreNotification":
          DispatchQueue.main.async { self?.restorePersistentNotification() }
          result(nil)
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
          // Called only after Dart confirmed the merged write.
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
          // iOS 17+: Live Activity is the end-event UI — restore it if gone
          if Activity<MERActivityAttributes>.activities.isEmpty,
             let eventId = active["id"] as? String {
            startLiveActivity(eventId: eventId, startIso: startIso)
          }
        } else {
          showPersistentActiveNotification(startIso: startIso)
        }
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

  override func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    didReceive response: UNNotificationResponse,
    withCompletionHandler completionHandler: @escaping () -> Void
  ) {
    let notifId = response.notification.request.identifier
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
      let standard = UserDefaults.standard
      standard.removeObject(forKey: kActiveEventKey)
      standard.synchronize()
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
      standard.set(true, forKey: kPendingOpenLatest)
      standard.synchronize()
      navChannel?.invokeMethod("openLatestEvent", arguments: nil)
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

    if #available(iOS 17.0, *) {
      // Live Activity button handles end — no active notification needed
      completion()
    } else {
      let fmt = DateFormatter()
      fmt.dateFormat = "h:mm a"
      scheduleActiveNotification(startTimeStr: fmt.string(from: now), completion: completion)
    }
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
    }

    // ── 2. NOTIFY ──
    // Both requests are handed to usernotificationsd here, before anything that
    // can wait on cfprefsd or ActivityKit. Copy, timing, identifiers and
    // categories are unchanged; only their position moved. Once `add` lands, the
    // daemon owns the schedule and fires it even if this process dies.
    showFeedbackNotification(elapsed: elapsedStr)
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
    standard.removeObject(forKey: kActiveEventKey)
    UserDefaults(suiteName: kAppGroupId)?.removeObject(forKey: kSharedActiveKey)

    // Hands the action's window back to iOS only once the Live Activity is
    // actually gone, or the deadline passes — see endLiveActivity(completion:).
    // Last, because it is the only step whose failure the user can already see.
    endLiveActivity(completion: completion)
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
    UNUserNotificationCenter.current().add(request) { _ in completion?() }
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
    UNUserNotificationCenter.current().add(request) { _ in completion?() }
  }

  private func showFeedbackNotification(elapsed: String) {
    let content = UNMutableNotificationContent()
    content.title = elapsed.isEmpty ? "Event ended" : "Event ended · \(elapsed)"
    content.body = "Open MER to add details"
    content.sound = .default
    let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 2, repeats: false)
    let request = UNNotificationRequest(
      identifier: kFeedbackId, content: content, trigger: trigger
    )
    UNUserNotificationCenter.current().add(request)
  }
}
