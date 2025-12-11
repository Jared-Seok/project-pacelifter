import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:health/health.dart';

/// 운동 목표 페이스
class Pace {
  final int minutes;
  final int seconds;

  Pace({required this.minutes, required this.seconds});

  @override
  String toString() {
    return "$minutes'${seconds.toString().padLeft(2, '0')}\"";
  }
}

/// 운동 추적 서비스
class WorkoutTrackingService with ChangeNotifier {
  // 상태
  bool _isTracking = false;
  bool _isPaused = false;
  DateTime? _startTime;
  DateTime? _pausedTime;
  Duration _totalPausedDuration = Duration.zero;

  final List<Position> _route = [];
  double _totalDistance = 0; // 미터

  // 실시간 지표 계산용
  final List<_SpeedDataPoint> _recentSpeeds = [];
  final List<PaceDataPoint> _paceHistory = []; // 페이스 이력 저장
  int? _latestHeartRate;

  // 목표
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

  // Getters
  bool get isTracking => _isTracking;
  bool get isPaused => _isPaused;
  double get totalDistance => _totalDistance;
  int get routePointsCount => _route.length;
  double? get goalDistance => _goalDistance;
  Duration? get goalTime => _goalTime;
  Pace? get goalPace => _goalPace;

  /// 목표 설정
  void setGoals({double? distance, Duration? time, Pace? pace}) {
    _goalDistance = distance;
    _goalTime = time;
    _goalPace = pace;
    notifyListeners();
  }

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

