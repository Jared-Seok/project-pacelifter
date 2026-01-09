import Flutter
import UIKit
import GoogleMaps
import HealthKit

/// Bridge to access additional HealthKit properties not exposed by the health package
class HealthKitBridge {
    private let healthStore = HKHealthStore()

    // Dynamic registrar to avoid header issues during diagnosis
    static func registerPlugin(name: String, registry: FlutterPluginRegistry) {
        NSLog("🧪 [AppDelegate] Attempting to dynamically register: \(name)")
        
        // Try direct class name, then module-prefixed names for Swift plugins
        let potentialNames = [
            name,
            "path_provider_foundation.\(name)",
            "shared_preferences_foundation.\(name)",
            "sqflite_darwin.\(name)",
            "geolocator_apple.\(name)",
            "health.\(name)",
            "live_activities.\(name)"
        ]
        
        var foundClass: NSObject.Type? = nil
        for className in potentialNames {
            if let pluginClass = NSClassFromString(className) as? NSObject.Type {
                foundClass = pluginClass
                NSLog("✅ [AppDelegate] Found class: \(className)")
                break
            }
        }
        
        if let pluginClass = foundClass {
            if let registrar = registry.registrar(forPlugin: name) {
                let selector = NSSelectorFromString("registerWithRegistrar:")
                if pluginClass.responds(to: selector) {
                    pluginClass.perform(selector, with: registrar)
                    NSLog("✅ [AppDelegate] Successfully registered: \(name)")
                } else {
                    NSLog("⚠️ [AppDelegate] Class \(name) does not respond to registerWithRegistrar:")
                }
            }
        } else {
            NSLog("❌ [AppDelegate] Could not find class: \(name)")
        }
    }

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
    NSLog("🚀 [AppDelegate] application(_:didFinishLaunchingWithOptions:) started")
    
    // 1. Google Maps 초기화
    if let googleMapsApiKey = Bundle.main.object(forInfoDictionaryKey: "GOOGLE_MAPS_API_KEY") as? String, !googleMapsApiKey.isEmpty && !googleMapsApiKey.contains("$") {
      GMSServices.provideAPIKey(googleMapsApiKey)
      NSLog("✅ [AppDelegate] Google Maps API Key provided")
    } else {
      print("⚠️ Warning: Google Maps API Key not found or invalid in Info.plist. Maps may not load.")
    }

    // 2. 동적 플러그인 등록 (격리 진단용)
    // GeneratedPluginRegistrant.register(with: self)
    
    // 필수 인프라 및 기능 플러그인들 등록
    let safePlugins = [
        "SharedPreferencesPlugin",
        "PathProviderPlugin",
        "SqflitePlugin",
        "GeolocatorPlugin",
        "FPPDeviceInfoPlusPlugin",
        "FPPPackageInfoPlusPlugin",
        "FlutterAppGroupDirectoryPlugin",
        "HealthPlugin",
        "FilePickerPlugin",
        "FLTImageCropperPlugin",
        "ImageGallerySaverPlugin",
        "FLTImagePickerPlugin",
        "PedometerPlugin",
        "PermissionHandlerPlugin",
        "FPPSensorsPlusPlugin",
        "FPPSharePlusPlugin",
        "WorkmanagerPlugin"
    ]
    
    for plugin in safePlugins {
        HealthKitBridge.registerPlugin(name: plugin, registry: self)
    }

    // 🚩 LiveActivitiesPlugin은 여전히 제외합니다 (네이티브 행의 원인).
    NSLog("ℹ️ [AppDelegate] All safe plugins registered. LiveActivities still excluded.")

    // 3. Method Channel 설정 (엔진 구동 확인 후)
    if let controller = window?.rootViewController as? FlutterViewController {
        NSLog("🚀 [AppDelegate] Setting up HealthKit Method Channel")
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
              result(FlutterError(code: "INVALID_ARGS", message: "Missing uuid", details: nil))
              return
            }
            self.healthKitBridge.getWorkoutDuration(uuid: uuid, result: result)
          case "getWorkoutDetails":
            guard let args = call.arguments as? [String: Any],
                  let uuid = args["uuid"] as? String else {
              result(FlutterError(code: "INVALID_ARGS", message: "Missing uuid", details: nil))
              return
            }
            self.healthKitBridge.getWorkoutDetails(uuid: uuid, result: result)
          default:
            result(FlutterMethodNotImplemented)
          }
        }

        // LiveActivities 제어를 위한 별도 채널
        let liveActivitiesChannel = FlutterMethodChannel(
          name: "com.jared.pacelifter/live_activities_control",
          binaryMessenger: controller.binaryMessenger
        )
        
        liveActivitiesChannel.setMethodCallHandler { [weak self] (call, result) in
          guard let self = self else { return }
          if call.method == "activateLiveActivities" {
             NSLog("🚀 [AppDelegate] On-demand registration for LiveActivitiesPlugin requested")
             HealthKitBridge.registerPlugin(name: "LiveActivitiesPlugin", registry: self)
             result(true)
          } else {
             result(FlutterMethodNotImplemented)
          }
        }
    }

    NSLog("🚀 [AppDelegate] Calling super.application()")
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
