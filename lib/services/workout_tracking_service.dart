import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:health/health.dart';

/// 운동 추적 서비스
///
/// NRC/Strava 방식 벤치마킹:
/// - 1초마다 GPS 위치 업데이트
/// - 최근 N초 데이터로 실시간 속도 계산 (노이즈 제거)
/// - 운동 종료 시 HealthKit + 로컬 DB 저장
class WorkoutTrackingService extends ChangeNotifier {
  // 상태
  bool _isTracking = false;
  bool _isPaused = false;
  DateTime? _startTime;
  DateTime? _stopTime; // 운동 중지 시간 (HealthKit의 stop time)
  DateTime? _pausedTime;
  Duration _totalPausedDuration = Duration.zero;

  final List<Position> _route = [];
  double _totalDistance = 0; // 미터

  // 실시간 지표 계산용
  final List<_SpeedDataPoint> _recentSpeeds = [];
  final List<PaceDataPoint> _paceHistory = []; // 페이스 이력 저장
  int? _latestHeartRate;

  // 목표 설정
  double? _goalDistance; // 미터
  Duration? _goalTime;
  Pace? _goalPace;

  // 스트림
  final _workoutStateController = StreamController<WorkoutState>.broadcast();
  Stream<WorkoutState> get workoutStateStream => _workoutStateController.stream;

  // 서비스
  final Health _health = Health();
  StreamSubscription<Position>? _positionStream;
  Timer? _updateTimer;

  // 상수
  static const int _speedWindowSeconds = 10; // 속도 계산 윈도우
  static const double _minSpeedThreshold = 0.5; // 최소 속도 (m/s, ~1.8 km/h)

  // ==============================
  // 1. 운동 시작
  // ==============================

  Future<void> startWorkout() async {
    if (_isTracking) return;

    // 1.1 권한 확인
    bool locationGranted = await _checkLocationPermission();
    bool healthGranted = await _checkHealthPermission();

    if (!locationGranted) {
      throw Exception('위치 권한이 필요합니다');
    }
    if (!healthGranted) {
      throw Exception('건강 데이터 권한이 필요합니다');
    }

    // 1.2 상태 초기화
    _isTracking = true;
    _isPaused = false;
    _startTime = DateTime.now();
    _stopTime = null; // 아직 운동이 중지되지 않음
    _pausedTime = null;
    _totalPausedDuration = Duration.zero;
    _route.clear();
    _totalDistance = 0;
    _recentSpeeds.clear();
    _paceHistory.clear();
    _latestHeartRate = null;

    // 1.3 GPS 추적 시작
    _startGPSTracking();

    // 1.4 실시간 업데이트 타이머 (1초마다)
    _startUpdateTimer();

    // 1.5 백그라운드 추적 설정
    _enableBackgroundTracking();
  }

  // ==============================
  // 2. GPS 추적 시작
  // ==============================

  void _startGPSTracking() {
    // NRC/Strava 방식: accuracy.high + distanceFilter 5m
    const LocationSettings locationSettings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 5, // 5미터 이동 시 업데이트
    );

