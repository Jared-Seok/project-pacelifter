import 'package:hive/hive.dart';
import 'package:pacelifter/models/sessions/workout_session.dart';
import 'package:pacelifter/models/sessions/exercise_record.dart';
import 'package:pacelifter/models/templates/workout_template.dart';
import 'package:pacelifter/models/sessions/session_metadata.dart';
import 'package:uuid/uuid.dart';

class WorkoutHistoryService {
  static const String _sessionBoxName = 'user_workout_history';
  static const String _indexBoxName = 'session_metadata_index';

  // 동기화 모드 (Box <-> LazyBox 전환용)
  bool _isSyncMode = false;

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

  /// HealthKit UUID로 운동 세션 찾기 (인덱스 우선 활용)
  Future<WorkoutSession?> getSessionByHealthKitId(String healthKitId) async {
    // 1. 인덱스에서 먼저 찾기 (메모리 조회)
    final indexBox = Hive.box<SessionMetadata>(_indexBoxName);
    try {
      final meta = indexBox.values.firstWhere(
        (meta) => meta.healthKitId == healthKitId,
      );
      return await getSessionById(meta.id);
    } catch (_) {
      // 인덱스에 없으면 ID 자체로 조회 시도
      return await getSessionById(healthKitId);
    }
  }

  // getAllSessions 및 getRecentSessions는 하단에 인덱스 기반으로 구현됨

  /// 운동 세션 저장
  Future<void> saveSession(WorkoutSession session) async {
    final box = await _getBox();
    await (box as BoxBase<WorkoutSession>).put(session.id, session);
    
    // 인덱스 업데이트
    final indexBox = Hive.box<SessionMetadata>(_indexBoxName);
    await indexBox.put(session.id, SessionMetadata.fromSession(session));
  }

  /// 여러 운동 세션 일괄 저장 (Batch Save)
  Future<void> saveSessions(List<WorkoutSession> sessions) async {
    if (sessions.isEmpty) return;
    final box = await _getBox();
    
    final Map<String, WorkoutSession> sessionMap = {
      for (var s in sessions) s.id: s
    };
    await (box as BoxBase<WorkoutSession>).putAll(sessionMap);

    // 인덱스 일괄 업데이트
    final indexBox = Hive.box<SessionMetadata>(_indexBoxName);
    final Map<String, SessionMetadata> indexMap = {
      for (var s in sessions) s.id: SessionMetadata.fromSession(s)
    };
    await indexBox.putAll(indexMap);
  }

  /// 운동 세션 삭제 (PaceLifter 로컬 기록만 삭제)
  Future<void> deleteSession(String sessionId) async {
    final box = await _getBox();
    await (box as BoxBase<WorkoutSession>).delete(sessionId);
    
    // 인덱스 삭제
    final indexBox = Hive.box<SessionMetadata>(_indexBoxName);
    await indexBox.delete(sessionId);
  }

  /// 내부 박스 접근 도우미 (동기화 모드 대응 + 지연 로딩 지원)
  Future<BoxBase<WorkoutSession>> _getBox() async {
    const timeout = Duration(seconds: 5);
    
    // 1. 이미 열려있는지 확인
    if (Hive.isBoxOpen(_sessionBoxName)) {
      if (_isSyncMode) {
        try {
          return Hive.box<WorkoutSession>(_sessionBoxName);
        } catch (_) {}
      } else {
        try {
          return Hive.lazyBox<WorkoutSession>(_sessionBoxName);
        } catch (_) {}
      }
      // 모드 불일치 시 닫기
      try {
        await Hive.box(_sessionBoxName).close();
      } catch (_) {
        try {
          await Hive.lazyBox(_sessionBoxName).close();
        } catch (_) {}
      }
    }
    
    // 2. 새로 열기 (지연 로딩의 핵심)
    print('📦 [WorkoutHistoryService] Lazy opening $_sessionBoxName (SyncMode: $_isSyncMode)');
    if (_isSyncMode) {
      return await Hive.openBox<WorkoutSession>(_sessionBoxName).timeout(timeout);
    } else {
      return await Hive.openLazyBox<WorkoutSession>(_sessionBoxName).timeout(timeout);
    }
  }

