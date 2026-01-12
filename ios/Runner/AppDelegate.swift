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
                
                var details: [String: Any] = [
                    "activeDuration": Int(activeDurationSeconds * 1000),
                    "elapsedTime": Int(elapsedTimeSeconds * 1000),
                    "pausedDuration": Int(max(0, pausedDurationSeconds) * 1000),
                    "startDate": Int(workout.startDate.timeIntervalSince1970 * 1000),
                    "endDate": Int(workout.endDate.timeIntervalSince1970 * 1000)
                ]

                // NRC 및 Apple 워크아웃의 추가 지표 안전하게 추출
                if #available(iOS 13.0, *) {
                    // 1. 평균 케이던스 (SPM)
                    // "HKAverageCadence"는 NRC 등에서 사용하는 일반적인 메타데이터 키입니다.
                    if let cadence = workout.metadata?["HKAverageCadence"] as? HKQuantity {
                        let spmUnit = HKUnit.count().unitDivided(by: HKUnit.minute())
                        details["averageCadence"] = cadence.doubleValue(for: spmUnit)
                    }
                    
                    // 2. 고도 상승 (Elevation Gain)
                    // HKMetadataKeyWorkoutElevationGain의 실제 값은 "HKElevationGain"입니다.
                    // 상수를 찾지 못하는 경우를 대비해 직접 문자열 키를 사용합니다.
                    if let elevation = workout.metadata?["HKElevationGain"] as? HKQuantity {
                        details["elevationGain"] = elevation.doubleValue(for: HKUnit.meter())
                    }
                }

                result(details)
            }

            self.healthStore.execute(query)
        }
    }

    /// Get GPS route points for a workout by UUID
    func getWorkoutRoute(uuid: String, result: @escaping FlutterResult) {
        guard let workoutUUID = UUID(uuidString: uuid) else {
            result(FlutterError(code: "INVALID_UUID", message: "Invalid UUID format", details: nil))
            return
        }

        // 1. Get the workout object
        let workoutType = HKObjectType.workoutType()
        let predicate = HKQuery.predicateForObject(with: workoutUUID)
        
        let query = HKSampleQuery(sampleType: workoutType, predicate: predicate, limit: 1, sortDescriptors: nil) { [weak self] (query, samples, error) in
            guard let self = self, let workout = samples?.first as? HKWorkout else {
                result(nil) // No workout found
                return
            }

            // 2. Find route data linked to this workout
            let routeType = HKSeriesType.workoutRoute()
            let routePredicate = HKQuery.predicateForObjects(from: workout)
            
            let routeQuery = HKSampleQuery(sampleType: routeType, predicate: routePredicate, limit: 1, sortDescriptors: nil) { (q, routeSamples, err) in
                guard let route = routeSamples?.first as? HKWorkoutRoute else {
                    result(nil) // No route found for this workout
                    return
                }

                // 3. Query the location data from the route
                var locations: [[String: Any]] = []
                let locationQuery = HKWorkoutRouteQuery(route: route) { (query, newLocations, done, error) in
                    if let newLocations = newLocations {
                        for loc in newLocations {
                            locations.append([
                                "latitude": loc.coordinate.latitude,
                                "longitude": loc.coordinate.longitude,
                                "altitude": loc.altitude,
                                "timestamp": Int(loc.timestamp.timeIntervalSince1970 * 1000)
                            ])
                        }
                    }

                    if done {
                        result(locations)
                    }
                }
                self.healthStore.execute(locationQuery)
            }
            self.healthStore.execute(routeQuery)
        }
        self.healthStore.execute(query)
    }
}

@main
@objc class AppDelegate: FlutterAppDelegate {
  private lazy var healthKitBridge = HealthKitBridge()

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // 1. PLAB v3 (Engine-First) - 즉시 제어권 반환
    NSLog("🚀 [BOOT] [PLAB v3] application(_:didFinishLaunchingWithOptions:) started")
    let result = super.application(application, didFinishLaunchingWithOptions: launchOptions)
    
    // 2. 모든 초기화 작업을 다음 런루프로 미룸 (비동기)
    DispatchQueue.main.async { [weak self] in
        guard let self = self else { return }
        self.performTieredRegistration()
    }
    
