import 'package:hive/hive.dart';
import 'package:health/health.dart';
import 'package:flutter/foundation.dart';
import '../models/scoring/performance_scores.dart';
import '../models/sessions/workout_session.dart';
import '../models/workout_data_wrapper.dart';
import 'workout_history_service.dart';
import 'profile_service.dart';
import 'health_service.dart';
import '../utils/workout_ui_utils.dart';

/// Scoring Engine v3.2 (Unified Data Source: Local + HealthKit)
class ScoringEngine {
  static const String _scoresBoxName = 'user_scores';

  static final ScoringEngine _instance = ScoringEngine._internal();
  factory ScoringEngine() => _instance;
  ScoringEngine._internal();

  final _historyService = WorkoutHistoryService();
  final _profileService = ProfileService();
  final _healthService = HealthService();

  /// 점수 계산 및 업데이트 (로컬 세션 + HealthKit 데이터 통합)
  Future<PerformanceScores> calculateAndSaveScores() async {
    // 1. 모든 데이터 통합 수집
    final unifiedWorkouts = await _getUnifiedWorkouts(days: 180);
    final now = DateTime.now();

    // 2. Endurance 상세 데이터 산출
    final endResult = _calculateDetailedMetrics(unifiedWorkouts, 'Endurance');
    
    // 3. Strength 상세 데이터 산출
    final strResult = _calculateDetailedMetrics(unifiedWorkouts, 'Strength');

    // 4. 컨디셔닝 상세
    final userProfile = await _profileService.getProfile();
    final condResult = await _calculateDetailedConditioning(unifiedWorkouts, userProfile).timeout(
      const Duration(seconds: 10),
      onTimeout: () => {
        'score': 0.0,
        'acwr': 1.0,
        'rhr': null,
        'hrv': null,
      },
    );

    // 5. 결과 객체 생성
    final scores = PerformanceScores(
      enduranceScore: endResult['score'],
      enduranceWeeklyFreq: endResult['weeklyFreq'],
      enduranceBaselineFreq: endResult['baselineFreq'],
      totalDistanceKm: endResult['totalMetric'],
      
      strengthScore: strResult['score'],
      strengthWeeklyFreq: strResult['weeklyFreq'],
      strengthBaselineFreq: strResult['baselineFreq'],
      totalVolumeTon: strResult['totalMetric'],

      conditioningScore: condResult['score'],
      acwr: condResult['acwr'],
      avgRestingHeartRate: condResult['rhr'],
      avgHRV: condResult['hrv'],

      hybridBalanceScore: _calculateHybridBalance(endResult['score'].toDouble(), strResult['score'].toDouble()),
      lastUpdated: now,
    );

    await _saveScores(scores);
    return scores;
  }

  /// 로컬 세션과 HealthKit 데이터를 중복 없이 통합
  Future<List<WorkoutDataWrapper>> _getUnifiedWorkouts({int days = 365}) async {
    // A. 로컬 세션 로드 (Full Sync 시 모든 과거 데이터가 여기 저장됨)
    final localSessions = await _historyService.getRecentSessions(days: days);
    
    // B. HealthKit 데이터 로드 (최근 데이터만 보완적으로 가져옴)
    final healthData = await _healthService.fetchWorkoutData(days: 30).timeout(
      const Duration(seconds: 10),
      onTimeout: () => [],
    );

    final List<WorkoutDataWrapper> unified = [];
    final Set<String> linkedHealthIds = {};

    // 1. 로컬 세션 기반으로 매핑
    for (var session in localSessions) {
      if (session.healthKitWorkoutId != null) {
        linkedHealthIds.add(session.healthKitWorkoutId!);
      }
      unified.add(WorkoutDataWrapper(session: session));
    }

    // 2. 연동되지 않은 HealthKit 데이터 추가 (최근 30일 내 누락분)
    for (var data in healthData) {
      if (!linkedHealthIds.contains(data.uuid)) {
        unified.add(WorkoutDataWrapper(healthData: data));
      }
    }

    return unified;
  }

