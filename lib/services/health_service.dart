import 'package:flutter/foundation.dart';
import 'package:health/health.dart';

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
      List<HealthDataPoint> healthData = await health.getHealthDataFromTypes(
        types: types,
        startTime: startTime,
        endTime: endTime,
      ).timeout(
        const Duration(seconds: 10),
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

  /// 운동 데이터 가져오기
  Future<List<HealthDataPoint>> fetchWorkoutData({int days = 30}) async {
    final now = DateTime.now();
    // 지정된 일수 전부터 데이터를 가져오기 (기본 30일)
    // 대시보드에서는 최근 데이터만 필요하므로 범위를 좁혀 성능 개선
    final startDate = now.subtract(Duration(days: days));

    bool granted = await requestAuthorization();
    if (granted) {
      try {
        // 지정된 기간 동안의 운동 데이터 요청
        List<HealthDataPoint> healthData = await health.getHealthDataFromTypes(
          types: [HealthDataType.WORKOUT],
          startTime: startDate,
          endTime: now,
        ).timeout(
          const Duration(seconds: 15),
          onTimeout: () {
            debugPrint('⚠️ [HealthService] Workout data fetch timed out');
            return [];
          },
        );

        // 중복 데이터 제거
        healthData = health.removeDuplicates(healthData);

        return healthData;
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

