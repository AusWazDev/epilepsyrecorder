import Flutter
import UIKit
import UserNotifications
import ActivityKit
import awesome_notifications
import shared_preferences_foundation

@main
@objc class AppDelegate: FlutterAppDelegate {

  // ── SharedPreferences key prefix (Flutter uses "flutter." on iOS) ─────────
  private let kStorageKey      = "flutter.epilepsy_event_records_v1"
  private let kActiveEventKey  = "flutter.mer_active_event"

  // ── App Groups shared storage (used by MERWidget / EndMEREventIntent) ──────
  private let kAppGroupId      = "group.au.com.notiva.medicaleventrecorder"
  private let kSharedRecords   = "mer_records"
  private let kSharedActiveKey = "mer_active_event"

  // ── Notification identifiers ──────────────────────────────────────────────
  private let kPersistentId        = "1"
  private let kActivePersistentId  = "2"
  private let kFeedbackId          = "mer_feedback_native"
  private let kBtnStart            = "QUICK_LOG_START"
  private let kBtnEnd              = "QUICK_LOG_END"
  private let kCategoryNormal      = "MER_NORMAL"
  private let kCategoryActive      = "MER_ACTIVE"

  private weak var previousDelegate: UNUserNotificationCenterDelegate?

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

    previousDelegate = UNUserNotificationCenter.current().delegate
    UNUserNotificationCenter.current().delegate = self
    registerNativeNotificationCategories()

    return result
  }

  override func applicationDidBecomeActive(_ application: UIApplication) {
    super.applicationDidBecomeActive(application)
    previousDelegate = UNUserNotificationCenter.current().delegate
    UNUserNotificationCenter.current().delegate = self
    registerNativeNotificationCategories()
    syncFromSharedIfNeeded()
    UNUserNotificationCenter.current().requestAuthorization(
      options: [.alert, .sound, .badge]
    ) { [weak self] _, _ in
      DispatchQueue.main.async { self?.restorePersistentNotification() }
    }
  }

  // ── Shared storage sync ───────────────────────────────────────────────────
  // Called on every foreground. If MERWidget's EndMEREventIntent ran while the
  // app was backgrounded/locked, the shared suite has the end-event data but
  // Flutter's standard UserDefaults does not. Detect and reconcile here.
  private func syncFromSharedIfNeeded() {
    guard let shared = UserDefaults(suiteName: kAppGroupId) else { return }
    let standard = UserDefaults.standard

    let sharedActive   = shared.string(forKey: kSharedActiveKey)
    let standardActive = standard.string(forKey: kActiveEventKey)

    if standardActive != nil && sharedActive == nil {
      // Widget intent ended the event while app was not running — sync records
      if let sharedRecs = shared.string(forKey: kSharedRecords) {
        standard.set(sharedRecs, forKey: kStorageKey)
      }
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
      if Date().timeIntervalSince(startDate) >= 30 * 60 {
        defaults.removeObject(forKey: kActiveEventKey)
        defaults.synchronize()
        if let shared = UserDefaults(suiteName: kAppGroupId) {
          shared.removeObject(forKey: kSharedActiveKey)
          shared.synchronize()
        }
        if #available(iOS 16.2, *) { endLiveActivity() }
        showPersistentNormalNotification()
      } else {
        showPersistentActiveNotification(startIso: startIso)
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
    let content    = ActivityContent(state: state, staleDate: nil)
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
    if let prev = previousDelegate {
      prev.userNotificationCenter?(center, willPresent: notification, withCompletionHandler: completionHandler)
    } else {
      completionHandler([.alert, .sound])
    }
  }

  override func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    didReceive response: UNNotificationResponse,
    withCompletionHandler completionHandler: @escaping () -> Void
  ) {
    switch response.actionIdentifier {
    case kBtnStart:
      handleQuickLogStart(completion: completionHandler)
    case kBtnEnd:
      handleQuickLogEnd(completion: completionHandler)
    default:
      if let prev = previousDelegate {
        prev.userNotificationCenter?(center, didReceive: response, withCompletionHandler: completionHandler)
      } else {
        completionHandler()
      }
    }
  }

  // ── Action handlers ───────────────────────────────────────────────────────

  private func handleQuickLogStart(completion: @escaping () -> Void) {
    let standard = UserDefaults.standard
    let shared   = UserDefaults(suiteName: kAppGroupId)
    let now  = Date()
    let id   = UUID().uuidString
    let isoNow = ISO8601DateFormatter().string(from: now)

    let record = NSMutableDictionary()
    record["id"]               = id
    record["timestamp"]        = isoNow
    record["duration"]         = "lt1"
    record["feelings"]         = NSArray()
    record["triggers"]         = NSArray()
    record["referralRequired"] = NSNumber(value: false)
    record["notes"]            = ""
    record["eventType"]        = "seizure"
    record["severity"]         = "mild"

    // Prepend to standard (Flutter) storage
    var list = NSMutableArray()
    if let raw = standard.string(forKey: kStorageKey),
       let data = raw.data(using: .utf8),
       let decoded = try? JSONSerialization.jsonObject(with: data) as? NSArray {
      list = NSMutableArray(array: decoded)
    }
    list.insert(record, at: 0)
    if let encoded = try? JSONSerialization.data(withJSONObject: list),
       let str = String(data: encoded, encoding: .utf8) {
      standard.set(str, forKey: kStorageKey)
      shared?.set(str, forKey: kSharedRecords)
    }

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

    let fmt = DateFormatter()
    fmt.dateFormat = "h:mm a"
    scheduleActiveNotification(startTimeStr: fmt.string(from: now), completion: completion)
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
      let duration = secs < 60 ? "lt1" : (secs < 300 ? "oneToFive" : "gt5")

      func updateList(_ raw: String?) -> String? {
        guard let raw = raw,
              let listData = raw.data(using: .utf8),
              let decoded = try? JSONSerialization.jsonObject(with: listData) as? NSArray else { return nil }
        let list = NSMutableArray(array: decoded)
        for i in 0..<list.count {
          if let item = list[i] as? NSMutableDictionary, (item["id"] as? String) == eventId {
            item["duration"] = duration; break
          }
          if let item = list[i] as? NSDictionary, (item["id"] as? String) == eventId {
            let mutable = NSMutableDictionary(dictionary: item)
            mutable["duration"] = duration; list[i] = mutable; break
          }
        }
        guard let enc = try? JSONSerialization.data(withJSONObject: list),
              let str = String(data: enc, encoding: .utf8) else { return nil }
        return str
      }

      if let updated = updateList(standard.string(forKey: kStorageKey)) {
        standard.set(updated, forKey: kStorageKey)
        shared?.set(updated, forKey: kSharedRecords)
      }
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
