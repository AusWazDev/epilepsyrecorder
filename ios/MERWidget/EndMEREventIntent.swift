import AppIntents
import ActivityKit
import UserNotifications
import Foundation
import os.log

@available(iOS 16.0, *)
struct EndMEREventIntent: AppIntent {
    static var title: LocalizedStringResource = "End Event"
    static var isDiscoverable = false
    static var authenticationPolicy: IntentAuthenticationPolicy { .alwaysAllowed }

    // Runner's AppDelegate.captureLog is private to the Runner TARGET and not
    // visible here — MERWidget is a separate target, the same boundary that
    // already forces MERActivityAttributes.swift to be duplicated. Same
    // subsystem and category deliberately, so one Console.app filter shows both
    // processes.
    private static let captureLog = OSLog(subsystem: "au.com.notiva.mer",
                                          category: "capture")

    func perform() async throws -> some IntentResult {
        let kAppGroupId   = "group.au.com.notiva.medicaleventrecorder"
        let kSharedActive = "mer_active_event"
        let kInboxPrefix  = "mer_inbox_"

        // PRESERVATION ONLY. Nothing in the field reads these; the os_log below
        // is a development reader over a cable. Names must match AppDelegate's
        // kQuarantineKey / kQuarantineCountKey — same App Group, same keys, and
        // the schema mirroring note above applies to these too.
        let kQuarantineKey      = "mer_active_quarantine"
        let kQuarantineCountKey = "mer_active_quarantine_count"

        guard let shared = UserDefaults(suiteName: kAppGroupId) else {
            return .result()
        }

        var elapsedStr = ""
        // Set ONLY inside the if let body, so it separates "the chain succeeded"
        // from "the marker was there and would not parse".
        var endedCleanly = false
        // Hoisted because the feedback notification is built BELOW this block,
        // where `eventId` is out of scope. Nil means the same as
        // endedCleanly == false — the marker did not read — and the
        // notification is posted either way.
        var endedEventId: String?

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
            endedCleanly = true
            endedEventId = eventId
        }

        // MOVED ASIDE, NOT DELETED. The re-read is deliberate: activeRaw binds
        // in the first clause above and is out of scope here, and the key is
        // untouched until the removal below. A nil re-read means the chain failed
        // at its FIRST clause — nothing to preserve — so nothing is written, and
        // an empty entry never manufactures evidence of a loss that did not happen.
        //
        // ⛔ BUDGET: one read, two sets, one os_log. NO synchronize is added —
        // the one below already existed. This is the tightest window of the three
        // sites and nothing here may block it.
        if !endedCleanly, let raw = shared.string(forKey: kSharedActive), !raw.isEmpty {
            let count = shared.integer(forKey: kQuarantineCountKey) + 1
            shared.set(raw,   forKey: kQuarantineKey)
            shared.set(count, forKey: kQuarantineCountKey)
            os_log("preserved unreadable active marker site=%{public}@ count=%{public}d",
                   log: Self.captureLog, type: .default, "EndMEREventIntent", count)
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
        // ⭐ THE ID RIDES ALONG, 23 September 2026, AND ON 17+ THIS IS THE
        // POSTER THAT MATTERS. The event ends in this extension, so the app is
        // usually not running and this is the notification most taps arrive on.
        // Leaving it out here would disable the carrier on its main path while
        // AppDelegate's copy made it look implemented.
        //
        // ⚠️ "mer_event_id" IS A DUPLICATED LITERAL. AppDelegate holds it as
        // kNotificationEventIdKey and cannot be imported — Runner and MERWidget
        // are separate targets, the same boundary that already forces
        // MERActivityAttributes.swift and the inbox schema to be duplicated.
        // test/notification_fallback_routing_test.dart asserts both sides.
        //
        // ⛔ CONTENT, IDENTIFIER, TRIGGER AND SOUND ARE UNCHANGED. `userInfo`
        // is not presented by the system, so nothing a user can see moves.
        if let endedEventId, !endedEventId.isEmpty {
            feedback.userInfo = ["mer_event_id": endedEventId]
        }
        try? await center.add(UNNotificationRequest(
            identifier: "mer_feedback_intent",
            content:    feedback,
            trigger:    UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)))

        return .result()
    }
}

@available(iOS 17.0, *)
extension EndMEREventIntent: LiveActivityIntent {}

