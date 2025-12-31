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
      final templateBox = Hive.box<WorkoutTemplate>(_templatesBoxName);
      final exerciseBox = Hive.box<Exercise>(_exercisesBoxName);

      // 이미 데이터가 충분히 있다면 로드 과정을 생략하여 구동 속도 개선
      if (templateBox.length >= 20 && exerciseBox.length >= 50) {
        print('✅ Templates and exercises already loaded. Skipping initialization.');
        return;
      }

      // 운동 라이브러리를 먼저 로드
      await _loadExercisesLibrary();

      // 템플릿 로드
      await _loadEnduranceTemplates();
      await _loadStrengthTemplates();
      await _loadHybridTemplates();
      
      // 프리셋 박스 확인
      if (!Hive.isBoxOpen(_presetsBoxName)) {
        await Hive.openBox<CustomPhasePreset>(_presetsBoxName);
      }

      print('✅ All templates and exercises loaded successfully');
    } catch (e) {
      print('❌ Error loading templates and exercises: $e');
      // 치명적인 에러가 아니면 계속 진행할 수 있도록 rethrow 대신 로그만 출력
    }
  }

  /// 운동 라이브러리 로드
  static Future<void> _loadExercisesLibrary() async {
    final box = Hive.box<Exercise>(_exercisesBoxName);
    
    // 데이터가 이미 있으면 중복 로드 방지
    if (box.length > 50) return;

    // 기본 운동 데이터 파일 목록
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

    try {
      for (var filePath in libraryFiles) {
        final String jsonString = await rootBundle.loadString(filePath);
        final Map<String, dynamic> jsonData = json.decode(jsonString);
        final List<dynamic> exercisesList = jsonData['exercises'] as List;

        for (var exerciseJson in exercisesList) {
          final exercise = Exercise.fromJson(exerciseJson as Map<String, dynamic>);
          await box.put(exercise.id, exercise);
        }
      }

      print('✅ Loaded ${box.length} exercises from all libraries');
    } catch (e) {
      print('❌ Error loading exercises library: $e');
    }
  }

  /// Endurance 템플릿 로드
  static Future<void> _loadEnduranceTemplates() async {
    final box = Hive.box<WorkoutTemplate>(_templatesBoxName);
    
    // 이미 Endurance 템플릿이 로드되어 있는지 확인 (기본 12개)
    final enduranceCount = box.values.where((t) => t.category == 'Endurance' && !t.isCustom).length;
    if (enduranceCount >= 12) return;

    final templateFiles = [
      'indoor_lsd.json',
      'indoor_interval.json',
      'indoor_tempo.json',
      'indoor_basic_run.json',
      'outdoor_lsd.json',
      'outdoor_interval.json',
      'outdoor_tempo.json',
      'outdoor_basic_run.json',
      'trail_lsd.json',
      'trail_interval.json',
      'trail_tempo.json',
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
    int loadedCount = 0;

    for (var filename in files) {
      try {
        final String jsonString =
            await rootBundle.loadString('$directory/$filename');
        final Map<String, dynamic> jsonData = json.decode(jsonString);
        final template = WorkoutTemplate.fromJson(jsonData);

        // 기본 템플릿만 로드 (isCustom == false)
        if (!template.isCustom) {
          await box.put(template.id, template);
          loadedCount++;
        }
      } catch (e) {
        print('❌ Error loading $filename: $e');
      }
    }

    print('✅ Loaded $loadedCount $category templates');
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
