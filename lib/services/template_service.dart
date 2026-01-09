import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:hive/hive.dart';
import '../models/templates/workout_template.dart';
import '../models/templates/custom_phase_preset.dart';
import '../models/exercises/exercise.dart';

/// 템플릿 및 운동 데이터를 로드하고 관리하는 서비스
class TemplateService {
  static const String _templatesBoxName = 'workout_templates';
  static const String _exercisesBoxName = 'exercises';
  static const String _presetsBoxName = 'custom_phase_presets';

  /// 모든 템플릿과 운동 데이터를 Assets에서 로드하여 Hive에 저장
  static Future<void> loadAllTemplatesAndExercises() async {
    try {
      // 박스가 열려있는지 확인하고 없으면 여기서라도 열기 시도
      if (!Hive.isBoxOpen(_templatesBoxName)) {
        await Hive.openBox<WorkoutTemplate>(_templatesBoxName);
      }
      if (!Hive.isBoxOpen(_exercisesBoxName)) {
        await Hive.openBox<Exercise>(_exercisesBoxName);
      }

      final templateBox = Hive.box<WorkoutTemplate>(_templatesBoxName);
      final exerciseBox = Hive.box<Exercise>(_exercisesBoxName);

      // 데이터 존재 여부 확인 (최소 기준치)
      bool hasTemplates = templateBox.length >= 30; // 정예화된 템플릿 최소 수
      bool hasExercises = exerciseBox.length >= 50;

      if (hasTemplates && hasExercises) {
        print('✅ TemplateService: Data already exists, skipping heavy load');
        return;
      }

      print('📦 TemplateService: Starting data import from assets...');

      // 1. 운동 라이브러리 로드 (병렬 로딩 시도)
      await _loadExercisesLibrary();

      // 2. 템플릿 로드 (병렬 실행)
      await Future.wait([
        _loadEnduranceTemplates(),
        _loadStrengthTemplates(),
        _loadHybridTemplates(),
      ]);
      
      // 3. 프리셋 박스 보장
      if (!Hive.isBoxOpen(_presetsBoxName)) {
        await Hive.openBox<CustomPhasePreset>(_presetsBoxName);
      }

      print('✅ TemplateService: All data successfully synchronized');
    } catch (e, stackTrace) {
      print('❌ TemplateService: Critical error during data load: $e');
      print(stackTrace);
      // 여기서 에러를 던지지 않아야 초기화 프로세스가 멈추지 않음 (최소한 앱 실행은 가능하게 함)
    }
  }

  /// 운동 라이브러리 로드
  static Future<void> _loadExercisesLibrary() async {
    try {
      if (!Hive.isBoxOpen(_exercisesBoxName)) return;
      final box = Hive.box<Exercise>(_exercisesBoxName);
      
      if (box.length > 50) return;

      final libraryFiles = [
        'assets/data/exercises/chest_exercises.json',
        'assets/data/exercises/back_exercises.json',
        'assets/data/exercises/shoulder_exercises.json',
        'assets/data/exercises/biceps_exercises.json',
        'assets/data/exercises/triceps_exercises.json',
        'assets/data/exercises/forearms_exercises.json',
        'assets/data/exercises/legs_exercises.json',
        'assets/data/exercises/core_exercises.json',
      ];

      // 각 파일을 로드하여 Map으로 변환 후 일괄 처리 (Batch Load)
      final allExercises = <String, Exercise>{};
      
      for (var filePath in libraryFiles) {
        try {
          final String jsonString = await rootBundle.loadString(filePath);
          final Map<String, dynamic> jsonData = json.decode(jsonString);
          final List<dynamic> exercisesList = jsonData['exercises'] as List;

          for (var exerciseJson in exercisesList) {
            final exercise = Exercise.fromJson(exerciseJson as Map<String, dynamic>);
            allExercises[exercise.id] = exercise;
          }
        } catch (e) {
          print('⚠️ Failed to load exercise file $filePath: $e');
        }
      }

      if (allExercises.isNotEmpty) {
        await box.putAll(allExercises);
        print('✅ TemplateService: Batch loaded ${allExercises.length} exercises');
      }
    } catch (e) {
      print('❌ TemplateService: Exercise library load failed: $e');
    }
  }

