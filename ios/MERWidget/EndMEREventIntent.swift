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
        let kAppGroupId   = "group.au.com.notiva.medicaleventrecorder"
        let kSharedActive = "mer_active_event"
        let kInboxPrefix  = "mer_inbox_"

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

            // Post an END fact. This replaces reading the whole record list,
            // finding the matching entry, rewriting it and writing the list
            // back — from a SEPARATE PROCESS, with the app free to be doing the
            // same thing at the same time.
            //
            // Everything needed is already here: the id and start time come from
            // the active-event key. This extension now has no knowledge of the
            // record list at all, which is the single most important property of
            // the design — the cross-process read-modify-write is removed rather
            // than relocated.
            //
            // Seconds, not a bucket: the lt1/oneToFive/gt5 mapping lived here and
            // in two places in AppDelegate. It is now bucketFromSeconds in
            // capture_inbox.dart, once. max(0, …) above means the value can never
            // be the negative the schema defers on.
            //
            // Duplicated from AppDelegate.writeInboxInstruction rather than
            // shared: Runner and MERWidget are separate targets, and the project
            // already duplicates MERActivityAttributes.swift across the same
            // boundary. Any change to the schema must be mirrored in both.
            let payload: [String: Any] = [
                "v": NSNumber(value: 1),
                "kind": "end",
                "id": eventId,
                "at": ISO8601DateFormatter().string(from: endTime),
                "seconds": NSNumber(value: secs),
            ]
            if let enc = try? JSONSerialization.data(withJSONObject: payload),
               let json = String(data: enc, encoding: .utf8) {
                shared.set(json, forKey: "\(kInboxPrefix)\(UUID().uuidString)")
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

