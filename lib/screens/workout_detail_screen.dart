import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import 'package:intl/intl.dart';
import 'package:health/health.dart';
import 'package:share_plus/share_plus.dart'; // Added
import '../utils/tracking/gpx_exporter.dart'; // Added
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
import '../screens/workout_share_screen.dart';
import '../constants/strength_categories.dart';

// Modularized Widgets
import '../widgets/workout/detail/common/workout_header.dart';
import '../widgets/workout/detail/visuals/workout_heart_rate_chart.dart';
import '../widgets/workout/detail/visuals/workout_route_map.dart';
import '../widgets/workout/detail/sections/workout_metrics_grid.dart';
import '../widgets/workout/detail/strength/set_edit_dialog.dart';
import '../widgets/workout/detail/common/workout_result_overlay.dart';
import '../widgets/workout/detail/sections/endurance_dashboard.dart';
import '../widgets/workout/detail/sections/endurance_hero_header.dart';
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
    // 💡 최적화: 화면 진입 렉 방지를 위해 미세한 지연 후 네이티브 서비스 활성화
    await Future.delayed(const Duration(milliseconds: 500));
    if (!mounted) return;
    
    await Future.wait([
      NativeActivationService().activateGoogleMaps(),
      NativeActivationService().activateMediaPicker(),
    ]);
  }

  void _handleExportGpx(BuildContext context, WorkoutDetailProvider provider) async {
    final session = provider.session;
    if (session == null || session.routePoints == null || session.routePoints!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('내보낼 경로 데이터가 없습니다.')),
      );
      return;
    }

    try {
      // 로딩 표시
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(child: CircularProgressIndicator()),
      );

      final file = await GpxExporter.generateGpxFile(session);
      
      if (context.mounted) {
        Navigator.pop(context); // 로딩 닫기
        
        await Share.shareXFiles(
          [XFile(file.path)],
          subject: 'PaceLifter 운동 경로 내보내기',
          text: '${session.templateName} 운동의 GPX 파일입니다.',
        );
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.pop(context); // 로딩 닫기
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('GPX 생성 오류: $e')),
        );
      }
    }
  }

  void _handleShareWorkout(BuildContext context, WorkoutDetailProvider provider) {
    // 💡 개선: healthData가 없더라도 session(로컬 기록)이 있으면 공유 가능하도록 변경
    if (provider.dataWrapper.healthData == null && provider.session == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('공유할 수 있는 운동 데이터가 없습니다.')),
      );
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => WorkoutShareScreen(
          workoutData: provider.dataWrapper.healthData, // null 허용 (ShareScreen에서 처리)
          session: provider.session, // 로컬 세션 전달 추가
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
                if (category == 'Endurance' || category == 'Hybrid')
                  IconButton(
                    icon: const Icon(Icons.map_outlined),
                    tooltip: 'GPX 내보내기',
                    onPressed: () => _handleExportGpx(context, provider),
                  ),
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