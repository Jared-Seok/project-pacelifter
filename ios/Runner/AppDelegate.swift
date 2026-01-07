import Flutter
import UIKit
import GoogleMaps
import HealthKit

/// Bridge to access additional HealthKit properties not exposed by the health package
class HealthKitBridge {
    private let healthStore = HKHealthStore()

    /// Get the active duration (excluding pauses) for a workout by UUID
    func getWorkoutDuration(uuid: String, result: @escaping FlutterResult) {
        guard let workoutUUID = UUID(uuidString: uuid) else {
            result(FlutterError(code: "INVALID_UUID",
                              message: "Invalid UUID format",
                              details: nil))
            return
        }

        let workoutType = HKObjectType.workoutType()
        let typesToRead: Set<HKObjectType> = [workoutType]

        healthStore.requestAuthorization(toShare: nil, read: typesToRead) { (success, error) in
            if let error = error {
                result(FlutterError(code: "AUTH_ERROR",
                                  message: "HealthKit authorization failed",
                                  details: error.localizedDescription))
                return
            }

            if !success {
                result(FlutterError(code: "AUTH_DENIED",
                                  message: "HealthKit authorization denied",
                                  details: nil))
                return
            }

            let predicate = HKQuery.predicateForObject(with: workoutUUID)
            let query = HKSampleQuery(
                sampleType: workoutType,
                predicate: predicate,
                limit: 1,
                sortDescriptors: nil
            ) { (query, samples, error) in
                if let error = error {
                    result(FlutterError(code: "QUERY_ERROR",
                                      message: "Failed to query workout",
                                      details: error.localizedDescription))
                    return
                }

                guard let workout = samples?.first as? HKWorkout else {
                    result(FlutterError(code: "NOT_FOUND",
                                      message: "Workout not found",
                                      details: nil))
                    return
                }

                let durationMs = Int(workout.duration * 1000)
                result(durationMs)
            }

            self.healthStore.execute(query)
        }
    }

    /// Get detailed workout information including active duration and elapsed time
    func getWorkoutDetails(uuid: String, result: @escaping FlutterResult) {
        guard let workoutUUID = UUID(uuidString: uuid) else {
            result(FlutterError(code: "INVALID_UUID",
                              message: "Invalid UUID format",
                              details: nil))
            return
        }

        let workoutType = HKObjectType.workoutType()
        let typesToRead: Set<HKObjectType> = [workoutType]

        healthStore.requestAuthorization(toShare: nil, read: typesToRead) { (success, error) in
            if let error = error {
                result(FlutterError(code: "AUTH_ERROR",
                                  message: "HealthKit authorization failed",
                                  details: error.localizedDescription))
                return
            }

            if !success {
                result(FlutterError(code: "AUTH_DENIED",
                                  message: "HealthKit authorization denied",
                                  details: nil))
                return
            }

            let predicate = HKQuery.predicateForObject(with: workoutUUID)
            let query = HKSampleQuery(
                sampleType: workoutType,
                predicate: predicate,
                limit: 1,
                sortDescriptors: nil
            ) { (query, samples, error) in
                if let error = error {
                    result(FlutterError(code: "QUERY_ERROR",
                                      message: "Failed to query workout",
                                      details: error.localizedDescription))
                    return
                }

                guard let workout = samples?.first as? HKWorkout else {
                    result(FlutterError(code: "NOT_FOUND",
                                      message: "Workout not found",
                                      details: nil))
                    return
                }

                let elapsedTimeSeconds = workout.endDate.timeIntervalSince(workout.startDate)
                let activeDurationSeconds = workout.duration
                let pausedDurationSeconds = elapsedTimeSeconds - activeDurationSeconds

                let details: [String: Any] = [
                    "activeDuration": Int(activeDurationSeconds * 1000),
                    "elapsedTime": Int(elapsedTimeSeconds * 1000),
                    "pausedDuration": Int(max(0, pausedDurationSeconds) * 1000),
                    "startDate": Int(workout.startDate.timeIntervalSince1970 * 1000),
                    "endDate": Int(workout.endDate.timeIntervalSince1970 * 1000)
                ]

                result(details)
            }

            self.healthStore.execute(query)
        }
    }
}

@main
@objc class AppDelegate: FlutterAppDelegate {
  private let healthKitBridge = HealthKitBridge()

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // Fetch the API key from the Info.plist
    if let googleMapsApiKey = Bundle.main.object(forInfoDictionaryKey: "GOOGLE_MAPS_API_KEY") as? String, !googleMapsApiKey.isEmpty && !googleMapsApiKey.contains("$") {
      GMSServices.provideAPIKey(googleMapsApiKey)
    } else {
      print("⚠️ Warning: Google Maps API Key not found or invalid in Info.plist. Maps may not load.")
    }

    // Setup Method Channel for HealthKit Bridge
    if let controller = window?.rootViewController as? FlutterViewController {
        let healthKitChannel = FlutterMethodChannel(
          name: "com.jared.pacelifter/healthkit",
          binaryMessenger: controller.binaryMessenger
        )

        healthKitChannel.setMethodCallHandler { [weak self] (call, result) in
          guard let self = self else { return }

          switch call.method {
          case "getWorkoutDuration":
            guard let args = call.arguments as? [String: Any],
                  let uuid = args["uuid"] as? String else {
              result(FlutterError(code: "INVALID_ARGS",
                                message: "Missing or invalid uuid argument",
                                details: nil))
              return
            }
            self.healthKitBridge.getWorkoutDuration(uuid: uuid, result: result)

          case "getWorkoutDetails":
            guard let args = call.arguments as? [String: Any],
                  let uuid = args["uuid"] as? String else {
              result(FlutterError(code: "INVALID_ARGS",
                                message: "Missing or invalid uuid argument",
                                details: nil))
              return
            }
            self.healthKitBridge.getWorkoutDetails(uuid: uuid, result: result)

          default:
            result(FlutterMethodNotImplemented)
          }
        }
    }

    GeneratedPluginRegistrant.register(with: self)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
