import 'package:hive/hive.dart';
import 'package:health/health.dart';
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
    final condResult = await _calculateDetailedConditioning(unifiedWorkouts);

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

      hybridBalanceScore: _calculateHybridBalance(endResult['score'], strResult['score']),
      lastUpdated: now,
    );

    await _saveScores(scores);
    return scores;
  }

  /// 로컬 세션과 HealthKit 데이터를 중복 없이 통합
  Future<List<WorkoutDataWrapper>> _getUnifiedWorkouts({int days = 180}) async {
    final now = DateTime.now();
    final startDate = now.subtract(Duration(days: days));

    // A. 로컬 세션 로드
    final localSessions = _historyService.getRecentSessions(days: days);
    
    // B. HealthKit 데이터 로드
    final healthData = await _healthService.getHealthDataFromTypes(
      startDate, now, [HealthDataType.WORKOUT]
    );

    final List<WorkoutDataWrapper> unified = [];
    final Set<String> linkedHealthIds = {};

    // 1. 로컬 세션 기반으로 매핑 (연동된 Health ID 수집)
    for (var session in localSessions) {
      if (session.healthKitWorkoutId != null) {
        linkedHealthIds.add(session.healthKitWorkoutId!);
      }
      unified.add(WorkoutDataWrapper(session: session));
    }

    // 2. 연동되지 않은 순수 HealthKit 데이터 추가
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

    // Baseline: 주당 평균 빈도
    final firstDate = categoryWorkouts.map((w) => w.dateFrom).reduce((a, b) => a.isBefore(b) ? a : b);
    final daysDiff = now.difference(firstDate).inDays.clamp(7, 180);
    final baselineFreq = (categoryWorkouts.length / daysDiff) * 7;

    // Recent: 7일간 데이터
    final recentWorkouts = categoryWorkouts.where((w) => w.dateFrom.isAfter(sevenDaysAgo)).toList();
    final weeklyFreq = recentWorkouts.length.toDouble();

    // 누적 지표 (Endurance: Km, Strength: Ton)
    double totalMetric = 0;
    for (var w in recentWorkouts) {
      if (category == 'Endurance') {
        if (w.session != null) {
          totalMetric += (w.session!.totalDistance ?? 0) / 1000;
        } else if (w.healthData != null && w.healthData!.value is WorkoutHealthValue) {
          totalMetric += ((w.healthData!.value as WorkoutHealthValue).totalDistance ?? 0) / 1000;
        }
      } else {
        // Strength: 로컬 세션 기록이 있는 경우에만 볼륨 합산 가능
        totalMetric += (w.session?.totalVolume ?? 0) / 1000;
      }
    }

    // Scoring Curve
    double score = 0;
    if (baselineFreq > 0) {
      final ratio = weeklyFreq / baselineFreq;
      if (ratio >= 1.2) score = 90 + (ratio - 1.2) * 10;
      else if (ratio >= 1.0) score = 80 + (ratio - 1.0) * 50;
      else if (ratio >= 0.5) score = 40 + (ratio - 0.5) * 80;
      else score = ratio * 80;
    } else {
      score = weeklyFreq > 0 ? 70.0 : 0.0;
    }

    return {
      'score': score.clamp(0, 100),
      'weeklyFreq': weeklyFreq,
      'baselineFreq': baselineFreq,
      'totalMetric': totalMetric,
    };
  }

  Future<Map<String, dynamic>> _calculateDetailedConditioning(List<WorkoutDataWrapper> workouts) async {
    double? rhr;
    double? hrv;
    try {
      final now = DateTime.now();
      final yesterday = now.subtract(const Duration(days: 1));
      final rhrData = await _healthService.getHealthDataFromTypes(yesterday, now, [HealthDataType.RESTING_HEART_RATE]);
      if (rhrData.isNotEmpty) rhr = (rhrData.last.value as NumericHealthValue).numericValue.toDouble();
      final hrvData = await _healthService.getHealthDataFromTypes(yesterday, now, [HealthDataType.HEART_RATE_VARIABILITY_SDNN]);
      if (hrvData.isNotEmpty) hrv = (hrvData.last.value as NumericHealthValue).numericValue.toDouble();
    } catch (e) {}

    // ACWR (Load Sum 기반)
    final acuteLoad = _calculateLoadSum(workouts.where((w) => w.dateFrom.isAfter(DateTime.now().subtract(const Duration(days: 7)))).toList());
    final chronicLoad = _calculateLoadSum(workouts.where((w) => w.dateFrom.isAfter(DateTime.now().subtract(const Duration(days: 28)))).toList());
    
    double acwr = 1.0;
    double loadScore = 70;
    if (chronicLoad > 0) {
      acwr = acuteLoad / (chronicLoad / 4);
      if (acwr >= 0.8 && acwr <= 1.3) loadScore = 100;
      else if (acwr > 1.5) loadScore = 40;
      else loadScore = (acwr / 0.8) * 100;
    }

    final score = (loadScore * 0.6 + (rhr != null ? 20 : 10) + (hrv != null ? 20 : 10)).clamp(0, 100);
    return {'score': score, 'acwr': acwr, 'rhr': rhr, 'hrv': hrv};
  }

  double _calculateLoadSum(List<WorkoutDataWrapper> workouts) {
    double sum = 0;
    for (var w in workouts) {
      String cat = 'Unknown';
      double dist = 0;
      double vol = 0;

      if (w.session != null) {
        cat = w.session!.category;
        dist = w.session!.totalDistance ?? 0;
        vol = w.session!.totalVolume ?? 0;
      } else if (w.healthData != null && w.healthData!.value is WorkoutHealthValue) {
        final val = w.healthData!.value as WorkoutHealthValue;
        cat = WorkoutUIUtils.getWorkoutCategory(val.workoutActivityType.name);
        dist = val.totalDistance?.toDouble() ?? 0;
      }

      if (cat == 'Endurance') sum += dist / 1000;
      else sum += vol / 1000;
    }
    return sum;
  }

  double _calculateHybridBalance(double endurance, double strength) {
    final difference = (endurance - strength).abs();
    if (difference <= 10) return 100.0;
    if (difference >= 50) return 0.0;
    return 100.0 - (difference - 10) / 40 * 100;
  }

  PerformanceScores getLatestScores() {
    final box = Hive.box<PerformanceScores>(_scoresBoxName);
    return box.get('current') ?? PerformanceScores.initial();
  }

  Future<void> _saveScores(PerformanceScores scores) async {
    final box = Hive.box<PerformanceScores>(_scoresBoxName);
    await box.put('current', scores);
  }
}
