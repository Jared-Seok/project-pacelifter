import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../services/template_service.dart';
import '../models/sessions/workout_session.dart';

class WorkoutUIUtils {
  /// 운동 유형과 세션 정보를 바탕으로 적절한 아이콘 위젯 반환
  static Widget getWorkoutIconWidget({
    required BuildContext context,
    required String type,
    required Color color,
    double iconSize = 24,
    String? environmentType,
    WorkoutSession? session,
  }) {
    final upperType = type.toUpperCase();

    // 1. 트레일 러닝 환경이면 트레일 아이콘 우선 사용
    if (environmentType == 'Trail') {
      return SvgPicture.asset(
        'assets/images/endurance/trail-icon.svg',
        width: iconSize,
        height: iconSize,
        colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
      );
    }

    // 2. 세션 정보가 있는 경우 세부 운동 아이콘 확인
    if (session != null && session.templateId != null) {
      final template = TemplateService.getTemplateById(session.templateId!);
      if (template != null && template.phases.isNotEmpty) {
        // 첫 번째 페이즈의 첫 번째 블록에서 운동 정보 가져오기
        final firstBlock = template.phases.first.blocks.isNotEmpty 
            ? template.phases.first.blocks.first 
            : null;
            
        if (firstBlock != null && firstBlock.exerciseId != null) {
          final exercise = TemplateService.getExerciseById(firstBlock.exerciseId!);
          final imagePath = exercise?.imagePath;
          if (imagePath != null) {
            // 세부 운동 아이콘은 배경 공간(정사각형) 없이 크게 표시
            return SvgPicture.asset(
              imagePath,
              width: iconSize * 2.6, // 기존 24 기준 약 62~64
              height: iconSize * 2.6,
              colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
            );
          }
        }
      }
    }

    // 3. 기본 카테고리별 아이콘 매핑
    if (upperType.contains('RUNNING') ||
        upperType.contains('WALKING') ||
        upperType.contains('HIKING')) {
      return SvgPicture.asset(
        'assets/images/endurance/runner-icon.svg',
        width: iconSize,
        height: iconSize,
        colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
      );
    }

    if (upperType.contains('CORE') || upperType.contains('FUNCTIONAL')) {
      return SvgPicture.asset(
        'assets/images/strength/core-icon.svg',
        width: iconSize,
        height: iconSize,
        colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
      );
    }

    if (upperType.contains('STRENGTH') ||
        upperType.contains('WEIGHT') ||
        upperType.contains('TRADITIONAL_STRENGTH_TRAINING')) {
      return SvgPicture.asset(
        'assets/images/strength/lifter-icon.svg',
        width: iconSize,
        height: iconSize,
        colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
      );
    }

    // 기본 폴백
    return Icon(Icons.fitness_center, size: iconSize, color: color);
  }

  /// 운동 타입 문자열로 카테고리(Strength/Endurance) 판별
  static String getWorkoutCategory(String type) {
    final upperType = type.toUpperCase();
    if (upperType.contains('CORE') ||
        upperType.contains('FUNCTIONAL') ||
        upperType.contains('STRENGTH') ||
        upperType.contains('WEIGHT') ||
        upperType.contains('TRADITIONAL_STRENGTH_TRAINING')) {
      return 'Strength';
    } else {
      return 'Endurance';
    }
  }
}
