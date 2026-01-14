import 'dart:async';
import 'dart:math' as math; // math prefix 사용으로 충돌 방지
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:health/health.dart';
import 'package:sensors_plus/sensors_plus.dart';
import '../models/sessions/route_point.dart';
import '../models/templates/workout_template.dart';
import '../models/templates/template_block.dart';
import 'heart_rate_service.dart';
import 'live_activity_service.dart';
import 'workout_history_service.dart';
import '../models/sessions/workout_session.dart';
import 'package:uuid/uuid.dart';
import 'watch_connectivity_service.dart';
import 'voice_guidance_service.dart';

import '../utils/tracking/kalman_filter.dart';
import '../utils/tracking/pace_smoother.dart';
import '../utils/tracking/altitude_smoother.dart';

/// 운동 추적 서비스
class WorkoutTrackingService extends ChangeNotifier {
  // 상태 변수
  bool _isTracking = false;
  bool _isPaused = false;
  bool _isAutoPaused = false;
  DateTime? _startTime;
  DateTime? _stopTime; 
  DateTime? _pausedTime;
  Duration _totalPausedDuration = Duration.zero;

  final List<RoutePoint> _route = [];
  double _totalDistance = 0; // 미터
  double _totalElevationGain = 0; // 누적 상승 고도 (미터)

  // 필터 및 스무더
  final KalmanFilter _kalmanFilter = KalmanFilter();
  final PaceSmoother _paceSmoother = PaceSmoother(windowSizeSeconds: 10);
  final AltitudeSmoother _altitudeSmoother = AltitudeSmoother(threshold: 3.0);
  
  final List<PaceDataPoint> _paceHistory = []; 
  int? _latestHeartRate;
  double? _lastBarometricAltitude;
  int _lastAnnouncedKm = 0; 

  // Auto Pause 설정
  int _lowSpeedSeconds = 0;
  static const int _autoPauseThresholdSeconds = 5;
  static const double _autoPauseSpeedThreshold = 0.8; 

  // 목표 설정
  double? _goalDistance; 
  Duration? _goalTime;
  Pace? _goalPace;

  // 구조화된 운동 (템플릿) 상태
  bool _isStructured = false;
  WorkoutTemplate? _activeTemplate;
  String _activeTemplateName = "Running";
  List<TemplateBlock> _activeBlocks = [];
  int _currentBlockIndex = 0;
  double _blockDistanceAccumulator = 0; 
  Duration _blockDurationAccumulator = Duration.zero; 
  DateTime? _blockStartTime;
  Duration? _lastBlockDuration; 

  // 서비스 및 스트림
  final VoiceGuidanceService _voiceService = VoiceGuidanceService();
  final Health _health = Health();
  StreamSubscription<Position>? _positionStream;
  StreamSubscription<double>? _heartRateSubscription;
  StreamSubscription<BarometerEvent>? _barometerSubscription;
  Timer? _updateTimer;

  final _workoutStateController = StreamController<WorkoutState>.broadcast();
  Stream<WorkoutState> get workoutStateStream => _workoutStateController.stream;

  static const double _minSpeedThreshold = 0.5;

  // ==============================
  // 1. 운동 시작 및 종료
  // ==============================

  Future<void> startWorkout({WorkoutTemplate? template}) async {
    if (_isTracking) return;

    // 1.1 권한 및 엔진 상태 즉시 활성화 (로딩 방지)
    _isTracking = true; 
    _isPaused = false;
    _isAutoPaused = false;
    _startTime = DateTime.now();
    _route.clear();
    _totalDistance = 0;
    _totalElevationGain = 0;
    _paceHistory.clear();
    _lastAnnouncedKm = 0;
    
    _kalmanFilter.reset();
    _paceSmoother.reset();
    _altitudeSmoother.reset();

    // 1.2 템플릿 설정 즉시 반영
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
      _paceSmoother.setWindowSize(template.subCategory?.contains('Interval') == true ? 3 : 10);
    } else {
      _isStructured = false;
      _activeTemplate = null;
      _activeTemplateName = "Free Run";
      _activeBlocks = [];
      _currentBlockIndex = 0;
      _lastBlockDuration = null;
      _paceSmoother.setWindowSize(10);
    }

    // 1.3 첫 번째 상태를 즉시 스트림으로 발송 (UI 전환 트리거)
    _updateWorkoutState();

