import 'package:flutter/material.dart';
import 'package:pacelifter/services/auth_service.dart';
import 'package:pacelifter/screens/login_screen.dart';
import 'package:pacelifter/screens/main_navigation.dart';
import 'package:google_fonts/google_fonts.dart';

/// 스플래시 화면
///
/// 앱 시작 시 PaceLifter 로고를 표시하고,
/// 로그인 상태를 확인한 후 적절한 화면으로 이동합니다.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  final AuthService _authService = AuthService();
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();

    // 애니메이션 초기화
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(0.0, 0.5, curve: Curves.easeIn),
      ),
    );

    _scaleAnimation = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(0.0, 0.5, curve: Curves.easeOut),
      ),
    );

    // 애니메이션 시작
    _animationController.forward();

    // 2초 후 로그인 상태 확인 및 화면 전환
    _checkAuthAndNavigate();
  }

  Future<void> _checkAuthAndNavigate() async {
    // 최소 2초간 스플래시 화면 표시
    await Future.delayed(const Duration(seconds: 2));

    if (!mounted) return;

    // 로그인 상태 확인
    final isLoggedIn = await _authService.isLoggedIn();

    if (!mounted) return;

    // 로그인 여부에 따라 화면 전환
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (context) => isLoggedIn
            ? const MainNavigation()
            : const LoginScreen(),
      ),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
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
                    // 로고 아이콘
                    Icon(
                      Icons.directions_run,
                      size: 140,
                      color: Theme.of(context).colorScheme.secondary,
                    ),
                    const SizedBox(height: 28),
                    // 앱 이름
                    Text(
                      'PaceLifter',
                      style: GoogleFonts.anton(
                        fontSize: 52,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.secondary,
                      ),
                    ),
                    const SizedBox(height: 20),
                    // Discipline Conquers All (이탤릭)
                    Text(
                      'Discipline Conquers All',
                      style: GoogleFonts.oswald(
                        fontSize: 21,
                        fontStyle: FontStyle.italic,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.onSurface.withOpacity(0.8),
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 12),
                    // Welcome Hybrid Athlete (Athlete에 포인트 색상)
                    RichText(
                      text: TextSpan(
                        style: TextStyle(
                          fontSize: 18,
                          color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                        ),
                        children: [
                          const TextSpan(text: 'Welcome Hybrid '),
                          TextSpan(
                            text: 'Athlete',
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.secondary,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
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
