import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../providers/strength_routine_provider.dart';
import 'exercise_list_screen.dart';
import '../models/templates/workout_template.dart';
import '../models/templates/template_phase.dart';
import '../services/template_service.dart';
import 'strength_tracking_screen.dart';

class StrengthTemplateScreen extends StatefulWidget {
  const StrengthTemplateScreen({super.key});

  @override
  State<StrengthTemplateScreen> createState() => _StrengthTemplateScreenState();
}

class _StrengthTemplateScreenState extends State<StrengthTemplateScreen> {
  final TextEditingController _searchController = TextEditingController();

  final List<Map<String, dynamic>> _muscleGroups = [
    {'id': 'chest', 'name': '가슴', 'icon': 'assets/images/strength/lifter-icon.svg'},
    {'id': 'back', 'name': '등', 'icon': 'assets/images/strength/lifter-icon.svg'},
    {'id': 'shoulders', 'name': '어깨', 'icon': 'assets/images/strength/lifter-icon.svg'},
    {'id': 'legs', 'name': '하체', 'icon': 'assets/images/strength/lifter-icon.svg'},
    {'id': 'arms', 'name': '팔', 'icon': 'assets/images/strength/pullup-icon.svg'},
    {'id': 'core', 'name': '코어', 'icon': 'assets/images/strength/core-icon.svg'},
  ];

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
                    blocks: List.from(blocks), // Deep copy not strictly needed here if saved immediately
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
                // Refresh logic if needed (SetState to update 'My Routines' tab)
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

    // 임시 템플릿 생성
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
        body: Column(
          children: [
            Expanded(
              child: TabBarView(
                children: [
                  _buildSelectionTab(),
                  _buildMyRoutinesTab(),
                ],
              ),
            ),
            _buildBottomRoutineBar(),
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
              hintText: '운동 검색 (예: 벤치프레스)',
              prefixIcon: const Icon(Icons.search),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              filled: true,
              fillColor: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
            onSubmitted: (value) {
              // TODO: 검색 결과 화면으로 이동
            },
          ),
        ),

        // 2. 부위별 그리드
        Expanded(
          child: GridView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 1.1, // 카드 비율
            ),
            itemCount: _muscleGroups.length,
            itemBuilder: (context, index) {
              final group = _muscleGroups[index];
              return _buildMuscleCard(group);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildMyRoutinesTab() {
    // 저장된 커스텀 템플릿 로드
    final allTemplates = TemplateService.getAllTemplates();
    final myRoutines = allTemplates.where((t) => t.category == 'Strength' && t.isCustom).toList();

    if (myRoutines.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.fitness_center, size: 64, color: Colors.grey.withValues(alpha: 0.3)),
            const SizedBox(height: 16),
            const Text('저장된 루틴이 없습니다', style: TextStyle(color: Colors.grey)),
            const SizedBox(height: 8),
            const Text('운동을 선택하고 나만의 루틴을 만들어보세요', style: TextStyle(color: Colors.grey, fontSize: 12)),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: myRoutines.length,
      itemBuilder: (context, index) {
        final routine = myRoutines[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: Theme.of(context).colorScheme.primaryContainer,
              child: Icon(Icons.star, color: Theme.of(context).colorScheme.primary),
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
              // 삭제 옵션
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
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: SvgPicture.asset(
                group['icon'],
                width: 32,
                height: 32,
                colorFilter: ColorFilter.mode(
                  Theme.of(context).colorScheme.primary,
                  BlendMode.srcIn,
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              group['name'],
              style: const TextStyle(
                fontSize: 18,
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
        return SafeArea(
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              border: Border(
                top: BorderSide(
                  color: Theme.of(context).colorScheme.outlineVariant,
                  width: 1,
                ),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        '현재 루틴',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '$count개 운동 선택됨',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                    ],
                  ),
                ),
                if (count > 0)
                  TextButton.icon(
                    onPressed: _saveCustomRoutine,
                    icon: const Icon(Icons.save_alt),
                    label: const Text('저장'),
                  ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: count > 0 ? _startCustomRoutine : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    foregroundColor: Theme.of(context).colorScheme.onPrimary,
                  ),
                  child: const Text('루틴 시작'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
