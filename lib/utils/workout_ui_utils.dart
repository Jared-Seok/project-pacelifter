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
  static String getWorkoutIconPath(String activityType, {String? templateName}) {
    // 1. 템플릿 이름이나 활동명에서 더 구체적인 키워드(Deep Layer)를 먼저 체크
    final combinedName = (activityType + (templateName ?? '')).toUpperCase();
    
    if (combinedName.contains('CORE') || combinedName.contains('ABDOMINAL')) {
      return 'assets/images/strength/core-icon.svg';
    }
    
    if (combinedName.contains('FUNCTIONAL') || combinedName.contains('HYROX')) {
      return 'assets/images/strength/core-icon.svg'; // 기능성 운동은 코어 아이콘 활용
    }
    
    if (combinedName.contains('TRAIL')) {
      return 'assets/images/endurance/trail-icon.svg';
    }

    // 2. 일반 카테고리 체크
    if (combinedName.contains('STRENGTH') || combinedName.contains('WEIGHT') || combinedName.contains('TRADITIONAL_STRENGTH_TRAINING')) {
      return 'assets/images/strength/lifter-icon.svg';
    }
    
    if (combinedName.contains('RUN') || combinedName.contains('JOG')) {
      return 'assets/images/endurance/runner-icon.svg';
    }
    
    return 'assets/images/endurance/runner-icon.svg'; // 기본값
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
    String iconPath = getWorkoutIconPath(type, templateName: session?.templateName);
    final upperType = type.toUpperCase();
    final combinedName = (upperType + (session?.templateName ?? '')).toUpperCase();
    
    // Core/Functional은 Strength 계열 색상으로 고정 (사용자 요청)
    Color iconColor = color;
    if (combinedName.contains('CORE') || combinedName.contains('FUNCTIONAL')) {
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
  static String formatWorkoutType(String type, {String? templateName}) {
    // 1. 템플릿 이름이 있으면 그것을 최우선으로 사용
    if (templateName != null && templateName.trim().isNotEmpty) {
      return templateName;
    }

    final upper = type.toUpperCase();
    
    // 2. 특정 타입에 대한 명칭 매핑
    if (upper.contains('CORE_TRAINING')) {
      return 'Core Training';
    }
    
    if (upper.contains('TRADITIONAL_STRENGTH_TRAINING') || upper.contains('STRENGTH_TRAINING')) {
      return 'Strength Training';
    }
    
    if (upper.contains('RUNNING') || upper.contains('RUN')) {
      return 'Running';
    }
    
    if (upper.contains('TRAIL_RUNNING')) {
      return 'Trail Running';
    }
    
    // 3. 기본 변환 logic
    String name = upper.replaceAll('WORKOUT_ACTIVITY_TYPE_', '').replaceAll('_', ' ');
    // 첫글자 대문자화 등 기본 포맷팅
    return name[0].toUpperCase() + name.substring(1).toLowerCase();
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