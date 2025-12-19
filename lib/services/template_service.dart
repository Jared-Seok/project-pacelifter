import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:hive/hive.dart';
import '../models/templates/workout_template.dart';
import '../models/exercises/exercise.dart';

/// 템플릿 및 운동 데이터를 로드하고 관리하는 서비스
class TemplateService {
  static const String _templatesBoxName = 'workout_templates';
  static const String _exercisesBoxName = 'exercises';

  /// 모든 템플릿과 운동 데이터를 Assets에서 로드하여 Hive에 저장
  static Future<void> loadAllTemplatesAndExercises() async {
    try {
      // 운동 라이브러리를 먼저 로드
      await _loadExercisesLibrary();

      // 템플릿 로드
      await _loadEnduranceTemplates();
      await _loadStrengthTemplates();
      await _loadHybridTemplates();

      print('✅ All templates and exercises loaded successfully');
    } catch (e) {
      print('❌ Error loading templates and exercises: $e');
      rethrow;
    }
  }

  /// 운동 라이브러리 로드
  static Future<void> _loadExercisesLibrary() async {
    final box = Hive.box<Exercise>(_exercisesBoxName);

    // 이미 로드되어 있으면 스킵
    if (box.isNotEmpty) {
      print('📦 Exercises already loaded (${box.length} exercises)');
      return;
    }

    try {
      final String jsonString = await rootBundle
          .loadString('assets/data/exercises/exercises_library.json');
      final Map<String, dynamic> jsonData = json.decode(jsonString);
      final List<dynamic> exercisesList = jsonData['exercises'] as List;

      for (var exerciseJson in exercisesList) {
        final exercise = Exercise.fromJson(exerciseJson as Map<String, dynamic>);
        await box.put(exercise.id, exercise);
      }

      print('✅ Loaded ${box.length} exercises');
    } catch (e) {
      print('❌ Error loading exercises library: $e');
      rethrow;
    }
  }

  /// Endurance 템플릿 로드 (9개)
  static Future<void> _loadEnduranceTemplates() async {
    final templateFiles = [
      'indoor_lsd.json',
      'indoor_interval.json',
      'indoor_tempo.json',
      'outdoor_lsd.json',
      'outdoor_interval.json',
      'outdoor_tempo.json',
      'track_lsd.json',
      'track_interval.json',
      'track_tempo.json',
    ];

    await _loadTemplatesFromDirectory(
      'assets/data/templates/endurance',
      templateFiles,
      'Endurance',
    );
  }

  /// Strength 템플릿 로드 (8개)
  static Future<void> _loadStrengthTemplates() async {
    final templateFiles = [
      'upper_push.json',
      'upper_pull.json',
      'lower_squat.json',
      'lower_hinge.json',
      'full_body_compound.json',
      'core_stability.json',
      'power_explosive.json',
      'hypertrophy_volume.json',
    ];

    await _loadTemplatesFromDirectory(
      'assets/data/templates/strength',
      templateFiles,
      'Strength',
    );
  }

  /// Hybrid 템플릿 로드 (6개)
  static Future<void> _loadHybridTemplates() async {
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
}
