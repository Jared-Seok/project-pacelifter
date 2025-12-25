import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../providers/strength_routine_provider.dart';
import 'exercise_list_screen.dart';
import '../models/templates/workout_template.dart';
import '../models/templates/template_phase.dart';
import '../models/templates/template_block.dart';
import '../models/exercises/exercise.dart';
import '../services/template_service.dart';
import 'strength_tracking_screen.dart';
import '../utils/korean_search_utils.dart';

class StrengthTemplateScreen extends StatefulWidget {
  const StrengthTemplateScreen({super.key});

  @override
  State<StrengthTemplateScreen> createState() => _StrengthTemplateScreenState();
}

class _StrengthTemplateScreenState extends State<StrengthTemplateScreen> with SingleTickerProviderStateMixin {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  final List<Map<String, dynamic>> _muscleGroups = [
    {'id': 'chest', 'name': '가슴', 'icon': 'assets/images/strength/lifter-icon.svg'},
    {'id': 'shoulders', 'name': '어깨', 'icon': 'assets/images/strength/lifter-icon.svg'},
    {'id': 'back', 'name': '등', 'icon': 'assets/images/strength/lifter-icon.svg'},
    {'id': 'biceps', 'name': '이두', 'icon': 'assets/images/strength/lifter-icon.svg'},
    {'id': 'triceps', 'name': '삼두', 'icon': 'assets/images/strength/lifter-icon.svg'},
    {'id': 'forearms', 'name': '전완', 'icon': 'assets/images/strength/lifter-icon.svg'},
    {'id': 'legs', 'name': '하체', 'icon': 'assets/images/strength/lifter-icon.svg'},
    {'id': 'core', 'name': '코어', 'icon': 'assets/images/strength/core-icon.svg'},
    {'id': 'compound', 'name': '복합', 'icon': 'assets/images/strength/lifter-icon.svg'},
  ];

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text;
      });
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _onMuscleGroupTap(String id, String name) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ExerciseListScreen(muscleGroupId: id, title: name),
      ),
    );
  }

  void _addExerciseToRoutine(Exercise exercise) {
    final provider = Provider.of<StrengthRoutineProvider>(context, listen: false);
    
    final block = TemplateBlock(
      id: const Uuid().v4(),
      name: exercise.nameKo,
      type: 'strength',
      exerciseId: exercise.id,
      sets: 3,
      reps: 10,
      restSeconds: 60,
      order: provider.blocks.length,
    );

    provider.addBlock(block);
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${exercise.nameKo}가 루틴에 추가되었습니다'),
        duration: const Duration(seconds: 1),
        action: SnackBarAction(
          label: '취소',
          onPressed: () => provider.removeBlock(block.id),
        ),
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
                setState(() {});
              }
            },
            child: const Text('저장'),
          ),
        ],
      ),
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

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: Theme.of(context).colorScheme.surface,
        appBar: AppBar(
          title: const Text('Strength Training'),
          backgroundColor: Theme.of(context).colorScheme.surface,
          foregroundColor: Theme.of(context).colorScheme.onSurface,
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: () {
                Provider.of<StrengthRoutineProvider>(context, listen: false).clear();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('루틴이 초기화되었습니다')),
                );
              },
            ),
          ],
          bottom: const TabBar(
            tabs: [
              Tab(text: '운동 선택'),
              Tab(text: '내 루틴'),
            ],
          ),
        ),
        body: Stack(
          children: [
            TabBarView(
              children: [
                _buildSelectionTab(),
                _buildMyRoutinesTab(),
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
      ),
    );
  }

  Widget _buildSelectionTab() {
    return Column(
      children: [
        // 1. 검색바
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: '운동 검색 (예: 벤치프레스, ㅂㅊ)',
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
        ),

        // 2. 검색 결과 또는 부위별 그리드
        Expanded(
          child: _searchQuery.isEmpty 
            ? GridView.builder(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 200), // 더 넓은 하단 공간 확보
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 10,
                  childAspectRatio: 0.95,
                ),
                itemCount: _muscleGroups.length,
                itemBuilder: (context, index) {
                  final group = _muscleGroups[index];
                  return _buildMuscleCard(group);
                },
              )
            : _buildFilteredExerciseList(),
        ),
      ],
    );
  }

  Widget _buildFilteredExerciseList() {
    final allExercises = TemplateService.getAllExercises();
    final filtered = allExercises.where((ex) => 
      KoreanSearchUtils.matches(ex.nameKo, _searchQuery) || 
      KoreanSearchUtils.matches(ex.name, _searchQuery)
    ).toList();

    if (filtered.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search_off, size: 64, color: Colors.grey.withValues(alpha: 0.3)),
            const SizedBox(height: 16),
            const Text('일치하는 운동이 없습니다', style: TextStyle(color: Colors.grey)),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 200), // 하단 공간 확보
      itemCount: filtered.length,
      itemBuilder: (context, index) {
        final ex = filtered[index];
        final hasSpecificIcon = ex.imagePath != null;
        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            leading: hasSpecificIcon
              ? SvgPicture.asset(
                  ex.imagePath!,
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
            title: Text(ex.nameKo, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            subtitle: Text('${ex.equipment} | ${ex.primaryMuscles.join(", ")}', style: const TextStyle(fontSize: 13)),
            trailing: const Icon(Icons.add_circle_outline),
            onTap: () => _addExerciseToRoutine(ex),
          ),
        );
      },
    );
  }

  Widget _buildMyRoutinesTab() {
    final allTemplates = TemplateService.getAllTemplates();
    final myRoutines = allTemplates.where((t) => t.category == 'Strength' && t.isCustom).toList();

    if (myRoutines.isEmpty) {
      return Container(
        padding: const EdgeInsets.only(bottom: 80), // 하단 장바구니 높이를 고려한 시각적 중앙 보정
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SvgPicture.asset(
                'assets/images/strength/lifter-icon.svg',
                width: 96, // 64에서 50% 증가
                height: 96,
                colorFilter: ColorFilter.mode(
                  Colors.grey.withValues(alpha: 0.3),
                  BlendMode.srcIn,
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                '저장된 루틴이 없습니다', 
                style: TextStyle(color: Colors.grey, fontSize: 16, fontWeight: FontWeight.bold), // 14에서 10% 이상 증가
              ),
              const SizedBox(height: 10),
              const Text(
                '운동을 선택하고 나만의 루틴을 만들어보세요', 
                style: TextStyle(color: Colors.grey, fontSize: 13), // 12에서 약 10% 증가
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 200), // 하단 공간 확보
      itemCount: myRoutines.length,
      itemBuilder: (context, index) {
        final routine = myRoutines[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
              child: SvgPicture.asset(
                'assets/images/strength/lifter-icon.svg',
                width: 24,
                height: 24,
                colorFilter: ColorFilter.mode(
                  Theme.of(context).colorScheme.primary,
                  BlendMode.srcIn,
                ),
              ),
            ),
            title: Text(routine.name, style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text('${routine.phases.first.blocks.length}개 운동'),
            trailing: IconButton(
              icon: const Icon(Icons.play_arrow),
              color: Theme.of(context).colorScheme.primary,
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => StrengthTrackingScreen(template: routine),
                  ),
                );
              },
            ),
            onLongPress: () async {
              final confirm = await showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('루틴 삭제'),
                  content: Text('${routine.name} 루틴을 삭제하시겠습니까?'),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('취소')),
                    TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('삭제')),
                  ],
                ),
              );
              
              if (confirm == true) {
                await TemplateService.deleteTemplate(routine.id);
                setState(() {});
              }
            },
          ),
        );
      },
    );
  }

  Widget _buildMuscleCard(Map<String, dynamic> group) {
    return InkWell(
      onTap: () => _onMuscleGroupTap(group['id'], group['name']),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.2),
            width: 1,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: SvgPicture.asset(
                group['icon'],
                width: 24,
                height: 24,
                colorFilter: ColorFilter.mode(
                  Theme.of(context).colorScheme.primary,
                  BlendMode.srcIn,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              group['name'],
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
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
                // 1. 운동 아이콘 리스트 (선택된 운동이 있을 때만 표시 및 높이 확보)
                if (hasSelection)
                  Container(
                    height: 130, // 아이콘 크기 증가에 따른 높이 확보
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
                              width: 91, // 기존 70에서 30% 증가
                              height: 91,
                              decoration: BoxDecoration(
                                color: Theme.of(context).colorScheme.surface, // 앱 배경색과 일치
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.5),
                                  width: 2.0,
                                ),
                              ),
                              child: Center(
                                child: Padding(
                                  padding: const EdgeInsets.all(2.0), // 여백 최소화
                                  child: SvgPicture.asset(
                                    imagePath ?? 'assets/images/strength/lifter-icon.svg',
                                    fit: BoxFit.contain, // 최대한 채우기
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
                // 2. 루틴 정보 및 시작 버튼
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