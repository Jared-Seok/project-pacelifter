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
    
    // 한국어 키워드 지원 추가
    if (combinedName.contains('CORE') || combinedName.contains('ABDOMINAL') || combinedName.contains('코어')) {
      return 'assets/images/strength/core-icon.svg';
    }
    
    if (combinedName.contains('FUNCTIONAL') || combinedName.contains('HYROX') || combinedName.contains('기능성')) {
      return 'assets/images/strength/core-icon.svg'; // 기능성 운동은 코어 아이콘 활용
    }
    
    if (combinedName.contains('TRAIL') || combinedName.contains('트레일')) {
      return 'assets/images/endurance/trail-icon.svg';
    }

    // 2. 일반 카테고리 체크
    if (combinedName.contains('STRENGTH') || combinedName.contains('WEIGHT') || 
        combinedName.contains('TRADITIONAL_STRENGTH_TRAINING') || combinedName.contains('근력')) {
      return 'assets/images/strength/lifter-icon.svg';
    }
    
    if (combinedName.contains('RUN') || combinedName.contains('JOG') || combinedName.contains('러닝')) {
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

  /// 운동 타입 한국어 매핑 테이블
  static const Map<String, String> _activityTypeToKorean = {
    'RUNNING': '러닝',
    'WALKING': '걷기',
    'HIKING': '하이킹',
    'TRADITIONAL_STRENGTH_TRAINING': '근력 웨이트',
    'STRENGTH_TRAINING': '근력 웨이트',
    'CORE_TRAINING': '코어 강화',
    'FUNCTIONAL_STRENGTH_TRAINING': '기능성 훈련',
    'CROSS_TRAINING': '크로스 트레이닝',
    'YOGA': '요가',
    'STAIR_CLIMBING': '계단 오르기',
    'TRAIL_RUNNING': '트레일 러닝',
    'CYCLING': '사이클',
    'SWIMMING': '수영',
    'OTHER': '기타 운동',
    'FITNESS_GAMING': '피트니스 게임',
    'BARRE': '바레',
    'CARDIO_DANCE': '댄스 카디오',
    'SOCIAL_DANCE': '소셜 댄스',
    'MIND_AND_BODY': '마음 챙김',
    'PICKLEBALL': '피클볼',
    'COOLDOWN': '쿨다운',
    'FLEXIBILITY': '스트레칭',
  };

  /// 운동 타입 이름 포맷팅 (한국어 전면 도입)
  static String formatWorkoutType(String type, {String? templateName}) {
    // 1. 표시할 기본 이름 결정
    String baseName = (templateName != null && templateName.trim().isNotEmpty) 
        ? templateName 
        : type.toUpperCase().replaceAll('WORKOUT_ACTIVITY_TYPE_', '');

    final upper = baseName.toUpperCase();
    
    // 2. 레거시 영문 이름 및 특정 키워드 한국어 매핑 (템플릿 이름이 영문인 경우 포함)
    if (upper.contains('TREADMILL') || upper.contains('INDOOR RUN')) {
      return '실내 러닝';
    }
    if (upper.contains('TRAIL')) {
      return '트레일 러닝';
    }
    if (upper == 'RUNNING' || upper == 'OUTDOOR RUN' || upper == 'BASIC RUN') {
      return '러닝';
    }
    if (upper.contains('INTERVAL')) {
      return '인터벌';
    }
    if (upper.contains('LSD')) {
      return 'LSD (장거리)';
    }
    if (upper.contains('TEMPO')) {
      return '템포';
    }

    // 3. 한국어 매핑 테이블 확인
    if (_activityTypeToKorean.containsKey(upper)) {
      return _activityTypeToKorean[upper]!;
    }

    // 4. 매핑 테이블 부분 일치 확인
    for (var entry in _activityTypeToKorean.entries) {
      if (upper.contains(entry.key)) {
        return entry.value;
      }
    }
    
    // 5. 기본 변환 logic (영문일 경우만 포맷팅)
    if (RegExp(r'[a-zA-Z]').hasMatch(baseName)) {
      String name = upper.replaceAll('_', ' ');
      return name[0].toUpperCase() + name.substring(1).toLowerCase();
    }
    
    return baseName;
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