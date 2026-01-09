import 'package:flutter/material.dart';

/// 최종 UI 출력에 필요한 가공된 운동 정보를 담는 모델
class WorkoutDisplayInfo {
  final String category;
  final String displayName;
  final String dateStr;
  final String? templateName;
  final String? distanceStr;
  final Color color;
  final Color backgroundColor;
  final Color iconColor;
  final bool hasSpecificIcon;
  final String type;

  WorkoutDisplayInfo({
    required this.category,
    required this.displayName,
    required this.dateStr,
    this.templateName,
    this.distanceStr,
    required this.color,
    required this.backgroundColor,
    required this.iconColor,
    required this.hasSpecificIcon,
    required this.type,
  });
}