    return result
  }

  private func performTieredRegistration() {
    NSLog("📍 [BOOT] Starting Tiered Registration...")

    // Stage 0: Infrastructure (No Delay)
    let stage0 = [
        ("SharedPreferencesPlugin", "shared_preferences_foundation"),
        ("PathProviderPlugin", "path_provider_foundation"),
        ("SqflitePlugin", "sqflite_darwin")
    ]
    for (name, mod) in stage0 {
        HealthKitBridge.registerPlugin(name: name, registry: self, module: mod)
    }
    NSLog("📍 [BOOT] Stage 0 Complete (Infrastructure)")

    // Stage 1: Core Features (Short Delay)
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
        guard let self = self else { return }
        let stage1 = [
            ("GeolocatorPlugin", "geolocator_apple"),
            ("HealthPlugin", "health"),
            ("PermissionHandlerPlugin", "permission_handler_apple"),
            ("WatchConnectivityPlugin", "watch_connectivity")
        ]
        for (name, mod) in stage1 {
            HealthKitBridge.registerPlugin(name: name, registry: self, module: mod)
        }
        self.setupMethodChannels()
        NSLog("📍 [BOOT] Stage 1 Complete (Core & Channels)")
    }

    // Stage 2: Essential Utilities (Deferred)
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
        guard let self = self else { return }
        let stage2 = [
            ("FPPDeviceInfoPlusPlugin", "device_info_plus"),
            ("FPPPackageInfoPlusPlugin", "package_info_plus"),
            ("FlutterAppGroupDirectoryPlugin", "flutter_app_group_directory"),
            ("PedometerPlugin", "pedometer"),
            ("FPPSensorsPlusPlugin", "sensors_plus"),
            ("WorkmanagerPlugin", "workmanager_apple")
        ]
        for (name, mod) in stage2 {
            HealthKitBridge.registerPlugin(name: name, registry: self, module: mod)
        }
        NSLog("📍 [BOOT] Stage 2 Complete (Essential Utilities)")
    }
  }

  private func setupMethodChannels() {
    guard let controller = window?.rootViewController as? FlutterViewController else {
        NSLog("⚠️ [BOOT] Missing rootViewController during channel setup")
        return
    }

    // Control Channel (On-Demand Activation)
    let controlChannel = FlutterMethodChannel(
      name: "com.jared.pacelifter/control",
      binaryMessenger: controller.binaryMessenger
    )
    
    controlChannel.setMethodCallHandler { [weak self] (call, result) in
      guard let self = self else { return }
      
      switch call.method {
      case "activateLiveActivities":
          NSLog("🚀 [ON-DEMAND] Activating LiveActivitiesPlugin")
          HealthKitBridge.registerPlugin(name: "LiveActivitiesPlugin", registry: self)
          result(true)
          
      case "activateGoogleMaps":
          NSLog("🚀 [ON-DEMAND] Activating GoogleMaps")
          if let apiKey = Bundle.main.object(forInfoDictionaryKey: "GOOGLE_MAPS_API_KEY") as? String, !apiKey.isEmpty {
              GMSServices.provideAPIKey(apiKey)
              HealthKitBridge.registerPlugin(name: "FLTGoogleMapsPlugin", registry: self, module: "google_maps_flutter_ios")
              NSLog("✅ [ON-DEMAND] Google Maps Activated Successfully")
              result(true)
          } else {
              result(FlutterError(code: "NO_API_KEY", message: "Google Maps API Key missing", details: nil))
          }

      case "activateMediaPicker":
          NSLog("🚀 [ON-DEMAND] Activating Media & Share Plugins")
          let mediaPlugins = [
              ("FilePickerPlugin", nil),
              ("FLTImageCropperPlugin", nil),
              ("ImageGallerySaverPlugin", nil),
              ("FLTImagePickerPlugin", nil),
              ("FPPSharePlusPlugin", "share_plus")
          ]
          for (name, mod) in mediaPlugins {
              HealthKitBridge.registerPlugin(name: name, registry: self, module: mod)
          }
          result(true)
          
      default:
          result(FlutterMethodNotImplemented)
      }
    }

    // HealthKit Channel
    let healthKitChannel = FlutterMethodChannel(
      name: "com.jared.pacelifter/healthkit",
      binaryMessenger: controller.binaryMessenger
    )
    
    healthKitChannel.setMethodCallHandler { [weak self] (call, result) in
      guard let self = self else { return }
      switch call.method {
      case "getWorkoutDuration":
        guard let args = call.arguments as? [String: Any], let uuid = args["uuid"] as? String else {
          result(FlutterError(code: "INVALID_ARGS", message: "Missing uuid", details: nil))
          return
        }
        self.healthKitBridge.getWorkoutDuration(uuid: uuid, result: result)
      case "getWorkoutDetails":
        guard let args = call.arguments as? [String: Any], let uuid = args["uuid"] as? String else {
          result(FlutterError(code: "INVALID_ARGS", message: "Missing uuid", details: nil))
          return
        }
        self.healthKitBridge.getWorkoutDetails(uuid: uuid, result: result)
      case "getWorkoutRoute":
        guard let args = call.arguments as? [String: Any], let uuid = args["uuid"] as? String else {
          result(FlutterError(code: "INVALID_ARGS", message: "Missing uuid", details: nil))
          return
        }
        self.healthKitBridge.getWorkoutRoute(uuid: uuid, result: result)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }
}