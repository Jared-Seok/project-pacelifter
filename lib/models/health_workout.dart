class HealthWorkout {
  final String workoutType;
  final DateTime startDate;
  final DateTime endDate;
  final double? distance; // meters
  final double? totalEnergyBurned; // kcal
  final String? sourceName;
  final Map<String, dynamic> metadata;

  HealthWorkout({
    required this.workoutType,
    required this.startDate,
    required this.endDate,
    this.distance,
    this.totalEnergyBurned,
    this.sourceName,
    this.metadata = const {},
  });

  Duration get duration => endDate.difference(startDate);

  double? get averageSpeed {
    if (distance == null || distance! <= 0) return null;
    // km/h 반환
    final durationHours = duration.inSeconds / 3600.0;
    final distanceKm = distance! / 1000.0;
    return distanceKm / durationHours;
  }

  factory HealthWorkout.fromXml(Map<String, dynamic> attributes) {
    return HealthWorkout(
      workoutType: attributes['workoutActivityType'] ?? 'Unknown',
      startDate: DateTime.parse(attributes['startDate'] ?? ''),
      endDate: DateTime.parse(attributes['endDate'] ?? ''),
      distance: attributes['totalDistance'] != null
          ? double.tryParse(attributes['totalDistance'])
          : null,
      totalEnergyBurned: attributes['totalEnergyBurned'] != null
          ? double.tryParse(attributes['totalEnergyBurned'])
          : null,
      sourceName: attributes['sourceName'],
      metadata: attributes,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'workoutType': workoutType,
      'startDate': startDate.toIso8601String(),
      'endDate': endDate.toIso8601String(),
      'distance': distance,
      'totalEnergyBurned': totalEnergyBurned,
      'sourceName': sourceName,
      'duration': duration.inSeconds,
      'averageSpeed': averageSpeed,
    };
  }

  @override
  String toString() {
    final distStr = distance != null
        ? '${(distance! / 1000).toStringAsFixed(2)} km'
        : 'N/A';
    return '$workoutType: $distStr, ${duration.inMinutes} min';
  }
}
