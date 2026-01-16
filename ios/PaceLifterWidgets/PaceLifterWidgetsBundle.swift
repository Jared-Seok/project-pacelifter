import ActivityKit
import WidgetKit
import SwiftUI

struct WorkoutLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: WorkoutAttributes.self) { context in
            // 잠금화면 대시보드
            VStack {
                HStack {
                    Image(systemName: "figure.run.circle.fill")
                        .foregroundColor(.green)
                        .font(.title)
                    Text(context.state.name)
                        .font(.headline)
                        .foregroundColor(.white)
                    Spacer()
                    Text(context.state.time)
                        .font(.system(.title, design: .monospaced))
                        .fontWeight(.bold)
                        .foregroundColor(.green)
                }
                .padding(.bottom, 5)

                Divider().background(Color.white.opacity(0.3))

                HStack(alignment: .center) {
                    VStack {
                        Text("거리").font(.caption).foregroundColor(.gray)
                        Text(context.state.dist).font(.headline).foregroundColor(.white)
                    }
                    Spacer()
                    VStack {
                        Text("페이스").font(.caption).foregroundColor(.gray)
                        Text(context.state.pace).font(.headline).foregroundColor(.white)
                    }
                    Spacer()
                    VStack {
                        Text("심박수").font(.caption).foregroundColor(.gray)
                        Text(context.state.hr).font(.headline).foregroundColor(.white)
                    }
                }
                .padding(.top, 5)
            }
            .padding()
            .background(Color.black.opacity(0.8))

        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    HStack {
                        Image(systemName: "figure.run").foregroundColor(.green)
                        Text(context.state.dist).font(.title2).fontWeight(.bold)
                    }
                }
                DynamicIslandExpandedRegion(.trailing) {
                    VStack(alignment: .trailing) {
                        Text(context.state.time).font(.title2).fontWeight(.bold).foregroundColor(.green)
                        Text(context.state.pace).font(.caption)
                    }
                }
                DynamicIslandExpandedRegion(.bottom) {
                    HStack {
                        Text("❤️ \(context.state.hr)").foregroundColor(.red)
                        Spacer()
                        Text(context.state.name).font(.caption).foregroundColor(.gray)
                    }
                }
            } compactLeading: {
                HStack {
                    Image(systemName: "figure.run").foregroundColor(.green)
                    Text(context.state.dist).font(.caption2).fontWeight(.bold)
                }
            } compactTrailing: {
                Text(context.state.time).font(.caption2).monospacedDigit().foregroundColor(.green)
            } minimal: {
                Image(systemName: "figure.run").foregroundColor(.green)
            }
        }
    }
}

@main
struct PaceLifterWidgetsBundle: WidgetBundle {
    var body: some Widget {
        WorkoutLiveActivity()
    }
}