    _positionStream =
        Geolocator.getPositionStream(locationSettings: locationSettings).listen(
          _onLocationUpdate,
          onError: (error) {
            // GPS 오류 무시
          },
        );
  }

  // ==============================
  // 3. GPS 위치 업데이트
  // ==============================

  void _onLocationUpdate(Position position) {
    if (!_isTracking || _isPaused) return;

    // 3.1 경로에 추가
    _route.add(position);

    // 3.2 거리 계산 (이전 위치와의 거리)
    if (_route.length > 1) {
      double distance = Geolocator.distanceBetween(
        _route[_route.length - 2].latitude,
        _route[_route.length - 2].longitude,
        position.latitude,
        position.longitude,
      );

      // 노이즈 필터링: 비정상적으로 큰 거리는 무시
      if (distance < 100) {
        _totalDistance += distance;

        // 속도 계산 및 저장
        final timeDiff = position.timestamp.difference(
          _route[_route.length - 2].timestamp,
        );

        if (timeDiff.inSeconds > 0) {
          double speed = distance / timeDiff.inSeconds;
          _recentSpeeds.add(
            _SpeedDataPoint(timestamp: position.timestamp, speedMs: speed),
          );

          // 오래된 데이터 제거 (10초 이상)
          _recentSpeeds.removeWhere((point) {
            return position.timestamp.difference(point.timestamp).inSeconds >
                _speedWindowSeconds;
          });
        }
      }
    }
  }

  // ==============================
  // 4. 실시간 업데이트 타이머
  // ==============================

  void _startUpdateTimer() {
    // 1초마다 UI 업데이트
    _updateTimer = Timer.periodic(Duration(seconds: 1), (timer) {
      if (_isTracking && !_isPaused) {
        _updateWorkoutState();
      }
    });
  }

  // ==============================
  // 5. 실시간 지표 계산 및 업데이트
  // ==============================

  void _updateWorkoutState() {
    if (_startTime == null) return;

    final now = DateTime.now();
    final activeDuration = now.difference(_startTime!) - _totalPausedDuration;

    // 5.1 현재 속도 (최근 N초 평균)
    double currentSpeed = _calculateCurrentSpeed();

    // 5.2 평균 페이스
    String averagePace = _calculatePace(_totalDistance / 1000, activeDuration);

    // 5.3 현재 페이스 (실시간)
    String currentPace = currentSpeed > _minSpeedThreshold
        ? _calculatePace(currentSpeed * 3.6 / 1000, Duration(seconds: 1))
        : '--:--';

    // 5.4 칼로리 계산
    double calories = _calculateCalories(_totalDistance / 1000, activeDuration);

    // 5.5 페이스 이력 저장 (시각화용)
    if (currentSpeed >= _minSpeedThreshold) {
      // 속도(m/s)를 페이스(분/km)로 변환
      double paceMinPerKm = 1000 / (currentSpeed * 60);

      _paceHistory.add(PaceDataPoint(
        elapsedTime: activeDuration,
        paceMinPerKm: paceMinPerKm,
        speedMs: currentSpeed,
      ));
    }

    // 5.6 평균 심박수 (실시간 - 추후 구현)
    // TODO: HealthKit에서 실시간 심박수 가져오기

    // 5.7 UI 업데이트
    _workoutStateController.add(
      WorkoutState(
        isTracking: true,
        isPaused: _isPaused,
        duration: activeDuration,
        distanceMeters: _totalDistance,
        currentSpeedMs: currentSpeed,
        averagePace: averagePace,
        currentPace: currentPace,
        calories: calories,
        heartRate: _latestHeartRate,
        routePointsCount: _route.length,
      ),
    );
  }

  // ==============================
  // 6. 속도 계산 (최근 N초 평균)
  // ==============================

  double _calculateCurrentSpeed() {
    if (_recentSpeeds.isEmpty) return 0;

    // 최근 N초간 평균 속도 (노이즈 제거)
    double sum = 0;
    int count = 0;

    for (var point in _recentSpeeds) {
      // 비정상적으로 빠른 속도 제외 (> 10 m/s = 36 km/h)
      if (point.speedMs < 10) {
        sum += point.speedMs;
        count++;
      }
    }

    if (count == 0) return 0;
    return sum / count;
  }

  // ==============================
  // 7. 페이스 계산
  // ==============================

  String _calculatePace(double distanceKm, Duration duration) {
    if (distanceKm == 0) return '--:--';

    double minutesPerKm = duration.inSeconds / 60 / distanceKm;

    // 비정상적으로 느린 페이스 제외 (>20 min/km)
    if (minutesPerKm > 20) return '--:--';

    int minutes = minutesPerKm.floor();
    int seconds = ((minutesPerKm - minutes) * 60).round();

    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  // ==============================
  // 8. 칼로리 계산 (MET 기반)
  // ==============================

  double _calculateCalories(double distanceKm, Duration duration) {
    // 사용자 체중 (기본값 70kg, 추후 UserProfile에서 가져오기)
    double weightKg = 70;
    // TODO: UserProfile.instance.weight

    // 속도 (km/h)
    double hours = duration.inSeconds / 3600;
    if (hours == 0) return 0;
    double speedKmh = distanceKm / hours;

    // MET 값 (American College of Sports Medicine)
    double met;
    if (speedKmh < 6.4) {
      met = 6.0; // 조깅 (< 6.4 km/h)
    } else if (speedKmh < 8.0) {
      met = 8.3; // 러닝 (8 km/h)
    } else if (speedKmh < 9.7) {
      met = 9.8; // 러닝 (9.7 km/h)
    } else if (speedKmh < 11.3) {
      met = 11.0; // 러닝 (11.3 km/h)
    } else if (speedKmh < 12.9) {
      met = 11.8; // 러닝 (12.9 km/h)
    } else {
      met = 12.3; // 러닝 (> 12.9 km/h)
    }

    // 칼로리 = MET × 체중(kg) × 시간(hour)
    return met * weightKg * hours;
  }

  // ==============================
  // 9. 일시정지
  // ==============================

  void pauseWorkout() {
    if (!_isTracking || _isPaused) return;

    _isPaused = true;
    _pausedTime = DateTime.now();
    _positionStream?.pause();

    _updateWorkoutState();
  }

  // ==============================
  // 10. 재개
  // ==============================

  void resumeWorkout() {
    if (!_isTracking || !_isPaused || _pausedTime == null) return;

    final resumeTime = DateTime.now();
    _totalPausedDuration += resumeTime.difference(_pausedTime!);

    _isPaused = false;
    _pausedTime = null;
    _positionStream?.resume();

    _updateWorkoutState();
  }

  // ==============================
  // 11. 운동 종료
  // ==============================

  Future<WorkoutSummary> stopWorkout() async {
    if (!_isTracking) {
      throw Exception('운동 중이 아닙니다');
    }

    // 11.1 일시정지 상태면 재개 후 종료
    if (_isPaused) {
      resumeWorkout();
    }

    // 11.2 운동 중지 시간 기록 (HealthKit의 stopActivity 시점)
    _stopTime = DateTime.now();

    _isTracking = false;
    _positionStream?.cancel();
    _updateTimer?.cancel();

    // 11.3 최종 시간 계산
    // endTime: 사용자가 "완료"를 누른 시간 (HealthKit의 session.end)
    // stopTime: 사용자가 "중지"를 누른 시간 (HealthKit의 stopActivity)
    // activeDuration: 실제 운동 시간 (일시정지 제외)
    final endTime = DateTime.now();
    final activeDuration =
        _stopTime!.difference(_startTime!) - _totalPausedDuration;

    // 11.4 최종 요약 생성
    final summary = WorkoutSummary(
      startTime: _startTime!,
      endTime: endTime, // 완료 시간 (elapsed time)
      stopTime: _stopTime!, // 중지 시간 (workout time) - HealthKit 기준
      duration: activeDuration, // 실제 운동 시간 (일시정지 제외)
      totalDuration: endTime.difference(_startTime!),
      distanceMeters: _totalDistance,
      averagePace: _calculatePace(_totalDistance / 1000, activeDuration),
      calories: _calculateCalories(_totalDistance / 1000, activeDuration),
      routePoints: List.from(_route),
      averageHeartRate: _latestHeartRate,
      pausedDuration: _totalPausedDuration,
      paceData: List.from(_paceHistory),
    );

    // 11.3 HealthKit에 저장
    await _saveToHealthKit(summary);

    // 11.4 로컬 DB에 저장 (추후 구현)
    // TODO: Hive에 저장

    return summary;
  }

  // ==============================
  // 12. HealthKit에 저장
  // ==============================

  Future<void> _saveToHealthKit(WorkoutSummary summary) async {
    try {
      // 12.1 HKWorkout 저장
      // HealthKit의 stopActivity 시점(stopTime)을 종료 시간으로 사용
      // 이렇게 해야 HealthKit이 자동으로 계산하는 평균 페이스가 정확함
      bool workoutSaved = await _health.writeWorkoutData(
        activityType: HealthWorkoutActivityType.RUNNING,
        start: summary.startTime,
        end: summary.stopTime, // stopTime 사용 (endTime 아님)
        totalDistance: summary.distanceMeters.toInt(),
        totalEnergyBurned: summary.calories.toInt(),
      );

      if (!workoutSaved) {
        return;
      }

      // 12.2 거리 샘플 저장
      await _health.writeHealthData(
        value: summary.distanceMeters,
        type: HealthDataType.DISTANCE_WALKING_RUNNING,
        startTime: summary.startTime,
        endTime: summary.stopTime, // stopTime 사용
      );

      // 12.3 칼로리 샘플 저장
      await _health.writeHealthData(
        value: summary.calories,
        type: HealthDataType.ACTIVE_ENERGY_BURNED,
        startTime: summary.startTime,
        endTime: summary.stopTime, // stopTime 사용
      );

      // 12.4 걸음 수 저장 (추정)
      // 평균 보폭 0.8m 가정
      int estimatedSteps = (summary.distanceMeters / 0.8).round();
      await _health.writeHealthData(
        value: estimatedSteps.toDouble(),
        type: HealthDataType.STEPS,
        startTime: summary.startTime,
        endTime: summary.stopTime, // stopTime 사용
      );

    } catch (e) {
      // HealthKit 저장 오류 무시
    }
  }

  // ==============================
  // 13. 백그라운드 추적
  // ==============================

  void _enableBackgroundTracking() {
    // iOS: Background Modes - Location updates 필요
    // TODO: workmanager 패키지 사용 (추후 구현)
  }

  // ==============================
  // 14. 권한 확인
  // ==============================

  Future<bool> _checkLocationPermission() async {
    LocationPermission permission = await Geolocator.checkPermission();

    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.deniedForever) {
      return false;
    }

    return permission == LocationPermission.whileInUse ||
        permission == LocationPermission.always;
  }

  Future<bool> _checkHealthPermission() async {
    // HealthService의 권한 요청 사용
    try {
      bool granted = await _health.requestAuthorization(
        [
          HealthDataType.WORKOUT,
          HealthDataType.DISTANCE_WALKING_RUNNING,
          HealthDataType.ACTIVE_ENERGY_BURNED,
          HealthDataType.HEART_RATE,
          HealthDataType.STEPS,
        ],
        permissions: [
          HealthDataAccess.READ_WRITE,
          HealthDataAccess.READ_WRITE,
          HealthDataAccess.READ_WRITE,
          HealthDataAccess.READ_WRITE,
          HealthDataAccess.READ_WRITE,
        ],
      );
      return granted;
    } catch (e) {
      return false;
    }
  }

  // ==============================
  // 15. 유틸리티
  // ==============================


  // ==============================
  // 16. 정리
  // ==============================

  @override
  void dispose() {
    _positionStream?.cancel();
    _updateTimer?.cancel();
    _workoutStateController.close();
    super.dispose();
  }

  // Getters
  bool get isTracking => _isTracking;
  bool get isPaused => _isPaused;
  double get totalDistance => _totalDistance;
  int get routePointsCount => _route.length;
  double? get goalDistance => _goalDistance;
  Duration? get goalTime => _goalTime;
  Pace? get goalPace => _goalPace;

  // 목표 설정 메서드 (부분 업데이트)
  void setGoals({double? distance, Duration? time, Pace? pace}) {
    if (distance != null) _goalDistance = distance;
    if (time != null) _goalTime = time;
    if (pace != null) _goalPace = pace;
    notifyListeners();
  }

  // 목표 초기화
  void resetGoals() {
    _goalDistance = null;
    _goalTime = null;
    _goalPace = null;
    notifyListeners();
  }
}

