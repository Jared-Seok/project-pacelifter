import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:health/health.dart';
import '../models/sessions/route_point.dart';
import '../models/templates/workout_template.dart';
import '../models/templates/template_block.dart';
import 'heart_rate_service.dart';
import 'live_activity_service.dart';
import 'workout_history_service.dart';
import '../models/sessions/workout_session.dart';
import 'package:uuid/uuid.dart';
import 'watch_connectivity_service.dart';

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

  final List<RoutePoint> _route = [];
  double _totalDistance = 0; // 미터
  double _totalElevationGain = 0; // 누적 상승 고도 (미터)

  // 실시간 지표 계산용
  final List<_SpeedDataPoint> _recentSpeeds = [];
  final List<PaceDataPoint> _paceHistory = []; // 페이스 이력 저장
  int? _latestHeartRate;

  // 목표 설정
  double? _goalDistance; // 미터
  Duration? _goalTime;
  Pace? _goalPace;

  // 구조화된 운동 (템플릿) 상태
  bool _isStructured = false;
  WorkoutTemplate? _activeTemplate;
  String _activeTemplateName = "Running";
  List<TemplateBlock> _activeBlocks = [];
  int _currentBlockIndex = 0;
  double _blockDistanceAccumulator = 0; // 현재 블록 누적 거리
  Duration _blockDurationAccumulator = Duration.zero; // 현재 블록 누적 시간
  DateTime? _blockStartTime;
  Duration? _lastBlockDuration; // 이전 블록 소요 시간 (Lap Time)

  // 스트림
  final _workoutStateController = StreamController<WorkoutState>.broadcast();
  Stream<WorkoutState> get workoutStateStream => _workoutStateController.stream;

  // 서비스
  final Health _health = Health();
  StreamSubscription<Position>? _positionStream;
  StreamSubscription<double>? _heartRateSubscription;
  Timer? _updateTimer;

  // 상수
  static const int _speedWindowSeconds = 10; // 속도 계산 윈도우
  static const double _minSpeedThreshold = 0.5; // 최소 속도 (m/s, ~1.8 km/h)

  // ==============================
  // 1. 운동 시작
  // ==============================

  Future<void> startWorkout({WorkoutTemplate? template}) async {
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
    _stopTime = null;
    _pausedTime = null;
    _totalPausedDuration = Duration.zero;
    _route.clear();
    _totalDistance = 0;
    _totalElevationGain = 0;
    _recentSpeeds.clear();
    _paceHistory.clear();
    _latestHeartRate = null;

    // 구조화된 템플릿 설정
    if (template != null) {
      _isStructured = true;
      _activeTemplate = template;
      _activeTemplateName = template.name;
      _activeBlocks = template.phases.expand((p) => p.blocks).toList();
      _currentBlockIndex = 0;
      _blockDistanceAccumulator = 0;
      _blockDurationAccumulator = Duration.zero;
      _blockStartTime = DateTime.now();
      _lastBlockDuration = null;
    } else {
      _isStructured = false;
      _activeTemplate = null;
      _activeTemplateName = "Free Run";
      _activeBlocks = [];
      _currentBlockIndex = 0;
      _lastBlockDuration = null;
    }

    // Live Activity 강제 초기화 및 시작
    final laService = LiveActivityService();
    await laService.init(); // 초기화 보장
    await laService.startActivity(
      name: _activeTemplateName,
      distanceKm: "0.00",
      duration: "00:00:00",
      pace: "--:--",
      heartRate: null,
    );

    // 1.3 GPS 추적 시작
    _startGPSTracking();

    // 1.3.5 심박수 스트림 구독 (Watch 우선, 실패시 폰 센서)
    _heartRateSubscription?.cancel();
    
    // 1. Watch 연결 서비스로부터 심박수 수신
    final watchService = WatchConnectivityService();
    _heartRateSubscription = watchService.heartRateStream.map((bpm) => bpm.toDouble()).listen((bpm) {
      debugPrint('⌚ Heart rate from Watch: $bpm');
      _latestHeartRate = bpm.toInt();
    });

    // 2. Watch에게 운동 시작 명령 전송
    await watchService.startWatchWorkout(
      activityType: _isStructured && _activeTemplate?.category == 'Strength' ? 'Strength' : 'Running',
    );

    // 1.4 실시간 업데이트 타이머 (1초마다)
    _startUpdateTimer();
  }

  // ==============================
  // 2. GPS 추적 시작
  // ==============================

  void _startGPSTracking() {
    // NRC/Strava 방식: accuracy.high + distanceFilter 5m
    // 백그라운드에서도 OS에 의해 종료되지 않도록 플랫폼별 상세 설정 추가
    late final LocationSettings locationSettings;

    if (defaultTargetPlatform == TargetPlatform.android) {
      locationSettings = AndroidSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 5,
        forceLocationManager: true,
        intervalDuration: const Duration(seconds: 1),
        // 안드로이드 백그라운드 알림 설정 (필요 시)
        foregroundNotificationConfig: const ForegroundNotificationConfig(
          notificationText: "운동 경로를 기록 중입니다.",
          notificationTitle: "PaceLifter 실행 중",
          enableWakeLock: true,
        ),
      );
    } else if (defaultTargetPlatform == TargetPlatform.iOS ||
        defaultTargetPlatform == TargetPlatform.macOS) {
      locationSettings = AppleSettings(
        accuracy: LocationAccuracy.high,
        activityType: ActivityType.fitness,
        distanceFilter: 5,
        pauseLocationUpdatesAutomatically: false,
        // 백그라운드에서 실행되도록 허용
        showBackgroundLocationIndicator: true,
        allowBackgroundLocationUpdates: true,
      );
    } else {
      locationSettings = const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 5,
      );
    }

    _positionStream =
        Geolocator.getPositionStream(locationSettings: locationSettings).listen(
      _onLocationUpdate,
      onError: (error) {
        debugPrint('📍 GPS Error: $error');
      },
    );
  }

  // ==============================
  // 3. GPS 위치 업데이트
  // ==============================

  void _onLocationUpdate(Position position) {
    if (!_isTracking || _isPaused) return;

    // 3.1 거리 및 고도 계산 (이전 위치와의 차이)
    if (_route.isNotEmpty) {
      final lastPoint = _route.last;
      
      double distance = Geolocator.distanceBetween(
        lastPoint.latitude,
        lastPoint.longitude,
        position.latitude,
        position.longitude,
      );

      // 노이즈 필터링: 비정상적으로 큰 거리는 무시
      if (distance < 100) {
        _totalDistance += distance;
        
        if (_isStructured) {
          _blockDistanceAccumulator += distance;
        }

        // 고도 상승분 계산 (Elevation Gain)
        double elevationDiff = position.altitude - lastPoint.altitude;
        if (elevationDiff > 0) {
          _totalElevationGain += elevationDiff;
        }

        // 속도 계산 및 저장
        final timeDiff = position.timestamp.difference(lastPoint.timestamp);

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

    // 3.2 경로에 추가
    _route.add(RoutePoint(
      latitude: position.latitude,
      longitude: position.longitude,
      altitude: position.altitude,
      timestamp: position.timestamp,
      speed: position.speed,
      accuracy: position.accuracy,
    ));
  }

  // ==============================
  // 4. 실시간 업데이트 타이머
  // ==============================

  void _startUpdateTimer() {
    // 1초마다 UI 업데이트
    _updateTimer = Timer.periodic(Duration(seconds: 1), (timer) {
      if (_isTracking && !_isPaused) {
        _updateWorkoutState();
        if (_isStructured) {
          _checkBlockCompletion();
        }
      }
    });
  }

  // ==============================
  // 4.5 블록 진행 관리 (구조화된 운동)
  // ==============================

  void _checkBlockCompletion() {
    if (_activeBlocks.isEmpty || _currentBlockIndex >= _activeBlocks.length) return;

    final currentBlock = _activeBlocks[_currentBlockIndex];
    bool shouldAdvance = false;

    // 시간 업데이트
    if (_blockStartTime != null) {
      // 일시정지 고려: 단순히 시간 차이가 아니라, 실제 흐른 시간(activeDuration) 기반이어야 함.
      // 여기서는 간소화를 위해 Timer가 1초마다 돌 때마다 1초씩 더하는 방식 or _blockDurationAccumulator를 별도로 관리
      // _updateWorkoutState에서 계산된 값을 사용하면 좋음.
      
      // 임시: 타이머 주기로 1초씩 증가 (정확도를 위해 개선 필요)
      _blockDurationAccumulator += const Duration(seconds: 1);
    }

    // 목표 체크
    if (currentBlock.targetDistance != null && currentBlock.targetDistance! > 0) {
      if (_blockDistanceAccumulator >= currentBlock.targetDistance!) {
        shouldAdvance = true;
      }
    } else if (currentBlock.targetDuration != null && currentBlock.targetDuration! > 0) {
      if (_blockDurationAccumulator.inSeconds >= currentBlock.targetDuration!) {
        shouldAdvance = true;
      }
    }

    if (shouldAdvance) {
      advanceBlock();
    }
  }

  void advanceBlock() {
    if (_currentBlockIndex < _activeBlocks.length - 1) {
      // 현재 블록 종료 시간 기록
      _lastBlockDuration = _blockDurationAccumulator;
      
      _currentBlockIndex++;
      _blockDistanceAccumulator = 0;
      _blockDurationAccumulator = Duration.zero;
      _blockStartTime = DateTime.now();
      // TODO: Play sound/TTS for next block
    } else {
      // 마지막 블록 완료 -> 운동 종료? 아니면 쿨다운 계속?
      // 일단은 마지막 블록 상태 유지 (Free run처럼)
      // 또는 종료 알림
    }
    _updateWorkoutState();
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

    // 5.7 UI 업데이트
    final state = WorkoutState(
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
      elevationGain: _totalElevationGain,
      isStructured: _isStructured,
      currentBlockIndex: _currentBlockIndex,
      lastBlockDuration: _lastBlockDuration,
      currentBlockDuration: _blockDurationAccumulator,
    );

    _workoutStateController.add(state);

    // Live Activity 업데이트
    LiveActivityService().updateActivity(
      distanceKm: state.distanceKm,
      duration: state.durationFormatted,
      pace: state.currentPace,
      heartRate: state.heartRate,
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

  Future<WorkoutSummary> stopWorkout({int? avgHeartRate}) async {
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
    _heartRateSubscription?.cancel();
    _heartRateSubscription = null;
    _updateTimer?.cancel();

    // 11.3 최종 시간 계산
    final endTime = DateTime.now();
    final activeDuration =
        _stopTime!.difference(_startTime!) - _totalPausedDuration;

    // 11.3 최종 요약 생성
    final summary = WorkoutSummary(
      startTime: _startTime!,
      endTime: endTime, // 완료 시간 (elapsed time)
      stopTime: _stopTime!, // 중지 시간 (workout time) - HealthKit 기준
      duration: activeDuration, // 실제 운동 시간 (일시정지 제외)
      totalDuration: endTime.difference(_startTime!),
      distanceMeters: _totalDistance,
      elevationGain: _totalElevationGain,
      averagePace: _calculatePace(_totalDistance / 1000, activeDuration),
      calories: _calculateCalories(_totalDistance / 1000, activeDuration),
      routePoints: List.from(_route),
      averageHeartRate: avgHeartRate ?? _latestHeartRate,
      pausedDuration: _totalPausedDuration,
      paceData: List.from(_paceHistory),
    );

    // 11.3.5 로컬 DB 저장 (WorkoutHistoryService 활용)
    final workoutSession = WorkoutSession(
      id: const Uuid().v4(),
      templateId: _activeTemplate?.id ?? 'free_run',
      templateName: _activeTemplateName,
      category: _activeTemplate?.category ?? 'Endurance',
      startTime: _startTime!,
      endTime: endTime,
      activeDuration: activeDuration.inSeconds,
      totalDuration: endTime.difference(_startTime!).inSeconds,
      totalDistance: _totalDistance,
      calories: summary.calories,
      averageHeartRate: summary.averageHeartRate,
      elevationGain: _totalElevationGain,
      environmentType: _activeTemplate?.environmentType,
      exerciseRecords: [], // Endurance는 exerciseRecords가 비어있음
    );
    await WorkoutHistoryService().saveSession(workoutSession);

    // 11.4 HealthKit에 저장
    await _saveToHealthKit(summary);

    // Watch 운동 종료
    await WatchConnectivityService().stopWatchWorkout();

    // Live Activity 종료
    LiveActivityService().endActivity();

    return summary;
  }

  // ==============================
  // 12. HealthKit에 저장
  // ==============================

  Future<void> _saveToHealthKit(WorkoutSummary summary) async {
    try {
      // 12.1 HKWorkout 저장
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

  @override
  void dispose() {
    _positionStream?.cancel();
    _heartRateSubscription?.cancel();
    _updateTimer?.cancel();
    _workoutStateController.close();
    super.dispose();
  }

  // Getters
  bool get isTracking => _isTracking;
  bool get isPaused => _isPaused;
  double get totalDistance => _totalDistance;
  List<RoutePoint> get route => List.unmodifiable(_route);
  int get routePointsCount => _route.length;
  double? get goalDistance => _goalDistance;
  Duration? get goalTime => _goalTime;
  Pace? get goalPace => _goalPace;

  // 목표 설정 메서드
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
  final double elevationGain;
  
  // 구조화된 운동 상태
  final bool isStructured;
  final int currentBlockIndex;
  final Duration? lastBlockDuration;
  final Duration currentBlockDuration; // 현재 블록 경과 시간

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
    this.elevationGain = 0.0,
    this.isStructured = false,
    this.currentBlockIndex = 0,
    this.lastBlockDuration,
    this.currentBlockDuration = Duration.zero,
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
  final DateTime endTime;
  final DateTime stopTime;
  final Duration duration;
  final Duration totalDuration;
  final double distanceMeters;
  final double elevationGain;
  final String averagePace;
  final double calories;
  final List<RoutePoint> routePoints;
  final int? averageHeartRate;
  final Duration pausedDuration;
  final List<PaceDataPoint> paceData;

  WorkoutSummary({
    required this.startTime,
    required this.endTime,
    required this.stopTime,
    required this.duration,
    required this.totalDuration,
    required this.distanceMeters,
    required this.elevationGain,
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
    if (hours > 0) return '${hours}h ${minutes}m ${seconds}s';
    return '${minutes}m ${seconds}s';
  }
}

class _SpeedDataPoint {
  final DateTime timestamp;
  final double speedMs;
  _SpeedDataPoint({required this.timestamp, required this.speedMs});
}

class PaceDataPoint {
  final Duration elapsedTime;
  final double paceMinPerKm;
  final double speedMs;
  PaceDataPoint({
    required this.elapsedTime,
    required this.paceMinPerKm,
    required this.speedMs,
  });
}

class Pace {
  final int minutes;
  final int seconds;
  Pace({required this.minutes, required this.seconds});
  @override
  String toString() => '$minutes:${seconds.toString().padLeft(2, '0')}';
}