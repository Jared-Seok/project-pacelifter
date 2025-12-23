import 'package:flutter/material.dart';
import '../models/exercises/exercise.dart';
import '../services/template_service.dart';
import '../widgets/exercise_config_sheet.dart'; // 다음 단계에서 생성 예정

class ExerciseListScreen extends StatefulWidget {
  final String muscleGroupId;
  final String title;

  const ExerciseListScreen({
    super.key,
    required this.muscleGroupId,
    required this.title,
  });

  @override
  State<ExerciseListScreen> createState() => _ExerciseListScreenState();
}

class _ExerciseListScreenState extends State<ExerciseListScreen> {
  Map<String, List<Exercise>> _groupedExercises = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadExercises();
  }

  Future<void> _loadExercises() async {
    // 모든 운동 로드 후 필터링
    final allExercises = TemplateService.getAllExercises();
    
    final filtered = allExercises.where((ex) {
      // muscleGroupId 매핑 (UI ID -> Data ID)
      final p = ex.primaryMuscles.first.toLowerCase(); // List<String>
      final id = widget.muscleGroupId;

      if (id == 'chest') return p == 'chest' || p == 'upper_chest' || p == 'lower_chest';
      if (id == 'back') return p == 'back' || p == 'lats' || p == 'traps';
      if (id == 'shoulders') return p == 'shoulders';
      if (id == 'legs') return p == 'quads' || p == 'hamstrings' || p == 'glutes' || p == 'calves';
      if (id == 'arms') return p == 'biceps' || p == 'triceps' || p == 'forearms';
      if (id == 'core') return p == 'core';
      
      return false;
    }).toList();

    // 그룹화
    final Map<String, List<Exercise>> grouped = {};
    for (var ex in filtered) {
      final groupName = ex.group ?? 'Others';
      if (!grouped.containsKey(groupName)) {
        grouped[groupName] = [];
      }
      grouped[groupName]!.add(ex);
    }

    setState(() {
      _groupedExercises = grouped;
      _isLoading = false;
    });
  }

  void _onExerciseTap(Exercise exercise) {
    // 세부 설정 시트 표시
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => ExerciseConfigSheet(exercise: exercise),
    );
  }

  @override
  Widget build(BuildContext context) {
    final groupKeys = _groupedExercises.keys.toList();

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        title: Text(widget.title),
        backgroundColor: Theme.of(context).colorScheme.surface,
        foregroundColor: Theme.of(context).colorScheme.onSurface,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : groupKeys.isEmpty
              ? const Center(child: Text('등록된 운동이 없습니다.'))
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: groupKeys.length,
                  itemBuilder: (context, groupIndex) {
                    final groupName = groupKeys[groupIndex];
                    final exercises = _groupedExercises[groupName]!;

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (groupName != 'Others' || groupKeys.length > 1)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 4.0),
                            child: Text(
                              groupName,
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                            ),
                          ),
                        ...exercises.map((exercise) => Card(
                          margin: const EdgeInsets.only(bottom: 12),
                          child: ListTile(
                            title: Text(
                              exercise.nameKo.isNotEmpty ? exercise.nameKo : exercise.name,
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                            subtitle: Text(
                              exercise.equipment,
                              style: TextStyle(color: Colors.grey[600]),
                            ),
                            trailing: IconButton(
                              icon: const Icon(Icons.add_circle_outline),
                              color: Theme.of(context).colorScheme.primary,
                              onPressed: () => _onExerciseTap(exercise),
                            ),
                            onTap: () => _onExerciseTap(exercise),
                          ),
                        )),
                        const SizedBox(height: 16),
                      ],
                    );
                  },
                ),
    );
  }
}
