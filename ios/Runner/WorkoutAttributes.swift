import ActivityKit
import WidgetKit
import SwiftUI
import Foundation

// 💡 스키마 캐시를 깨기 위해 필드명을 새롭게 정의 (Decodable 안정성 확보)
public struct WorkoutAttributes: ActivityAttributes {
    public typealias WorkoutStatus = ContentState

    public struct ContentState: Codable, Hashable {
        public var name: String
        public var time: String
        public var dist: String
        public var pace: String
        public var hr: String
        
        // 💡 모든 필드를 포함하는 public init 필수
        public init(name: String, time: String, dist: String, pace: String, hr: String) {
            self.name = name
            self.time = time
            self.dist = dist
            self.pace = pace
            self.hr = hr
        }
    }

    // 💡 빈 public init 필수
    public init() {}
}