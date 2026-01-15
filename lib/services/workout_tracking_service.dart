import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:health/health.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:pedometer/pedometer.dart';
import 'package:permission_handler/permission_handler.dart'; // Added
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

/// 고도화된 러닝 트래킹 서비스 (Final Integrated Version)
class WorkoutTrackingService extends ChangeNotifier {
  // 1. 상태 변수
  bool _isTracking = false;
  bool _isPaused = false;
  bool _isAutoPaused = false;
  bool _isInitializing = false;
  DateTime? _startTime;
  DateTime? _stopTime;
  DateTime? _pausedTime;
  Duration _totalPausedDuration = Duration.zero;

  final List<RoutePoint> _route = [];
  double _totalDistance = 0; // m
  double _totalElevationGain = 0; // m

  // 2. 필터 및 센서 데이터
  final KalmanFilter _kalmanFilter = KalmanFilter();
  final PaceSmoother _paceSmoother = PaceSmoother(windowSizeSeconds: 10);
  final AltitudeSmoother _altitudeSmoother = AltitudeSmoother(threshold: 3.0);
  
  final List<PaceDataPoint> _paceHistory = [];
  int? _latestHeartRate;
  int? _currentCadence;
  int? _lastStepCount;
  DateTime? _lastStepTimestamp;
  double? _lastBarometricAltitude;
  double _lastMagnitude = 0.0;
  int _lastAnnouncedKm = 0;
  int _lowSpeedSeconds = 0;

  // 3. 목표 및 템플릿 설정
  double? _goalDistance;
  Duration? _goalTime;
  Pace? _goalPace;

  bool _isStructured = false;
  WorkoutTemplate? _activeTemplate;
  String _activeTemplateName = "Running";
  List<TemplateBlock> _activeBlocks = [];
  int _currentBlockIndex = 0;
  double _blockDistanceAccumulator = 0;
  Duration _blockDurationAccumulator = Duration.zero;
  DateTime? _blockStartTime;
  Duration? _lastBlockDuration;

  // 4. 서비스 및 스트림
  final VoiceGuidanceService _voiceService = VoiceGuidanceService();
  final Health _health = Health();
  StreamSubscription<Position>? _positionStream;
  StreamSubscription<double>? _heartRateSubscription;
  StreamSubscription<BarometerEvent>? _barometerSubscription;
  StreamSubscription<AccelerometerEvent>? _accelerometerSubscription;
  StreamSubscription<StepCount>? _pedometerSubscription;
  Timer? _updateTimer;

  final _workoutStateController = StreamController<WorkoutState>.broadcast();
  Stream<WorkoutState> get workoutStateStream => _workoutStateController.stream;

  // 상수
  static const double _minSpeedThreshold = 0.5;
  static const int _autoPauseThresholdSeconds = 5;
  static const double _autoPauseSpeedThreshold = 0.8;

  // ==============================
  // PUBLIC METHODS
  // ==============================

  Future<void> startWorkout({WorkoutTemplate? template}) async {
    if (_isTracking || _isInitializing) return;

    // 1.1 엔진 상태 즉시 활성화 (로딩 화면 방지)
    _isInitializing = true;
    _isTracking = true; 
    _isPaused = false;
    _isAutoPaused = false;
    _resetTrackingState();
    
    if (template != null) {
      _setupStructuredWorkout(template);
    } else {
      _setupFreeRun();
    }
    
    _updateWorkoutState(); // 첫 상태 발송
    notifyListeners();

    try {
      // 1.2 필수 권한 확인 (병렬 처리)
      // 이미 SetupScreen에서 권한을 받았으므로, 여기서는 실제 상태만 가볍게 체크
      // 팝업이 다시 뜨지 않도록 geolocator의 단순 체크 기능 활용
      final locStatus = await Geolocator.checkPermission();
      final hasLocation = locStatus == LocationPermission.whileInUse || locStatus == LocationPermission.always;
      
      // HealthKit은 이미 SetupScreen에서 세밀하게 체크됨 (HealthService 내부 로직 활용)
      
      if (!hasLocation) {
        // 만약의 상황을 대비한 최후의 요청
        final p = await _checkLocationPermission();
        if (!p) throw Exception('위치 권한이 필요합니다.');
      }

      // 1.3 서비스 초기화
      await _voiceService.init();
      // _voiceService.speak('$_activeTemplateName을 시작합니다.'); // 💡 제거: 실제 시작(actualStart) 시점으로 이동
      HapticFeedback.heavyImpact();

      // 하드웨어 서비스 시작
      _startHardwareServices();
      
      _isInitializing = false;
      notifyListeners();

    } catch (e) {
      _isTracking = false;
      _isInitializing = false;
      _stopHardwareServices();
      debugPrint('❌ Workout Start Error: $e');
      notifyListeners();
      rethrow;
    }
  }

