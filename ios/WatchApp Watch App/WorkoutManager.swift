import Foundation
import HealthKit
import Combine

#if os(watchOS)
class WorkoutManager: NSObject, ObservableObject {
    static let shared = WorkoutManager()
    
    let healthStore = HKHealthStore()
    var session: HKWorkoutSession?
    var builder: HKLiveWorkoutBuilder?
    
    @Published var heartRate: Double = 0
    @Published var isRunning = false
    
    private override init() {
        super.init()
    }
    
    func requestAuthorization() {
        let typesToShare: Set = [HKQuantityType.workoutType()]
        let typesToRead: Set = [
            HKQuantityType.quantityType(forIdentifier: .heartRate)!,
            HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned)!
        ]
        
        healthStore.requestAuthorization(toShare: typesToShare, read: typesToRead) { success, error in
            if !success {
                print("❌ HealthKit authorization failed")
            }
        }
    }
    
    func startWorkout(activityType: String) {
        if isRunning { return }
        
        let configuration = HKWorkoutConfiguration()
        configuration.activityType = activityType == "Strength" ? .traditionalStrengthTraining : .running
        configuration.locationType = .unknown
        
        do {
            session = try HKWorkoutSession(healthStore: healthStore, configuration: configuration)
            builder = session?.associatedWorkoutBuilder()
            
            session?.delegate = self
            builder?.delegate = self
            
            builder?.dataSource = HKLiveWorkoutDataSource(healthStore: healthStore, workoutConfiguration: configuration)
            
            let startDate = Date()
            session?.startActivity(with: startDate)
            builder?.beginCollection(withStart: startDate) { success, error in
                DispatchQueue.main.async {
                    self.isRunning = true
                }
            }
        } catch {
            print("❌ Failed to start workout session: \(error.localizedDescription)")
        }
    }
    
    func stopWorkout() {
        session?.end()
        builder?.endCollection(withEnd: Date()) { success, error in
            self.builder?.finishWorkout { workout, error in
                DispatchQueue.main.async {
                    self.isRunning = false
                    self.heartRate = 0
                }
            }
        }
    }
}

extension WorkoutManager: HKWorkoutSessionDelegate {
    func workoutSession(_ workoutSession: HKWorkoutSession, didChangeTo toState: HKWorkoutSessionState, from fromState: HKWorkoutSessionState, date: Date) {
        print("⌚ WorkoutSession changed to state: \(toState.rawValue)")
    }
    
    func workoutSession(_ workoutSession: HKWorkoutSession, didFailWithError error: Error) {
        print("❌ WorkoutSession failed: \(error.localizedDescription)")
    }
}

extension WorkoutManager: HKLiveWorkoutBuilderDelegate {
    func workoutBuilder(_ workoutBuilder: HKLiveWorkoutBuilder, didCollectDataOf collectedTypes: Set<HKSampleType>) {
        for type in collectedTypes {
            guard let quantityType = type as? HKQuantityType else { continue }
            
            if quantityType.identifier == HKQuantityTypeIdentifier.heartRate.rawValue {
                let statistics = workoutBuilder.statistics(for: quantityType)
                let heartRateUnit = HKUnit.count().unitDivided(by: HKUnit.minute())
                guard let value = statistics?.mostRecentQuantity()?.doubleValue(for: heartRateUnit) else { return }
                
                DispatchQueue.main.async {
                    self.heartRate = value
                    ConnectivityProvider.shared.sendHeartRate(value)
                }
            }
        }
    }
    
        func workoutBuilderDidCollectEvent(_ workoutBuilder: HKLiveWorkoutBuilder) {}
    
    }
    
    #endif
    
    