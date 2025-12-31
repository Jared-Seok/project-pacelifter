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
      // 1. 데이터 초기화 (Hive 박스 오픈 등)
      await AppInitializer.init();
      
      // 최소 로딩 시간 보장
      await Future.delayed(const Duration(milliseconds: 800));

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
      backgroundColor: const Color(0xFF121212),
      body: Center(
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
                        fontSize: 42,
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
    );
  }
}