import SwiftUI

struct ContentView: View {
    @StateObject var workoutManager = WorkoutManager.shared
    @StateObject var connectivityProvider = ConnectivityProvider.shared
    
    var body: some View {
        VStack(spacing: 12) {
            if workoutManager.isRunning {
                Text("Phone에서 제어 중")
                    .font(.caption)
                    .foregroundColor(.green)
                
                Text("\(Int(workoutManager.heartRate))")
                    .font(.system(size: 54, weight: .bold, design: .rounded))
                    .foregroundColor(.red)
                
                Text("BPM")
                    .font(.headline)
                    .foregroundColor(.red.opacity(0.8))
            } else {
                Image(systemName: "clock.arrow.2.circlepath")
                    .font(.system(size: 44))
                    .foregroundColor(.gray)
                
                Text("연결 대기 중")
                    .font(.headline)
                
                Text("폰에서 운동을 시작하세요")
                    .font(.caption)
                    .multilineTextAlignment(.center)
                    .foregroundColor(.secondary)
            }
        }
        .onAppear {
            workoutManager.requestAuthorization()
            setupCommandListener()
        }
    }
    
    private func setupCommandListener() {
        connectivityProvider.onCommandReceived = { command, activityType in
            if command == "START_WORKOUT" {
                workoutManager.startWorkout(activityType: activityType)
            } else if command == "STOP_WORKOUT" {
                workoutManager.stopWorkout()
            }
        }
    }
}