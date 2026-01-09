import Flutter
import UIKit
import GoogleMaps
import HealthKit

/// Bridge to access additional HealthKit properties not exposed by the health package
class HealthKitBridge {
    private let healthStore = HKHealthStore()

    // Dynamic registrar to avoid header issues during diagnosis
    static func registerPlugin(name: String, registry: FlutterPluginRegistry, module: String? = nil) {
        NSLog("🧪 [AppDelegate] Attempting to dynamically register: \(name)")
        
        var potentialNames = [name]
        if let mod = module {
            potentialNames.insert("\(mod).\(name)", at: 0)
        }
        
        // Default potential module prefixes
        let defaultModules = [
            "path_provider_foundation", "shared_preferences_foundation", 
            "sqflite_darwin", "geolocator_apple", "health", 
            "live_activities", "google_maps_flutter_ios", "pedometer", 
            "workmanager_apple", "flutter_app_group_directory", "sensors_plus"
        ]
        
        for mod in defaultModules {
            potentialNames.append("\(mod).\(name)")
        }
        
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
                }
            }
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
    
    // 1. Google Maps Library 초기화
    if let googleMapsApiKey = Bundle.main.object(forInfoDictionaryKey: "GOOGLE_MAPS_API_KEY") as? String, !googleMapsApiKey.isEmpty && !googleMapsApiKey.contains("$") {
      GMSServices.provideAPIKey(googleMapsApiKey)
      NSLog("✅ [AppDelegate] Google Maps API Key provided")
    } else {
      NSLog("⚠️ [AppDelegate] Warning: Google Maps API Key not found or invalid in Info.plist")
    }

    // 2. PLAB (PaceLifter Advanced Boot) - 계층형 플러그인 등록
    // Stage 1: Immediate (Critical Infrastructure)
    let stage1 = [
        ("SharedPreferencesPlugin", "shared_preferences_foundation"),
        ("PathProviderPlugin", "path_provider_foundation"),
        ("SqflitePlugin", "sqflite_darwin")
    ]
    for (name, mod) in stage1 {
        HealthKitBridge.registerPlugin(name: name, registry: self, module: mod)
    }

    // Stage 2: Deferred (Features & Utilities) - 500ms 지연하여 Watchdog 회피
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
        guard let self = self else { return }
        let stage2 = [
            ("GeolocatorPlugin", "geolocator_apple"),
            ("FPPDeviceInfoPlusPlugin", "device_info_plus"),
            ("FPPPackageInfoPlusPlugin", "package_info_plus"),
            ("HealthPlugin", "health"),
            ("FlutterAppGroupDirectoryPlugin", "flutter_app_group_directory"),
            ("FilePickerPlugin", nil),
            ("FLTImageCropperPlugin", nil),
            ("ImageGallerySaverPlugin", nil),
            ("FLTImagePickerPlugin", nil),
            ("PedometerPlugin", "pedometer"),
            ("PermissionHandlerPlugin", "permission_handler_apple"),
            ("FPPSensorsPlusPlugin", "sensors_plus"),
            ("FPPSharePlusPlugin", "share_plus"),
            ("WorkmanagerPlugin", "workmanager_apple"),
            ("FLTGoogleMapsPlugin", "google_maps_flutter_ios")
        ]
        for (name, mod) in stage2 {
            HealthKitBridge.registerPlugin(name: name, registry: self, module: mod)
        }
        NSLog("✅ [AppDelegate] PLAB Stage 2 Registration Complete")
    }

    NSLog("ℹ️ [AppDelegate] PLAB Stage 1 Complete. Stage 2 Scheduled.")

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
