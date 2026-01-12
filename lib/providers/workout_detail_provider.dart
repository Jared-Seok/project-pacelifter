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

      // 3. 네이티브 데이터 로드 (순차 실행으로 정확도 및 의존성 보장)
      await _fetchNativeDuration(); 

      // 4. 나머지 지표 비동기 로드
      await Future.wait([
        _fetchHeartRateData(),
        _fetchPaceSamples(),
        _fetchCadenceAndElevation(),
      ]);

    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// 네이티브 HealthKit으로부터 정밀한 운동 시간 및 추가 지표(고도, 케이던스) 정보를 가져옵니다.
  Future<void> _fetchNativeDuration() async {
    try {
      final details = await _healthKitBridge.getWorkoutDetails(dataWrapper.uuid);
      if (details != null) {
        final parsed = _healthKitBridge.parseWorkoutDetails(details);
        if (parsed != null) {
          _activeDuration = parsed.activeDuration;
          
          // 네이티브에서 직접 제공하는 지표가 있으면 우선 적용 (NRC 등 타사 앱 호환)
          if (parsed.elevationGain != null && parsed.elevationGain! > 0) {
            _elevationGain = parsed.elevationGain!;
          }
          if (parsed.averageCadence != null && parsed.averageCadence! > 0) {
            _avgCadence = parsed.averageCadence!.round();
          }
        }
      }
    } catch (e) {
      debugPrint('⚠️ WorkoutDetailProvider: Failed to fetch native details: $e');
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

  /// 케이던스 및 고도 정보를 가져옵니다. (네이티브 값이 없을 때만 폴백으로 실행)
  Future<void> _fetchCadenceAndElevation() async {
    try {
      final samples = await _healthService.getHealthDataFromTypes(
        dataWrapper.dateFrom,
        dataWrapper.dateTo,
        [HealthDataType.STEPS],
      );

      if (samples.isNotEmpty) {
        // 1. 케이던스 처리
        if (_avgCadence == 0) {
          // 소스별로 걸음수 그룹화
          final Map<String, double> sourceStepCounts = {};
          for (var s in samples) {
            final source = s.sourceName;
            final val = (s.value as NumericHealthValue).numericValue.toDouble();
            sourceStepCounts[source] = (sourceStepCounts[source] ?? 0) + val;
          }
          
          if (sourceStepCounts.isNotEmpty) {
            final duration = _activeDuration ?? dataWrapper.dateTo.difference(dataWrapper.dateFrom);
            
            if (duration.inMinutes > 0) {
              // 1) 최대 걸음수 확인 (기준점)
              final maxSteps = sourceStepCounts.values.reduce((a, b) => a > b ? a : b);
              
              // 2) 유효한 소스만 필터링 (최대값의 50% 이상인 것만 '성실한' 기록으로 인정)
              final validCadences = sourceStepCounts.values
                .where((steps) => steps >= maxSteps * 0.5)
                .map((steps) => steps / duration.inMinutes)
                .toList();
              
              // 3) 유효 소스들의 평균값 계산
              if (validCadences.isNotEmpty) {
                final sumCadence = validCadences.reduce((a, b) => a + b);
                _avgCadence = (sumCadence / validCadences.length).round();
                debugPrint('✅ WorkoutDetailProvider: Averaged cadence from ${validCadences.length} sources: $_avgCadence');
              }
            }
          }
        }

        // 2. 고도 상승 처리 (네이티브 값이 없을 때만)
        if (_elevationGain == 0) {
          // (고도 관련 샘플 처리 로직 추가 가능)
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
