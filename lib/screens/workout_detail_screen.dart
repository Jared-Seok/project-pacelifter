import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import 'package:intl/intl.dart';
import 'package:health/health.dart';
import '../models/workout_data_wrapper.dart';
import '../services/native_activation_service.dart';
import '../services/workout_history_service.dart';
import '../services/scoring_engine.dart';
import '../services/template_service.dart';
import '../utils/workout_ui_utils.dart';
import '../providers/workout_detail_provider.dart';
import '../models/sessions/workout_session.dart';
import '../models/sessions/exercise_record.dart';
import '../providers/strength_routine_provider.dart';
import '../screens/exercise_list_screen.dart';
import '../widgets/exercise_config_sheet.dart';
import '../screens/workout_share_screen.dart'; // 추가

// Modularized Widgets
import '../widgets/workout/detail/common/workout_header.dart';
import '../widgets/workout/detail/visuals/workout_heart_rate_chart.dart';
import '../widgets/workout/detail/visuals/workout_route_map.dart';
import '../widgets/workout/detail/visuals/workout_pace_chart.dart';
import '../widgets/workout/detail/strength/strength_exercise_records.dart';
import '../widgets/workout/detail/strength/strength_enrichment_card.dart';
import '../widgets/workout/detail/sections/workout_metrics_grid.dart';
import '../widgets/workout/detail/strength/set_edit_dialog.dart';
import '../widgets/workout/detail/common/workout_result_overlay.dart';

enum WorkoutDetailMode { detail, result }

/// 운동 세부 정보 화면 (Modularized & Integrated)
class WorkoutDetailScreen extends StatefulWidget {
  final WorkoutDataWrapper dataWrapper;
  final WorkoutDetailMode mode;

  const WorkoutDetailScreen({
    super.key, 
    required this.dataWrapper,
    this.mode = WorkoutDetailMode.detail,
  });

  @override
  State<WorkoutDetailScreen> createState() => _WorkoutDetailScreenState();
}

class _WorkoutDetailScreenState extends State<WorkoutDetailScreen> {
  @override
  void initState() {
    super.initState();
    _activateServices();
  }

  Future<void> _activateServices() async {
    await NativeActivationService().activateGoogleMaps();
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => WorkoutDetailProvider(dataWrapper: widget.dataWrapper),
      child: Consumer<WorkoutDetailProvider>(
        builder: (context, provider, child) {
          if (provider.isLoading) {
            return const Scaffold(body: Center(child: CircularProgressIndicator()));
          }

          final displayInfo = WorkoutUIUtils.getWorkoutDisplayInfo(context, widget.dataWrapper);
          final color = displayInfo.color;
          final category = displayInfo.category;

          return Scaffold(
            backgroundColor: Theme.of(context).colorScheme.surface,
            appBar: AppBar(
              title: const Text('운동 세부 정보'),
              backgroundColor: Theme.of(context).colorScheme.surface,
              foregroundColor: Theme.of(context).colorScheme.onSurface,
              actions: [
                IconButton(
                  icon: const Icon(Icons.share), 
                  onPressed: () => _handleShareWorkout(context, provider)
                ),
              ],
            ),
            body: SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 0. 결과 모드 축하 오버레이
                  if (widget.mode == WorkoutDetailMode.result)
                    WorkoutResultOverlay(
                      themeColor: color,
                      onShareTap: () => _handleShareWorkout(context, provider),
                    ),

                  // 1. 헤더 (Icon, Name, Template)
                  WorkoutHeader(
                    displayInfo: displayInfo,
                    onTemplateTap: () => _showTemplateSelectionDialog(context),
                  ),
                  const SizedBox(height: 16),

                  // 2. 지도 (Endurance/Hybrid 전용)
                  if (category == 'Endurance' || category == 'Hybrid') ...[
                    WorkoutRouteMap(themeColor: color),
                    const SizedBox(height: 16),
                  ],

                  // 3. 지표 그리드 및 상세 리스트 (드롭다운 + 종목 추가 통합)
                  WorkoutMetricsGrid(
                    key: const ValueKey('workout_metrics_grid'),
                    provider: provider,
                    category: category,
                    themeColor: color,
                    onEditRecord: (record) => _editExerciseRecord(context, provider, record),
                    onAddExercise: () => _startRetroactiveLogging(context, provider),
                  ),
                  const SizedBox(height: 16),

                  // 4. 심박수 시각화
                  HeartRateVisualizer(themeColor: color),
                  const SizedBox(height: 16),

                  // 5. 페이스 시각화 (Endurance/Hybrid 전용)
                  if (category == 'Endurance' || category == 'Hybrid') ...[
                    PaceVisualizer(themeColor: color),
                    const SizedBox(height: 16),
                  ],

                  const SizedBox(height: 80),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  void _showTemplateSelectionDialog(BuildContext context) {
    // 템플릿 선택 로직 유지
  }

  void _startRetroactiveLogging(BuildContext context, WorkoutDetailProvider provider) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => _StrengthCategorySelectionView(
          onExercisesSelected: (newRecords) async {
            String sessionId = provider.session?.id ?? '';
            if (sessionId.isEmpty) {
              final newSession = WorkoutSession(
                id: Uuid().v4(),
                templateId: 'imported_${widget.dataWrapper.uuid}',
                templateName: '보강된 기록',
                category: 'Strength',
                startTime: widget.dataWrapper.dateFrom,
                endTime: widget.dataWrapper.dateTo,
                activeDuration: widget.dataWrapper.dateTo.difference(widget.dataWrapper.dateFrom).inSeconds,
                totalDuration: widget.dataWrapper.dateTo.difference(widget.dataWrapper.dateFrom).inSeconds,
                totalDistance: 0.0,
                calories: 0.0,
                healthKitWorkoutId: widget.dataWrapper.uuid,
                exerciseRecords: [],
              );
              await WorkoutHistoryService().saveSession(newSession);
              sessionId = newSession.id;
            }

            final currentRecords = List<ExerciseRecord>.from(provider.session?.exerciseRecords ?? []);
            currentRecords.addAll(newRecords);

            await WorkoutHistoryService().updateSessionExerciseRecords(sessionId: sessionId, exerciseRecords: currentRecords);
            await ScoringEngine().calculateAndSaveScores();
            provider.refresh();
          },
        ),
      ),
    );
  }

  void _editExerciseRecord(BuildContext context, WorkoutDetailProvider provider, ExerciseRecord record) {
    showDialog(
      context: context,
      builder: (context) => SetEditDialog(
        record: record,
        themeColor: WorkoutUIUtils.getWorkoutColor(context, provider.session?.category ?? 'Strength'),
        onSave: (newSets) async {
          final updatedRecord = ExerciseRecord(
            id: record.id,
            exerciseId: record.exerciseId,
            exerciseName: record.exerciseName,
            sets: newSets,
            order: record.order,
            timestamp: record.timestamp,
          );

          final currentRecords = List<ExerciseRecord>.from(provider.session?.exerciseRecords ?? []);
          final index = currentRecords.indexWhere((r) => r.id == record.id);
          if (index != -1) currentRecords[index] = updatedRecord;

          await WorkoutHistoryService().updateSessionExerciseRecords(
            sessionId: provider.session?.id ?? '',
            exerciseRecords: currentRecords,
          );
          await ScoringEngine().calculateAndSaveScores();
          provider.refresh();
        },
      ),
    );
  }

  void _handleShareWorkout(BuildContext context, WorkoutDetailProvider provider) {
    if (provider.dataWrapper.healthData == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('건강 데이터가 유실되어 공유할 수 없습니다.')),
      );
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => WorkoutShareScreen(
          workoutData: provider.dataWrapper.healthData!,
          heartRateData: provider.heartRateData,
          avgHeartRate: provider.avgHeartRate,
          paceData: provider.paceData,
          avgPace: provider.avgPace,
          movingTime: provider.activeDuration,
          templateName: provider.session?.templateName,
          environmentType: provider.session?.environmentType,
        ),
      ),
    );
  }
}

