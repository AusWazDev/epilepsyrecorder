import AppIntents
import ActivityKit
import UserNotifications
import Foundation

@available(iOS 16.0, *)
struct EndMEREventIntent: AppIntent {
    static var title: LocalizedStringResource = "End Event"
    static var isDiscoverable = false
    static var authenticationPolicy: IntentAuthenticationPolicy { .alwaysAllowed }

    func perform() async throws -> some IntentResult {
        let kAppGroupId    = "group.au.com.notiva.medicaleventrecorder"
        let kSharedActive  = "mer_active_event"
        let kSharedRecords = "mer_records"

        guard let shared = UserDefaults(suiteName: kAppGroupId) else {
            return .result()
        }

        var elapsedStr = ""

        if let activeRaw = shared.string(forKey: kSharedActive),
           let data      = activeRaw.data(using: .utf8),
           let active    = try? JSONSerialization.jsonObject(with: data) as? NSDictionary,
           let eventId   = active["id"] as? String,
           let startIso  = active["startIso"] as? String,
           let startTime = ISO8601DateFormatter().date(from: startIso) {

            let endTime = Date()
            let secs = max(0, Int(endTime.timeIntervalSince(startTime)))
            let m = secs / 60, s = secs % 60
            elapsedStr = m == 0 ? "\(s)s" : (s == 0 ? "\(m)m" : "\(m)m \(s)s")
            let duration = secs < 60 ? "lt1" : (secs < 300 ? "oneToFive" : "gt5")

            if let raw = shared.string(forKey: kSharedRecords),
               let listData = raw.data(using: .utf8),
               let decoded  = try? JSONSerialization.jsonObject(with: listData) as? NSArray {
                let list = NSMutableArray(array: decoded)
                for i in 0..<list.count {
                    if let item = list[i] as? NSMutableDictionary,
                       (item["id"] as? String) == eventId {
                        item["duration"] = duration; break
                    }
                    if let item = list[i] as? NSDictionary,
                       (item["id"] as? String) == eventId {
                        let m2 = NSMutableDictionary(dictionary: item)
                        m2["duration"] = duration; list[i] = m2; break
                    }
                }
                if let enc = try? JSONSerialization.data(withJSONObject: list),
                   let str = String(data: enc, encoding: .utf8) {
                    shared.set(str, forKey: kSharedRecords)
                }
            }

        }

        shared.removeObject(forKey: kSharedActive)
        shared.synchronize()

        // End any running Live Activity
        if #available(iOS 16.2, *) {
            for activity in Activity<MERActivityAttributes>.activities {
                await activity.end(nil, dismissalPolicy: .immediate)
            }
        }

        // Remove active notification, schedule feedback + normal
        let center = UNUserNotificationCenter.current()
        center.removeDeliveredNotifications(withIdentifiers: ["2"])

        let feedback = UNMutableNotificationContent()
        feedback.title = elapsedStr.isEmpty ? "Event ended" : "Event ended · \(elapsedStr)"
        feedback.body  = "Open MER to add details"
        feedback.sound = .default
        try? await center.add(UNNotificationRequest(
            identifier: "mer_feedback_intent",
            content:    feedback,
            trigger:    UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)))

        return .result()
    }
}

@available(iOS 17.0, *)
extension EndMEREventIntent: LiveActivityIntent {}