// ==============================
// Data Models
// ==============================

/// 실시간 운동 상태
class WorkoutState {
  final bool isTracking;
  final bool isPaused;
  final Duration duration;
  final double distanceMeters;
  final double currentSpeedMs;
  final String averagePace;
  final String currentPace;
  final double calories;
  final int? heartRate;
  final int routePointsCount;

  WorkoutState({
    required this.isTracking,
    required this.isPaused,
    required this.duration,
    required this.distanceMeters,
    required this.currentSpeedMs,
    required this.averagePace,
    required this.currentPace,
    required this.calories,
    this.heartRate,
    required this.routePointsCount,
  });

  String get distanceKm => (distanceMeters / 1000).toStringAsFixed(2);

  String get distanceKmFormatted => '$distanceKm km';

  String get currentSpeedKmh => (currentSpeedMs * 3.6).toStringAsFixed(1);

  String get durationFormatted {
    int hours = duration.inHours;
    int minutes = duration.inMinutes.remainder(60);
    int seconds = duration.inSeconds.remainder(60);
    return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  String get caloriesFormatted => calories.toStringAsFixed(0);
}

/// 운동 완료 요약
class WorkoutSummary {
  final DateTime startTime;
  final DateTime endTime; // 완료 시간 (HealthKit의 session.end)
  final DateTime stopTime; // 중지 시간 (HealthKit의 stopActivity) - 페이스 계산 기준
  final Duration duration; // 실제 운동 시간 (일시정지 제외)
  final Duration totalDuration; // 전체 시간 (일시정지 포함)
  final double distanceMeters;
  final String averagePace;
  final double calories;
  final List<Position> routePoints;
  final int? averageHeartRate;
  final Duration pausedDuration;
  final List<PaceDataPoint> paceData; // 페이스 시각화용 데이터

