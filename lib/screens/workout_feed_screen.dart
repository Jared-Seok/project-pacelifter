import 'package:flutter/material.dart';
import 'package:health/health.dart';
import 'package:intl/intl.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:pacelifter/screens/workout_detail_screen.dart';
import 'package:pacelifter/models/time_period.dart';
import 'package:pacelifter/services/workout_history_service.dart';
import 'package:pacelifter/models/workout_data_wrapper.dart';
import 'package:pacelifter/models/sessions/workout_session.dart';
import 'package:pacelifter/services/template_service.dart';
import 'package:pacelifter/utils/workout_ui_utils.dart';

class WorkoutFeedScreen extends StatefulWidget {
  final List<HealthDataPoint> workoutData;
  final TimePeriod period;
  final String dateRangeText;
  final String? raceName; // 레이스 이름 (선택적)

  const WorkoutFeedScreen({
    super.key,
    required this.workoutData,
    required this.period,
    required this.dateRangeText,
    this.raceName,
  });

  @override
  State<WorkoutFeedScreen> createState() => _WorkoutFeedScreenState();
}

class _WorkoutFeedScreenState extends State<WorkoutFeedScreen> {
  bool _showTotalTime = false; // false: 총 거리, true: 총 시간
  Map<String, WorkoutSession> _sessionMap = {};
  final String _filterType = 'All'; // 'All', 'Set', 'Unset'

  @override
  void initState() {
    super.initState();
    _loadSessions();
  }

  void _loadSessions() {
    final sessions = WorkoutHistoryService().getAllSessions();
    final map = <String, WorkoutSession>{};
    for (var session in sessions) {
      if (session.healthKitWorkoutId != null) {
        map[session.healthKitWorkoutId!] = session;
      }
    }
    if (mounted) {
      setState(() {
        _sessionMap = map;
      });
    }
  }

  String get periodTitle {
    // 레이스 이름이 있으면 레이스 이름 사용, 없으면 기간 표시
    if (widget.raceName != null) {
      return widget.raceName!;
    }
    switch (widget.period) {
      case TimePeriod.week:
        return '주간';
      case TimePeriod.month:
        return '월간';
      case TimePeriod.year:
        return '연간';
    }
  }

  Color _getCategoryColor(String category, BuildContext context) {
    switch (category) {
      case 'Strength':
        return Theme.of(context).colorScheme.primary;
      case 'Endurance':
        return Theme.of(context).colorScheme.secondary;
      default:
        return Theme.of(context).colorScheme.secondary;
    }
  }

