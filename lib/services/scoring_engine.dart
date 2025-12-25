import 'package:hive/hive.dart';
import 'package:health/health.dart';
import '../models/scoring/performance_scores.dart';
import '../models/sessions/workout_session.dart';
import '../models/user_profile.dart';
import 'workout_history_service.dart';
import 'profile_service.dart';
import 'health_service.dart';

/// Scoring Engine v3.0 (Discipline & Trend Focused)
/// 
/// 모든 지표를 '상대적 운동 추세(Discipline)'로 전환합니다.
/// 180일간의 평균 주당 빈도를 베이스라인으로 하여, 최근 7일간의 수행력을 평가합니다.
class ScoringEngine {
  static const String _scoresBoxName = 'user_scores';

  static final ScoringEngine _instance = ScoringEngine._internal();
  factory ScoringEngine() => _instance;
  ScoringEngine._internal();

  final _historyService = WorkoutHistoryService();
  final _profileService = ProfileService();
  final _healthService = HealthService();

  /// 점수 계산 및 업데이트 (메인 진입점)
  Future<PerformanceScores> calculateAndSaveScores() async {
    // 1. 데이터 로드 (최근 180일 베이스라인 확보)
    final sessions = _historyService.getRecentSessions(days: 180);
    
    // 2. Discipline 기반 점수 계산 (7d vs 180d Baseline)
    final enduranceScore = _calculateDisciplineScore(sessions, 'Endurance');
    final strengthScore = _calculateDisciplineScore(sessions, 'Strength');
    
    // 3. 컨디셔닝 점수는 기존의 생체 지표 및 ACWR 유지 (이미 상대 추세 지표임)
    final conditioningScore = await _calculateConditioningScore(sessions);

    // 4. 밸런스 점수 계산
    final balanceScore = _calculateHybridBalance(enduranceScore, strengthScore);

    // 5. 결과 객체 생성
    final scores = PerformanceScores(
      enduranceScore: enduranceScore,
      strengthScore: strengthScore,
      conditioningScore: conditioningScore,
      hybridBalanceScore: balanceScore,
      lastUpdated: DateTime.now(),
    );

    // 6. 저장
    await _saveScores(scores);
    return scores;
  }

  /// 최신 점수 불러오기
  PerformanceScores getLatestScores() {
    final box = Hive.box<PerformanceScores>(_scoresBoxName);
    return box.get('current') ?? PerformanceScores.initial();
  }

  Future<void> _saveScores(PerformanceScores scores) async {
    final box = Hive.box<PerformanceScores>(_scoresBoxName);
    await box.put('current', scores);
  }

  /// Discipline Score 산출 (추세 기반)
  /// 
  /// Logic:
  /// 1. 180일간 해당 카테고리의 총 횟수를 구해 '주당 평균 횟수' 산출 (Baseline)
  /// 2. 최근 7일간의 수행 횟수 산출 (Recent)
  /// 3. Baseline 대비 Recent 비율로 점수화
  double _calculateDisciplineScore(List<WorkoutSession> allSessions, String category) {
    final now = DateTime.now();
    final sevenDaysAgo = now.subtract(const Duration(days: 7));
    
    // 카테고리 필터링
    final categorySessions = allSessions.where((s) => 
      s.category == category || (category == 'Strength' && s.category == 'Hybrid')
    ).toList();

    if (categorySessions.isEmpty) return 0.0;

    // 1. Baseline: 180일 평균 주당 빈도
    // 실제 데이터가 있는 기간을 고려하여 계산 (신규 유저 배려)
    final firstSessionDate = categorySessions.map((s) => s.startTime).reduce((a, b) => a.isBefore(b) ? a : b);
    final daysDiff = now.difference(firstSessionDate).inDays.clamp(7, 180);
    final baselineWeeklyFreq = (categorySessions.length / daysDiff) * 7;

    // 2. Recent: 최근 7일 빈도
    final recentCount = categorySessions.where((s) => s.startTime.isAfter(sevenDaysAgo)).length.toDouble();

    // 3. Scoring
    if (baselineWeeklyFreq == 0) return recentCount > 0 ? 70.0 : 0.0;

    // 비율 계산 (최근 / 기준)
    final ratio = recentCount / baselineWeeklyFreq;

    // 점수 곡선: 
    // 1.0 (유지) -> 80점
    // 1.2 이상 (상승) -> 90~100점
    // 0.5 (하락) -> 40~50점
    double score = 0;
    if (ratio >= 1.2) {
      score = 90 + (ratio - 1.2) * 10;
    } else if (ratio >= 1.0) {
      score = 80 + (ratio - 1.0) * 50; // 1.0~1.2 사이에서 80~90
    } else if (ratio >= 0.5) {
      score = 40 + (ratio - 0.5) * 80; // 0.5~1.0 사이에서 40~80
    } else {
      score = ratio * 80; // 0.5 미만
    }

    return score.clamp(0, 100);
  }