  WorkoutSummary({
    required this.startTime,
    required this.endTime,
    required this.stopTime,
    required this.duration,
    required this.totalDuration,
    required this.distanceMeters,
    required this.averagePace,
    required this.calories,
    required this.routePoints,
    this.averageHeartRate,
    required this.pausedDuration,
    required this.paceData,
  });

  String get distanceKm => (distanceMeters / 1000).toStringAsFixed(2);

  String get durationFormatted {
    int hours = duration.inHours;
    int minutes = duration.inMinutes.remainder(60);
    int seconds = duration.inSeconds.remainder(60);

    if (hours > 0) {
      return '${hours}h ${minutes}m ${seconds}s';
    } else {
      return '${minutes}m ${seconds}s';
    }
  }
}

/// 속도 데이터 포인트 (내부 사용)
class _SpeedDataPoint {
  final DateTime timestamp;
  final double speedMs;

  _SpeedDataPoint({required this.timestamp, required this.speedMs});
}

/// 페이스 데이터 포인트 (시각화용)
class PaceDataPoint {
  final Duration elapsedTime; // 운동 시작 후 경과 시간 (일시정지 제외)
  final double paceMinPerKm; // 페이스 (분/km)
  final double speedMs; // 속도 (m/s)

  PaceDataPoint({
    required this.elapsedTime,
    required this.paceMinPerKm,
    required this.speedMs,
  });
}

/// 페이스 목표 (분:초 형식)
class Pace {
  final int minutes;
  final int seconds;

  Pace({required this.minutes, required this.seconds});

  @override
  String toString() {
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }
}
