import 'package:hive/hive.dart';

part 'performance_scores.g.dart';

/// 사용자의 종합 퍼포먼스 점수 모델
/// Endurance, Strength, Conditioning 및 상세 분석 지표를 저장
@HiveType(typeId: 40)
class PerformanceScores extends HiveObject {
  @HiveField(0)
  final double enduranceScore; // 0-100

  @HiveField(1)
  final double strengthScore; // 0-100

  @HiveField(2)
  final double conditioningScore; // 0-100

  @HiveField(3)
  final double hybridBalanceScore; // 0-100

  @HiveField(4)
  final DateTime lastUpdated;

  // 상세 분석 데이터 (인사이트 화면용)
  
  // 1. Endurance 상세
  @HiveField(9)
  final double enduranceWeeklyFreq; // 최근 7일 운동 횟수
  @HiveField(10)
  final double enduranceBaselineFreq; // 베이스라인 주당 평균 횟수
  @HiveField(11)
  final double totalDistanceKm; // 최근 7일 누적 거리

  // 2. Strength 상세
  @HiveField(12)
  final double strengthWeeklyFreq; // 최근 7일 운동 횟수
  @HiveField(13)
  final double strengthBaselineFreq; // 베이스라인 주당 평균 횟수
  @HiveField(14)
  final double totalVolumeTon; // 최근 7일 누적 볼륨 (톤)

  // 3. Conditioning 상세
  @HiveField(15)
  final double acwr; // Acute-Chronic Workload Ratio
  @HiveField(16)
  final double? avgRestingHeartRate;
  @HiveField(17)
  final double? avgHRV;

  PerformanceScores({
    required this.enduranceScore,
    required this.strengthScore,
    required this.conditioningScore,
    required this.hybridBalanceScore,
    required this.lastUpdated,
    this.enduranceWeeklyFreq = 0,
    this.enduranceBaselineFreq = 0,
    this.totalDistanceKm = 0,
    this.strengthWeeklyFreq = 0,
    this.strengthBaselineFreq = 0,
    this.totalVolumeTon = 0,
    this.acwr = 1.0,
    this.avgRestingHeartRate,
    this.avgHRV,
  });

  factory PerformanceScores.initial() {
    return PerformanceScores(
      enduranceScore: 0,
      strengthScore: 0,
      conditioningScore: 0,
      hybridBalanceScore: 0,
      lastUpdated: DateTime.now(),
    );
  }

  String getGrade(double score) {
    if (score >= 90) return 'Elite';
    if (score >= 80) return 'Advanced';
    if (score >= 70) return 'Intermediate+';
    if (score >= 60) return 'Intermediate';
    if (score >= 50) return 'Beginner+';
    if (score >= 40) return 'Beginner';
    return 'Novice';
  }

  Map<String, dynamic> toJson() {
    return {
      'enduranceScore': enduranceScore,
      'strengthScore': strengthScore,
      'conditioningScore': conditioningScore,
      'hybridBalanceScore': hybridBalanceScore,
      'lastUpdated': lastUpdated.toIso8601String(),
      'enduranceWeeklyFreq': enduranceWeeklyFreq,
      'enduranceBaselineFreq': enduranceBaselineFreq,
      'totalDistanceKm': totalDistanceKm,
      'strengthWeeklyFreq': strengthWeeklyFreq,
      'strengthBaselineFreq': strengthBaselineFreq,
      'totalVolumeTon': totalVolumeTon,
      'acwr': acwr,
      'avgRestingHeartRate': avgRestingHeartRate,
      'avgHRV': avgHRV,
    };
  }
}