    try {
      // 1.4 권한 확인 (병렬 처리)
      final results = await Future.wait([
        _checkLocationPermission(),
        _checkHealthPermission(),
      ]);

      if (!results[0] || !results[1]) {
        _isTracking = false;
        notifyListeners();
        throw Exception('필수 권한이 거부되었습니다.');
      }

      // 1.5 서비스 초기화 (음성 서비스는 별도 대기)
      await _voiceService.init();
      _voiceService.speak('$_activeTemplateName을 시작합니다.');
      HapticFeedback.heavyImpact();

      // Live Activity 및 센서 추적 시작 (Non-blocking)
      _startServicesAsync();

    } catch (e) {
      _isTracking = false;
      debugPrint('❌ Workout Start Error: $e');
      rethrow;
    }
  }

  /// 백그라운드에서 서비스를 순차적으로 시작 (UI를 막지 않음)
  Future<void> _startServicesAsync() async {
    final laService = LiveActivityService();
    await laService.init();
    await laService.startActivity(
      name: _activeTemplateName, distanceKm: "0.00", duration: "00:00:00", pace: "--:--", heartRate: null,
    );

    _startGPSTracking();
    _startBarometerTracking();

    _heartRateSubscription?.cancel();
    final watchService = WatchConnectivityService();
    _heartRateSubscription = watchService.heartRateStream.map((bpm) => bpm.toDouble()).listen((bpm) => _latestHeartRate = bpm.toInt());
    
    await watchService.startWatchWorkout(activityType: _isStructured && _activeTemplate?.category == 'Strength' ? 'Strength' : 'Running');
    _startUpdateTimer();
  }

  Future<WorkoutSummary> stopWorkout({int? avgHeartRate}) async {
    if (!_isTracking) throw Exception('운동 중이 아닙니다');
    if (_isPaused) resumeWorkout();

    _stopTime = DateTime.now();
    _isTracking = false;
    _isAutoPaused = false;
    _positionStream?.cancel();
    _heartRateSubscription?.cancel();
    _barometerSubscription?.cancel();
    _updateTimer?.cancel();

    _voiceService.speak('운동을 완료했습니다.');
    HapticFeedback.heavyImpact();

    final activeDuration = _stopTime!.difference(_startTime!) - _totalPausedDuration;
    final summary = WorkoutSummary(
      startTime: _startTime!, endTime: DateTime.now(), stopTime: _stopTime!,
      duration: activeDuration, totalDuration: DateTime.now().difference(_startTime!),
      distanceMeters: _totalDistance, elevationGain: _totalElevationGain,
      averagePace: _calculatePace(_totalDistance / 1000, activeDuration),
      calories: _calculateCalories(_totalDistance / 1000, activeDuration),
      routePoints: List.from(_route), averageHeartRate: avgHeartRate ?? _latestHeartRate,
      pausedDuration: _totalPausedDuration, paceData: List.from(_paceHistory),
    );

    await WorkoutHistoryService().saveSession(WorkoutSession(
      id: const Uuid().v4(), templateId: _activeTemplate?.id ?? 'free_run',
      templateName: _activeTemplateName, category: _activeTemplate?.category ?? 'Endurance',
      startTime: _startTime!, endTime: summary.endTime, activeDuration: activeDuration.inSeconds,
      totalDuration: summary.totalDuration.inSeconds, totalDistance: _totalDistance,
      calories: summary.calories, averageHeartRate: summary.averageHeartRate,
      elevationGain: _totalElevationGain, environmentType: _activeTemplate?.environmentType,
      exerciseRecords: [],
    ));

    await _saveToHealthKit(summary);
    await WatchConnectivityService().stopWatchWorkout();
    LiveActivityService().endActivity();

    return summary;
  }

  // ==============================
  // 2. 센서 로직
  // ==============================

  void _startGPSTracking() {
    late final LocationSettings settings;
    if (defaultTargetPlatform == TargetPlatform.android) {
      settings = AndroidSettings(
        accuracy: LocationAccuracy.high, distanceFilter: 5, forceLocationManager: true,
        intervalDuration: const Duration(seconds: 1),
        foregroundNotificationConfig: const ForegroundNotificationConfig(
          notificationText: "운동 경로를 기록 중입니다.", notificationTitle: "PaceLifter 실행 중", enableWakeLock: true,
        ),
      );
    } else {
      settings = AppleSettings(
        accuracy: LocationAccuracy.high, activityType: ActivityType.fitness, distanceFilter: 5,
        pauseLocationUpdatesAutomatically: false, showBackgroundLocationIndicator: true, allowBackgroundLocationUpdates: true,
      );
    }
    _positionStream = Geolocator.getPositionStream(locationSettings: settings).listen(
      _onLocationUpdate, onError: (error) => debugPrint('📍 GPS Error: $error'),
    );
  }

  void _startBarometerTracking() {
    _barometerSubscription?.cancel();
    // sensors_plus 최신 API: barometerEventStream()
    _barometerSubscription = barometerEventStream().listen((event) {
      double altitude = 44330 * (1 - math.pow(event.pressure / 1013.25, 1 / 5.255).toDouble());
      _lastBarometricAltitude = altitude;
    });
  }

  void _onLocationUpdate(Position position) {
    if (!_isTracking) return;

    final smoothed = _kalmanFilter.process(
      position.latitude, position.longitude, position.accuracy, position.timestamp.millisecondsSinceEpoch,
    );
    final sLat = smoothed[0];
    final sLng = smoothed[1];

    double speed = 0;
    if (_route.isNotEmpty) {
      double dist = Geolocator.distanceBetween(_route.last.latitude, _route.last.longitude, sLat, sLng);
      final tDiff = position.timestamp.difference(_route.last.timestamp);
      if (tDiff.inMilliseconds > 0) speed = dist / (tDiff.inMilliseconds / 1000.0);
    }
    _checkAutoPause(speed);

    if (_isPaused || _isAutoPaused) return;

    if (_route.isNotEmpty) {
      double dist = Geolocator.distanceBetween(_route.last.latitude, _route.last.longitude, sLat, sLng);
      if (dist < 100) {
        _totalDistance += dist;
        if (_isStructured) _blockDistanceAccumulator += dist;
        _totalElevationGain = _altitudeSmoother.process(_lastBarometricAltitude ?? position.altitude);
        _paceSmoother.add(speed);
        _checkDistanceMilestone();
      }
    } else {
      _paceSmoother.add(0);
    }

    _route.add(RoutePoint(
      latitude: sLat, longitude: sLng, altitude: _lastBarometricAltitude ?? position.altitude,
      timestamp: position.timestamp, speed: _paceSmoother.currentSpeedMs, accuracy: position.accuracy,
    ));
  }

  void _checkAutoPause(double speed) {
    if (!_isTracking || _isPaused) return;
    if (_isAutoPaused) {
      if (speed > _autoPauseSpeedThreshold + 0.2) {
        _isAutoPaused = false;
        _lowSpeedSeconds = 0;
        _voiceService.speak('운동을 다시 시작합니다.');
        HapticFeedback.lightImpact();
        notifyListeners();
      }
    } else {
      if (speed < _autoPauseSpeedThreshold) {
        _lowSpeedSeconds++;
        if (_lowSpeedSeconds >= _autoPauseThresholdSeconds) {
          _isAutoPaused = true;
          _voiceService.speak('자동 일시정지되었습니다.');
          HapticFeedback.mediumImpact();
          notifyListeners();
        }
      } else {
        _lowSpeedSeconds = 0;
      }
    }
  }

  void _checkDistanceMilestone() {
    int currentKm = (_totalDistance / 1000).floor();
    if (currentKm > _lastAnnouncedKm) {
      _lastAnnouncedKm = currentKm;
      String paceStr = _calculatePace(_totalDistance / 1000, DateTime.now().difference(_startTime!) - _totalPausedDuration);
      _voiceService.speak('$currentKm 킬로미터 통과. 현재 페이스 ${paceStr.replaceAll(':', '분 ')}초.');
    }
  }

  // ==============================
  // 3. 업데이트 및 제어
  // ==============================

  void _startUpdateTimer() {
    _updateTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_isTracking && !_isPaused && !_isAutoPaused) {
        _updateWorkoutState();
        if (_isStructured) _checkBlockCompletion();
      }
    });
  }

  void _checkBlockCompletion() {
    if (_activeBlocks.isEmpty || _currentBlockIndex >= _activeBlocks.length) return;
    final block = _activeBlocks[_currentBlockIndex];
    _blockDurationAccumulator += const Duration(seconds: 1);
    bool advance = false;
    if (block.targetDistance != null && block.targetDistance! > 0) {
      if (_blockDistanceAccumulator >= block.targetDistance!) advance = true;
    } else if (block.targetDuration != null && block.targetDuration! > 0) {
      if (_blockDurationAccumulator.inSeconds >= block.targetDuration!) advance = true;
    }
    if (advance) advanceBlock();
  }

  void advanceBlock() {
    if (_currentBlockIndex < _activeBlocks.length - 1) {
      _lastBlockDuration = _blockDurationAccumulator;
      _currentBlockIndex++;
      _blockDistanceAccumulator = 0;
      _blockDurationAccumulator = Duration.zero;
      _blockStartTime = DateTime.now();
      _voiceService.speak('다음 구간, ${_activeBlocks[_currentBlockIndex].name} 시작.');
      HapticFeedback.vibrate();
    }
    _updateWorkoutState();
  }

  void _updateWorkoutState() {
    if (_startTime == null) return;
    final activeDur = DateTime.now().difference(_startTime!) - _totalPausedDuration;
    double speed = _calculateCurrentSpeed();
    String avgPace = _calculatePace(_totalDistance / 1000, activeDur);
    String curPace = speed > _minSpeedThreshold ? _calculatePace(speed * 3.6 / 1000, const Duration(seconds: 1)) : '--:--';

    if (speed >= _minSpeedThreshold) {
      _paceHistory.add(PaceDataPoint(elapsedTime: activeDur, paceMinPerKm: 1000 / (speed * 60), speedMs: speed));
    }

    final state = WorkoutState(
      isTracking: true, isPaused: _isPaused, isAutoPaused: _isAutoPaused,
      duration: activeDur, distanceMeters: _totalDistance, currentSpeedMs: speed,
      averagePace: avgPace, currentPace: curPace, calories: _calculateCalories(_totalDistance / 1000, activeDur),
      heartRate: _latestHeartRate, routePointsCount: _route.length, elevationGain: _totalElevationGain,
      isStructured: _isStructured, currentBlockIndex: _currentBlockIndex,
      lastBlockDuration: _lastBlockDuration, currentBlockDuration: _blockDurationAccumulator,
    );

    _workoutStateController.add(state);
    LiveActivityService().updateActivity(distanceKm: state.distanceKm, duration: state.durationFormatted, pace: state.currentPace, heartRate: state.heartRate);
  }

  double _calculateCurrentSpeed() => _paceSmoother.currentSpeedMs;

  String _calculatePace(double distKm, Duration dur) {
    if (distKm <= 0) return '--:--';
    double minKm = dur.inSeconds / 60 / distKm;
    if (minKm > 20) return '--:--';
    int m = minKm.floor();
    int s = ((minKm - m) * 60).round();
    return '$m:${s.toString().padLeft(2, '0')}';
  }

  double _calculateCalories(double distKm, Duration dur) {
    double weight = 70;
    double hrs = dur.inSeconds / 3600;
    if (hrs == 0) return 0;
    double spd = distKm / hrs;
    double met = spd < 6.4 ? 6.0 : spd < 8.0 ? 8.3 : spd < 9.7 ? 9.8 : spd < 11.3 ? 11.0 : spd < 12.9 ? 11.8 : 12.3;
    return met * weight * hrs;
  }

  void pauseWorkout() {
    if (!_isTracking || _isPaused) return;
    _isPaused = true;
    _pausedTime = DateTime.now();
    _positionStream?.pause();
    _voiceService.speak('운동을 일시정지합니다.');
    _updateWorkoutState();
  }

  void resumeWorkout() {
    if (!_isTracking || !_isPaused || _pausedTime == null) return;
    _totalPausedDuration += DateTime.now().difference(_pausedTime!);
    _isPaused = false;
    _pausedTime = null;
    _positionStream?.resume();
    _voiceService.speak('운동을 다시 시작합니다.');
    _updateWorkoutState();
  }

  // ==============================
  // 4. 권한 및 헬퍼
  // ==============================

  Future<void> _saveToHealthKit(WorkoutSummary summary) async {
    try {
      await _health.writeWorkoutData(activityType: HealthWorkoutActivityType.RUNNING, start: summary.startTime, end: summary.stopTime, totalDistance: summary.distanceMeters.toInt(), totalEnergyBurned: summary.calories.toInt());
    } catch (_) {}
  }

  Future<bool> _checkLocationPermission() async {
    LocationPermission p = await Geolocator.checkPermission();
    if (p == LocationPermission.denied) p = await Geolocator.requestPermission();
    return p == LocationPermission.whileInUse || p == LocationPermission.always;
  }

  Future<bool> _checkHealthPermission() async {
    try {
      return await _health.requestAuthorization(
        [HealthDataType.WORKOUT, HealthDataType.DISTANCE_WALKING_RUNNING, HealthDataType.ACTIVE_ENERGY_BURNED, HealthDataType.HEART_RATE, HealthDataType.STEPS],
        permissions: [HealthDataAccess.READ_WRITE, HealthDataAccess.READ_WRITE, HealthDataAccess.READ_WRITE, HealthDataAccess.READ_WRITE, HealthDataAccess.READ_WRITE],
      );
    } catch (_) { return false; }
  }

  @override
  void dispose() {
    _positionStream?.cancel(); _heartRateSubscription?.cancel(); _barometerSubscription?.cancel();
    _updateTimer?.cancel(); _workoutStateController.close();
    super.dispose();
  }

  // Getters
  bool get isTracking => _isTracking;
  bool get isPaused => _isPaused;
  bool get isAutoPaused => _isAutoPaused;
  double get totalDistance => _totalDistance;
  List<RoutePoint> get route => List.unmodifiable(_route);
  double? get goalDistance => _goalDistance;
  Duration? get goalTime => _goalTime;
  Pace? get goalPace => _goalPace;

  void setGoals({double? distance, Duration? time, Pace? pace}) {
    if (distance != null) _goalDistance = distance;
    if (time != null) _goalTime = time;
    if (pace != null) _goalPace = pace;
    notifyListeners();
  }

  void resetGoals() { _goalDistance = null; _goalTime = null; _goalPace = null; notifyListeners(); }
}

