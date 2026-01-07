import 'package:flutter/foundation.dart';
import 'package:health/health.dart';
import 'package:shared_preferences/shared_preferences.dart';

class HealthService {
  final Health health = Health();

  // 읽기 권한 데이터 타입 (P0 - MVP 필수)
  static final readTypes = [
    // 프로필 정보
    HealthDataType.WEIGHT,
    HealthDataType.HEIGHT,

    // 러닝 기본 데이터
    HealthDataType.DISTANCE_WALKING_RUNNING,
    HealthDataType.STEPS,
    HealthDataType.ACTIVE_ENERGY_BURNED,

    // 심박수 & 운동
    HealthDataType.HEART_RATE,
    HealthDataType.WORKOUT,

    // 고급 지표 (선택적)
    HealthDataType.RESTING_HEART_RATE,
    HealthDataType.HEART_RATE_VARIABILITY_SDNN,
  ];

  // 쓰기 권한 데이터 타입 (P0 - MVP 필수)
  static final writeTypes = [
    HealthDataType.DISTANCE_WALKING_RUNNING,
    HealthDataType.STEPS,
    HealthDataType.ACTIVE_ENERGY_BURNED,
    HealthDataType.HEART_RATE,
    HealthDataType.WORKOUT,
  ];

  // 모든 타입 (읽기 + 쓰기)
  static final allTypes = {...readTypes, ...writeTypes}.toList();

  /// 건강 데이터 접근 권한 요청 (읽기 + 쓰기)
  Future<bool> requestAuthorization() async {
    try {
      // 읽기 + 쓰기 권한 모두 요청
      List<HealthDataAccess> permissions = allTypes.map((type) {
        // 쓰기 가능한 타입은 READ_WRITE, 나머지는 READ
        if (writeTypes.contains(type)) {
          return HealthDataAccess.READ_WRITE;
        }
        return HealthDataAccess.READ;
      }).toList();

      bool? hasPermissions = await health.hasPermissions(
        allTypes,
        permissions: permissions,
      );

      if (hasPermissions != true) {
        bool requested = await health.requestAuthorization(
          allTypes,
          permissions: permissions,
        ).timeout(
          const Duration(seconds: 30),
          onTimeout: () {
            debugPrint('⚠️ [HealthService] Authorization request timed out');
            return false;
          },
        );
        return requested;
      }
      return true;
    } catch (e) {
      debugPrint('❌ [HealthService] Authorization Error: $e');
      return false;
    }
  }

  Future<List<HealthDataPoint>> getHealthDataFromTypes(
    DateTime startTime,
    DateTime endTime,
    List<HealthDataType> types,
  ) async {
    try {
      // 여러 타입을 동시에 요청 (속도 개선)
      List<HealthDataPoint> healthData = await health.getHealthDataFromTypes(
        types: types,
        startTime: startTime,
        endTime: endTime,
      ).timeout(
        const Duration(seconds: 15),
        onTimeout: () {
          debugPrint('⚠️ [HealthService] Data fetch timed out for $types');
          return [];
        },
      );
      return health.removeDuplicates(healthData);
    } catch (e) {
      debugPrint('❌ [HealthService] Error fetching $types: $e');
      return [];
    }
  }

  static const String _lastSyncKey = 'last_health_sync_time';

  Future<DateTime?> getLastSyncTime() async {
    final prefs = await SharedPreferences.getInstance();
    final lastSyncStr = prefs.getString(_lastSyncKey);
    return lastSyncStr != null ? DateTime.parse(lastSyncStr) : null;
  }

  Future<void> setLastSyncTime(DateTime time) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_lastSyncKey, time.toIso8601String());
  }

  /// 마지막 동기화 시간 기반 증분 업데이트 지원
  Future<List<HealthDataPoint>> fetchWorkoutData({int days = 30, DateTime? lastSyncTime}) async {
    final now = DateTime.now();
    // 마지막 동기화 시간이 지정되지 않았다면 저장된 시간 확인
    final effectiveLastSync = lastSyncTime ?? await getLastSyncTime();
    final startDate = effectiveLastSync ?? now.subtract(Duration(days: days));

    bool granted = await requestAuthorization();
    if (granted) {
      try {
        debugPrint('🔄 [HealthService] Fetching workouts from $startDate to $now');
        List<HealthDataPoint> healthData = await health.getHealthDataFromTypes(
          types: [HealthDataType.WORKOUT],
          startTime: startDate,
          endTime: now,
        ).timeout(
          const Duration(seconds: 20),
          onTimeout: () {
            debugPrint('⚠️ [HealthService] Workout data fetch timed out');
            return [];
          },
        );

        return health.removeDuplicates(healthData);
      } catch (e) {
        debugPrint('❌ Error fetching workout data: $e');
        return [];
      }
    } else {
      return [];
    }
  }

  /// 수동으로 HealthDataPoint 생성 (캘린더 등에서 사용)
  /// Note: HealthPlatform enum visibility issues prevent direct instantiation.
  /// This method is deprecated and should not be used until resolved.
  static HealthDataPoint? createWorkoutDataPoint({
    required String uuid,
    required DateTime start,
    required DateTime end,
    required int distance,
    required int calories,
    required String category, // 'Strength', 'Endurance', 'Hybrid'
  }) {
    return null;
  }
}