  /// 고속 동기화 모드 설정 (RAM 활용)
  Future<void> setSyncMode(bool enabled) async {
    if (_isSyncMode == enabled) return;
    
    _isSyncMode = enabled;
    if (Hive.isBoxOpen(_sessionBoxName)) {
      if (_isSyncMode) {
        // LazyBox -> Box 전환
        final lazyBox = Hive.lazyBox<WorkoutSession>(_sessionBoxName);
        await lazyBox.close();
        await Hive.openBox<WorkoutSession>(_sessionBoxName);
      } else {
        // Box -> LazyBox 전환
        final box = Hive.box<WorkoutSession>(_sessionBoxName);
        await box.close();
        await Hive.openLazyBox<WorkoutSession>(_sessionBoxName);
      }
    }
  }

  /// 인덱스 재빌드 (전체 세션 기반)
  static bool _isRebuilding = false;
  Future<void> rebuildIndex() async {
    if (_isRebuilding) return;
    _isRebuilding = true;

    try {
      final indexBox = Hive.box<SessionMetadata>(_indexBoxName);
      final box = await _getBox();
      final Map<String, SessionMetadata> indexMap = {};

      print('🔍 [WorkoutHistoryService] Starting index rebuild for ${box.length} items...');

      if (box is Box<WorkoutSession>) {
        for (var session in box.values) {
          indexMap[session.id] = SessionMetadata.fromSession(session);
        }
      } else {
        final lazyBox = box as LazyBox<WorkoutSession>;
        // LazyBox는 하나씩 비동기로 가져와야 함 하지만 한꺼번에 Map에 담아 putAll 처리
        for (var key in lazyBox.keys) {
          final session = await lazyBox.get(key);
          if (session != null) {
            indexMap[session.id] = SessionMetadata.fromSession(session);
          }
        }
      }

      if (indexMap.isNotEmpty) {
        await indexBox.clear();
        await indexBox.putAll(indexMap);
        print('✅ [WorkoutHistoryService] Index rebuild complete: ${indexMap.length} items');
      }
    } finally {
      _isRebuilding = false;
    }
  }

  /// 최근 N일간의 세션 가져오기 (인덱스 기반 초고속 쿼리)
  Future<List<WorkoutSession>> getRecentSessions({int days = 90}) async {
    final indexBox = Hive.box<SessionMetadata>(_indexBoxName);
    final cutoff = DateTime.now().subtract(Duration(days: days));
    
    // 1. 인덱스에서 조건에 맞는 ID들만 추출 및 날짜순 정렬
    final targetMetas = indexBox.values
        .where((meta) => meta.startTime.isAfter(cutoff))
        .toList();
    
    targetMetas.sort((a, b) => b.startTime.compareTo(a.startTime));
    final targetIds = targetMetas.map((meta) => meta.id).toList();

    // 2. 해당 ID들만 LazyBox에서 로드
    final box = await _getBox();
    final List<WorkoutSession> results = [];
    
    for (var id in targetIds) {
      if (box is Box<WorkoutSession>) {
        final session = box.get(id);
        if (session != null) results.add(session);
      } else {
        final session = await (box as LazyBox<WorkoutSession>).get(id);
        if (session != null) results.add(session);
      }
    }
    
    return results;
  }

  /// 모든 세션 가져오기 (인덱스 활용)
  Future<List<WorkoutSession>> getAllSessions() async {
    final indexBox = Hive.box<SessionMetadata>(_indexBoxName);
    final targetMetas = indexBox.values.toList();
    targetMetas.sort((a, b) => b.startTime.compareTo(a.startTime));
    final targetIds = targetMetas.map((meta) => meta.id).toList();

    final box = await _getBox();
    final List<WorkoutSession> results = [];
    
    for (var id in targetIds) {
      if (box is Box<WorkoutSession>) {
        final session = box.get(id);
        if (session != null) results.add(session);
      } else {
        final session = await (box as LazyBox<WorkoutSession>).get(id);
        if (session != null) results.add(session);
      }
    }
    
    return results;
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

  /// 운동 세션의 운동 기록 리스트를 업데이트하고 통계를 재계산합니다.
  Future<void> updateSessionExerciseRecords({
    required String sessionId,
    required List<ExerciseRecord> exerciseRecords,
  }) async {
    final session = await getSessionById(sessionId);
    if (session == null) return;

    // 총 합계 재계산
    final totalVolume = exerciseRecords.fold<double>(0.0, (sum, r) => sum + r.totalVolume);
    final totalSets = exerciseRecords.fold<int>(0, (sum, r) => sum + r.sets.length);
    final totalReps = exerciseRecords.fold<int>(0, (sum, r) => sum + r.totalReps);

    final updatedSession = session.copyWith(
      exerciseRecords: exerciseRecords,
      totalVolume: totalVolume,
      totalSets: totalSets,
      totalReps: totalReps,
    );

    await saveSession(updatedSession);
  }
}