class _StrengthCategorySelectionView extends StatelessWidget {
  final Function(List<ExerciseRecord>) onExercisesSelected;
  const _StrengthCategorySelectionView({required this.onExercisesSelected});

  @override
  Widget build(BuildContext context) {
    final categories = [
      {'id': 'chest', 'name': '가슴', 'icon': 'assets/images/strength/category/chest.svg'},
      {'id': 'back', 'name': '등', 'icon': 'assets/images/strength/category/back.svg'},
      {'id': 'shoulders', 'name': '어깨', 'icon': 'assets/images/strength/category/shoulders.svg'},
      {'id': 'legs', 'name': '하체', 'icon': 'assets/images/strength/category/legs.svg'},
      {'id': 'biceps', 'name': '이두', 'icon': 'assets/images/strength/category/biceps.svg'},
      {'id': 'triceps', 'name': '삼두', 'icon': 'assets/images/strength/category/triceps.svg'},
      {'id': 'core', 'name': '코어', 'icon': 'assets/images/strength/category/core.svg'},
      {'id': 'compound', 'name': '복합', 'icon': 'assets/images/strength/lifter-icon.svg'},
    ];

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(title: const Text('수행 부위 선택')),
      body: GridView.builder(
        padding: const EdgeInsets.all(20),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2, crossAxisSpacing: 16, mainAxisSpacing: 16, childAspectRatio: 1.3,
        ),
        itemCount: categories.length,
        itemBuilder: (context, index) {
          final cat = categories[index];
          return _CategoryCard(
            name: cat['name']!,
            iconPath: cat['icon']!,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => ExerciseListScreen(
                    muscleGroupId: cat['id']!,
                    title: cat['name']!,
                    isEnrichmentMode: true,
                  ),
                ),
              ).then((_) {
                final provider = Provider.of<StrengthRoutineProvider>(context, listen: false);
                if (provider.blocks.isNotEmpty) {
                  final records = provider.blocks.map((block) => ExerciseRecord(
                    id: Uuid().v4(),
                    exerciseId: block.exerciseId ?? 'manual',
                    exerciseName: block.name,
                    sets: List.generate(block.sets ?? 3, (i) => SetRecord(
                      setNumber: i + 1,
                      weight: block.weight ?? 0,
                      repsTarget: block.reps ?? 10,
                      repsCompleted: block.reps ?? 10,
                    )),
                    order: 0,
                    timestamp: DateTime.now(),
                  )).toList();
                  onExercisesSelected(records);
                  provider.clear();
                  Navigator.pop(context);
                }
              });
            },
          );
        },
      ),
    );
  }
}

class _CategoryCard extends StatelessWidget {
  final String name;
  final String iconPath;
  final VoidCallback onTap;
  const _CategoryCard({required this.name, required this.iconPath, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SvgPicture.asset(
              iconPath, width: 40, height: 40,
              colorFilter: ColorFilter.mode(Theme.of(context).colorScheme.secondary, BlendMode.srcIn),
            ),
            const SizedBox(height: 12),
            Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          ],
        ),
      ),
    );
  }
}
