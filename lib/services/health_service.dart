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
        );
        return requested;
      }
      return true;
    } catch (e) {
      print("권한 요청 실패: $e");
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
      );
      return health.removeDuplicates(healthData);
    } catch (e) {
      print("데이터 가져오기 실패: $e");
      return [];
    }
  }

  /// 운동 데이터 가져오기
  Future<List<HealthDataPoint>> fetchWorkoutData() async {
    final now = DateTime.now();
    // 가능한 모든 데이터를 가져오기 (10년 전까지)
    final startDate = now.subtract(const Duration(days: 365 * 10));

    bool granted = await requestAuthorization();
    if (granted) {
      try {
        // 지정된 기간 동안의 운동 데이터 요청
        List<HealthDataPoint> healthData = await health.getHealthDataFromTypes(
          types: [HealthDataType.WORKOUT],
          startTime: startDate,
          endTime: now,
        );

        // 중복 데이터 제거 (필요 시)
        healthData = health.removeDuplicates(healthData);

        return healthData;
      } catch (e) {
        print("운동 데이터 가져오기 실패: $e");
        return [];
      }
    } else {
      print("건강 데이터 접근 권한이 거부되었습니다.");
      return [];
    }
  }
}