  @override
  Widget build(BuildContext context) {
    // Calculate statistics
    int strengthCount = 0;
    int enduranceCount = 0;
    double totalDistance = 0.0;
    Duration totalTime = Duration.zero;

    for (final data in widget.workoutData) {
      final workout = data.value as WorkoutHealthValue;
      final type = workout.workoutActivityType.name;
      if (WorkoutUIUtils.getWorkoutCategory(type) == 'Strength') {
        strengthCount++;
      } else {
        enduranceCount++;
      }
      totalDistance += workout.totalDistance ?? 0.0;

      // 운동 시간 합산
      final workoutDuration = data.dateTo.difference(data.dateFrom);
      totalTime += workoutDuration;
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('$periodTitle 운동 피드'),
        backgroundColor: Theme.of(context).colorScheme.surface,
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () {
              Navigator.of(context).pushNamed('/add-workout');
            },
            tooltip: '운동 추가',
          ),
        ],
      ),
      body: Column(
        children: [
          // Summary Card
          Container(
            margin: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                Text(
                  widget.dateRangeText,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    Expanded(
                      child: _buildStatItem(
                        context,
                        '총 운동',
                        '${widget.workoutData.length}회',
                        null,
                        svgPath: 'assets/images/pllogo.svg',
                        iconSize: 36,
                        color: Theme.of(context).colorScheme.secondary,
                      ),
                    ),
                    Expanded(
                      child: _buildStatItem(
                        context,
                        'Endurance',
                        '$enduranceCount회',
                        null,
                        svgPath: 'assets/images/endurance/runner-icon.svg',
                        color: Theme.of(context).colorScheme.secondary,
                      ),
                    ),
                    Expanded(
                      child: _buildStatItem(
                        context,
                        'Strength',
                        '$strengthCount회',
                        null,
                        svgPath: 'assets/images/strength/lifter-icon.svg',
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                    if (totalDistance > 0 || totalTime > Duration.zero)
                      Expanded(
                        child: _buildToggleableStatItem(
                          context,
                          totalDistance,
                          totalTime,
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
          // Workout List
          Expanded(
            child: widget.workoutData.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.inbox_outlined,
                          size: 64,
                          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.3),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          '운동 기록이 없습니다',
                          style: TextStyle(
                            fontSize: 16,
                            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: widget.workoutData.length,
                    itemBuilder: (context, index) {
                      return _buildWorkoutItem(context, widget.workoutData[index]);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(
    BuildContext context,
    String label,
    String value,
    IconData? icon, {
    String? svgPath,
    Color? color,
    double? iconSize,
  }) {
    final displayColor = color ?? Theme.of(context).colorScheme.primary;
    final size = iconSize ?? 32.0;
    return Column(
      children: [
        if (svgPath != null)
          SvgPicture.asset(
            svgPath,
            width: size,
            height: size,
            colorFilter: ColorFilter.mode(displayColor, BlendMode.srcIn),
          )
        else if (icon != null)
          Icon(icon, size: size, color: displayColor),
        const SizedBox(height: 8),
        Text(
          label,
          style: TextStyle(
            fontSize: 13,
            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: displayColor,
          ),
        ),
      ],
    );
  }

  Widget _buildToggleableStatItem(
    BuildContext context,
    double totalDistance,
    Duration totalTime,
  ) {
    final displayColor = Theme.of(context).colorScheme.primary;
    const size = 32.0;

    String formatDuration(Duration duration) {
      final hours = duration.inHours;
      final minutes = duration.inMinutes.remainder(60);
      final seconds = duration.inSeconds.remainder(60);

      if (hours > 0) {
        return '$hours시간 $minutes분';
      } else if (minutes > 0) {
        return '$minutes분 $seconds초';
      } else {
        return '$seconds초';
      }
    }

    return InkWell(
      onTap: () {
        setState(() {
          _showTotalTime = !_showTotalTime;
        });
      },
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.all(4.0),
        child: Column(
          children: [
            Icon(
              _showTotalTime ? Icons.timer : Icons.straighten,
              size: size,
              color: displayColor,
            ),
            const SizedBox(height: 8),
            Text(
              _showTotalTime ? '총 시간' : '총 거리',
              style: TextStyle(
                fontSize: 13,
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              _showTotalTime
                  ? formatDuration(totalTime)
                  : '${(totalDistance / 1000).toStringAsFixed(1)}km',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: displayColor,
              ),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWorkoutItem(BuildContext context, HealthDataPoint data) {
    final workout = data.value as WorkoutHealthValue;
    final distance = workout.totalDistance ?? 0.0;
    final type = workout.workoutActivityType.name;
    final workoutCategory = WorkoutUIUtils.getWorkoutCategory(type);
    final color = _getCategoryColor(workoutCategory, context);

    String displayName;
    final session = _sessionMap[data.uuid];
    
    if (session != null) {
      displayName = session.templateName;
    } else {
      final upperType = type.toUpperCase();
      if (type == 'TRADITIONAL_STRENGTH_TRAINING') {
        displayName = 'STRENGTH TRAINING';
      } else if (type == 'CORE_TRAINING') {
        displayName = 'CORE TRAINING';
      } else if (upperType.contains('RUNNING')) {
        displayName = 'RUNNING';
      } else {
        displayName = type;
      }
    }

    final Color backgroundColor;
    final Color iconColor;

    final upperType = type.toUpperCase();
    if (upperType.contains('CORE') || upperType.contains('FUNCTIONAL')) {
      backgroundColor = Theme.of(context).colorScheme.primary.withValues(alpha: 0.2);
      iconColor = Theme.of(context).colorScheme.secondary;
    } else {
      backgroundColor = color.withValues(alpha: 0.2);
      iconColor = color;
    }

    // 세부 운동 아이콘이 있는지 확인 (배경 제거 로직용)
    bool hasSpecificIcon = false;
    if (session != null && session.templateId != null) {
      final template = TemplateService.getTemplateById(session.templateId!);
      if (template != null && template.phases.isNotEmpty) {
        final firstBlock = template.phases.first.blocks.isNotEmpty ? template.phases.first.blocks.first : null;
        if (firstBlock != null && firstBlock.exerciseId != null) {
          final exercise = TemplateService.getExerciseById(firstBlock.exerciseId!);
          if (exercise?.imagePath != null) hasSpecificIcon = true;
        }
      }
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        onTap: () async {
          await Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => WorkoutDetailScreen(
                dataWrapper: WorkoutDataWrapper(healthData: data, session: session),
              ),
            ),
          );
          _loadSessions();
        },
        onLongPress: () {
          _showTemplateSelectionDialog(context, data);
        },
        leading: Container(
          padding: hasSpecificIcon ? EdgeInsets.zero : const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: hasSpecificIcon ? Colors.transparent : backgroundColor,
            borderRadius: BorderRadius.circular(8),
          ),
          child: WorkoutUIUtils.getWorkoutIconWidget(
            context: context,
            type: type,
            color: iconColor,
            environmentType: session?.environmentType,
            session: session,
          ),
        ),
        title: Text(displayName, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(DateFormat('yyyy-MM-dd HH:mm').format(data.dateFrom)),
            if (session != null)
              Padding(
                padding: const EdgeInsets.only(top: 6.0),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.secondary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(
                      color: Theme.of(context).colorScheme.secondary.withValues(alpha: 0.5),
                      width: 0.5,
                    ),
                  ),
                  child: Text(
                    session.templateName,
                    style: TextStyle(
                      fontSize: 11,
                      color: Theme.of(context).colorScheme.secondary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
          ],
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            if (distance > 0)
              Text(
                '${(distance / 1000).toStringAsFixed(2)} km',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
            Text(workoutCategory, style: TextStyle(fontSize: 12, color: color)),
          ],
        ),
      ),
    );
  }

  void _showTemplateSelectionDialog(BuildContext context, HealthDataPoint data) {
    final workout = data.value as WorkoutHealthValue;
    final type = workout.workoutActivityType.name;
    final category = WorkoutUIUtils.getWorkoutCategory(type);
    
    final templates = TemplateService.getTemplatesByCategory(category);
    if (templates.isEmpty) {
      templates.addAll(TemplateService.getAllTemplates());
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.7,
          minChildSize: 0.5,
          maxChildSize: 0.9,
          expand: false,
          builder: (context, scrollController) {
            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Text(
                    '템플릿 설정',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                ),
                Expanded(
                  child: ListView.builder(
                    controller: scrollController,
                    itemCount: templates.length,
                    itemBuilder: (context, index) {
                      final template = templates[index];
                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor: Theme.of(context).colorScheme.secondary.withValues(alpha: 0.1),
                          child: Icon(Icons.bookmark_border, color: Theme.of(context).colorScheme.secondary),
                        ),
                        title: Text(template.name),
                        subtitle: Text(template.description, maxLines: 1, overflow: TextOverflow.ellipsis),
                        onTap: () async {
                          await WorkoutHistoryService().linkTemplateToWorkout(
                            healthKitId: data.uuid,
                            template: template,
                            startTime: data.dateFrom,
                            endTime: data.dateTo,
                            totalDistance: (workout.totalDistance ?? 0).toDouble(),
                            calories: (workout.totalEnergyBurned ?? 0).toDouble(),
                          );
                          
                          if (mounted) {
                            Navigator.pop(context);
                            _loadSessions(); 
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('${template.name} 템플릿으로 설정되었습니다.')),
                            );
                          }
                        },
                      );
                    },
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }
}