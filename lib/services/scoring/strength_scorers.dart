import 'dart:math';

/// 1RM 추정 계산기 (Epley Formula)
class OneRMCalculator {
  static double estimate({required double weight, required int reps}) {
    if (reps == 1) return weight;
    if (reps == 0) return 0.0;
    
    // Epley Formula: 1RM = w * (1 + r/30)
    return weight * (1 + reps / 30.0);
  }
}

/// 상대 근력 점수 산출 클래스 (체중 대비 중량)
class RelativeStrengthScorer {
  // 체중 대비 배수 기준 (남성 기준, 여성은 0.8배 적용)
  static const Map<String, Map<String, double>> strengthStandards = {
    'squat': {
      'elite': 2.5,
      'advanced': 2.0,
      'intermediate': 1.5,
      'novice': 1.0,
      'beginner': 0.5,
    },
    'bench_press': {
      'elite': 1.75,
      'advanced': 1.5,
      'intermediate': 1.25,
      'novice': 1.0,
      'beginner': 0.5,
    },
    'deadlift': {
      'elite': 2.75,
      'advanced': 2.25,
      'intermediate': 1.75,
      'novice': 1.25,
      'beginner': 0.75,
    },
  };

  static double calculateRelativeStrengthScore({
    required Map<String, double> oneRMs, // {'squat': 120.0, ...}
    required double bodyWeightKg,
    required String gender,
  }) {
    if (bodyWeightKg <= 0) return 0;

    final genderMultiplier = gender.toLowerCase() == 'female' ? 0.8 : 1.0;
    double totalScore = 0;
    int liftCount = 0;

    for (final entry in oneRMs.entries) {
      final liftType = entry.key; // 'squat', 'bench_press', 'deadlift'
      final oneRM = entry.value;

      // 표준 데이터에 없는 운동은 점수 계산 제외 (또는 기본값 적용)
      if (!strengthStandards.containsKey(liftType)) continue;

      final relativeStrength = (oneRM / bodyWeightKg) / genderMultiplier;
      final benchmarks = strengthStandards[liftType]!;

      double liftScore = 0;
      if (relativeStrength >= benchmarks['elite']!) {
        liftScore = 100;
      } else if (relativeStrength >= benchmarks['advanced']!) {
        liftScore = 85 + 15 * ((relativeStrength - benchmarks['advanced']!) /
                   (benchmarks['elite']! - benchmarks['advanced']!));
      } else if (relativeStrength >= benchmarks['intermediate']!) {
        liftScore = 70 + 15 * ((relativeStrength - benchmarks['intermediate']!) /
                   (benchmarks['advanced']! - benchmarks['intermediate']!));
      } else if (relativeStrength >= benchmarks['novice']!) {
        liftScore = 55 + 15 * ((relativeStrength - benchmarks['novice']!) /
                   (benchmarks['intermediate']! - benchmarks['novice']!));
      } else if (relativeStrength >= benchmarks['beginner']!) {
        liftScore = 40 + 15 * ((relativeStrength - benchmarks['beginner']!) /
                   (benchmarks['novice']! - benchmarks['beginner']!));
      } else {
        liftScore = max(0, 40 * (relativeStrength / benchmarks['beginner']!));
      }

      totalScore += liftScore;
      liftCount++;
    }

    return liftCount > 0 ? totalScore / liftCount : 0.0;
  }
}

/// 근력 훈련량 점수 산출 클래스
class StrengthVolumeScorer {
  static double calculateVolumeScore({
    required double weeklyVolumeTons, // 톤 단위 (kg * reps / 1000)
    required double bodyWeightKg,
  }) {
    if (bodyWeightKg <= 0) return 0;

    // 체중 대비 주간 볼륨 계수
    final relativeVolume = weeklyVolumeTons * 1000 / bodyWeightKg;

    if (relativeVolume >= 150) return 100;
    if (relativeVolume >= 120) return 85 + 15 * ((relativeVolume - 120) / 30);
    if (relativeVolume >= 90) return 70 + 15 * ((relativeVolume - 90) / 30);
    if (relativeVolume >= 60) return 55 + 15 * ((relativeVolume - 60) / 30);
    if (relativeVolume >= 30) return 40 + 15 * ((relativeVolume - 30) / 30);

    return max(0, 40 * (relativeVolume / 30));
  }
}

/// 훈련 균형 점수 산출 클래스
class BalanceScorer {
  static double calculateBalanceScore({
    required double pushVolume,
    required double pullVolume,
    required double legsVolume,
  }) {
    final totalVolume = pushVolume + pullVolume + legsVolume;
    if (totalVolume == 0) return 0;

    final pushRatio = pushVolume / totalVolume;
    final pullRatio = pullVolume / totalVolume;
    final legsRatio = legsVolume / totalVolume;

    // 이상적 비율: Push 30%, Pull 30%, Legs 40%
    final idealRatios = {'push': 0.30, 'pull': 0.30, 'legs': 0.40};
    
    double totalDeviation = 0;
    totalDeviation += (pushRatio - idealRatios['push']!).abs();
    totalDeviation += (pullRatio - idealRatios['pull']!).abs();
    totalDeviation += (legsRatio - idealRatios['legs']!).abs();

    // 총 편차가 0.2 이하면 100점, 0.6 이상이면 0점
    if (totalDeviation <= 0.2) return 100;
    if (totalDeviation >= 0.6) return 0;

    return 100 - ((totalDeviation - 0.2) / 0.4 * 100);
  }
}
