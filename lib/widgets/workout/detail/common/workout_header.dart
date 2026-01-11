import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';
import '../../../../models/workout_display_info.dart';
import '../../../../providers/workout_detail_provider.dart';
import '../../../../utils/workout_ui_utils.dart';

class WorkoutHeader extends StatelessWidget {
  final WorkoutDisplayInfo displayInfo;
  final VoidCallback onTemplateTap;

  const WorkoutHeader({
    super.key,
    required this.displayInfo,
    required this.onTemplateTap,
  });

  @override
  Widget build(BuildContext context) {
    return Consumer<WorkoutDetailProvider>(
      builder: (context, provider, child) {
        final session = provider.session;
        final color = displayInfo.color;
        final workoutType = displayInfo.type;
        final iconPath = WorkoutUIUtils.getWorkoutIconPath(workoutType, templateName: session?.templateName);

        return Card(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SvgPicture.asset(
                    iconPath, width: 80, height: 80,
                    colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    session != null && session.templateName.isNotEmpty
                        ? session.templateName
                        : WorkoutUIUtils.formatWorkoutType(workoutType, templateName: session?.templateName),
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: color),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  _buildCategoryBadge(displayInfo.category, color),
                  const SizedBox(height: 16),
                  _buildTemplateButton(context, session?.templateName, color),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildCategoryBadge(String category, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(12)),
      child: Text(category, style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: color)),
    );
  }

  Widget _buildTemplateButton(BuildContext context, String? templateName, Color color) {
    return InkWell(
      onTap: onTemplateTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(border: Border.all(color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.5)), borderRadius: BorderRadius.circular(20)),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.bookmark_border, size: 18, color: templateName != null ? color : Colors.grey),
            const SizedBox(width: 8),
            Text(templateName ?? '템플릿 설정하기', style: TextStyle(fontSize: 14, color: templateName != null ? color : Colors.grey)),
            const SizedBox(width: 4),
            const Icon(Icons.arrow_drop_down, size: 20, color: Colors.grey),
          ],
        ),
      ),
    );
  }
}