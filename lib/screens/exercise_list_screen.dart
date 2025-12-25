import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../models/exercises/exercise.dart';
import '../services/template_service.dart';
import '../widgets/exercise_config_sheet.dart'; 
import '../utils/korean_search_utils.dart';
import '../providers/strength_routine_provider.dart';
import '../models/templates/workout_template.dart';
import '../models/templates/template_phase.dart';
import '../models/templates/template_block.dart';
import 'strength_tracking_screen.dart';

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
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  Map<String, List<Exercise>> _groupedExercises = {};
  List<Exercise> _allFilteredExercises = []; 
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text;
      });
    });
    _loadExercises();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadExercises() async {
    final allExercises = TemplateService.getAllExercises();
    
    final filtered = allExercises.where((ex) {
      final p = ex.primaryMuscles.first.toLowerCase();
      final id = widget.muscleGroupId;

      if (id == 'chest') return p == 'chest' || p == 'upper_chest' || p == 'lower_chest';
      if (id == 'back') return p == 'back' || p == 'lats' || p == 'traps';
      if (id == 'shoulders') return p == 'shoulders';
      if (id == 'legs') return p == 'quads' || p == 'hamstrings' || p == 'glutes' || p == 'calves';
      if (id == 'arms') return p == 'biceps' || p == 'triceps' || p == 'forearms';
      if (id == 'core') return p == 'core';
      if (id == 'compound') return ex.isCompound;
      
      return false;
    }).toList();

    _allFilteredExercises = filtered;

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
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => ExerciseConfigSheet(exercise: exercise),
    );
  }

  void _startCustomRoutine() {
    final blocks = Provider.of<StrengthRoutineProvider>(context, listen: false).blocks;
    if (blocks.isEmpty) return;

    final template = WorkoutTemplate(
      id: const Uuid().v4(),
      name: '나만의 루틴',
      description: '직접 구성한 커스텀 루틴',
      category: 'Strength',
      subCategory: 'Custom',
      isCustom: true,
      phases: [
        TemplatePhase(
          id: const Uuid().v4(),
          name: 'Main Workout',
          order: 0,
          blocks: blocks,
        ),
      ],
    );

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => StrengthTrackingScreen(template: template),
      ),
    );
  }

  Future<void> _saveCustomRoutine() async {
    final blocks = Provider.of<StrengthRoutineProvider>(context, listen: false).blocks;
    if (blocks.isEmpty) return;

    final nameController = TextEditingController();

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('루틴 저장'),
        content: TextField(
          controller: nameController,
          decoration: const InputDecoration(
            labelText: '루틴 이름',
            hintText: '예: 가슴/삼두 루틴',
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('취소'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (nameController.text.trim().isEmpty) return;

              final template = WorkoutTemplate(
                id: const Uuid().v4(),
                name: nameController.text.trim(),
                description: '직접 구성한 커스텀 루틴',
                category: 'Strength',
                subCategory: 'Custom',
                isCustom: true,
                phases: [
                  TemplatePhase(
                    id: const Uuid().v4(),
                    name: 'Main Workout',
                    order: 0,
                    blocks: List.from(blocks),
                  ),
                ],
                createdAt: DateTime.now(),
              );

              await TemplateService.saveCustomTemplate(template);

              if (mounted) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('루틴이 저장되었습니다')),
                );
              }
            },
            child: const Text('저장'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        title: Text(widget.title),
        backgroundColor: Theme.of(context).colorScheme.surface,
        foregroundColor: Theme.of(context).colorScheme.onSurface,
      ),
      body: Stack(
        children: [
          Column(
            children: [
              _buildSearchBar(),
              Expanded(
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : _searchQuery.isEmpty 
                        ? _buildGroupedList() 
                        : _buildSearchResults(),
              ),
            ],
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: _buildBottomRoutineBar(),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: TextField(
        controller: _searchController,
        decoration: InputDecoration(
          hintText: '${widget.title} 운동 검색 (예: ㅂㅊ)',
          prefixIcon: const Icon(Icons.search),
          suffixIcon: _searchQuery.isNotEmpty 
            ? IconButton(
                icon: const Icon(Icons.clear),
                onPressed: () => _searchController.clear(),
              )
            : null,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          filled: true,
          fillColor: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
      ),
    );
  }

  Widget _buildGroupedList() {
    final groupKeys = _groupedExercises.keys.toList();
    if (groupKeys.isEmpty) {
      return const Center(child: Text('등록된 운동이 없습니다.'));
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 200), // 장바구니 공간 확보
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
            ...exercises.map((exercise) => _buildExerciseCard(exercise)),
            const SizedBox(height: 16),
          ],
        );
      },
    );
  }

  Widget _buildSearchResults() {
    final filtered = _allFilteredExercises.where((ex) => 
      KoreanSearchUtils.matches(ex.nameKo, _searchQuery) || 
      KoreanSearchUtils.matches(ex.name, _searchQuery)
    ).toList();

    if (filtered.isEmpty) {
      return const Center(child: Text('일치하는 운동이 없습니다.'));
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 200), // 장바구니 공간 확보
      itemCount: filtered.length,
      itemBuilder: (context, index) => _buildExerciseCard(filtered[index]),
    );
  }

  Widget _buildExerciseCard(Exercise exercise) {
    final hasSpecificIcon = exercise.imagePath != null;
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        leading: hasSpecificIcon 
          ? SvgPicture.asset(
              exercise.imagePath!,
              width: 66,
              height: 66,
              colorFilter: ColorFilter.mode(
                Theme.of(context).colorScheme.primary,
                BlendMode.srcIn,
              ),
            )
          : Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: SvgPicture.asset(
                'assets/images/strength/lifter-icon.svg',
                width: 40,
                height: 40,
                colorFilter: ColorFilter.mode(
                  Theme.of(context).colorScheme.primary,
                  BlendMode.srcIn,
                ),
              ),
            ),
        title: Text(
          exercise.nameKo.isNotEmpty ? exercise.nameKo : exercise.name,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        subtitle: Text(
          exercise.equipment,
          style: TextStyle(color: Colors.grey[600], fontSize: 13),
        ),
        trailing: IconButton(
          icon: const Icon(Icons.add_circle_outline),
          color: Theme.of(context).colorScheme.primary,
          onPressed: () => _onExerciseTap(exercise),
        ),
        onTap: () => _onExerciseTap(exercise),
      ),
    );
  }

  Widget _buildBottomRoutineBar() {
    return Consumer<StrengthRoutineProvider>(
      builder: (context, provider, child) {
        final count = provider.blocks.length;
        final bool hasSelection = count > 0;

        return Container(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.98),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.4),
                blurRadius: 20,
                offset: const Offset(0, -5),
              ),
            ],
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (hasSelection)
                  Container(
                    height: 130,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: provider.blocks.length,
                      itemBuilder: (context, index) {
                        final block = provider.blocks[index];
                        final exercise = block.exerciseId != null 
                            ? TemplateService.getExerciseById(block.exerciseId!) 
                            : null;
                        final imagePath = exercise?.imagePath;

                        return Stack(
                          children: [
                            Container(
                              margin: const EdgeInsets.only(right: 16, top: 6),
                              width: 91,
                              height: 91,
                              decoration: BoxDecoration(
                                color: Theme.of(context).colorScheme.surface,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.5),
                                  width: 2.0,
                                ),
                              ),
                              child: Center(
                                child: Padding(
                                  padding: const EdgeInsets.all(2.0),
                                  child: SvgPicture.asset(
                                    imagePath ?? 'assets/images/strength/lifter-icon.svg',
                                    fit: BoxFit.contain,
                                    colorFilter: ColorFilter.mode(
                                      Theme.of(context).colorScheme.primary,
                                      BlendMode.srcIn,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            Positioned(
                              right: 6,
                              top: 0,
                              child: GestureDetector(
                                onTap: () => provider.removeBlock(block.id),
                                child: Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: const BoxDecoration(
                                    color: Colors.red,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(Icons.close, size: 16, color: Colors.white),
                                ),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              '$count개 운동 선택됨',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: hasSelection 
                                    ? Theme.of(context).colorScheme.primary 
                                    : Colors.grey,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (hasSelection)
                        TextButton.icon(
                          onPressed: _saveCustomRoutine,
                          icon: const Icon(Icons.save_alt),
                          label: const Text('저장'),
                        ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: hasSelection ? _startCustomRoutine : null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Theme.of(context).colorScheme.primary,
                          foregroundColor: Theme.of(context).colorScheme.onPrimary,
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text('루틴 시작'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}