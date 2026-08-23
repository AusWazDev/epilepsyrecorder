import Flutter
import UIKit
import UserNotifications
import ActivityKit
import awesome_notifications
import shared_preferences_foundation

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
    SwiftAwesomeNotificationsPlugin.setPluginRegistrantCallback { registry in
      SwiftAwesomeNotificationsPlugin.register(
        with: registry.registrar(forPlugin: "io.flutter.plugins.awesomenotifications.AwesomeNotificationsPlugin")!)
      SharedPreferencesPlugin.register(
        with: registry.registrar(forPlugin: "SharedPreferencesPlugin")!)
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
      if #available(iOS 16.2, *) { endLiveActivity() }
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
        if #available(iOS 16.2, *) { endLiveActivity() }
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
      showPersistentNormalNotification()
    }
  }

  // ── Live Activity helpers ─────────────────────────────────────────────────

  @available(iOS 16.2, *)
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

  @available(iOS 16.2, *)
  private func endLiveActivity() {
    Task {
      for activity in Activity<MERActivityAttributes>.activities {
        await activity.end(nil, dismissalPolicy: .immediate)
      }
    }
  }

  // ── Native category registration ──────────────────────────────────────────
  private func registerNativeNotificationCategories() {
    let startAction = UNNotificationAction(
      identifier: kBtnStart,
      title: "Log Event Now",
      options: []
    )
    let endAction = UNNotificationAction(
      identifier: kBtnEnd,
      title: "Event Ended",
      options: []
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
      if let channel = navChannel {
        channel.invokeMethod("openLatestEvent", arguments: nil)
      } else {
        // Cold start — Flutter not ready yet; set flag for getPendingOpenLatest poll
        standard.set(true, forKey: kPendingOpenLatest)
        standard.synchronize()
      }
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

  private func writeInboxInstruction(_ payload: [String: Any]) {
    guard let shared = UserDefaults(suiteName: kAppGroupId),
          let data = try? JSONSerialization.data(withJSONObject: payload),
          let json = String(data: data, encoding: .utf8) else { return }
    shared.set(json, forKey: "\(kInboxPrefix)\(UUID().uuidString)")
    shared.synchronize()
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

    // Start Live Activity (iOS 16.2+)
    if #available(iOS 16.2, *) {
      startLiveActivity(eventId: id, startIso: isoNow)
    }

    if #available(iOS 17.0, *) {
      // Live Activity button handles end — no active notification needed
      completion()
    } else {
      let fmt = DateFormatter()
      fmt.dateFormat = "h:mm a"
      scheduleActiveNotification(startTimeStr: fmt.string(from: now), completion: completion)
    }
  }

  private func handleQuickLogEnd(completion: @escaping () -> Void) {
    let standard = UserDefaults.standard
    let shared   = UserDefaults(suiteName: kAppGroupId)
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

    standard.removeObject(forKey: kActiveEventKey)
    standard.synchronize()
    shared?.removeObject(forKey: kSharedActiveKey)
    shared?.synchronize()

    if #available(iOS 16.2, *) { endLiveActivity() }

    showFeedbackNotification(elapsed: elapsedStr)
    showPersistentNormalNotification(completion: completion)
  }

  func endEvent() async {
    handleQuickLogEnd(completion: {})
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
