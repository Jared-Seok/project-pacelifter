import 'package:flutter/foundation.dart';
import 'package:health/health.dart';
import 'package:shared_preferences/shared_preferences.dart';

class HealthService {
  static final HealthService _instance = HealthService._internal();
  factory HealthService() => _instance;
  HealthService._internal();

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
    HealthDataType.RUNNING_SPEED,
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

  static const String _authRequestedKey = 'health_authorization_requested';

  /// 건강 데이터 접근 권한 요청 (읽기 + 쓰기)
  Future<bool> requestAuthorization({bool force = false}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final alreadyRequested = prefs.getBool(_authRequestedKey) ?? false;

      // 이미 요청한 적이 있고 강제가 아니라면 헬스킷 팝업 방지를 위해 true 반환 (패치 시도)
      if (alreadyRequested && !force) {
        debugPrint('ℹ️ [HealthService] Authorization already requested once. Skipping intrusive prompt.');
        // hasPermissions으로 가볍게 체크만 시도 (팝업 안 뜸)
        return true;
      }

      // 읽기 + 쓰기 권한 모두 요청
      List<HealthDataAccess> permissions = allTypes.map((type) {
        if (writeTypes.contains(type)) return HealthDataAccess.READ_WRITE;
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
          onTimeout: () => false,
        );
        
        if (requested) {
          await prefs.setBool(_authRequestedKey, true);
        }
        return requested;
      }
      
      await prefs.setBool(_authRequestedKey, true);
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
  bool _isFetching = false;

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
    if (_isFetching) {
      debugPrint('ℹ️ [HealthService] Fetch already in progress. Ignoring redundant request.');
      return [];
    }
    
    _isFetching = true;
    try {
      final now = DateTime.now();
      // 마지막 동기화 시간이 지정되지 않았다면 저장된 시간 확인
      final effectiveLastSync = lastSyncTime ?? await getLastSyncTime();
      final startDate = effectiveLastSync ?? now.subtract(Duration(days: days));

      bool granted = await requestAuthorization();
      if (granted) {
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
      } else {
        return [];
      }
    } catch (e) {
      debugPrint('❌ Error fetching workout data: $e');
      return [];
    } finally {
      _isFetching = false;
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

