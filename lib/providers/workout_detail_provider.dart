import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:health/health.dart';
import '../../../models/sessions/workout_session.dart';
import '../../../models/workout_data_wrapper.dart';
import '../../../services/health_service.dart';
import '../../../services/healthkit_bridge_service.dart';
import '../../../services/workout_history_service.dart';
import '../../../utils/workout_ui_utils.dart';

/// 운동 상세 화면의 데이터 로딩 및 가공을 담당하는 Provider
class WorkoutDetailProvider extends ChangeNotifier {
  final WorkoutDataWrapper dataWrapper;
  
  // 상태 데이터
  WorkoutSession? _session;
  List<HealthDataPoint> _heartRateData = [];
  List<HealthDataPoint> _paceData = [];
  
  // 지표 데이터
  double _avgHeartRate = 0;
  double _avgPace = 0; // min/km
  int _avgCadence = 0; // Steps per minute
  double _elevationGain = 0; // Meters
  Duration? _activeDuration;
  
  // 로딩 상태
  bool _isLoading = true;
  String? _error;

  // Getters
  WorkoutSession? get session => _session;
  List<HealthDataPoint> get heartRateData => _heartRateData;
  List<HealthDataPoint> get paceData => _paceData;
  double get avgHeartRate => _avgHeartRate;
  double get avgPace => _avgPace;
  int get avgCadence => _avgCadence;
  double get elevationGain => _elevationGain;
  Duration? get activeDuration => _activeDuration;
  bool get isLoading => _isLoading;
  String? get error => _error;

  final HealthService _healthService = HealthService();
  final HealthKitBridgeService _healthKitBridge = HealthKitBridgeService();

  WorkoutDetailProvider({required this.dataWrapper}) {
    _initialize();
  }

  Future<void> _initialize() async {
    _isLoading = true;
    notifyListeners();

    try {
      // 1. 세션 연결 확인
      _session = await WorkoutHistoryService().getSessionByHealthKitId(dataWrapper.uuid);
      
      // 2. 기본 정보 설정 (세션에 이미 고도가 있으면 사용)
      if (_session != null) {
        _avgHeartRate = _session!.averageHeartRate?.toDouble() ?? 0;
        _avgPace = _session!.averagePace != null ? _session!.averagePace! / 60 : 0;
        _elevationGain = _session!.elevationGain ?? 0.0;
      }

      // 3. 네이티브 데이터 비동기 로드
      await Future.wait([
        _fetchNativeDuration(),
        _fetchHeartRateData(),
        _fetchPaceSamples(),
        _fetchCadenceAndElevation(), // 추가
      ]);

    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// 네이티브 HealthKit으로부터 정밀한 운동 시간 정보를 가져옵니다.
  Future<void> _fetchNativeDuration() async {
    try {
      final details = await _healthKitBridge.getWorkoutDetails(dataWrapper.uuid);
      if (details != null) {
        final parsed = _healthKitBridge.parseWorkoutDetails(details);
        if (parsed != null) {
          _activeDuration = parsed.activeDuration;
        }
      }
    } catch (e) {
      debugPrint('⚠️ WorkoutDetailProvider: Failed to fetch native duration: $e');
    }
  }

  /// 심박수 샘플 데이터를 가져옵니다.
  Future<void> _fetchHeartRateData() async {
    try {
      final samples = await _healthService.getHealthDataFromTypes(
        dataWrapper.dateFrom,
        dataWrapper.dateTo,
        [HealthDataType.HEART_RATE],
      );

      if (samples.isNotEmpty) {
        _heartRateData = samples;
        double sum = samples.fold(0, (prev, element) => prev + (element.value as NumericHealthValue).numericValue);
        _avgHeartRate = sum / samples.length;
      }
    } catch (e) {
      debugPrint('⚠️ WorkoutDetailProvider: Failed to fetch heart rate samples: $e');
    }
  }

  /// 페이스/속도 샘플 데이터를 가져옵니다.
  Future<void> _fetchPaceSamples() async {
    try {
      final samples = await _healthService.getHealthDataFromTypes(
        dataWrapper.dateFrom,
        dataWrapper.dateTo,
        [HealthDataType.DISTANCE_WALKING_RUNNING, HealthDataType.RUNNING_SPEED],
      );

      final speedSamples = samples.where((d) => d.type == HealthDataType.RUNNING_SPEED).toList();
      
      if (speedSamples.isNotEmpty) {
        _paceData = speedSamples;
      } else {
        // 💡 중요: 속도 샘플이 없는 경우 거리 샘플을 시간으로 나누어 속도 추정
        final distSamples = samples.where((d) => d.type == HealthDataType.DISTANCE_WALKING_RUNNING).toList();
        if (distSamples.length >= 2) {
          distSamples.sort((a, b) => a.dateFrom.compareTo(b.dateFrom));
          _paceData = _calculateSpeedFromDistance(distSamples);
        }
      }
    } catch (e) {
      debugPrint('⚠️ WorkoutDetailProvider: Failed to fetch pace samples: $e');
    }
  }

  /// 케이던스 및 고도 정보를 가져옵니다.
  Future<void> _fetchCadenceAndElevation() async {
    try {
      final samples = await _healthService.getHealthDataFromTypes(
        dataWrapper.dateFrom,
        dataWrapper.dateTo,
        [HealthDataType.STEPS],
      );

      if (samples.isNotEmpty) {
        final totalSteps = samples.fold(0.0, (sum, s) => sum + (s.value as NumericHealthValue).numericValue);
        final duration = _activeDuration ?? dataWrapper.dateTo.difference(dataWrapper.dateFrom);
        
        if (duration.inMinutes > 0) {
          _avgCadence = (totalSteps / duration.inMinutes).round();
        }
      }
    } catch (e) {
      debugPrint('⚠️ WorkoutDetailProvider: Failed to fetch cadence: $e');
    }
  }

  /// 거리 데이터 리스트를 속도(m/s) 데이터 리스트로 변환합니다.
  List<HealthDataPoint> _calculateSpeedFromDistance(List<HealthDataPoint> distSamples) {
    final List<HealthDataPoint> speedPoints = [];
    for (int i = 1; i < distSamples.length; i++) {
      final p1 = distSamples[i - 1];
      final p2 = distSamples[i];
      
      final double distance = (p2.value as NumericHealthValue).numericValue.toDouble();
      final double seconds = p2.dateFrom.difference(p1.dateFrom).inSeconds.toDouble();
      
      if (seconds > 0 && distance > 0) {
        final double speedMs = distance / seconds;
        // 비정상적인 속도(0.5m/s ~ 15m/s) 범위만 허용
        if (speedMs > 0.5 && speedMs < 15.0) {
          speedPoints.add(HealthDataPoint(
            uuid: '${p2.uuid}_calc',
            value: NumericHealthValue(numericValue: speedMs),
            type: HealthDataType.RUNNING_SPEED,
            unit: HealthDataUnit.METER_PER_SECOND,
            dateFrom: p2.dateFrom,
            dateTo: p2.dateTo,
            sourcePlatform: p2.sourcePlatform,
            sourceDeviceId: p2.sourceDeviceId,
            sourceId: p2.sourceId,
            sourceName: p2.sourceName,
          ));
        }
      }
    }
    return speedPoints;
  }

  /// 데이터를 새로고침합니다.
  Future<void> refresh() => _initialize();
}
