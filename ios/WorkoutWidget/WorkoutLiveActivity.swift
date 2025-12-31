import ActivityKit
import WidgetKit
import SwiftUI

struct WorkoutLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: LiveActivityAttributes.self) { context in
            // 잠금화면 UI
            VStack(alignment: .leading) {
                HStack {
                    Image(systemName: "figure.run")
                        .foregroundColor(.green)
                    Text(context.attributes.name)
                        .font(.headline)
                        .foregroundColor(.secondary)
                    Spacer()
                    Text(context.state.duration)
                        .font(.system(.title2, design: .monospaced))
                        .bold()
                }
                
                HStack(alignment: .bottom) {
                    Text(context.state.distanceKm)
                        .font(.system(size: 48, weight: .black, design: .rounded))
                    Text("km")
                        .font(.title2)
                        .bold()
                        .foregroundColor(.secondary)
                        .padding(.bottom, 8)
                    
                    Spacer()
                    
                    VStack(alignment: .trailing) {
                        HStack {
                            Image(systemName: "speedometer")
                            Text(context.state.pace)
                        }
                        HStack {
                            Image(systemName: "heart.fill")
                                .foregroundColor(.red)
                            Text("\(context.state.heartRate) bpm")
                        }
                    }
                    .font(.caption)
                    .bold()
                }
            }
            .padding()
            .activityBackgroundTint(Color.black.opacity(0.8))
            .activitySystemActionForegroundColor(Color.green)

        } dynamicIsland: { context in
            DynamicIsland {
                // Expanded UI (다이내믹 아일랜드 길게 누를 때)
                DynamicIslandExpandedRegion(.leading) {
                    HStack {
                        Image(systemName: "figure.run")
                            .foregroundColor(.green)
                        Text(context.state.distanceKm)
                            .font(.title2)
                            .bold()
                    }
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text(context.state.duration)
                        .font(.title2)
                        .monospacedDigit()
                        .bold()
                }
                DynamicIslandExpandedRegion(.bottom) {
                    HStack {
                        Label(context.state.pace, systemImage: "speedometer")
                        Spacer()
                        Label("\(context.state.heartRate) bpm", systemImage: "heart.fill")
                            .foregroundColor(.red)
                    }
                    .font(.callout)
                    .bold()
                }
            } compactLeading: {
                // Compact UI (좌측)
                Image(systemName: "figure.run")
                    .foregroundColor(.green)
            } compactTrailing: {
                // Compact UI (우측)
                Text(context.state.distanceKm)
                    .bold()
            } minimal: {
                // Minimal UI (다이내믹 아일랜드에 다른 앱과 함께 있을 때)
                Text(context.state.distanceKm)
                    .bold()
            }
            .widgetURL(URL(string: "pacelifter://workout"))
            .keylineTint(Color.green)
        }
    }
}