  /// Endurance 템플릿 로드 (정예화: 로드 4, 실내 4, 트레일 1)
  static Future<void> _loadEnduranceTemplates() async {
    final box = Hive.box<WorkoutTemplate>(_templatesBoxName);
    
    // 1. 불필요한 레거시 템플릿 정리 (트레일 리서치 기반으로 제거)
    final legacyIds = [
      'endurance_trail_lsd',
      'endurance_trail_interval',
      'endurance_trail_tempo',
    ];
    for (var id in legacyIds) {
      if (box.containsKey(id)) {
        await box.delete(id);
      }
    }

    final templateFiles = [
      // 로드 (Outdoor) - 4개
      'outdoor_lsd.json',
      'outdoor_interval.json',
      'outdoor_tempo.json',
      'outdoor_basic_run.json',
      // 실내 (Indoor) - 4개
      'indoor_lsd.json',
      'indoor_interval.json',
      'indoor_tempo.json',
      'indoor_basic_run.json',
      // 트레일 (Trail) - 1개
      'trail_basic_run.json',
    ];

    await _loadTemplatesFromDirectory(
      'assets/data/templates/endurance',
      templateFiles,
      'Endurance',
    );
  }

  /// Strength 템플릿 로드
  static Future<void> _loadStrengthTemplates() async {
    final box = Hive.box<WorkoutTemplate>(_templatesBoxName);
    
    final count = box.values.where((t) => t.category == 'Strength' && !t.isCustom).length;
    if (count >= 11) return;

    final templateFiles = [
      'push_day.json',
      'pull_day.json',
      'leg_day.json',
      'upper_body.json',
      'lower_body.json',
      'full_body_a.json',
      'chest_back.json',
      'core_stability.json',
      'chest_hypertrophy.json',
      'chest_strength.json',
      'back_workout.json',
    ];

    await _loadTemplatesFromDirectory(
      'assets/data/templates/strength',
      templateFiles,
      'Strength',
    );
  }

  /// Hybrid 템플릿 로드
  static Future<void> _loadHybridTemplates() async {
    final box = Hive.box<WorkoutTemplate>(_templatesBoxName);
    
    final count = box.values.where((t) => t.category == 'Hybrid' && !t.isCustom).length;
    if (count >= 6) return;

    final templateFiles = [
      'hyrox_simulation.json',
      'crossfit_metcon.json',
      'circuit_training.json',
      'emom_mixed.json',
      'amrap_endurance.json',
      'strength_endurance.json',
    ];

    await _loadTemplatesFromDirectory(
      'assets/data/templates/hybrid',
      templateFiles,
      'Hybrid',
    );
  }

  /// 특정 디렉토리에서 템플릿 파일 로드
  static Future<void> _loadTemplatesFromDirectory(
    String directory,
    List<String> files,
    String category,
  ) async {
    final box = Hive.box<WorkoutTemplate>(_templatesBoxName);
    final templatesToLoad = <String, WorkoutTemplate>{};

    for (var filename in files) {
      try {
        final String jsonString =
            await rootBundle.loadString('$directory/$filename');
        final Map<String, dynamic> jsonData = json.decode(jsonString);
        final template = WorkoutTemplate.fromJson(jsonData);

        // 기본 템플릿만 로드 (isCustom == false)
        if (!template.isCustom) {
          templatesToLoad[template.id] = template;
        }
      } catch (e) {
        print('❌ Error loading $filename: $e');
      }
    }

    if (templatesToLoad.isNotEmpty) {
      await box.putAll(templatesToLoad);
      print('✅ Batch loaded ${templatesToLoad.length} $category templates');
    }
  }

  /// 카테고리별 템플릿 조회
  static List<WorkoutTemplate> getTemplatesByCategory(String category) {
    final box = Hive.box<WorkoutTemplate>(_templatesBoxName);
    return box.values
        .where((template) => template.category == category)
        .toList();
  }

