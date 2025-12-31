import Foundation
import ActivityKit

struct LiveActivityAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        // Dynamic data (Changes during the workout)
        var distanceKm: String
        var duration: String
        var pace: String
        var heartRate: String
    }

    // Static data (Set once at the start)
    var name: String
}
