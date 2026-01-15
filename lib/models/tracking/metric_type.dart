enum MetricType {
  distance,
  time,
  pace,
  heartRate,
  calories,
}

extension MetricTypeExtension on MetricType {
  String get label {
    switch (this) {
      case MetricType.distance: return 'DISTANCE';
      case MetricType.time: return 'TIME';
      case MetricType.pace: return 'PACE';
      case MetricType.heartRate: return 'HEART RATE';
      case MetricType.calories: return 'CALORIES';
    }
  }

  String get unit {
    switch (this) {
      case MetricType.distance: return 'km';
      case MetricType.time: return '';
      case MetricType.pace: return '/km';
      case MetricType.heartRate: return 'bpm';
      case MetricType.calories: return 'kcal';
    }
  }
}
