import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../../models/workout_display_info.dart';

/// 유산소 전용 히어로 헤더 (아이콘 없이 지도와 정보에 집중)
class EnduranceHeroHeader extends StatelessWidget {
  final WorkoutDisplayInfo displayInfo;
  final DateTime date;

  const EnduranceHeroHeader({
    super.key,
    required this.displayInfo,
    required this.date,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dateStr = DateFormat('yyyy년 MM월 dd일 • HH:mm').format(date);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 4,
                height: 24,
                decoration: BoxDecoration(
                  color: displayInfo.color,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      displayInfo.displayName,
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      dateStr,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: theme.colorScheme.onSurface.withOpacity(0.5),
                      ),
                    ),
                  ],
                ),
              ),
              // 템플릿 태그 (작게 표시)
              if (displayInfo.templateName != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: displayInfo.color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    displayInfo.templateName!,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: displayInfo.color,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