class WorkoutState {
  final bool isTracking, isPaused, isAutoPaused, isStructured;
  final Duration duration, currentBlockDuration;
  final Duration? lastBlockDuration;
  final double distanceMeters, currentSpeedMs, calories, elevationGain;
  final String averagePace, currentPace;
  final int? heartRate;
  final int routePointsCount, currentBlockIndex;

  WorkoutState({
    required this.isTracking, required this.isPaused, this.isAutoPaused = false,
    required this.duration, required this.distanceMeters, required this.currentSpeedMs,
    required this.averagePace, required this.currentPace, required this.calories,
    this.heartRate, required this.routePointsCount, this.elevationGain = 0.0,
    this.isStructured = false, this.currentBlockIndex = 0, this.lastBlockDuration,
    this.currentBlockDuration = Duration.zero,
  });

  String get distanceKm => (distanceMeters / 1000).toStringAsFixed(2);
  String get distanceKmFormatted => '$distanceKm km';
  String get currentSpeedKmh => (currentSpeedMs * 3.6).toStringAsFixed(1);
  String get durationFormatted {
    int h = duration.inHours, m = duration.inMinutes.remainder(60), s = duration.inSeconds.remainder(60);
    return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }
  String get caloriesFormatted => calories.toStringAsFixed(0);
}

