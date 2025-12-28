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

  /// ID로 운동 세션 찾기 (내부 ID)
  WorkoutSession? getSessionById(String id) {
    final box = Hive.box<WorkoutSession>(_sessionBoxName);
    return box.get(id);
  }

  /// HealthKit UUID로 운동 세션 찾기
  WorkoutSession? getSessionByHealthKitId(String healthKitId) {
    final box = Hive.box<WorkoutSession>(_sessionBoxName);
    try {
      return box.values.firstWhere(
        (session) => session.healthKitWorkoutId == healthKitId,
      );
    } catch (e) {
      // HealthKit ID가 내부 ID일 수도 있으므로 한 번 더 확인
      return getSessionById(healthKitId);
    }
  }

  /// 모든 세션 가져오기
  List<WorkoutSession> getAllSessions() {
    final box = Hive.box<WorkoutSession>(_sessionBoxName);
    return box.values.toList();
  }

  /// 최근 N일간의 세션 가져오기
  List<WorkoutSession> getRecentSessions({int days = 90}) {
    final box = Hive.box<WorkoutSession>(_sessionBoxName);
    final cutoff = DateTime.now().subtract(Duration(days: days));
    return box.values.where((s) => s.startTime.isAfter(cutoff)).toList();
  }

  /// 운동 세션 저장
  Future<void> saveSession(WorkoutSession session) async {
    final box = Hive.box<WorkoutSession>(_sessionBoxName);
    await box.put(session.id, session);
  }

  /// 운동 세션 삭제 (PaceLifter 로컬 기록만 삭제)
  Future<void> deleteSession(String sessionId) async {
    final box = Hive.box<WorkoutSession>(_sessionBoxName);
    await box.delete(sessionId);
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
    
    // 이미 존재하는지 확인 (HealthKit ID 또는 내부 ID로 조회)
    WorkoutSession? existingSession = getSessionByHealthKitId(healthKitId);

    if (existingSession != null) {
      // 업데이트
      final updatedSession = existingSession.copyWith(
        templateId: template.id,
        templateName: template.name,
        category: template.category,
        environmentType: template.environmentType,
      );
      await box.put(updatedSession.id, updatedSession);
    } else {
      // 새로 생성
      final newSession = WorkoutSession(
        id: const Uuid().v4(),
        templateId: template.id,
        templateName: template.name,
        category: template.category,
        startTime: startTime,
        endTime: endTime,
        activeDuration: endTime.difference(startTime).inSeconds,
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