  /// 상세 메트릭 계산기 (WorkoutDataWrapper 리스트 기반)
  Map<String, dynamic> _calculateDetailedMetrics(List<WorkoutDataWrapper> workouts, String category) {
    final now = DateTime.now();
    final sevenDaysAgo = now.subtract(const Duration(days: 7));
    
    // 카테고리에 맞는 운동 필터링
    final categoryWorkouts = workouts.where((w) {
      String cat = 'Unknown';
      if (w.session != null) {
        cat = w.session!.category;
      } else if (w.healthData != null && w.healthData!.value is WorkoutHealthValue) {
        final type = (w.healthData!.value as WorkoutHealthValue).workoutActivityType.name;
        cat = WorkoutUIUtils.getWorkoutCategory(type);
      }
      return cat == category || (category == 'Strength' && cat == 'Hybrid');
    }).toList();

    if (categoryWorkouts.isEmpty) {
      return {'score': 0.0, 'weeklyFreq': 0.0, 'baselineFreq': 0.0, 'totalMetric': 0.0};
    }

    // 1. 빈도 점수 (Frequency Score - 70%)
    final firstDate = categoryWorkouts.map((w) => w.dateFrom).reduce((a, b) => a.isBefore(b) ? a : b);
    final daysDiff = now.difference(firstDate).inDays.clamp(7, 180);
    final baselineFreq = (categoryWorkouts.length.toDouble() / daysDiff.toDouble()) * 7.0;

    final recentWorkouts = categoryWorkouts.where((w) => w.dateFrom.isAfter(sevenDaysAgo)).toList();
    final weeklyFreq = recentWorkouts.length.toDouble();

    double freqScore = 0;
    if (baselineFreq > 0) {
      final ratio = weeklyFreq / baselineFreq;
      if (ratio >= 1.2) freqScore = 90 + (ratio - 1.2) * 10;
      else if (ratio >= 1.0) freqScore = 80 + (ratio - 1.0) * 50;
      else if (ratio >= 0.5) freqScore = 40 + (ratio - 0.5) * 80;
      else freqScore = ratio * 80;
    } else {
      freqScore = weeklyFreq > 0 ? 70.0 : 0.0;
    }

    // 2. 누적 지표 점수 (Metric Score - 30%)
    double totalMetric = 0; // Endurance: Km, Strength: Ton
    double baselineMetric = 0;

    // 베이스라인 메트릭 계산 (주당 평균)
    double allTimeTotalMetric = 0;
    for (var w in categoryWorkouts) {
      double m = 0;
      if (category == 'Endurance') {
        if (w.session != null) m = (w.session!.totalDistance?.toDouble() ?? 0.0) / 1000.0;
        else if (w.healthData?.value is WorkoutHealthValue) m = ((w.healthData!.value as WorkoutHealthValue).totalDistance?.toDouble() ?? 0.0) / 1000.0;
      } else {
        // Strength Volume Fallback (최근 7일 미만 데이터 시 추정치 우선)
        if (w.session != null && (w.session!.totalVolume ?? 0) > 0) {
          m = w.session!.totalVolume!.toDouble() / 1000.0;
        } else {
          // Fallback: kcal or duration based estimation
          final kcal = w.session?.calories ?? (w.healthData?.value as WorkoutHealthValue?)?.totalEnergyBurned?.toDouble() ?? 0.0;
          final durationMin = w.dateTo.difference(w.dateFrom).inMinutes;
          m = (kcal * 0.5 + durationMin * 2.0) / 1000.0; // Rough estimation: 1kcal ~ 0.5kg, 1min ~ 2kg
        }
      }
      allTimeTotalMetric += m;
    }
    baselineMetric = (allTimeTotalMetric / daysDiff.toDouble()) * 7.0;

    // 최근 7일 메트릭
    for (var w in recentWorkouts) {
      if (category == 'Endurance') {
        if (w.session != null) totalMetric += (w.session!.totalDistance?.toDouble() ?? 0.0) / 1000.0;
        else if (w.healthData?.value is WorkoutHealthValue) totalMetric += ((w.healthData!.value as WorkoutHealthValue).totalDistance?.toDouble() ?? 0.0) / 1000.0;
      } else {
        if (w.session != null && (w.session!.totalVolume ?? 0) > 0) {
          totalMetric += w.session!.totalVolume!.toDouble() / 1000.0;
        } else {
          final kcal = w.session?.calories ?? (w.healthData?.value as WorkoutHealthValue?)?.totalEnergyBurned?.toDouble() ?? 0.0;
          final durationMin = w.dateTo.difference(w.dateFrom).inMinutes;
          totalMetric += (kcal * 0.5 + durationMin * 2.0) / 1000.0;
        }
      }
    }

    double metricScore = 0;
    if (baselineMetric > 0) {
      final ratio = totalMetric / baselineMetric;
      if (ratio >= 1.2) metricScore = 90 + (ratio - 1.2) * 10;
      else if (ratio >= 1.0) metricScore = 80 + (ratio - 1.0) * 50;
      else if (ratio >= 0.5) metricScore = 40 + (ratio - 0.5) * 80;
      else metricScore = ratio * 80;
    } else {
      metricScore = totalMetric > 0 ? 70.0 : 0.0;
    }

    // 최종 합산 (0.7 Frequency + 0.3 Metric)
    final finalScore = (freqScore * 0.7 + metricScore * 0.3).clamp(0, 100);

    return {
      'score': finalScore,
      'weeklyFreq': weeklyFreq,
      'baselineFreq': baselineFreq,
      'totalMetric': totalMetric,
    };
  }

