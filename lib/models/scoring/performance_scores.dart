import 'package:hive/hive.dart';

part 'performance_scores.g.dart';

/// 사용자의 종합 퍼포먼스 점수 모델
/// Endurance, Strength, Readiness 및 밸런스 지표를 저장
@HiveType(typeId: 40)
class PerformanceScores extends HiveObject {
  @HiveField(0)
  final double enduranceScore; // 0-100

  @HiveField(1)
  final double strengthScore; // 0-100

  @HiveField(2)
  final double conditioningScore; // 0-100 (Changed from readinessScore)

  @HiveField(3)
  final double hybridBalanceScore; // 0-100 (Endurance vs Strength 균형)

  @HiveField(4)
  final DateTime lastUpdated; // 마지막 계산 시각

  // 세부 지표 (선택적 저장, 분석용)
  @HiveField(5)
  final double? vo2MaxScore; // Endurance 세부

  @HiveField(6)
  final double? paceScore; // Endurance 세부

  @HiveField(7)
  final double? relativeStrengthScore; // Strength 세부

  @HiveField(8)
  final double? recoveryScore; // Conditioning 세부 (Changed from readiness)

  PerformanceScores({
    required this.enduranceScore,
    required this.strengthScore,
    required this.conditioningScore,
    required this.hybridBalanceScore,
    required this.lastUpdated,
    this.vo2MaxScore,
    this.paceScore,
    this.relativeStrengthScore,
    this.recoveryScore,
  });

  /// 초기 상태 (모든 점수 0)
  factory PerformanceScores.initial() {
    return PerformanceScores(
      enduranceScore: 0,
      strengthScore: 0,
      conditioningScore: 0,
      hybridBalanceScore: 0,
      lastUpdated: DateTime.now(),
    );
  }

  /// 점수 등급 반환 (Elite, Advanced, ...)
  String getGrade(double score) {
    if (score >= 90) return 'Elite';
    if (score >= 80) return 'Advanced';
    if (score >= 70) return 'Intermediate+';
    if (score >= 60) return 'Intermediate';
    if (score >= 50) return 'Beginner+';
    if (score >= 40) return 'Beginner';
    return 'Novice';
  }

  /// JSON 변환 (서버 동기화용)
  Map<String, dynamic> toJson() {
    return {
      'enduranceScore': enduranceScore,
      'strengthScore': strengthScore,
      'conditioningScore': conditioningScore,
      'readinessScore': conditioningScore, // 하위 호환성 위해 유지
      'hybridBalanceScore': hybridBalanceScore,
      'lastUpdated': lastUpdated.toIso8601String(),
      'vo2MaxScore': vo2MaxScore,
      'paceScore': paceScore,
      'relativeStrengthScore': relativeStrengthScore,
      'recoveryScore': recoveryScore,
    };
  }

  factory PerformanceScores.fromJson(Map<String, dynamic> json) {
    return PerformanceScores(
      enduranceScore: json['enduranceScore'] as double,
      strengthScore: json['strengthScore'] as double,
      conditioningScore: (json['conditioningScore'] ?? json['readinessScore'] ?? 0.0) as double,
      hybridBalanceScore: json['hybridBalanceScore'] as double,
      lastUpdated: DateTime.parse(json['lastUpdated'] as String),
      vo2MaxScore: json['vo2MaxScore'] as double?,
      paceScore: json['paceScore'] as double?,
      relativeStrengthScore: json['relativeStrengthScore'] as double?,
      recoveryScore: json['recoveryScore'] as double?,
    );
  }
}
