import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pacelifter/models/workout_data_wrapper.dart';
import 'package:pacelifter/screens/workout_detail_screen.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:pacelifter/models/time_period.dart';
import 'package:pacelifter/services/workout_history_service.dart';
import 'package:pacelifter/models/sessions/workout_session.dart';
import 'package:pacelifter/services/template_service.dart';
import 'package:health/health.dart';
import 'package:pacelifter/utils/workout_ui_utils.dart';

class WorkoutFeedScreen extends StatefulWidget {
  final List<WorkoutDataWrapper> unifiedWorkouts;
  final TimePeriod period;
  final String dateRangeText;
  final String? raceName;

  const WorkoutFeedScreen({
    super.key,
    required this.unifiedWorkouts,
    required this.period,
    required this.dateRangeText,
    this.raceName,
  });

  @override
  State<WorkoutFeedScreen> createState() => _WorkoutFeedScreenState();
}

class _WorkoutFeedScreenState extends State<WorkoutFeedScreen> {
  bool _showTotalTime = false;
  final String _filterType = 'All';

  String get periodTitle {
    if (widget.raceName != null) return widget.raceName!;
    switch (widget.period) {
      case TimePeriod.week: return '주간';
      case TimePeriod.month: return '월간';
      case TimePeriod.year: return '연간';
    }
  }

  Color _getCategoryColor(String category, BuildContext context) {
    switch (category) {
      case 'Strength': return Theme.of(context).colorScheme.secondary; // Orange
      case 'Endurance': return Theme.of(context).colorScheme.tertiary; // Deep Teal
      case 'Hybrid': return Theme.of(context).colorScheme.primary; // Neon Green
      default: return Theme.of(context).colorScheme.primary;
    }
  }