  Future<Map<String, dynamic>> _calculateDetailedConditioning(List<WorkoutDataWrapper> workouts, dynamic userProfile) async {
    double? rhr;
    double? hrv;
    try {
      final now = DateTime.now();
      final yesterday = now.subtract(const Duration(days: 1));
      
      // Parallel fetch for RHR and HRV (optimized)
      final healthData = await _healthService.getHealthDataFromTypes(
        yesterday, 
        now, 
        [HealthDataType.RESTING_HEART_RATE, HealthDataType.HEART_RATE_VARIABILITY_SDNN]
      );

      for (var data in healthData) {
        if (data.type == HealthDataType.RESTING_HEART_RATE) {
          rhr = (data.value as NumericHealthValue).numericValue.toDouble();
        } else if (data.type == HealthDataType.HEART_RATE_VARIABILITY_SDNN) {
          hrv = (data.value as NumericHealthValue).numericValue.toDouble();
        }
      }
    } catch (e) {
      debugPrint('⚠️ [ScoringEngine] Error fetching conditioning data: $e');
    }

    // ACWR (Load Sum 기반)
    final acuteLoad = _calculateLoadSum(workouts.where((w) => w.dateFrom.isAfter(DateTime.now().subtract(const Duration(days: 7)))).toList());
    final chronicLoad = _calculateLoadSum(workouts.where((w) => w.dateFrom.isAfter(DateTime.now().subtract(const Duration(days: 28)))).toList());
    
    double acwr = 1.0;
    double loadScore = 70;
    if (chronicLoad > 0) {
      acwr = acuteLoad / (chronicLoad / 4 + 0.01);
      if (acwr >= 0.8 && acwr <= 1.3) loadScore = 100;
      else if (acwr > 1.5) loadScore = 40;
      else if (acwr < 0.8) loadScore = (acwr / 0.8) * 100;
      else loadScore = 100 - (acwr - 1.3) * 200; // 1.5일 때 60점 근처로 하락
    }

    // Watch가 없을 경우 (RHR/HRV 데이터 부재) ACWR 100% 반영
    if (rhr == null && hrv == null) {
      return {'score': loadScore.clamp(0, 100), 'acwr': acwr, 'rhr': null, 'hrv': null};
    }

    // RHR 보정 (나이 적용)
    double recoveryScore = 50;
    if (userProfile != null && userProfile.birthDate != null) {
      final age = DateTime.now().year - userProfile.birthDate!.year;
      // 노멀 RHR은 보통 60~80, 운동선수는 40~60. 간단한 보정 수행.
      if (rhr != null) {
        if (rhr < 60) recoveryScore += 25;
        else if (rhr > 80) recoveryScore -= 15;
      }
    }
    if (hrv != null && hrv > 50) recoveryScore += 25;

    final finalScore = (loadScore * 0.6 + recoveryScore * 0.4).clamp(0, 100);
    return {'score': finalScore, 'acwr': acwr, 'rhr': rhr, 'hrv': hrv};
  }

  double _calculateLoadSum(List<WorkoutDataWrapper> workouts) {
    double sum = 0;
    for (var w in workouts) {
      String cat = 'Unknown';
      double dist = 0;
      double vol = 0;

      if (w.session != null) {
        cat = w.session!.category;
        dist = (w.session!.totalDistance ?? 0).toDouble();
        vol = (w.session!.totalVolume ?? 0).toDouble();
      } else if (w.healthData != null && w.healthData!.value is WorkoutHealthValue) {
        final val = w.healthData!.value as WorkoutHealthValue;
        cat = WorkoutUIUtils.getWorkoutCategory(val.workoutActivityType.name);
        dist = (val.totalDistance ?? 0).toDouble();
      }

      if (cat == 'Endurance') {
        sum += dist / 1000.0;
      } else {
        sum += vol / 1000.0;
      }
    }
    return sum;
  }

  double _calculateHybridBalance(double endurance, double strength) {
    final difference = (endurance - strength).abs();
    if (difference <= 10) return 100.0;
    if (difference >= 50) return 0.0;
    return 100.0 - (difference - 10) / 40 * 100;
  }

  Future<PerformanceScores> getLatestScores() async {
    final box = await _getScoresBox();
    if (box is Box<PerformanceScores>) {
      return box.get('current') ?? PerformanceScores.initial();
    } else {
      return await (box as LazyBox<PerformanceScores>).get('current') ?? PerformanceScores.initial();
    }
  }

  Future<void> _saveScores(PerformanceScores scores) async {
    final box = await _getScoresBox();
    if (box is Box<PerformanceScores>) {
      await box.put('current', scores);
    } else {
      await (box as LazyBox<PerformanceScores>).put('current', scores);
    }
  }

  Future<BoxBase<PerformanceScores>> _getScoresBox() async {
    if (Hive.isBoxOpen(_scoresBoxName)) {
      try {
        return Hive.box<PerformanceScores>(_scoresBoxName);
      } catch (_) {
        return Hive.lazyBox<PerformanceScores>(_scoresBoxName);
      }
    }
    return await Hive.openBox<PerformanceScores>(_scoresBoxName);
  }
}
