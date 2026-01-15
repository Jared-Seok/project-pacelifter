import ActivityKit
import WidgetKit
import SwiftUI

// 1. 데이터 구조체 정의 (플러터 live_activities 패키지와 통신용)
struct WorkoutAttributes: ActivityAttributes {
    public typealias WorkoutStatus = ContentState

    public struct ContentState: Codable, Hashable {
        var duration: String
        var distance: String
        var pace: String
        var heartRate: String
    }

    var workoutName: String
}

// 2. 라이브 액티비티 위젯 UI 정의
struct WorkoutLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: WorkoutAttributes.self) { context in
            // 잠금화면 실시간 현황 레이아웃
            VStack {
                HStack {
                    Image(systemName: "figure.run.circle.fill")
                        .foregroundColor(.green)
                        .font(.title)
                    Text(context.attributes.workoutName)
                        .font(.headline)
                        .foregroundColor(.white)
                    Spacer()
                    Text(context.state.duration)
                        .font(.system(.title, design: .monospaced))
                        .fontWeight(.bold)
                        .foregroundColor(.green)
                }
                .padding(.bottom, 5)

                Divider().background(Color.white.opacity(0.3))

                HStack(alignment: .center) {
                    VStack {
                        Text("거리").font(.caption).foregroundColor(.gray)
                        Text(context.state.distance).font(.headline).foregroundColor(.white)
                    }
                    Spacer()
                    VStack {
                        Text("페이스").font(.caption).foregroundColor(.gray)
                        Text(context.state.pace).font(.headline).foregroundColor(.white)
                    }
                    Spacer()
                    VStack {
                        Text("심박수").font(.caption).foregroundColor(.gray)
                        Text(context.state.heartRate).font(.headline).foregroundColor(.white)
                    }
                }
                .padding(.top, 5)
            }
            .padding()
            .background(Color.black.opacity(0.8))

        } dynamicIsland: { context in
            // 다이나믹 아일랜드 레이아웃
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    HStack {
                        Image(systemName: "figure.run").foregroundColor(.green)
                        Text(context.state.distance).font(.title2).fontWeight(.bold)
                    }
                }
                DynamicIslandExpandedRegion(.trailing) {
                    VStack(alignment: .trailing) {
                        Text(context.state.duration).font(.title2).fontWeight(.bold).foregroundColor(.green)
                        Text(context.state.pace).font(.caption)
                    }
                }
                DynamicIslandExpandedRegion(.bottom) {
                    HStack {
                        Text("❤️ \(context.state.heartRate)").foregroundColor(.red)
                        Spacer()
                        Text(context.attributes.workoutName).font(.caption).foregroundColor(.gray)
                    }
                }
            } compactLeading: {
                HStack {
                    Image(systemName: "figure.run").foregroundColor(.green)
                    Text(context.state.distance).font(.caption2).fontWeight(.bold)
                }
            } compactTrailing: {
                Text(context.state.duration).font(.caption2).monospacedDigit().foregroundColor(.green)
            } minimal: {
                Image(systemName: "figure.run").foregroundColor(.green)
            }
        }
    }
}

// 3. 💡 핵심: 위젯 번들 엔트리 포인트 (타겟의 유일한 @main)
@main
struct PaceLifterWidgetsBundle: WidgetBundle {
    var body: some Widget {
        // 불필요한 샘플 위젯들을 제거하고 WorkoutLiveActivity만 등록
        WorkoutLiveActivity()
    }
}