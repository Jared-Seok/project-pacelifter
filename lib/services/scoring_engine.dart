import 'package:hive/hive.dart';
import 'package:health/health.dart';
import '../models/scoring/performance_scores.dart';
import '../models/sessions/workout_session.dart';
import '../models/user_profile.dart';
import 'workout_history_service.dart';
import 'profile_service.dart';
import 'template_service.dart';
import 'health_service.dart';
import 'scoring/endurance_scorers.dart';
import 'scoring/strength_scorers.dart';
import 'scoring/conditioning_scorers.dart';

class ScoringEngine {
  static const String _scoresBoxName = 'user_scores';

  // Singleton instance
  static final ScoringEngine _instance = ScoringEngine._internal();

  factory ScoringEngine() {
    return _instance;
  }

  ScoringEngine._internal();

  final _historyService = WorkoutHistoryService();
  final _profileService = ProfileService();
  final _healthService = HealthService();

  /// 점수 계산 및 업데이트 (메인 진입점)
  Future<PerformanceScores> calculateAndSaveScores() async {
    // 1. 데이터 로드
    final sessions = _historyService.getRecentSessions(days: 90);
    final profile = await _profileService.getProfile();

    // 2. 각 영역별 점수 계산
    final enduranceScore = await _calculateEnduranceScore(sessions, profile);
    final strengthScore = await _calculateStrengthScore(sessions, profile);
    final conditioningScore = await _calculateConditioningScore(sessions);

    // 3. 밸런스 점수 계산
    final balanceScore = _calculateHybridBalance(enduranceScore, strengthScore);

    // 4. 결과 객체 생성
    final scores = PerformanceScores(
      enduranceScore: enduranceScore,
      strengthScore: strengthScore,
      conditioningScore: conditioningScore,
      hybridBalanceScore: balanceScore,
      lastUpdated: DateTime.now(),
    );

    // 5. 저장
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

  // --- 내부 계산 로직 ---

  Future<double> _calculateEnduranceScore(List<WorkoutSession> sessions, UserProfile? profile) async {
    final enduranceSessions = sessions.where((s) => s.category == 'Endurance').toList();
    if (enduranceSessions.isEmpty) return 0.0;

    final gender = profile?.gender ?? 'male';
    const age = 30;

    double totalPace = 0;
    int paceCount = 0;
    for (var s in enduranceSessions) {
      if (s.averagePace != null && s.averagePace! > 0) {
        totalPace += (s.averagePace! / 60);
        paceCount++;
      }
    }
    final avgPaceMin = paceCount > 0 ? totalPace / paceCount : 0.0;
    final paceScore = PaceScorer.calculatePaceScore(avgPaceMinPerKm: avgPaceMin, gender: gender);

    final totalDistanceKm = enduranceSessions.fold(0.0, (sum, s) => sum + (s.totalDistance ?? 0)) / 1000;
    final weeklyDistance = totalDistanceKm / (90 / 7);
    final weeklyFrequency = (enduranceSessions.length / (90 / 7)).ceil();
    final volumeScore = VolumeScorer.calculateVolumeScore(weeklyDistanceKm: weeklyDistance, weeklyFrequency: weeklyFrequency);

    final vo2Max = 14.5 + (4.8 * (1000 / (avgPaceMin.clamp(1, 20) * 60)) * 3.6);
    final vo2Score = VO2MaxScorer.calculateVO2MaxScore(vo2Max: vo2Max, gender: gender, age: age);

    return (vo2Score * 0.4 + paceScore * 0.4 + volumeScore * 0.2).clamp(0, 100);
  }

  Future<double> _calculateStrengthScore(List<WorkoutSession> sessions, UserProfile? profile) async {
    final strengthSessions = sessions.where((s) => s.category == 'Strength' || s.category == 'Hybrid').toList();
    if (strengthSessions.isEmpty) return 0.0;

    final bodyWeight = profile?.weight ?? 70.0;
    final gender = profile?.gender ?? 'male';

    final oneRMs = _calculateEstimated1RMs(strengthSessions);
    final relativeStrengthScore = RelativeStrengthScorer.calculateRelativeStrengthScore(
      oneRMs: oneRMs, bodyWeightKg: bodyWeight, gender: gender
    );

    final weeklyVolume = _calculateWeeklyVolume(strengthSessions);
    final volumeScore = StrengthVolumeScorer.calculateVolumeScore(weeklyVolumeTons: weeklyVolume, bodyWeightKg: bodyWeight);

    final balanceData = await _calculateMovementBalance(strengthSessions);
    final balanceScore = BalanceScorer.calculateBalanceScore(
      pushVolume: balanceData['push']!, pullVolume: balanceData['pull']!, legsVolume: balanceData['legs']!
    );

    return (relativeStrengthScore * 0.5 + volumeScore * 0.3 + balanceScore * 0.2).clamp(0, 100);
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
        for (var s in sleepData) totalMinutes += s.dateTo.difference(s.dateFrom).inMinutes;
        sleepHours = totalMinutes / 60.0;
      }
    } catch (e) { /* ignore */ }

