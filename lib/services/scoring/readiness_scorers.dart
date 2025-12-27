import 'dart:math';

/// 회복 점수 산출 클래스 (생체 지표 기반)
class RecoveryScorer {
  static double calculateRecoveryScore({
    required double? restingHeartRate, // 안정시 심박수
    required double? hrvSDNN, // 심박 변이도 (ms)
  }) {
    double score = 50; // 기본 중립 점수

    // 1. Resting Heart Rate (25점 만점 가점)
    if (restingHeartRate != null) {
      if (restingHeartRate <= 60) {
        score += 25;
      } else if (restingHeartRate <= 70) score += 20;
      else if (restingHeartRate <= 80) score += 10;
      else if (restingHeartRate <= 100) score += 5;
    }

    // 2. HRV (25점 만점 가점)
    if (hrvSDNN != null) {
      if (hrvSDNN >= 80) {
        score += 25;
      } else if (hrvSDNN >= 60) score += 20;
      else if (hrvSDNN >= 40) score += 10;
      else if (hrvSDNN >= 20) score += 5;
    }

    return score.clamp(0, 100);
  }
}

/// 훈련 부하 점수 산출 클래스 (ACWR: Acute-Chronic Workload Ratio)
class TrainingLoadScorer {
  static double calculateTrainingLoadScore({
    required double acuteLoad, // 최근 7일 부하
    required double chronicLoad, // 최근 28일 부하
  }) {
    if (chronicLoad == 0) return 70; // 데이터 부족 시 보통 점수

    final acwr = acuteLoad / (chronicLoad / 4); // 주간 평균 대비 최근 주 비율

    // 최적 범위 (Sweet Spot): 0.8 ~ 1.3
    if (acwr >= 0.8 && acwr <= 1.3) return 100;
    // 과훈련 위험 (Danger Zone): 1.5 이상
    if (acwr > 1.5) return max(0, 50 - (acwr - 1.5) * 100);
    // 디트레이닝 (부족): 0.5 이하
    return (acwr / 0.8 * 70).clamp(0, 100);
  }
}

/// 수면 점수 산출 클래스
class SleepScorer {
  static double calculateSleepScore({
    required double? sleepHours,
  }) {
    if (sleepHours == null) return 60; // 데이터 부족 시 보통

    if (sleepHours >= 7 && sleepHours <= 9) return 100;
    if (sleepHours > 9) return 80; // 과다 수면
    if (sleepHours >= 6) return 70;
    if (sleepHours >= 5) return 50;
    return 30; // 수면 부족
  }
}
