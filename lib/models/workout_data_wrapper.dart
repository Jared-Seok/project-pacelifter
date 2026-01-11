import 'package:health/health.dart';
import 'package:pacelifter/models/sessions/workout_session.dart';

class WorkoutDataWrapper {
  final HealthDataPoint? healthData;
  final WorkoutSession? session;

  WorkoutDataWrapper({this.healthData, this.session});

  String get uuid {
    if (healthData != null) return healthData!.uuid;
    if (session != null) return session!.healthKitWorkoutId ?? session!.id;
    return '';
  }

  DateTime get dateFrom {
    if (healthData != null) return healthData!.dateFrom;
    if (session != null) return session!.startTime;
    return DateTime.now();
  }

  DateTime get dateTo {
    if (healthData != null) return healthData!.dateTo;
    if (session != null) return session!.endTime;
    return DateTime.now();
  }

  String get sourceName {
    if (session?.sourceName != null && session!.sourceName!.isNotEmpty) {
      return session!.sourceName!;
    }
    if (healthData != null) return healthData!.sourceName;
    return 'PaceLifter';
  }

  double get totalDistance {
    if (session != null) return session!.totalDistance ?? 0.0;
    if (healthData != null && healthData!.value is WorkoutHealthValue) {
      return ((healthData!.value as WorkoutHealthValue).totalDistance ?? 0).toDouble();
    }
    return 0.0;
  }

  double get calories {
    if (session != null) return session!.calories ?? 0.0;
    if (healthData != null && healthData!.value is WorkoutHealthValue) {
      return ((healthData!.value as WorkoutHealthValue).totalEnergyBurned ?? 0).toDouble();
    }
    return 0.0;
  }
}
