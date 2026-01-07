import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../models/sessions/workout_session.dart';

class WorkoutUIUtils {
  /// 운동 유형에 따른 카테고리 반환
  static String getWorkoutCategory(String activityType) {
    final type = activityType.toUpperCase();
    if (type.contains('RUNNING') || type.contains('WALKING') || type.contains('HIKING')) {
      return 'Endurance';
    }
    if (type.contains('STRENGTH') || type.contains('WEIGHT') || type.contains('CORE') || type.contains('FUNCTIONAL')) {
      return 'Strength';
    }
    return 'Endurance';
  }

  /// 운동 카테고리에 따른 브랜드 색상 반환
  static Color getWorkoutColor(BuildContext context, String category) {
    switch (category) {
      case 'Strength':
        return Theme.of(context).colorScheme.primary; // Orange
      case 'Endurance':
        return Theme.of(context).colorScheme.tertiary; // Deep Teal
      case 'Hybrid':
        return Theme.of(context).colorScheme.secondary; // Neon Green
      default:
        return Theme.of(context).colorScheme.secondary;
    }
  }

  /// 운동 유형에 따른 아이콘 경로 반환
  static String getWorkoutIconPath(String activityType) {
    final type = activityType.toUpperCase();
    if (type.contains('CORE') || type.contains('FUNCTIONAL')) {
      return 'assets/images/strength/core-icon.svg';
    } else if (type.contains('STRENGTH') || type.contains('WEIGHT') || type.contains('TRADITIONAL_STRENGTH_TRAINING')) {
      return 'assets/images/strength/lifter-icon.svg';
    } else if (type.contains('TRAIL')) {
      return 'assets/images/endurance/trail-icon.svg';
    } else {
      return 'assets/images/endurance/runner-icon.svg';
    }
  }

  /// 공통 운동 아이콘 위젯 반환
  static Widget getWorkoutIconWidget({
    required BuildContext context,
    required String type,
    required Color color,
    String? environmentType,
    WorkoutSession? session,
    double size = 24,
  }) {
    String iconPath = getWorkoutIconPath(type);
    final upperType = type.toUpperCase();
    
    // Core/Functional은 Strength 계열 색상으로 고정 (사용자 요청)
    Color iconColor = color;
    if (upperType.contains('CORE') || upperType.contains('FUNCTIONAL')) {
      iconColor = Theme.of(context).colorScheme.primary;
    }

    return SvgPicture.asset(
      iconPath,
      width: size,
      height: size,
      colorFilter: ColorFilter.mode(iconColor, BlendMode.srcIn),
    );
  }

  /// 운동 타입 이름 포맷팅
  static String formatWorkoutType(String type) {
    final upper = type.toUpperCase();
    if (upper.contains('TRADITIONAL_STRENGTH_TRAINING') || upper.contains('STRENGTH_TRAINING')) {
      return 'STRENGTH TRAINING';
    }
    if (upper.contains('CORE_TRAINING')) {
      return 'CORE TRAINING';
    }
    return upper.replaceAll('WORKOUT_ACTIVITY_TYPE_', '').replaceAll('_', ' ');
  }

  /// 화면 상단에 세련된 알림 표시 (Top Toast)
  static void showTopNotification(BuildContext context, String message, {bool isSuccess = true}) {
    final overlay = Overlay.of(context);
    final overlayEntry = OverlayEntry(
      builder: (context) => _TopNotificationWidget(
        message: message,
        isSuccess: isSuccess,
      ),
    );

    overlay.insert(overlayEntry);
    
    // 2.5초 후 제거
    Future.delayed(const Duration(milliseconds: 2500), () {
      overlayEntry.remove();
    });
  }
}

class _TopNotificationWidget extends StatefulWidget {
  final String message;
  final bool isSuccess;

  const _TopNotificationWidget({required this.message, required this.isSuccess});

  @override
  State<_TopNotificationWidget> createState() => _TopNotificationWidgetState();
}

class _TopNotificationWidgetState extends State<_TopNotificationWidget> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Offset> _offsetAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );

    _offsetAnimation = Tween<Offset>(
      begin: const Offset(0, -1),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutBack,
    ));

    _fadeAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeIn,
    );

    _controller.forward();

    // 사라질 때 애니메이션
    Future.delayed(const Duration(milliseconds: 2100), () {
      if (mounted) _controller.reverse();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: MediaQuery.of(context).padding.top + 10,
      left: 20,
      right: 20,
      child: Material(
        color: Colors.transparent,
        child: SlideTransition(
          position: _offsetAnimation,
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xFF2C2C2C),
                borderRadius: BorderRadius.circular(30),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.3),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
                border: Border.all(
                  color: widget.isSuccess ? Theme.of(context).colorScheme.secondary.withValues(alpha: 0.5) : Colors.red.withValues(alpha: 0.5),
                  width: 1,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    widget.isSuccess ? Icons.check_circle : Icons.error,
                    color: widget.isSuccess ? Theme.of(context).colorScheme.secondary : Colors.red,
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      widget.message,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}