import WatchConnectivity
import WidgetKit
import Combine

class ConnectivityProvider: NSObject, ObservableObject, WCSessionDelegate {
    static let shared = ConnectivityProvider()
    
    @Published var lastMessage: [String: Any] = [:]
    
    // 심박수 수신 시 호출할 콜백 (WorkoutManager에서 사용)
    var onCommandReceived: ((String, String) -> Void)?
    
    private override init() {
        super.init()
        if WCSession.isSupported() {
            WCSession.default.delegate = self
            WCSession.default.activate()
        }
    }
    
    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        print("⌚ ConnectivityProvider: Activation complete - \(activationState.rawValue)")
    }
    
    #if os(iOS)
    func sessionDidBecomeInactive(_ session: WCSession) {}
    func sessionDidDeactivate(_ session: WCSession) {
        WCSession.default.activate()
    }
    #endif
    
    // Phone으로부터 메시지 수신 (START/STOP)
    func session(_ session: WCSession, didReceiveMessage message: [String : Any]) {
        DispatchQueue.main.async {
            self.lastMessage = message
            if let command = message["command"] as? String {
                let activityType = message["activityType"] as? String ?? "Running"
                self.onCommandReceived?(command, activityType)
            }
        }
    }
    
    // 심박수 데이터를 Phone으로 전송
    func sendHeartRate(_ heartRate: Double) {
        #if os(watchOS)
        guard WCSession.default.isReachable else {
            try? WCSession.default.updateApplicationContext(["heartRate": heartRate])
            return
        }
        
        WCSession.default.sendMessage(["heartRate": heartRate], replyHandler: nil) { error in
            print("❌ Error sending heart rate: \(error.localizedDescription)")
        }
        #endif
    }
}
