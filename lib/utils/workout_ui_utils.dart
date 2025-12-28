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
    
    // 세부 운동 아이콘 처리
    if (session != null && session.exerciseRecords != null && session.exerciseRecords!.isNotEmpty) {
      // 첫 번째 운동의 아이콘 확인 로직 등 추가 가능
    }

    return SvgPicture.asset(
      iconPath,
      width: size,
      height: size,
      colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
    );
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
                  color: widget.isSuccess ? const Color(0xFFD4E157).withValues(alpha: 0.5) : Colors.red.withValues(alpha: 0.5),
                  width: 1,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    widget.isSuccess ? Icons.check_circle : Icons.error,
                    color: widget.isSuccess ? const Color(0xFFD4E157) : Colors.red,
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