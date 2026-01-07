import 'package:flutter/material.dart';
import 'package:pacelifter/main.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_svg/flutter_svg.dart';

class SplashScreen extends StatefulWidget {
  final VoidCallback onInitComplete;

  const SplashScreen({super.key, required this.onInitComplete});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeIn),
    );

    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOutBack),
    );

    _animationController.forward();
    _performInitialization();
  }

  Future<void> _performInitialization() async {
    try {
      // 1. 데이터 초기화 (이미 main에서 수행되었으므로 즉시 반환됨)
      await AppInitializer.init();
      
      // 최소 로딩 시간 보장 (부드러운 전환을 위한 시각적 지연)
      await Future.delayed(const Duration(milliseconds: 1500));

      if (mounted) {
        widget.onInitComplete();
      }
    } catch (e) {
      debugPrint('❌ Splash Initialization Error: $e');
      if (mounted) {
        widget.onInitComplete();
      }
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment.center,
            radius: 1.2,
            colors: [
              Color(0xFF2C2C2E), // 약간 밝은 다크 그레이
              Color(0xFF000000), // 완전 블랙
            ],
          ),
        ),
        child: Stack(
          fit: StackFit.expand, // Stack이 부모 크기를 가득 채우도록 강제
          children: [
            // 중앙 로고 및 타이틀
            Center(
              child: AnimatedBuilder(
                animation: _animationController,
                builder: (context, child) {
                  return FadeTransition(
                    opacity: _fadeAnimation,
                    child: ScaleTransition(
                      scale: _scaleAnimation,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SvgPicture.asset(
                            'assets/images/pllogo.svg',
                            width: 180,
                            height: 180,
                            colorFilter: const ColorFilter.mode(Color(0xFFD4E157), BlendMode.srcIn),
                          ),
                          const SizedBox(height: 24),
                          Text(
                            'PaceLifter',
                            style: GoogleFonts.anton(
                              fontSize: 48,
                              letterSpacing: 2.0,
                              fontWeight: FontWeight.bold,
                              color: const Color(0xFFD4E157),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            // 하단 슬로건
            Positioned(
              bottom: 60,
              left: 0,
              right: 0,
              child: FadeTransition(
                opacity: _fadeAnimation,
                child: Column(
                  children: [
                    Text(
                      'DISCIPLINE CONQUERS ALL',
                      style: GoogleFonts.oswald(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        fontStyle: FontStyle.italic,
                        color: Colors.white.withOpacity(0.8),
                        letterSpacing: 1.0,
                      ),
                    ),
                    const SizedBox(height: 8),
                    RichText(
                      text: TextSpan(
                        style: GoogleFonts.oswald(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          fontStyle: FontStyle.italic,
                          letterSpacing: 1.5,
                        ),
                        children: [
                          TextSpan(
                            text: 'WELCOME, ',
                            style: TextStyle(color: Colors.white.withOpacity(0.7)),
                          ),
                          const TextSpan(
                            text: 'HYBRID ATHLETE',
                            style: TextStyle(color: Color(0xFFD4E157)),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}