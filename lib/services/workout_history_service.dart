import 'package:hive/hive.dart';
import 'package:pacelifter/models/sessions/workout_session.dart';
import 'package:pacelifter/models/sessions/exercise_record.dart';
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
  Future<WorkoutSession?> getSessionById(String id) async {
    final box = await _getBox();
    if (box is Box<WorkoutSession>) {
      return box.get(id);
    } else {
      return await (box as LazyBox<WorkoutSession>).get(id);
    }
  }

  /// HealthKit UUID로 운동 세션 찾기
  Future<WorkoutSession?> getSessionByHealthKitId(String healthKitId) async {
    final box = await _getBox();
    try {
      if (box is Box<WorkoutSession>) {
        return box.values.firstWhere(
          (session) => session.healthKitWorkoutId == healthKitId,
        );
      } else {
        final lazyBox = box as LazyBox<WorkoutSession>;
        for (var key in lazyBox.keys) {
          final session = await lazyBox.get(key);
          if (session?.healthKitWorkoutId == healthKitId) return session;
        }
      }
    } catch (e) {
      // ignore
    }
    return await getSessionById(healthKitId);
  }

  /// 모든 세션 가져오기
  Future<List<WorkoutSession>> getAllSessions() async {
    final box = await _getBox();
    if (box is Box<WorkoutSession>) {
      return box.values.toList();
    } else {
      final lazyBox = box as LazyBox<WorkoutSession>;
      final List<WorkoutSession> sessions = [];
      for (var key in lazyBox.keys) {
        final session = await lazyBox.get(key);
        if (session != null) sessions.add(session);
      }
      return sessions;
    }
  }

  /// 최근 N일간의 세션 가져오기
  Future<List<WorkoutSession>> getRecentSessions({int days = 90}) async {
    final box = await _getBox();
    final cutoff = DateTime.now().subtract(Duration(days: days));
    
    if (box is Box<WorkoutSession>) {
      return box.values.where((s) => s.startTime.isAfter(cutoff)).toList();
    } else {
      final lazyBox = box as LazyBox<WorkoutSession>;
      final List<WorkoutSession> sessions = [];
      for (var key in lazyBox.keys) {
        final session = await lazyBox.get(key);
        if (session != null && session.startTime.isAfter(cutoff)) {
          sessions.add(session);
        }
      }
      return sessions;
    }
  }

  /// 운동 세션 저장
  Future<void> saveSession(WorkoutSession session) async {
    final box = await _getBox();
    if (box is Box<WorkoutSession>) {
      await box.put(session.id, session);
    } else {
      await (box as LazyBox<WorkoutSession>).put(session.id, session);
    }
  }

  /// 운동 세션 삭제 (PaceLifter 로컬 기록만 삭제)
  Future<void> deleteSession(String sessionId) async {
    final box = await _getBox();
    if (box is Box<WorkoutSession>) {
      await box.delete(sessionId);
    } else {
      await (box as LazyBox<WorkoutSession>).delete(sessionId);
    }
  }

  /// 내부 박스 접근 도우미 (Box와 LazyBox 모두 대응)
  Future<BoxBase<WorkoutSession>> _getBox() async {
    if (Hive.isBoxOpen(_sessionBoxName)) {
      // 이미 열려있다면 해당 인스턴스 반환
      // Hive.box()나 Hive.lazyBox()는 타입이 맞지 않으면 에러를 내므로 안전하게 처리
      try {
        return Hive.box<WorkoutSession>(_sessionBoxName);
      } catch (_) {
        return Hive.lazyBox<WorkoutSession>(_sessionBoxName);
      }
    }
    // 닫혀있다면 LazyBox로 오픈 (기본 정책)
    return await Hive.openLazyBox<WorkoutSession>(_sessionBoxName);
  }

  /// 운동 세션에 템플릿 연결 (또는 세션 생성)
  Future<void> linkTemplateToWorkout({
    required String healthKitId,
    required WorkoutTemplate template,
    required DateTime startTime,
    required DateTime endTime,
    required double totalDistance,
    required double calories,
  }) async {
    // 이미 존재하는지 확인
    WorkoutSession? existingSession = await getSessionByHealthKitId(healthKitId);

    // 템플릿의 운동 정보를 기반으로 레코드 생성
    final exerciseRecords = <ExerciseRecord>[];
    int order = 0;
    for (var phase in template.phases) {
      for (var block in phase.blocks) {
        if (block.type == 'strength') {
          // exerciseId가 없더라도 이름이 있다면 레코드 생성 (기본 템플릿 대응)
          exerciseRecords.add(ExerciseRecord(
            id: const Uuid().v4(),
            exerciseId: block.exerciseId ?? 'manual_${block.name}',
            exerciseName: block.name,
            sets: List.generate(block.sets ?? 3, (index) => SetRecord(
              setNumber: index + 1,
              weight: block.weight ?? 0,
              repsTarget: block.reps ?? 10,
              repsCompleted: block.reps ?? 10,
            )),
            order: order++,
            timestamp: endTime,
          ));
        }
      }
    }

    // 총 합계 계산
    final totalVolume = exerciseRecords.fold<double>(0.0, (sum, r) => sum + r.totalVolume);
    final totalSets = exerciseRecords.fold<int>(0, (sum, r) => sum + r.sets.length);
    final totalReps = exerciseRecords.fold<int>(0, (sum, r) => sum + r.totalReps);

    if (existingSession != null) {
      // 업데이트
      final updatedSession = existingSession.copyWith(
        templateId: template.id,
        templateName: template.name,
        category: template.category,
        environmentType: template.environmentType,
        exerciseRecords: exerciseRecords,
        totalVolume: totalVolume,
        totalSets: totalSets,
        totalReps: totalReps,
      );
      await saveSession(updatedSession);
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
        exerciseRecords: exerciseRecords,
        totalVolume: totalVolume,
        totalSets: totalSets,
        totalReps: totalReps,
      );
      await saveSession(newSession);
    }
  }
}
