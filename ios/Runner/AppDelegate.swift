import Flutter
import UIKit
import UserNotifications
import awesome_notifications
import shared_preferences_foundation

@main
@objc class AppDelegate: FlutterAppDelegate {

  // ── SharedPreferences key prefix (Flutter uses "flutter." on iOS) ─────────
  private let kStorageKey     = "flutter.epilepsy_event_records_v1"
  private let kActiveEventKey = "flutter.mer_active_event"

  // ── Notification identifiers ──────────────────────────────────────────────
  // awesome_notifications converts Int id → String for the UNNotificationRequest identifier
  private let kPersistentId   = "1"
  private let kFeedbackId     = "mer_feedback_native"
  private let kBtnStart       = "QUICK_LOG_START"
  private let kBtnEnd         = "QUICK_LOG_END"
  private let kCategoryNormal = "MER_NORMAL"
  private let kCategoryActive = "MER_ACTIVE"

  // Reference to whoever was delegate before we reclaimed it (awesome_notifications),
  // so we can forward willPresent and non-MER didReceive calls through it.
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

    // MethodChannel: Dart calls "showNormal" / "showActive" to create the
    // persistent iOS notification natively, bypassing awesome_notifications.
    if let controller = window?.rootViewController as? FlutterViewController {
      let channel = FlutterMethodChannel(
        name: "au.com.notiva.mer/notifications",
        binaryMessenger: controller.binaryMessenger
      )
      channel.setMethodCallHandler { [weak self] call, result in
        switch call.method {
        case "showNormal":
          self?.showPersistentNormalNotification()
          result(nil)
        case "showActive":
          if let args = call.arguments as? [String: Any],
             let startIso = args["startIso"] as? String {
            self?.showPersistentActiveNotification(startIso: startIso)
          }
          result(nil)
        default:
          result(FlutterMethodNotImplemented)
        }
      }
    }

    // Reclaim the UNUserNotificationCenter delegate.
    // awesome_notifications registers itself as delegate during plugin init;
    // we take it back so locked-screen action buttons are handled natively
    // (without relying on a Dart background isolate, which is unreliable
    // in release builds on a locked device).
    previousDelegate = UNUserNotificationCenter.current().delegate
    UNUserNotificationCenter.current().delegate = self
    registerNativeNotificationCategories()