    final recoveryScore = RecoveryScorer.calculateRecoveryScore(restingHeartRate: rhr, hrvSDNN: hrv);
    final sleepScore = SleepScorer.calculateSleepScore(sleepHours: sleepHours);

    final acuteLoad = _calculateLoadSum(sessions.where((s) => s.startTime.isAfter(DateTime.now().subtract(const Duration(days: 7)))).toList());
    final chronicLoad = _calculateLoadSum(sessions.where((s) => s.startTime.isAfter(DateTime.now().subtract(const Duration(days: 28)))).toList());
    final loadScore = TrainingLoadScorer.calculateTrainingLoadScore(acuteLoad: acuteLoad, chronicLoad: chronicLoad);

    return (recoveryScore * 0.4 + loadScore * 0.4 + sleepScore * 0.2).clamp(0, 100);
  }

  double _calculateLoadSum(List<WorkoutSession> sessions) {
    double sum = 0;
    for (var s in sessions) {
      if (s.category == 'Endurance') sum += (s.totalDistance ?? 0) / 1000;
      else sum += (s.totalVolume ?? 0) / 1000;
    }
    return sum;
  }

  Map<String, double> _calculateEstimated1RMs(List<WorkoutSession> sessions) {
    final Map<String, double> maxOneRMs = {};
    for (var session in sessions) {
      if (session.exerciseRecords == null) continue;
      for (var record in session.exerciseRecords!) {
        String? liftType;
        final name = record.exerciseName.toLowerCase();
        if (name.contains('squat')) liftType = 'squat';
        else if (name.contains('bench press')) liftType = 'bench_press';
        else if (name.contains('deadlift')) liftType = 'deadlift';

        if (liftType != null) {
          double sessionMax1RM = 0;
          for (var set in record.sets) {
            if (set.weight != null && set.repsCompleted != null && set.repsCompleted! > 0) {
              final e1rm = OneRMCalculator.estimate(weight: set.weight!, reps: set.repsCompleted!);
              if (e1rm > sessionMax1RM) sessionMax1RM = e1rm;
            }
          }
          if (sessionMax1RM > (maxOneRMs[liftType] ?? 0)) maxOneRMs[liftType] = sessionMax1RM;
        }
      }
    }
    return maxOneRMs;
  }

  double _calculateWeeklyVolume(List<WorkoutSession> sessions) {
    double totalVolumeKg = 0;
    for (var session in sessions) if (session.totalVolume != null) totalVolumeKg += session.totalVolume!;
    return (totalVolumeKg / (90 / 7)) / 1000.0;
  }

  Future<Map<String, double>> _calculateMovementBalance(List<WorkoutSession> sessions) async {
    double push = 0, pull = 0, legs = 0;
    for (var session in sessions) {
      if (session.exerciseRecords == null) continue;
      for (var record in session.exerciseRecords!) {
        final exercise = TemplateService.getExerciseById(record.exerciseId);
        final pattern = exercise?.movementPattern;
        final volume = record.totalVolume;
        if (pattern == 'push') push += volume;
        else if (pattern == 'pull') pull += volume;
        else if (pattern == 'squat' || pattern == 'hinge' || pattern == 'lunge' || record.exerciseName.toLowerCase().contains('squat')) legs += volume;
      }
    }
    return {'push': push, 'pull': pull, 'legs': legs};
  }

  double _calculateHybridBalance(double endurance, double strength) {
    final difference = (endurance - strength).abs();
    if (difference <= 10) return 100.0;
    if (difference >= 50) return 0.0;
    return 100.0 - (difference - 10) / 40 * 100;
  }
}