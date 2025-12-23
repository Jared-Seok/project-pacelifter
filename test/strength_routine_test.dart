import 'package:flutter_test/flutter_test.dart';
import 'package:pacelifter/models/exercises/exercise.dart';
import 'package:pacelifter/providers/strength_routine_provider.dart';
import 'package:pacelifter/models/templates/template_block.dart';

void main() {
  group('Strength Routine Builder Tests', () {
    late StrengthRoutineProvider provider;

    setUp(() {
      provider = StrengthRoutineProvider();
    });

    test('Should add a basic exercise to routine', () {
      final exercise = Exercise(
        id: 'test_bench',
        name: 'Bench Press',
        nameKo: '벤치 프레스',
        category: 'strength',
        movementPattern: 'push',
        primaryMuscles: ['chest'],
        secondaryMuscles: [],
        equipment: 'barbell',
        difficulty: 'beginner',
        isCompound: true,
        isUnilateral: false,
      );

      provider.addExercise(
        exercise: exercise,
        sets: 3,
        reps: 10,
        weight: 60.0,
      );

      expect(provider.blocks.length, 1);
      expect(provider.blocks.first.name, 'Bench Press');
      expect(provider.blocks.first.sets, 3);
      expect(provider.blocks.first.weight, 60.0);
    });

    test('Should handle exercise with variations correctly', () {
      final exercise = Exercise(
        id: 'test_db_press',
        name: 'Dumbbell Press',
        nameKo: '덤벨 프레스',
        category: 'strength',
        movementPattern: 'push',
        primaryMuscles: ['chest'],
        secondaryMuscles: [],
        equipment: 'dumbbell',
        difficulty: 'beginner',
        isCompound: true,
        isUnilateral: true,
      );

      // UI에서 처리하는 방식과 동일하게 변형 옵션을 이름에 포함
      final variationText = ' (인클라인, 덤벨)';
      final modifiedExercise = exercise.copyWith(
        name: '${exercise.nameKo}$variationText',
      );

      provider.addExercise(
        exercise: modifiedExercise,
        sets: 4,
        reps: 12,
        weight: 20.0,
      );

      expect(provider.blocks.first.name, '덤벨 프레스 (인클라인, 덤벨)');
      expect(provider.blocks.first.sets, 4);
    });

    test('Should clear routine', () {
      final exercise = Exercise(
        id: 'test_ex',
        name: 'Ex',
        nameKo: '운동',
        category: 'strength',
        movementPattern: 'push',
        primaryMuscles: ['chest'],
        secondaryMuscles: [],
        equipment: 'barbell',
        difficulty: 'beginner',
        isCompound: true,
        isUnilateral: false,
      );

      provider.addExercise(exercise: exercise, sets: 1, reps: 1, weight: 10);
      expect(provider.blocks.length, 1);

      provider.clear();
      expect(provider.blocks.length, 0);
    });
  });
}