  Future<WorkoutSummary> stopWorkout({int? avgHeartRate}) async {
    if (!_isTracking) throw Exception('운동 중이 아닙니다');
    if (_isPaused) resumeWorkout(silent: true);

    _stopTime = DateTime.now();
    _isTracking = false;
    _isAutoPaused = false;
    
    _stopHardwareServices();

    _voiceService.speak('운동을 완료했습니다.');
    HapticFeedback.heavyImpact();

    final activeDuration = _stopTime!.difference(_startTime!) - _totalPausedDuration;
    final summary = _createSummary(activeDuration, avgHeartRate);

    // 기록 저장
    final session = _createSession(summary, activeDuration);
    await WorkoutHistoryService().saveSession(session);
    
    // HealthKit 저장 후 반환된 ID를 로컬 세션에 업데이트 (중복 방지 핵심)
    final healthKitId = await _saveToHealthKit(summary);
    if (healthKitId != null) {
      await WorkoutHistoryService().saveSession(session.copyWith(healthKitWorkoutId: healthKitId));
    }
    
    await WatchConnectivityService().stopWatchWorkout();
    LiveActivityService().endActivity();

    notifyListeners();
    return summary;
  }

  void pauseWorkout() {
    if (!_isTracking || _isPaused) return;
    _isPaused = true;
    _pausedTime = DateTime.now();
    _positionStream?.pause();
    _voiceService.speak('운동을 일시정지합니다.');
    _updateWorkoutState();
    notifyListeners();
  }

  void resumeWorkout({bool silent = false}) {
    if (!_isTracking || !_isPaused || _pausedTime == null) return;
    _totalPausedDuration += DateTime.now().difference(_pausedTime!);
    _isPaused = false;
    _pausedTime = null;
    _positionStream?.resume();
    if (!silent) _voiceService.speak('운동을 다시 시작합니다.');
    _updateWorkoutState();
    notifyListeners();
  }

  // ==============================
  // PRIVATE HELPERS
  // ==============================

  void _resetTrackingState() {
    _startTime = DateTime.now();
    _stopTime = null;
    _pausedTime = null;
    _totalPausedDuration = Duration.zero;
    _route.clear();
    _totalDistance = 0;
    _totalElevationGain = 0;
    _paceHistory.clear();
    _lastAnnouncedKm = 0;
    _lowSpeedSeconds = 0;
    _lastMagnitude = 0;
    _kalmanFilter.reset();
    _paceSmoother.reset();
    _altitudeSmoother.reset();
  }

  void _setupStructuredWorkout(WorkoutTemplate template) {
    _isStructured = true;
    _activeTemplate = template;
    _activeTemplateName = template.name;
    _activeBlocks = template.phases.expand((p) => p.blocks).toList();
    _currentBlockIndex = 0;
    _blockDistanceAccumulator = 0;
    _blockDurationAccumulator = Duration.zero;
    _blockStartTime = DateTime.now();
    _lastBlockDuration = null;
    
    final sub = template.subCategory ?? '';
    final isInterval = sub.contains('Interval') || sub.contains('인터벌') || sub.contains('속도');
    _paceSmoother.setWindowSize(isInterval ? 3 : 10);
  }

  void _setupFreeRun() {
    _isStructured = false;
    _activeTemplate = null;
    _activeTemplateName = "Free Run";
    _activeBlocks = [];
    _paceSmoother.setWindowSize(10);
  }

  void _startHardwareServices() {
    _startGPSTracking();
    _startBarometerTracking();
    _startAccelerometerTracking();
    _startUpdateTimer();
    
    // 심박수 연동 (업데이트 시 즉시 상태 반영)
    _heartRateSubscription?.cancel();
    final watch = WatchConnectivityService();
    _heartRateSubscription = watch.heartRateStream.map((bpm) => bpm.toDouble()).listen((bpm) {
      _latestHeartRate = bpm.toInt();
      if (_isTracking && !_isPaused && !_isAutoPaused) {
        _updateWorkoutState();
      }
    });
    watch.startWatchWorkout(activityType: _isStructured && _activeTemplate?.category == 'Strength' ? 'Strength' : 'Running');

    // 케이던스 (Pedometer) 연동
    _pedometerSubscription?.cancel();
    _pedometerSubscription = Pedometer.stepCountStream.listen((StepCount event) {
      if (!_isTracking || _isPaused || _isAutoPaused) {
        _lastStepCount = event.steps;
        _lastStepTimestamp = DateTime.now();
        return;
      }

      if (_lastStepCount != null && _lastStepTimestamp != null) {
        final now = DateTime.now();
        final secondsDiff = now.difference(_lastStepTimestamp!).inSeconds;
        
        // 💡 2초 이상의 간격으로 케이던스 계산 (노이즈 방지)
        if (secondsDiff >= 2) {
          final stepsDiff = event.steps - _lastStepCount!;
          if (stepsDiff >= 0) {
            // SPM = (걸음수 차이 / 초 차이) * 60
            _currentCadence = ((stepsDiff / secondsDiff) * 60).round();
            // 비정상 수치 필터링 (0~250 범위만 허용)
            if (_currentCadence! > 250) _currentCadence = 250;
          }
          _lastStepCount = event.steps;
          _lastStepTimestamp = now;
          
          // 케이던스 업데이트 시 UI 즉시 반영
          _updateWorkoutState();
        }
      } else {
        _lastStepCount = event.steps;
        _lastStepTimestamp = DateTime.now();
      }
    });
  }