    print('✅ 운동 시작: $_startTime');
    notifyListeners(); // 상태 변경 알림
  }

  // ==============================
  // 2. GPS 추적 시작
  // ==============================

  void _startGPSTracking() {
    const LocationSettings locationSettings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 5, // 5미터 이동 시 업데이트
    );

    _positionStream = Geolocator.getPositionStream(locationSettings: locationSettings).listen(
      _onLocationUpdate,
      onError: (error) {
        print('❌ GPS 오류: $error');
      },
    );
  }

  // ==============================
  // 3. GPS 위치 업데이트
  // ==============================

  void _onLocationUpdate(Position position) {
    if (!_isTracking || _isPaused) return;

    _route.add(position);

    if (_route.length > 1) {
      double distance = Geolocator.distanceBetween(
        _route[_route.length - 2].latitude,
        _route[_route.length - 2].longitude,
        position.latitude,
        position.longitude,
      );

      if (distance < 100) {
        _totalDistance += distance;

        final timeDiff = position.timestamp.difference(
          _route[_route.length - 2].timestamp,
        );

        if (timeDiff.inSeconds > 0) {
          double speed = distance / timeDiff.inSeconds;
          _recentSpeeds.add(
            _SpeedDataPoint(timestamp: position.timestamp, speedMs: speed),
          );

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
    _updateTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
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
    double currentSpeed = _calculateCurrentSpeed();
    String averagePace = _calculatePaceString(_totalDistance / 1000, activeDuration);
    String currentPace = currentSpeed > _minSpeedThreshold
        ? _calculatePaceString(currentSpeed * 3.6 / 1000, const Duration(seconds: 1))
        : '--:--';
    double calories = _calculateCalories(_totalDistance / 1000, activeDuration);

    if (currentSpeed >= _minSpeedThreshold) {
      double paceMinPerKm = 1000 / (currentSpeed * 60);
      _paceHistory.add(PaceDataPoint(
        elapsedTime: activeDuration,
        paceMinPerKm: paceMinPerKm,
        speedMs: currentSpeed,
      ));
    }

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
    notifyListeners();
  }

  // ==============================
  // 6. 속도 계산 (최근 N초 평균)
  // ==============================

  double _calculateCurrentSpeed() {
    if (_recentSpeeds.isEmpty) return 0;

    double sum = 0;
    int count = 0;
    for (var point in _recentSpeeds) {
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

  String _calculatePaceString(double distanceKm, Duration duration) {
    if (distanceKm == 0) return '--:--';
    double minutesPerKm = duration.inSeconds / 60 / distanceKm;
    if (minutesPerKm > 20) return '--:--';
    int minutes = minutesPerKm.floor();
    int seconds = ((minutesPerKm - minutes) * 60).round();
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  // ==============================
  // 8. 칼로리 계산 (MET 기반)
  // ==============================

  double _calculateCalories(double distanceKm, Duration duration) {
    double weightKg = 70;
    double hours = duration.inSeconds / 3600;
    if (hours == 0) return 0;
    double speedKmh = distanceKm / hours;

    double met;
    if (speedKmh < 6.4) met = 6.0;
    else if (speedKmh < 8.0) met = 8.3;
    else if (speedKmh < 9.7) met = 9.8;
    else if (speedKmh < 11.3) met = 11.0;
    else if (speedKmh < 12.9) met = 11.8;
    else met = 12.3;

    return met * weightKg * hours;
  }

  // ==============================
  // 9. 일시정지 & 10. 재개
  // ==============================

  void pauseWorkout() {
    if (!_isTracking || _isPaused) return;
    _isPaused = true;
    _pausedTime = DateTime.now();
    _positionStream?.pause();
    print('⏸️  운동 일시정지: $_pausedTime');
    _updateWorkoutState();
    notifyListeners();
  }

  void resumeWorkout() {
    if (!_isTracking || !_isPaused || _pausedTime == null) return;
    final resumeTime = DateTime.now();
    _totalPausedDuration += resumeTime.difference(_pausedTime!);
    _isPaused = false;
    _pausedTime = null;
    _positionStream?.resume();
    print('▶️  운동 재개: $resumeTime (총 일시정지 시간: $_totalPausedDuration)');
    _updateWorkoutState();
    notifyListeners();
  }

  // ==============================
  // 11. 운동 종료
  // ==============================

  Future<WorkoutSummary> stopWorkout() async {
    if (!_isTracking) throw Exception('운동 중이 아닙니다');
    if (_isPaused) resumeWorkout();

    _isTracking = false;
    _positionStream?.cancel();
    _updateTimer?.cancel();

    final endTime = DateTime.now();
    final activeDuration = endTime.difference(_startTime!) - _totalPausedDuration;

    final summary = WorkoutSummary(
      startTime: _startTime!,
      endTime: endTime,
      duration: activeDuration,
      totalDuration: endTime.difference(_startTime!),
      distanceMeters: _totalDistance,
      averagePace: _calculatePaceString(_totalDistance / 1000, activeDuration),
      calories: _calculateCalories(_totalDistance / 1000, activeDuration),
      routePoints: List.from(_route),
      averageHeartRate: _latestHeartRate,
      pausedDuration: _totalPausedDuration,
      paceData: List.from(_paceHistory),
    );

    await _saveToHealthKit(summary);

    print('✅ 운동 종료: $endTime');
    print('📊 거리: ${(_totalDistance / 1000).toStringAsFixed(2)} km');
    print('⏱️  시간: ${_formatDuration(activeDuration)}');
    print('🔥 칼로리: ${summary.calories.toStringAsFixed(0)} kcal');

    notifyListeners();
    return summary;
  }

  // ==============================
  // 12. HealthKit에 저장
  // ==============================

  Future<void> _saveToHealthKit(WorkoutSummary summary) async {
    try {
      bool workoutSaved = await _health.writeWorkoutData(
        activityType: HealthWorkoutActivityType.RUNNING,
        start: summary.startTime,
        end: summary.endTime,
        totalDistance: summary.distanceMeters.toInt(),
        totalEnergyBurned: summary.calories.toInt(),
      );
      if (!workoutSaved) {
        print('❌ HealthKit Workout 저장 실패');
        return;
      }
      await _health.writeHealthData(value: summary.distanceMeters, type: HealthDataType.DISTANCE_WALKING_RUNNING, startTime: summary.startTime, endTime: summary.endTime);
      await _health.writeHealthData(value: summary.calories, type: HealthDataType.ACTIVE_ENERGY_BURNED, startTime: summary.startTime, endTime: summary.endTime);
      int estimatedSteps = (summary.distanceMeters / 0.8).round();
      await _health.writeHealthData(value: estimatedSteps.toDouble(), type: HealthDataType.STEPS, startTime: summary.startTime, endTime: summary.endTime);
      print('✅ HealthKit 저장 완료');
    } catch (e) {
      print('❌ HealthKit 저장 오류: $e');
    }
  }

  // ==============================
  // 13. 백그라운드 추적
  // ==============================

  void _enableBackgroundTracking() {
    print('⚙️  백그라운드 추적 활성화');
  }

  // ==============================
  // 14. 권한 확인
  // ==============================

  Future<bool> _checkLocationPermission() async {
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.deniedForever) return false;
    return permission == LocationPermission.whileInUse || permission == LocationPermission.always;
  }

  Future<bool> _checkHealthPermission() async {
    try {
      return await _health.requestAuthorization([
        HealthDataType.WORKOUT,
        HealthDataType.DISTANCE_WALKING_RUNNING,
        HealthDataType.ACTIVE_ENERGY_BURNED,
        HealthDataType.HEART_RATE,
        HealthDataType.STEPS,
      ], permissions: [
        HealthDataAccess.READ_WRITE,
        HealthDataAccess.READ_WRITE,
        HealthDataAccess.READ_WRITE,
        HealthDataAccess.READ_WRITE,
        HealthDataAccess.READ_WRITE,
      ]);
    } catch (e) {
      print('❌ HealthKit 권한 요청 실패: $e');
      return false;
    }
  }

  // ==============================
  // 15. 유틸리티
  // ==============================

  String _formatDuration(Duration duration) {
    int hours = duration.inHours;
    int minutes = duration.inMinutes.remainder(60);
    int seconds = duration.inSeconds.remainder(60);
    if (hours > 0) return '${hours}h ${minutes}m ${seconds}s';
    return '${minutes}m ${seconds}s';
  }

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
}

// ==============================
// Data Models
// ==============================

class WorkoutState {
  final bool isTracking, isPaused;
  final Duration duration;
  final double distanceMeters, currentSpeedMs, calories;
  final String averagePace, currentPace;
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
    int h = duration.inHours;
    int m = duration.inMinutes.remainder(60);
    int s = duration.inSeconds.remainder(60);
    return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }
  String get caloriesFormatted => calories.toStringAsFixed(0);
}

class WorkoutSummary {
  final DateTime startTime, endTime;
  final Duration duration, totalDuration, pausedDuration;
  final double distanceMeters, calories;
  final String averagePace;
  final List<Position> routePoints;
  final int? averageHeartRate;
  final List<PaceDataPoint> paceData;

  WorkoutSummary({
    required this.startTime,
    required this.endTime,
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
    int h = duration.inHours;
    int m = duration.inMinutes.remainder(60);
    int s = duration.inSeconds.remainder(60);
    if (h > 0) return '${h}h ${m}m ${s}s';
    return '${m}m ${s}s';
  }
}

class _SpeedDataPoint {
  final DateTime timestamp;
  final double speedMs;
  _SpeedDataPoint({required this.timestamp, required this.speedMs});
}

class PaceDataPoint {
  final Duration elapsedTime;
  final double paceMinPerKm, speedMs;
  PaceDataPoint({required this.elapsedTime, required this.paceMinPerKm, required this.speedMs});
}