    return result
  }

  // ── Native category registration ──────────────────────────────────────────
  // Called at launch and before each native notification creation so our
  // categories survive if awesome_notifications overwrites them during
  // a Flutter resume cycle.

  private func registerNativeNotificationCategories() {
    let startAction = UNNotificationAction(
      identifier: kBtnStart,
      title: "Log Event Now",
      options: []  // background — no foreground, no authentication required
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
    // Forward to awesome_notifications so it can show notifications
    // while the app is in the foreground.
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
      // Handle natively — writes to UserDefaults directly so data is saved
      // even if the Dart VM is not running (locked screen, release build).
      handleQuickLogStart()
      completionHandler()
    case kBtnEnd:
      handleQuickLogEnd()
      completionHandler()
    default:
      // Forward everything else (notification body tap, dismiss, etc.)
      // to awesome_notifications so Dart-side routing still works.
      if let prev = previousDelegate {
        prev.userNotificationCenter?(center, didReceive: response, withCompletionHandler: completionHandler)
      } else {
        completionHandler()
      }
    }
  }

  // ── Action handlers ───────────────────────────────────────────────────────

  private func handleQuickLogStart() {
    let defaults = UserDefaults.standard
    let now = Date()
    let id = UUID().uuidString
    let isoNow = ISO8601DateFormatter().string(from: now)

    // Build a minimal EventRecord matching Dart's EventRecord.toMap() format
    let record: [String: Any] = [
      "id": id,
      "timestamp": isoNow,
      "duration": "lt1",
      "feelings": [String](),
      "triggers": [String](),
      "referralRequired": false,
      "notes": "",
      "eventType": "seizure",
      "severity": "mild",
    ]

    // Prepend to the stored list
    var list: [[String: Any]] = []
    if let raw = defaults.string(forKey: kStorageKey),
       let data = raw.data(using: .utf8),
       let decoded = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] {
      list = decoded
    }
    list.insert(record, at: 0)
    if let encoded = try? JSONSerialization.data(withJSONObject: list),
       let str = String(data: encoded, encoding: .utf8) {
      defaults.set(str, forKey: kStorageKey)
    }

    // Mark the active event
    let active: [String: String] = ["id": id, "startIso": isoNow]
    if let encoded = try? JSONSerialization.data(withJSONObject: active),
       let str = String(data: encoded, encoding: .utf8) {
      defaults.set(str, forKey: kActiveEventKey)
    }
    defaults.synchronize()

    let fmt = DateFormatter()
    fmt.dateFormat = "h:mm a"
    showPersistentActiveNotification(startTimeStr: fmt.string(from: now))
  }

  private func handleQuickLogEnd() {
    let defaults = UserDefaults.standard
    var elapsedStr = ""

    if let activeRaw = defaults.string(forKey: kActiveEventKey),
       let data = activeRaw.data(using: .utf8),
       let active = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
       let eventId = active["id"] as? String,
       let startIso = active["startIso"] as? String,
       let startTime = ISO8601DateFormatter().date(from: startIso) {

      let endTime = Date()
      let secs = max(0, Int(endTime.timeIntervalSince(startTime)))
      let m = secs / 60
      let s = secs % 60
      elapsedStr = m == 0 ? "\(s)s" : (s == 0 ? "\(m)m" : "\(m)m \(s)s")

      let duration = secs < 60 ? "lt1" : (secs < 300 ? "oneToFive" : "gt5")

      if let raw = defaults.string(forKey: kStorageKey),
         let listData = raw.data(using: .utf8),
         var list = try? JSONSerialization.jsonObject(with: listData) as? [[String: Any]] {
        if let idx = list.firstIndex(where: { ($0["id"] as? String) == eventId }) {
          list[idx]["duration"] = duration
        }
        if let encoded = try? JSONSerialization.data(withJSONObject: list),
           let str = String(data: encoded, encoding: .utf8) {
          defaults.set(str, forKey: kStorageKey)
        }
      }
    }

    defaults.removeObject(forKey: kActiveEventKey)
    defaults.synchronize()

    showFeedbackNotification(elapsed: elapsedStr)
    showPersistentNormalNotification()
  }

  // ── Notification builders ─────────────────────────────────────────────────

  func showPersistentNormalNotification() {
    registerNativeNotificationCategories()
    let content = UNMutableNotificationContent()
    content.title = "Medical Event Recorder"
    content.body = "Long-press this notification to log an event"
    content.sound = .none
    content.categoryIdentifier = kCategoryNormal
    let request = UNNotificationRequest(
      identifier: kPersistentId, content: content, trigger: nil
    )
    UNUserNotificationCenter.current().add(request)
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
    showPersistentActiveNotification(startTimeStr: timeStr)
  }

  private func showPersistentActiveNotification(startTimeStr: String) {
    registerNativeNotificationCategories()
    let content = UNMutableNotificationContent()
    content.title = "Event in progress · \(startTimeStr)"
    content.body = "Tap \"Event Ended\" when the event is over"
    content.sound = .none
    content.categoryIdentifier = kCategoryActive
    let request = UNNotificationRequest(
      identifier: kPersistentId, content: content, trigger: nil
    )
    UNUserNotificationCenter.current().add(request)
  }

  private func showFeedbackNotification(elapsed: String) {
    let content = UNMutableNotificationContent()
    content.title = elapsed.isEmpty ? "Event ended" : "Event ended · \(elapsed)"
    content.body = "Open MER to add details"
    content.sound = .default
    // 1-second delay so it appears after the persistent notification update
    let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
    let request = UNNotificationRequest(
      identifier: kFeedbackId, content: content, trigger: trigger
    )
    UNUserNotificationCenter.current().add(request)
  }
}