  Future<double> _calculateConditioningScore(List<WorkoutSession> sessions) async {
    double? rhr;
    double? hrv;
    double? sleepHours;

    try {
      final now = DateTime.now();
      final yesterday = now.subtract(const Duration(days: 1));

      final rhrData = await _healthService.getHealthDataFromTypes(yesterday, now, [HealthDataType.RESTING_HEART_RATE]);
      if (rhrData.isNotEmpty) rhr = (rhrData.last.value as NumericHealthValue).numericValue.toDouble();

      final hrvData = await _healthService.getHealthDataFromTypes(yesterday, now, [HealthDataType.HEART_RATE_VARIABILITY_SDNN]);
      if (hrvData.isNotEmpty) hrv = (hrvData.last.value as NumericHealthValue).numericValue.toDouble();

      final sleepData = await _healthService.getHealthDataFromTypes(yesterday, now, [HealthDataType.SLEEP_ASLEEP]);
      if (sleepData.isNotEmpty) {
        double totalMinutes = 0;
        for (var s in sleepData) {
          totalMinutes += s.dateTo.difference(s.dateFrom).inMinutes;
        }
        sleepHours = totalMinutes / 60.0;
      }
    } catch (e) { /* ignore */ }

    // Recovery Score (RHR, HRV 추세 반영)
    final recoveryScore = _calculateRecoveryTrendScore(rhr, hrv);
    final sleepScore = _calculateSleepScore(sleepHours);

    // ACWR (Acute-Chronic Workload Ratio)
    final acuteLoad = _calculateLoadSum(sessions.where((s) => s.startTime.isAfter(DateTime.now().subtract(const Duration(days: 7)))).toList());
    final chronicLoad = _calculateLoadSum(sessions.where((s) => s.startTime.isAfter(DateTime.now().subtract(const Duration(days: 28)))).toList());
    
    // ACWR 0.8~1.3 is optimal (100 pts)
    double loadScore = 70;
    if (chronicLoad > 0) {
      final acwr = acuteLoad / (chronicLoad / 4);
      if (acwr >= 0.8 && acwr <= 1.3) loadScore = 100;
      else if (acwr > 1.5) loadScore = 40; // Overreaching
      else loadScore = (acwr / 0.8) * 100;
    }

    return (recoveryScore * 0.4 + loadScore * 0.4 + sleepScore * 0.2).clamp(0, 100);
  }

  double _calculateRecoveryTrendScore(double? rhr, double? hrv) {
    double score = 70; // 기본값
    if (rhr != null) {
      if (rhr <= 60) score += 15;
      else if (rhr >= 80) score -= 20;
    }
    if (hrv != null) {
      if (hrv >= 60) score += 15;
      else if (hrv <= 30) score -= 20;
    }
    return score.clamp(0, 100);
  }

  double _calculateSleepScore(double? hours) {
    if (hours == null) return 70;
    if (hours >= 7 && hours <= 9) return 100;
    if (hours < 6) return 50;
    return 80;
  }

  double _calculateLoadSum(List<WorkoutSession> sessions) {
    double sum = 0;
    for (var s in sessions) {
      if (s.category == 'Endurance') {
        sum += (s.totalDistance ?? 0) / 1000;
      } else {
        sum += (s.totalVolume ?? 0) / 1000;
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
}