  @override
  Widget build(BuildContext context) {
    final filteredData = widget.unifiedWorkouts.where((wrapper) {
      if (_filterType == 'All') return true;
      final hasSession = wrapper.session != null;
      if (_filterType == 'Set') return hasSession;
      if (_filterType == 'Unset') return !hasSession;
      return true;
    }).toList();

    int strengthCount = 0;
    int enduranceCount = 0;
    double totalDistance = 0.0;
    Duration totalTime = Duration.zero;

    for (final wrapper in widget.unifiedWorkouts) {
      String category = 'Unknown';
      double dist = 0.0;
      
      if (wrapper.healthData != null && wrapper.healthData!.value is WorkoutHealthValue) {
        final workout = wrapper.healthData!.value as WorkoutHealthValue;
        category = WorkoutUIUtils.getWorkoutCategory(workout.workoutActivityType.name);
        dist = (workout.totalDistance ?? 0.0).toDouble();
      } else if (wrapper.session != null) {
        category = wrapper.session!.category;
      }

      if (category == 'Strength') {
        strengthCount++;
      } else {
        enduranceCount++;
      }
      totalDistance += dist;
      totalTime += wrapper.dateTo.difference(wrapper.dateFrom);
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('$periodTitle 운동 피드'),
        backgroundColor: Theme.of(context).colorScheme.surface,
      ),
      body: Column(
        children: [
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
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    Expanded(child: _buildStatItem(context, '총 운동', '${widget.unifiedWorkouts.length}회', null, svgPath: 'assets/images/pllogo.svg', iconSize: 36, color: Theme.of(context).colorScheme.secondary)),
                    Expanded(child: _buildStatItem(context, 'Endurance', '$enduranceCount회', null, svgPath: 'assets/images/endurance/runner-icon.svg', color: Theme.of(context).colorScheme.tertiary)),
                    Expanded(child: _buildStatItem(context, 'Strength', '$strengthCount회', null, svgPath: 'assets/images/strength/lifter-icon.svg', color: Theme.of(context).colorScheme.secondary)),
                    if (totalDistance > 0 || totalTime > Duration.zero)
                      Expanded(child: _buildToggleableStatItem(context, totalDistance, totalTime)),
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            child: filteredData.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.inbox_outlined, size: 64, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.3)),
                        const SizedBox(height: 16),
                        Text('운동 기록이 없습니다', style: TextStyle(fontSize: 16, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6))),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: filteredData.length,
                    itemBuilder: (context, index) => _buildWorkoutItem(context, filteredData[index]),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(BuildContext context, String label, String value, IconData? icon, {String? svgPath, Color? color, double? iconSize}) {
    final displayColor = color ?? Theme.of(context).colorScheme.secondary;
    final size = iconSize ?? 32.0;
    return Column(
      children: [
        if (svgPath != null) SvgPicture.asset(svgPath, width: size, height: size, colorFilter: ColorFilter.mode(displayColor, BlendMode.srcIn))
        else if (icon != null) Icon(icon, size: size, color: displayColor),
        const SizedBox(height: 8),
        Text(label, style: TextStyle(fontSize: 13, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6))),
        const SizedBox(height: 4),
        Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: displayColor)),
      ],
    );
  }

  Widget _buildToggleableStatItem(BuildContext context, double totalDistance, Duration totalTime) {
    final displayColor = Theme.of(context).colorScheme.secondary;
    const size = 32.0;

    String formatDuration(Duration duration) {
      final hours = duration.inHours;
      final minutes = duration.inMinutes.remainder(60);
      if (hours > 0) return '$hours시간 $minutes분';
      if (minutes > 0) return '$minutes분 ${duration.inSeconds.remainder(60)}초';
      return '${duration.inSeconds}초';
    }

    return InkWell(
      onTap: () => setState(() => _showTotalTime = !_showTotalTime),
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.all(4.0),
        child: Column(
          children: [
            Icon(_showTotalTime ? Icons.timer : Icons.straighten, size: size, color: displayColor),
            const SizedBox(height: 8),
            Text(_showTotalTime ? '총 시간' : '총 거리', style: TextStyle(fontSize: 13, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6))),
            const SizedBox(height: 4),
            Text(_showTotalTime ? formatDuration(totalTime) : '${(totalDistance / 1000).toStringAsFixed(1)}km', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: displayColor), textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis),
          ],
        ),
      ),
    );
  }

  Widget _buildWorkoutItem(BuildContext context, WorkoutDataWrapper wrapper) {
    String type = 'UNKNOWN';
    double distance = 0.0;
    String workoutCategory = 'Unknown';
    final session = wrapper.session;
    final healthData = wrapper.healthData;

    if (healthData != null && healthData.value is WorkoutHealthValue) {
      final workout = healthData.value as WorkoutHealthValue;
      type = workout.workoutActivityType.name;
      distance = (workout.totalDistance ?? 0.0).toDouble();
      workoutCategory = WorkoutUIUtils.getWorkoutCategory(type);
    } else if (session != null) {
      workoutCategory = session.category;
      type = session.category == 'Strength' ? 'TRADITIONAL_STRENGTH_TRAINING' : 'OTHER';
    }

    final color = _getCategoryColor(workoutCategory, context);
    final upperType = type.toUpperCase();

    // 표시 이름 결정
    String displayName;
    if (session != null && session.templateId.isNotEmpty && session.templateId != 'health_kit_import') {
      displayName = session.templateName;
    } else {
      displayName = WorkoutUIUtils.formatWorkoutType(type);
    }

    final Color backgroundColor;
    final Color iconColor;

    if (upperType.contains('CORE') || upperType.contains('FUNCTIONAL')) {
      backgroundColor = Theme.of(context).colorScheme.secondary.withValues(alpha: 0.2);
      iconColor = Theme.of(context).colorScheme.secondary;
    } else {
      backgroundColor = color.withValues(alpha: 0.2);
      iconColor = color;
    }

    bool hasSpecificIcon = false;
    if (session != null) {
      final template = TemplateService.getTemplateById(session.templateId);
      if (template?.imagePath != null) hasSpecificIcon = true;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        onTap: () {
          Navigator.of(context).push(MaterialPageRoute(builder: (context) => WorkoutDetailScreen(dataWrapper: wrapper)));
        },
        onLongPress: session != null ? () => _showDeleteWorkoutDialog(context, wrapper) : (healthData != null ? () => _showTemplateSelectionDialog(context, healthData) : null),
        leading: Container(
          padding: hasSpecificIcon ? EdgeInsets.zero : const EdgeInsets.all(8),
          decoration: BoxDecoration(color: hasSpecificIcon ? Colors.transparent : backgroundColor, borderRadius: BorderRadius.circular(8)),
          child: WorkoutUIUtils.getWorkoutIconWidget(context: context, type: type, color: iconColor, environmentType: session?.environmentType, session: session),
        ),
        title: Text(displayName, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(DateFormat('yyyy-MM-dd HH:mm').format(wrapper.dateFrom)),
            if (session != null && session.templateId.isNotEmpty && session.templateId != 'health_kit_import')
              Padding(
                padding: const EdgeInsets.only(top: 6.0),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(color: Theme.of(context).colorScheme.secondary.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(4), border: Border.all(color: Theme.of(context).colorScheme.secondary.withValues(alpha: 0.5), width: 0.5)),
                  child: Text(session.templateName, style: TextStyle(fontSize: 11, color: Theme.of(context).colorScheme.secondary, fontWeight: FontWeight.w600)),
                ),
              ),
          ],
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            if (distance > 0) Text('${(distance / 1000).toStringAsFixed(2)} km', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            Text(workoutCategory, style: TextStyle(fontSize: 12, color: color)),
          ],
        ),
      ),
    );
  }

  void _showDeleteWorkoutDialog(BuildContext context, WorkoutDataWrapper wrapper) {
    final session = wrapper.session;
    if (session == null) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('운동 기록 삭제'),
        content: Text('${session.templateName} 기록을 PaceLifter에서 삭제하시겠습니까?\n\n*이 작업은 PaceLifter 내부 기록만 삭제하며, Apple 건강 앱의 원본 데이터는 유지됩니다.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('취소')),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await WorkoutHistoryService().deleteSession(session.id);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('PaceLifter 기록이 삭제되었습니다. 대시보드에서 확인하세요.')));
              }
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('삭제'),
          ),
        ],
      ),
    );
  }

  void _showTemplateSelectionDialog(BuildContext context, HealthDataPoint data) {
    final workout = data.value as WorkoutHealthValue;
    final type = workout.workoutActivityType.name;
    final category = WorkoutUIUtils.getWorkoutCategory(type);
    final templates = TemplateService.getTemplatesByCategory(category);
    if (templates.isEmpty) templates.addAll(TemplateService.getAllTemplates());

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7, minChildSize: 0.5, maxChildSize: 0.9, expand: false,
        builder: (context, scrollController) => Column(
          children: [
            const Padding(padding: EdgeInsets.all(16.0), child: Text('템플릿 설정', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold))),
            Expanded(
              child: ListView.builder(
                controller: scrollController,
                itemCount: templates.length,
                itemBuilder: (context, index) {
                  final template = templates[index];
                  return ListTile(
                    leading: CircleAvatar(backgroundColor: Theme.of(context).colorScheme.secondary.withValues(alpha: 0.1), child: Icon(Icons.bookmark_border, color: Theme.of(context).colorScheme.secondary)),
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
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${template.name} 템플릿으로 설정되었습니다.')));
                      }
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
