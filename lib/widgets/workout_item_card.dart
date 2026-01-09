import 'package:flutter/material.dart';
import '../models/workout_data_wrapper.dart';
import '../utils/workout_ui_utils.dart';

/// 전역적으로 일관된 운동 항목 카드 위젯 (대시보드 표준 디자인)
class WorkoutItemCard extends StatelessWidget {
  final WorkoutDataWrapper wrapper;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final bool activityOnly;
  final EdgeInsets? margin;

  const WorkoutItemCard({
    super.key,
    required this.wrapper,
    this.onTap,
    this.onLongPress,
    this.activityOnly = false,
    this.margin,
  });

  @override
  Widget build(BuildContext context) {
    // 중앙 엔진으로부터 가공된 표시 정보 획득
    final info = WorkoutUIUtils.getWorkoutDisplayInfo(
      context, 
      wrapper, 
      activityOnly: activityOnly,
    );

    return Card(
      margin: margin ?? const EdgeInsets.only(bottom: 12),
      child: ListTile(
        onTap: onTap,
        onLongPress: onLongPress,
        leading: Container(
          padding: info.hasSpecificIcon ? EdgeInsets.zero : const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: info.hasSpecificIcon ? Colors.transparent : info.backgroundColor,
            borderRadius: BorderRadius.circular(8),
          ),
          child: WorkoutUIUtils.getWorkoutIconWidget(
            context: context,
            type: info.type,
            color: info.iconColor,
            environmentType: wrapper.session?.environmentType,
            session: wrapper.session,
          ),
        ),
        title: Text(
          info.displayName,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              info.dateStr,
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
            if (info.templateName != null)
              Padding(
                padding: const EdgeInsets.only(top: 6.0),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: info.color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(
                      color: info.color.withValues(alpha: 0.5),
                      width: 0.5,
                    ),
                  ),
                  child: Text(
                    info.templateName!,
                    style: TextStyle(
                      fontSize: 11,
                      color: info.color,
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
            if (info.distanceStr != null)
              Text(
                info.distanceStr!,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
            Text(
              info.category,
              style: TextStyle(fontSize: 12, color: info.color),
            ),
          ],
        ),
      ),
    );
  }
}
