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
}
