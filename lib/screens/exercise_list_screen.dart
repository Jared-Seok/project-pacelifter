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
import 'strength_routine_preview_screen.dart';

class ExerciseListScreen extends StatefulWidget {
  final String muscleGroupId;
  final String title;
  final bool isEnrichmentMode; // 보강 모드 여부

  const ExerciseListScreen({
    super.key,
    required this.muscleGroupId,
    required this.title,
    this.isEnrichmentMode = false, // 기본값은 false
  });

  @override
  State<ExerciseListScreen> createState() => _ExerciseListScreenState();
}

class _ExerciseListScreenState extends State<ExerciseListScreen> {
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _routineScrollController = ScrollController();
  Map<String, List<Exercise>> _groupedExercises = {};
  List<Exercise> _allFilteredExercises = []; 
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadExercises();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _routineScrollController.dispose();
    super.dispose();
  }

  void _scrollToEnd() {
    Future.delayed(const Duration(milliseconds: 300), () {
      if (_routineScrollController.hasClients) {
        _routineScrollController.animateTo(
          _routineScrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _loadExercises() async {
    try {
      var allExercises = TemplateService.getAllExercises();
      
      // 데이터가 아직 로드되지 않았다면 최대 3초간 대기하며 재시도
      int retryCount = 0;
      while (allExercises.isEmpty && retryCount < 10) {
        await Future.delayed(const Duration(milliseconds: 300));
        allExercises = TemplateService.getAllExercises();
        retryCount++;
        debugPrint('⏳ Waiting for exercise data... (Attempt $retryCount)');
      }
      
      final filtered = allExercises.where((ex) {
        // 모든 관련 근육 리스트를 합쳐서 검사 (대소문자 무시)
        final allMuscles = [
          ...ex.primaryMuscles.map((m) => m.toLowerCase()),
          ...ex.secondaryMuscles.map((m) => m.toLowerCase()),
        ];
        
        final id = widget.muscleGroupId.toLowerCase();

        if (id == 'chest') return allMuscles.any((m) => m.contains('chest'));
        if (id == 'back') return allMuscles.any((m) => (m.contains('back') && !m.contains('lower')) || m == 'lats' || m == 'traps');
        if (id == 'shoulders') return allMuscles.any((m) => m == 'shoulders' || m.contains('delt') || m == 'rotator_cuff' || m == 'traps');
        if (id == 'legs') return allMuscles.any((m) => m == 'quads' || m == 'hamstrings' || m == 'calves' || m == 'legs');
        if (id == 'arms') return allMuscles.any((m) => m == 'biceps' || m == 'triceps' || m == 'forearms' || m == 'arms');
        if (id == 'biceps') return allMuscles.any((m) => m.contains('biceps') || m.contains('brachialis'));
        if (id == 'triceps') return allMuscles.any((m) => m.contains('triceps'));
        if (id == 'forearms') return allMuscles.any((m) => m.contains('forearm') || m.contains('brachioradialis'));
        if (id == 'core') return allMuscles.any((m) => m == 'core' || m.contains('abs') || m.contains('oblique') || m.contains('lower_back') || m == 'erector_spinae' || m.contains('glute'));
        if (id == 'compound') return ex.isCompound;
        
        return false;
      }).toList();

      _allFilteredExercises = filtered;

      final Map<String, List<Exercise>> grouped = {};
      for (var ex in filtered) {
        final groupName = ex.group ?? '기타';
        if (!grouped.containsKey(groupName)) {
          grouped[groupName] = [];
        }
        grouped[groupName]!.add(ex);
      }

      if (mounted) {
        setState(() {
          final sortedKeys = grouped.keys.toList();
          
          // 부위별 커스텀 정렬 로직 (기존 로직 유지)
          sortedKeys.sort((a, b) {
            if (widget.muscleGroupId == 'back') {
              if (a == '로우') return -1;
              if (b == '로우') return 1;
            }
            if (widget.muscleGroupId == 'shoulders') {
              if (a == '프레스') return -1;
              if (b == '프레스') return 1;
            }
            if (widget.muscleGroupId == 'biceps') {
              if (a == '바벨 컬') return -1;
              if (b == '바벨 컬') return 1;
            }
            if (widget.muscleGroupId == 'triceps') {
              if (a == '복합 관절 운동') return -1;
              if (b == '복합 관절 운동') return 1;
            }
            if (widget.muscleGroupId == 'forearms') {
              if (a == '손목 운동') return -1;
              if (b == '손목 운동') return 1;
            }
            if (widget.muscleGroupId == 'legs') {
              if (a == '스쿼트') return -1;
              if (b == '스쿼트') return 1;
            }
            if (widget.muscleGroupId == 'core') {
              final coreOrder = {'복근': 0, '허리': 1, '둔근(힙)': 2};
              final aOrder = coreOrder[a] ?? 99;
              final bOrder = coreOrder[b] ?? 99;
              if (aOrder != bOrder) return aOrder.compareTo(bOrder);
            }
            if (a == '기타' && b != '기타') return 1;
            if (b == '기타' && a != '기타') return -1;
            return a.compareTo(b);
          });
          
          final Map<String, List<Exercise>> sortedGrouped = {};
          for (var key in sortedKeys) {
            sortedGrouped[key] = grouped[key]!;
          }
          
          _groupedExercises = sortedGrouped;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('❌ Error loading exercises: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
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
        builder: (context) => StrengthRoutinePreviewScreen(template: template),
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
                    : ValueListenableBuilder<TextEditingValue>(
                        valueListenable: _searchController,
                        builder: (context, value, child) {
                          final query = value.text;
                          return query.isEmpty 
                              ? _buildGroupedList() 
                              : _buildSearchResults(query);
                        },
                      ),
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
        key: const ValueKey('exercise_search_field'),
        controller: _searchController,
        decoration: InputDecoration(
          hintText: '${widget.title} 운동 검색 (예: ㅂㅊ)',
          prefixIcon: const Icon(Icons.search),
          suffixIcon: ValueListenableBuilder<TextEditingValue>(
            valueListenable: _searchController,
            builder: (context, value, child) {
              return value.text.isNotEmpty 
                ? IconButton(
                    icon: const Icon(Icons.clear),
                    onPressed: () => _searchController.clear(),
                  )
                : const SizedBox.shrink();
            },
          ),
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
                    color: Theme.of(context).colorScheme.secondary,
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

  Widget _buildSearchResults(String query) {
    final filtered = _allFilteredExercises.where((ex) => 
      KoreanSearchUtils.matches(ex.nameKo, query) || 
      KoreanSearchUtils.matches(ex.name, query)
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
          ? SizedBox(
              width: 50,
              height: 50,
              child: SvgPicture.asset(
                exercise.imagePath!,
                fit: BoxFit.contain,
              ),
            )
          : Container(
              width: 50,
              height: 50,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.secondary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: SvgPicture.asset(
                'assets/images/strength/lifter-icon.svg',
                fit: BoxFit.contain,
                colorFilter: ColorFilter.mode(
                  Theme.of(context).colorScheme.secondary,
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
          color: Theme.of(context).colorScheme.secondary,
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

        return TweenAnimationBuilder<double>(
          key: ValueKey(provider.lastAddedTimestamp),
          duration: const Duration(milliseconds: 300),
          tween: Tween(begin: 0.0, end: 1.0),
          builder: (context, value, child) {
            final double offset = (1.0 - value) * -15.0;
            return Transform.translate(
              offset: Offset(0, offset),
              child: child,
            );
          },
          child: Container(
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
                                        controller: _routineScrollController,
                                        scrollDirection: Axis.horizontal,
                                        padding: const EdgeInsets.symmetric(horizontal: 16),
                                        itemCount: provider.blocks.length,
                                        itemBuilder: (context, index) {
                                          // 리스트 빌드 시 마지막 아이템 추가 감지하여 스크롤
                                          if (index == provider.blocks.length - 1) {
                                            _scrollToEnd();
                                          }
                                          final block = provider.blocks[index];                          final exercise = block.exerciseId != null 
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
                                    color: Theme.of(context).colorScheme.secondary.withValues(alpha: 0.8),
                                    width: 2.5,
                                  ),
                                ),
                                child: Center(
                                  child: Padding(
                                    padding: const EdgeInsets.all(2.0),
                                    child: SvgPicture.asset(
                                      imagePath ?? 'assets/images/strength/lifter-icon.svg',
                                      fit: BoxFit.contain,
                                      colorFilter: ColorFilter.mode(
                                        Theme.of(context).colorScheme.secondary,
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
                                      ? Theme.of(context).colorScheme.secondary 
                                      : Colors.grey,
                                ),
                              ),
                            ],
                          ),
                        ),
                                                if (hasSelection && !widget.isEnrichmentMode)
                                                  TextButton.icon(
                                                    onPressed: _saveCustomRoutine,
                                                    icon: const Icon(Icons.save_alt),
                                                    label: const Text('저장'),
                                                  ),
                                                const SizedBox(width: 8),
                                                ElevatedButton(
                                                  onPressed: hasSelection 
                                                      ? (widget.isEnrichmentMode ? () => Navigator.pop(context) : _startCustomRoutine) 
                                                      : null,
                                                  style: ElevatedButton.styleFrom(
                                                    backgroundColor: Theme.of(context).colorScheme.secondary,
                                                    foregroundColor: Theme.of(context).colorScheme.onSecondary,
                                                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                                                    shape: RoundedRectangleBorder(
                                                      borderRadius: BorderRadius.circular(12),
                                                    ),
                                                  ),
                                                  child: Text(widget.isEnrichmentMode ? '기록에 추가' : '루틴 시작'),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                );
                              },
                            );
                          }
                        }
                        