  void _stopHardwareServices() {
    _positionStream?.cancel();
    _heartRateSubscription?.cancel();
    _barometerSubscription?.cancel();
    _accelerometerSubscription?.cancel();
    _pedometerSubscription?.cancel();
    _updateTimer?.cancel();
  }

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
    _positionStream = Geolocator.getPositionStream(locationSettings: settings).listen(_onLocationUpdate);
  }

  /// 💡 카운트다운 완료 후 실제 기록 시작을 알림 (시간 보정용)
  void actualStart() {
    if (!_isTracking) return;
    _startTime = DateTime.now();
    _totalDistance = 0;
    _blockDistanceAccumulator = 0;
    _blockStartTime = DateTime.now();
    _updateWorkoutState();
    
    // 💡 실제 시작 시점에 음성 안내 출력
    _voiceService.speak('$_activeTemplateName을 시작합니다.');
    
    debugPrint('🔥 Workout Recording Actually Started at: $_startTime');
  }

  void _startBarometerTracking() {
    _barometerSubscription?.cancel();
    _barometerSubscription = barometerEventStream().listen((event) {
      _lastBarometricAltitude = 44330 * (1 - math.pow(event.pressure / 1013.25, 1 / 5.255).toDouble());
    });
  }

  void _startAccelerometerTracking() {
    _accelerometerSubscription?.cancel();
    _accelerometerSubscription = accelerometerEventStream().listen((event) {
      _lastMagnitude = math.sqrt(event.x * event.x + event.y * event.y + event.z * event.z);
    });
  }

  void _onLocationUpdate(Position position) {
    if (!_isTracking) return;

    final smoothed = _kalmanFilter.process(position.latitude, position.longitude, position.accuracy, position.timestamp.millisecondsSinceEpoch);
    final sLat = smoothed[0];
    final sLng = smoothed[1];

    double speed = 0;
    if (_route.isNotEmpty) {
      double dist = Geolocator.distanceBetween(_route.last.latitude, _route.last.longitude, sLat, sLng);
      final tDiff = position.timestamp.difference(_route.last.timestamp);
      if (tDiff.inMilliseconds > 0) speed = dist / (tDiff.inMilliseconds / 1000.0);
    }
    
    _checkAutoPauseLogic(speed);

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

  void _checkAutoPauseLogic(double speed) {
    if (!_isTracking || _isPaused) return;
    bool isMoving = (_lastMagnitude - 9.8).abs() > 0.5;

    // 트레일 러닝은 경사가 가파를 수 있으므로 자동 일시정지 임계값을 낮춤 (0.8 -> 0.4)
    double threshold = _activeTemplate?.environmentType == 'Trail' ? 0.4 : _autoPauseSpeedThreshold;

    if (_isAutoPaused) {
      if (speed > threshold + 0.2 || isMoving) {
        _isAutoPaused = false;
        _lowSpeedSeconds = 0;
        _voiceService.speak('운동을 다시 시작합니다.');
        HapticFeedback.lightImpact();
        notifyListeners();
      }
    }
    else {
      if (speed < threshold && !isMoving) {
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
    final dur = DateTime.now().difference(_startTime!) - _totalPausedDuration;
    double speed = _paceSmoother.currentSpeedMs;
    String avgPace = _calculatePace(_totalDistance / 1000, dur);
    
    // 💡 정밀 수정: speed(m/s)는 1초당 이동 거리(m)와 같으므로, 
    // 이를 km로 변환하려면 1000으로만 나누면 됨 (3.6 곱하기 제거)
    String curPace = speed > _minSpeedThreshold 
        ? _calculatePace(speed / 1000, const Duration(seconds: 1)) 
        : '--:--';

    if (speed >= _minSpeedThreshold) {
      _paceHistory.add(PaceDataPoint(elapsedTime: dur, paceMinPerKm: 1000 / (speed * 60), speedMs: speed));
    }

    final state = WorkoutState(
      isTracking: _isTracking, isPaused: _isPaused, isAutoPaused: _isAutoPaused,
      duration: dur, distanceMeters: _totalDistance, currentSpeedMs: speed,
      averagePace: avgPace, currentPace: curPace, calories: _calculateCalories(_totalDistance / 1000, dur),
      heartRate: _latestHeartRate, cadence: _currentCadence, 
      routePointsCount: _route.length, elevationGain: _totalElevationGain,
      isStructured: _isStructured, currentBlockIndex: _currentBlockIndex,
      lastBlockDuration: _lastBlockDuration, currentBlockDuration: _blockDurationAccumulator,
    );

    _workoutStateController.add(state);

    // 💡 Live Activity (다이나믹 아일랜드) 실시간 업데이트 복구
    if (!kIsWeb && Platform.isIOS) {
      LiveActivityService().updateActivity(
        distanceKm: state.distanceKm,
        duration: state.durationFormatted,
        pace: state.currentPace,
        heartRate: state.heartRate,
      );
    }
  }

  String _calculatePace(double distKm, Duration dur) {
    if (distKm <= 0) return '--:--';
    double minKm = dur.inSeconds / 60 / distKm;
    if (minKm > 20) return '--:--';
    return '${minKm.floor()}:${((minKm - minKm.floor()) * 60).round().toString().padLeft(2, '0')}';
  }

  double _calculateCalories(double distKm, Duration dur) {
    double weight = 70;
    double hrs = dur.inSeconds / 3600;
    if (hrs == 0) return 0;
    double spd = distKm / hrs;
    double met = spd < 6.4 ? 6.0 : spd < 8.0 ? 8.3 : spd < 9.7 ? 9.8 : spd < 11.3 ? 11.0 : spd < 12.9 ? 11.8 : 12.3;
    return met * weight * hrs;
  }

  WorkoutSummary _createSummary(Duration activeDur, int? avgHR) {
    return WorkoutSummary(
      startTime: _startTime!, endTime: DateTime.now(), stopTime: _stopTime!,
      duration: activeDur, totalDuration: DateTime.now().difference(_startTime!),
      distanceMeters: _totalDistance, elevationGain: _totalElevationGain,
      averagePace: _calculatePace(_totalDistance / 1000, activeDur),
      calories: _calculateCalories(_totalDistance / 1000, activeDur),
      routePoints: List.from(_route), averageHeartRate: avgHR ?? _latestHeartRate,
      pausedDuration: _totalPausedDuration, paceData: List.from(_paceHistory),
    );
  }

  WorkoutSession _createSession(WorkoutSummary summary, Duration activeDur) {
    return WorkoutSession(
      id: const Uuid().v4(), templateId: _activeTemplate?.id ?? 'free_run',
      templateName: _activeTemplateName, category: _activeTemplate?.category ?? 'Endurance',
      startTime: _startTime!, endTime: summary.endTime, activeDuration: activeDur.inSeconds,
      totalDuration: summary.totalDuration.inSeconds, totalDistance: _totalDistance,
      calories: summary.calories, averageHeartRate: summary.averageHeartRate,
      elevationGain: _totalElevationGain, environmentType: _activeTemplate?.environmentType,
      exerciseRecords: [],
      routePoints: List.from(_route),
    );
  }

  Future<String?> _saveToHealthKit(WorkoutSummary summary) async {
    try {
      // 💡 writeWorkoutData는 성공 시 String(UUID)를 반환하거나 true를 반환할 수 있음
      final dynamic result = await _health.writeWorkoutData(
        activityType: HealthWorkoutActivityType.RUNNING, 
        start: summary.startTime, 
        end: summary.stopTime, 
        totalDistance: summary.distanceMeters.toInt(), 
        totalEnergyBurned: summary.calories.toInt()
      );
      
      if (result is String) {
        return result;
      }
      return null;
    } catch (e) {
      debugPrint('⚠️ Failed to save to HealthKit: $e');
      return null;
    }
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

  Future<bool> _checkSensorPermission() async {
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      final status = await Permission.sensors.request();
      return status.isGranted || status.isLimited;
    }
    return true; 
  }

  @override
  void dispose() {
    _stopHardwareServices();
    _workoutStateController.close();
    super.dispose();
  }

  // Getters
  bool get isTracking => _isTracking;
  bool get isPaused => _isPaused;
  bool get isAutoPaused => _isAutoPaused;
  bool get isInitializing => _isInitializing;
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
  final int? heartRate, cadence;
  final int routePointsCount, currentBlockIndex;

  WorkoutState({
    required this.isTracking, required this.isPaused, this.isAutoPaused = false,
    required this.duration, required this.distanceMeters, required this.currentSpeedMs,
    required this.averagePace, required this.currentPace, required this.calories,
    this.heartRate, this.cadence, required this.routePointsCount, this.elevationGain = 0.0,
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