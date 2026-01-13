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
import '../constants/strength_categories.dart';

// Modularized Widgets
import '../widgets/workout/detail/common/workout_header.dart';
import '../widgets/workout/detail/visuals/workout_heart_rate_chart.dart';
import '../widgets/workout/detail/visuals/workout_route_map.dart';
import '../widgets/workout/detail/sections/workout_metrics_grid.dart';
import '../widgets/workout/detail/strength/set_edit_dialog.dart';
import '../widgets/workout/detail/common/workout_result_overlay.dart';
import '../widgets/workout/detail/sections/endurance_dashboard.dart';
import '../widgets/workout/detail/sections/endurance_hero_header.dart'; // 추가
import '../widgets/workout/detail/visuals/performance_analytic_chart.dart';

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

                  // 💡 유산소(Endurance) 히어로 레이아웃
                  if (category == 'Endurance' || category == 'Hybrid') ...[
                    WorkoutRouteMap(themeColor: color),
                    const SizedBox(height: 16),
                    EnduranceHeroHeader(
                      displayInfo: displayInfo,
                      date: widget.dataWrapper.dateFrom,
                    ),
                    const SizedBox(height: 16),
                    EnduranceDashboard(
                      provider: provider,
                      themeColor: color,
                    ),
                  ] 
                  // 🏋️ 근력(Strength) 표준 레이아웃
                  else ...[
                    WorkoutHeader(
                      displayInfo: displayInfo,
                      onTemplateTap: () => _showTemplateSelectionDialog(context),
                    ),
                    const SizedBox(height: 16),
                    WorkoutMetricsGrid(
                      key: const ValueKey('workout_metrics_grid'),
                      provider: provider,
                      category: category,
                      themeColor: color,
                      onEditRecord: (record) => _editExerciseRecord(context, provider, record),
                      onAddExercise: () => _startRetroactiveLogging(context, provider),
                    ),
                  ],

                  const SizedBox(height: 24),

                  // 📊 통합 분석 차트 (유산소 전용)
                  if (category == 'Endurance' || category == 'Hybrid') ...[
                    PerformanceAnalyticChart(themeColor: color),
                    const SizedBox(height: 16),
                  ] else ...[
                    // 근력 운동은 심박수만 표시
                    HeartRateVisualizer(themeColor: color),
                    const SizedBox(height: 16),
                  ],

                  // 🏷️ 공통 데이터 출처 (최하단)
                  _buildDataSourceFooter(context, provider.dataWrapper.sourceName),

                  const SizedBox(height: 80),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildDataSourceFooter(BuildContext context, String source) {
    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 32),
        child: Column(
          children: [
            Icon(Icons.verified_user_outlined, size: 16, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.3)),
            const SizedBox(height: 8),
            Text(
              '데이터 출처: $source',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.3),
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Apple Health 및 PaceLifter 보안 규정을 준수합니다',
              style: TextStyle(
                fontSize: 9,
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.2),
              ),
            ),
          ],
        ),
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
    final categories = StrengthCategories.categories;

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
            name: cat.name,
            iconPath: cat.iconPath,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => ExerciseListScreen(
                    muscleGroupId: cat.id,
                    title: cat.name,
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
            SizedBox(
              width: 60,
              height: 60,
              child: SvgPicture.asset(
                iconPath,
                fit: BoxFit.contain,
              ),
            ),
            const SizedBox(height: 12),
            Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          ],
        ),
      ),
    );
  }
}
