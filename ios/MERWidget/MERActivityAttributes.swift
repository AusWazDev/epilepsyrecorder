import Foundation
import ActivityKit

@available(iOS 16.2, *)
struct MERActivityAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        var eventId: String
        var startIso: String
    }
}
