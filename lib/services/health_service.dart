import 'package:health/health.dart';

class HealthService {
  final Health health = Health();

  // 요청할 건강 데이터 유형 목록 (단순화를 위해 WORKOUT만 요청)
  static final types = [
    HealthDataType.WORKOUT,
    // HealthDataType.STEPS,
    // HealthDataType.HEART_RATE,
    // HealthDataType.WEIGHT,
    // HealthDataType.HEIGHT,
  ];

  // 읽기/쓰기 권한 정의 (여기서는 읽기만 사용)
  final permissions = types.map((e) => HealthDataAccess.READ).toList();

  /// 건강 데이터 접근 권한 요청
  Future<bool> requestAuthorization() async {
    // 요청 전, 권한이 이미 부여되었는지 확인
    bool? hasPermissions = await health.hasPermissions(types, permissions: permissions);
    if (hasPermissions == false) {
      // 권한이 없다면 사용자에게 요청
      bool requested = await health.requestAuthorization(types, permissions: permissions);
      return requested;
    }
    return true;
  }

  /// 운동 데이터 가져오기
  Future<List<HealthDataPoint>> fetchWorkoutData() async {
    final now = DateTime.now();
    // 1년 전 데이터까지만 가져오도록 설정
    final lastYear = now.subtract(const Duration(days: 365)); 

    bool granted = await requestAuthorization();
    if (granted) {
      try {
        // 지정된 기간 동안의 운동 데이터 요청
        List<HealthDataPoint> healthData = await health.getHealthDataFromTypes(
          types: [HealthDataType.WORKOUT],
          startTime: lastYear,
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