  /// 환경 타입별 Endurance 템플릿 조회
  static List<WorkoutTemplate> getEnduranceTemplatesByEnvironment(
    String environmentType,
  ) {
    final box = Hive.box<WorkoutTemplate>(_templatesBoxName);
    return box.values
        .where((template) =>
            template.category == 'Endurance' &&
            template.environmentType == environmentType)
        .toList();
  }

  /// ID로 템플릿 조회
  static WorkoutTemplate? getTemplateById(String id) {
    final box = Hive.box<WorkoutTemplate>(_templatesBoxName);
    return box.get(id);
  }

  /// 모든 템플릿 조회
  static List<WorkoutTemplate> getAllTemplates() {
    final box = Hive.box<WorkoutTemplate>(_templatesBoxName);
    return box.values.toList();
  }

  /// 커스텀 템플릿 저장
  static Future<void> saveCustomTemplate(WorkoutTemplate template) async {
    final box = Hive.box<WorkoutTemplate>(_templatesBoxName);
    await box.put(template.id, template);
  }

  /// 템플릿 삭제 (커스텀 템플릿만)
  static Future<void> deleteTemplate(String id) async {
    final box = Hive.box<WorkoutTemplate>(_templatesBoxName);
    final template = box.get(id);

    if (template != null && template.isCustom) {
      await box.delete(id);
    }
  }

  /// ID로 운동 조회
  static Exercise? getExerciseById(String id) {
    final box = Hive.box<Exercise>(_exercisesBoxName);
    return box.get(id);
  }

  /// 카테고리별 운동 조회
  static List<Exercise> getExercisesByCategory(String category) {
    final box = Hive.box<Exercise>(_exercisesBoxName);
    return box.values
        .where((exercise) => exercise.category == category)
        .toList();
  }

  /// 움직임 패턴별 운동 조회
  static List<Exercise> getExercisesByMovementPattern(String pattern) {
    final box = Hive.box<Exercise>(_exercisesBoxName);
    return box.values
        .where((exercise) => exercise.movementPattern == pattern)
        .toList();
  }

  /// 모든 운동 조회
  static List<Exercise> getAllExercises() {
    final box = Hive.box<Exercise>(_exercisesBoxName);
    return box.values.toList();
  }

  /// 템플릿 통계
  static Map<String, int> getTemplateStats() {
    final box = Hive.box<WorkoutTemplate>(_templatesBoxName);
    final templates = box.values.toList();

    return {
      'total': templates.length,
      'endurance': templates.where((t) => t.category == 'Endurance').length,
      'strength': templates.where((t) => t.category == 'Strength').length,
      'hybrid': templates.where((t) => t.category == 'Hybrid').length,
      'custom': templates.where((t) => t.isCustom).length,
    };
  }

  // ==========================================
  // Custom Phase Presets (세부 운동 템플릿)
  // ==========================================

  /// 커스텀 프리셋 저장
  static Future<void> saveCustomPhasePreset(CustomPhasePreset preset) async {
    final box = await Hive.openBox<CustomPhasePreset>(_presetsBoxName);
    await box.put(preset.id, preset);
  }

  /// 커스텀 프리셋 조회 (전체)
  static Future<List<CustomPhasePreset>> getCustomPhasePresets() async {
    final box = await Hive.openBox<CustomPhasePreset>(_presetsBoxName);
    return box.values.toList();
  }

  /// 카테고리별 프리셋 조회
  static Future<List<CustomPhasePreset>> getCustomPhasePresetsByCategory(String category) async {
    final box = await Hive.openBox<CustomPhasePreset>(_presetsBoxName);
    return box.values.where((p) => p.category == category).toList();
  }

  /// 프리셋 삭제
  static Future<void> deleteCustomPhasePreset(String id) async {
    final box = await Hive.openBox<CustomPhasePreset>(_presetsBoxName);
    await box.delete(id);
  }
}
