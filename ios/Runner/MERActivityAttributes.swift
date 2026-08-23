import Foundation
import ActivityKit

struct MERActivityAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        var eventId: String
        var startIso: String
    }
}
