import 'package:hive/hive.dart';
import 'package:pacelifter/models/sessions/workout_session.dart';
import 'package:pacelifter/models/templates/workout_template.dart';
import 'package:uuid/uuid.dart';

class WorkoutHistoryService {
  static const String _sessionBoxName = 'user_workout_history';

  // Singleton instance
  static final WorkoutHistoryService _instance = WorkoutHistoryService._internal();

  factory WorkoutHistoryService() {
    return _instance;
  }

  WorkoutHistoryService._internal();

  /// HealthKit UUID로 운동 세션 찾기
  WorkoutSession? getSessionByHealthKitId(String healthKitId) {
    final box = Hive.box<WorkoutSession>(_sessionBoxName);
    try {
      return box.values.firstWhere(
        (session) => session.healthKitWorkoutId == healthKitId,
      );
    } catch (e) {
      return null;
    }
  }

  /// 모든 세션 가져오기
  List<WorkoutSession> getAllSessions() {
    final box = Hive.box<WorkoutSession>(_sessionBoxName);
    return box.values.toList();
  }

  /// 운동 세션에 템플릿 연결 (또는 세션 생성)
  Future<void> linkTemplateToWorkout({
    required String healthKitId,
    required WorkoutTemplate template,
    required DateTime startTime,
    required DateTime endTime,
    required double totalDistance,
    required double calories,
    // 필요한 다른 필드들...
  }) async {
    final box = Hive.box<WorkoutSession>(_sessionBoxName);
    
    // 이미 존재하는지 확인
    WorkoutSession? existingSession = getSessionByHealthKitId(healthKitId);

    if (existingSession != null) {
      // 업데이트
      final updatedSession = existingSession.copyWith(
        templateId: template.id,
        templateName: template.name,
        category: template.category,
        environmentType: template.environmentType,
        // 필요시 다른 필드 업데이트
      );
      await updatedSession.save(); // HiveObject update
    } else {
      // 새로 생성
      final newSession = WorkoutSession(
        id: const Uuid().v4(),
        templateId: template.id,
        templateName: template.name,
        category: template.category,
        startTime: startTime,
        endTime: endTime,
        activeDuration: endTime.difference(startTime).inSeconds, // 추정
        totalDuration: endTime.difference(startTime).inSeconds,
        totalDistance: totalDistance,
        calories: calories,
        healthKitWorkoutId: healthKitId,
        environmentType: template.environmentType,
      );
      await box.put(newSession.id, newSession);
    }
  }
}
