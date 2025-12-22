import 'dart:math';

/// VO2 Max 점수 산출 클래스
class VO2MaxScorer {
  // 성별 및 연령별 기준표 (American Heart Association)
  static const Map<String, Map<String, Map<String, double>>> standards = {
    'male': {
      '20-29': {'elite': 55.4, 'excellent': 51.1, 'good': 45.4, 'fair': 41.7, 'poor': 33.0},
      '30-39': {'elite': 54.0, 'excellent': 48.3, 'good': 44.0, 'fair': 40.0, 'poor': 31.5},
      '40-49': {'elite': 52.5, 'excellent': 46.4, 'good': 42.4, 'fair': 38.5, 'poor': 30.2},
      '50-59': {'elite': 48.9, 'excellent': 43.4, 'good': 39.2, 'fair': 35.2, 'poor': 26.1},
      '60+': {'elite': 45.7, 'excellent': 39.5, 'good': 35.3, 'fair': 31.8, 'poor': 20.5},
    },
    'female': {
      '20-29': {'elite': 49.6, 'excellent': 43.9, 'good': 39.5, 'fair': 35.2, 'poor': 24.0},
      '30-39': {'elite': 47.4, 'excellent': 42.4, 'good': 37.8, 'fair': 34.6, 'poor': 22.8},
      '40-49': {'elite': 45.3, 'excellent': 39.7, 'good': 36.3, 'fair': 32.3, 'poor': 21.0},
      '50-59': {'elite': 41.1, 'excellent': 36.7, 'good': 32.9, 'fair': 29.4, 'poor': 20.2},
      '60+': {'elite': 37.8, 'excellent': 32.9, 'good': 29.4, 'fair': 26.9, 'poor': 17.5},
    },
  };

  static double calculateVO2MaxScore({
    required double vo2Max,
    required String gender,
    required int age,
  }) {
    final genderKey = gender.toLowerCase() == 'female' ? 'female' : 'male';
    final ageGroup = _getAgeGroup(age);
    final benchmarks = standards[genderKey]![ageGroup]!;

    if (vo2Max >= benchmarks['elite']!) return 100.0;
    if (vo2Max >= benchmarks['excellent']!) {
      return 85 + 15 * ((vo2Max - benchmarks['excellent']!) /
             (benchmarks['elite']! - benchmarks['excellent']!));
    }
    if (vo2Max >= benchmarks['good']!) {
      return 70 + 15 * ((vo2Max - benchmarks['good']!) /
             (benchmarks['excellent']! - benchmarks['good']!));
    }
    if (vo2Max >= benchmarks['fair']!) {
      return 55 + 15 * ((vo2Max - benchmarks['fair']!) /
             (benchmarks['good']! - benchmarks['fair']!));
    }
    if (vo2Max >= benchmarks['poor']!) {
      return 40 + 15 * ((vo2Max - benchmarks['poor']!) /
             (benchmarks['fair']! - benchmarks['poor']!));
    }

    return max(0, 40 * (vo2Max / benchmarks['poor']!));
  }

  static String _getAgeGroup(int age) {
    if (age < 30) return '20-29';
    if (age < 40) return '30-39';
    if (age < 50) return '40-49';
    if (age < 60) return '50-59';
    return '60+';
  }

  /// Cooper Test (12분 달리기) 기반 VO2 Max 추정
  static double estimateVO2MaxCooper(double distanceMeters) {
    return (distanceMeters - 504.9) / 44.73;
  }
}

/// 페이스 점수 산출 클래스
class PaceScorer {
  static const Map<String, Map<String, double>> paceBenchmarks = {
    '10K': {
      'elite': 3.2,      // 32:00
      'advanced': 3.8,   // 38:00
      'intermediate': 4.3, // 43:00
      'beginner': 5.3,   // 53:00
      'novice': 6.3,     // 63:00
    },
  };

  static double calculatePaceScore({
    required double avgPaceMinPerKm,
    required String gender,
  }) {
    if (avgPaceMinPerKm <= 0) return 0;

    final genderAdjustment = gender.toLowerCase() == 'female' ? 1.1 : 1.0;
    final adjustedPace = avgPaceMinPerKm / genderAdjustment;
    final benchmarks = paceBenchmarks['10K']!;

    if (adjustedPace <= benchmarks['elite']!) return 100.0;
    if (adjustedPace <= benchmarks['advanced']!) {
      return 85 + 15 * ((benchmarks['advanced']! - adjustedPace) /
             (benchmarks['advanced']! - benchmarks['elite']!));
    }
    if (adjustedPace <= benchmarks['intermediate']!) {
      return 70 + 15 * ((benchmarks['intermediate']! - adjustedPace) /
             (benchmarks['intermediate']! - benchmarks['advanced']!));
    }
    if (adjustedPace <= benchmarks['beginner']!) {
      return 55 + 15 * ((benchmarks['beginner']! - adjustedPace) /
             (benchmarks['beginner']! - benchmarks['intermediate']!));
    }
    if (adjustedPace <= benchmarks['novice']!) {
      return 40 + 15 * ((benchmarks['novice']! - adjustedPace) /
             (benchmarks['novice']! - benchmarks['beginner']!));
    }

    return max(0, 40 * (benchmarks['novice']! / adjustedPace));
  }
}

/// 훈련량 점수 산출 클래스
class VolumeScorer {
  static double calculateVolumeScore({
    required double weeklyDistanceKm,
    required int weeklyFrequency,
  }) {
    double distanceScore = 0;
    if (weeklyDistanceKm >= 80) distanceScore = 60;
    else if (weeklyDistanceKm >= 60) distanceScore = 50 + 10 * ((weeklyDistanceKm - 60) / 20);
    else if (weeklyDistanceKm >= 40) distanceScore = 40 + 10 * ((weeklyDistanceKm - 40) / 20);
    else if (weeklyDistanceKm >= 20) distanceScore = 30 + 10 * ((weeklyDistanceKm - 20) / 20);
    else if (weeklyDistanceKm >= 10) distanceScore = 20 + 10 * ((weeklyDistanceKm - 10) / 10);
    else distanceScore = 20 * (weeklyDistanceKm / 10);

    double frequencyScore = 0;
    if (weeklyFrequency >= 6) frequencyScore = 40;
    else if (weeklyFrequency >= 1) frequencyScore = 10 + 6 * (weeklyFrequency - 1);

    return (distanceScore + frequencyScore).clamp(0, 100);
  }
}