class WorkoutSummary {
  final DateTime startTime, endTime, stopTime;
  final Duration duration, totalDuration, pausedDuration;
  final double distanceMeters, elevationGain, calories;
  final String averagePace;
  final List<RoutePoint> routePoints;
  final int? averageHeartRate;
  final List<PaceDataPoint> paceData;

  WorkoutSummary({
    required this.startTime, required this.endTime, required this.stopTime,
    required this.duration, required this.totalDuration, required this.distanceMeters,
    required this.elevationGain, required this.averagePace, required this.calories,
    required this.routePoints, this.averageHeartRate, required this.pausedDuration,
    required this.paceData,
  });

  String get distanceKm => (distanceMeters / 1000).toStringAsFixed(2);
  String get durationFormatted {
    int h = duration.inHours, m = duration.inMinutes.remainder(60), s = duration.inSeconds.remainder(60);
    return h > 0 ? '${h}h ${m}m ${s}s' : '${m}m ${s}s';
  }
}

class PaceDataPoint {
  final Duration elapsedTime;
  final double paceMinPerKm, speedMs;
  PaceDataPoint({required this.elapsedTime, required this.paceMinPerKm, required this.speedMs});
}

class Pace {
  final int minutes, seconds;
  Pace({required this.minutes, required this.seconds});
  @override
  String toString() => '$minutes:${seconds.toString().padLeft(2, '0')}';
}