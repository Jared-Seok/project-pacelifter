import 'dart:async';
import 'package:flutter/material.dart';
import 'package:pacelifter/services/auth_service.dart';
import 'package:pacelifter/screens/main_navigation.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pacelifter/services/profile_service.dart';
import 'package:pacelifter/screens/profile_setup_screen.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// 로그인 화면
///
/// 스플래시 화면에서 로고가 위로 밀리는 애니메이션과 함께 표시됩니다.
/// 현재는 로컬 로그인만 지원하며, 추후 실제 계정 연동 기능이 추가될 예정입니다.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with TickerProviderStateMixin {
  final AuthService _authService = AuthService();
  final ProfileService _profileService = ProfileService();
  final TextEditingController _usernameController = TextEditingController();
  late AnimationController _animationController;
  late AnimationController _phraseAnimationController;
  late Animation<Offset> _logoSlideAnimation;
  late Animation<double> _formFadeAnimation;
  late Animation<double> _phraseFadeAnimation;
  bool _isLoading = false;

  // Motivational phrases
  final List<String> _motivationalPhrases = [
    'There is NO finish line',
    'Be unbreakable',
    'We pay for pain.\nNothing can hurt us.',
    'Run heavy, Lift fast.',
    'Defy Limits.',
    'Built to Last.',
    'No Easy Way.',
    'Pain is Fuel.',
    'Too strong for runners,\ntoo fast for lifters.',
    'Pain is temporary,\nbut glory lasts forever.',
  ];

  int _currentPhraseIndex = 0;
  Timer? _phraseTimer;

  @override
  void initState() {
    super.initState();

    // 로고/폼 애니메이션 초기화
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    // 로고가 중앙에서 위로 올라가는 애니메이션
    _logoSlideAnimation = Tween<Offset>(
      begin: Offset.zero, // 중앙
      end: const Offset(0, -0.5), // 위로 이동
    ).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeInOut,
      ),
    );

    // 로그인 폼이 서서히 나타나는 애니메이션
    _formFadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(0.3, 1.0, curve: Curves.easeIn),
      ),
    );

    // Phrase 애니메이션 초기화
    _phraseAnimationController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );

    _phraseFadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(
      CurvedAnimation(
        parent: _phraseAnimationController,
        curve: Curves.easeInOut,
      ),
    );

    // 화면이 표시된 후 애니메이션 시작
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) {
        _animationController.forward();
        _phraseAnimationController.forward();
      }
    });

    // 10초마다 phrase 변경
    _startPhraseTimer();
  }

  void _startPhraseTimer() {
    _phraseTimer = Timer.periodic(const Duration(seconds: 10), (timer) {
      if (mounted) {
        _changePhrase();
      }
    });
  }

  void _changePhrase() async {
    // Fade out
    await _phraseAnimationController.reverse();

    if (mounted) {
      setState(() {
        _currentPhraseIndex = (_currentPhraseIndex + 1) % _motivationalPhrases.length;
      });

      // Fade in
      await _phraseAnimationController.forward();
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    _phraseAnimationController.dispose();
    _phraseTimer?.cancel();
    _usernameController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    final username = _usernameController.text.trim();

    if (username.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('사용자 이름을 입력해주세요'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    // 로컬 로그인 처리
    await _authService.login(username);

    if (!mounted) return;

    setState(() {
      _isLoading = false;
    });

    final isProfileSetupCompleted = await _profileService.isProfileSetupCompleted();

    if (!mounted) return;

    if (isProfileSetupCompleted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (context) => const MainNavigation(),
        ),
      );
    } else {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (context) => const ProfileSetupScreen(),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: SafeArea(
        child: AnimatedBuilder(
          animation: _animationController,
          builder: (context, child) {
            return SingleChildScrollView(
              child: SizedBox(
                height: MediaQuery.of(context).size.height -
                    MediaQuery.of(context).padding.top,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32.0),
                  child: Column(
                    children: [
                      // 로고 섹션 (중앙에서 위로 올라감)
                      Expanded(
                        flex: 2,
                        child: SlideTransition(
                          position: _logoSlideAnimation,
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              SvgPicture.asset(
                                'assets/images/pllogo.svg',
                                width: 100,
                                height: 100,
                                colorFilter: ColorFilter.mode(
                                  Theme.of(context).colorScheme.secondary,
                                  BlendMode.srcIn,
                                ),
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'PaceLifter',
                                style: GoogleFonts.anton(
                                  fontSize: 40,
                                  fontWeight: FontWeight.bold,
                                  color: Theme.of(context).colorScheme.secondary,
                                  letterSpacing: 1.5,
                                ),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                'Discipline Conquers All',
                                style: GoogleFonts.oswald(
                                  fontSize: 21,
                                  fontWeight: FontWeight.bold,
                                  fontStyle: FontStyle.italic,
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurface
                                      .withOpacity(0.8),
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      // Motivational Phrase 섹션 (중앙)
                      Expanded(
                        flex: 1, // Give it a flex value to distribute space
                        child: Container(
                          alignment: Alignment.center,
                          padding: const EdgeInsets.only(
                            left: 24.0,
                            right: 24.0,
                            bottom: 30.0, // Move up
                          ),
                          child: AnimatedBuilder(
                            animation: _phraseAnimationController,
                            builder: (context, child) {
                              return FadeTransition(
                                opacity: _phraseFadeAnimation,
                                child: ShaderMask(
                                  shaderCallback: (bounds) {
                                    return LinearGradient(
                                      colors: [
                                        Theme.of(context).colorScheme.primary,
                                        Theme.of(context).colorScheme.secondary,
                                      ],
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                    ).createShader(bounds);
                                  },
                                  child: Text(
                                    _motivationalPhrases[_currentPhraseIndex],
                                    textAlign: TextAlign.center,
                                    style: GoogleFonts.bebasNeue(
                                      fontSize: 40,
                                      fontStyle: FontStyle.italic,
                                      fontWeight: FontWeight.w500,
                                      color: Colors.white, // Color needs to be white for ShaderMask to work correctly with gradient
                                      height: 1.3,
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ),

                      // 로그인 폼 섹션 (서서히 나타남)
                      Expanded(
                        flex: 3,
                        child: FadeTransition(
                          opacity: _formFadeAnimation,
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              // 환영 메시지
                              Text(
                                '환영합니다!',
                                style: TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  color: Theme.of(context).colorScheme.onSurface,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                '시작하려면 이름을 입력하세요',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurface
                                      .withOpacity(0.6),
                                ),
                              ),
                              const SizedBox(height: 32),

                              // 사용자 이름 입력 필드
                              TextField(
                                controller: _usernameController,
                                decoration: InputDecoration(
                                  labelText: '사용자 이름',
                                  hintText: '이름을 입력하세요',
                                  prefixIcon: Icon(
                                    Icons.person,
                                    color: Theme.of(context).colorScheme.primary,
                                  ),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onSurface
                                          .withOpacity(0.3),
                                    ),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide(
                                      color: Theme.of(context).colorScheme.primary,
                                      width: 2,
                                    ),
                                  ),
                                ),
                                onSubmitted: (_) => _handleLogin(),
                              ),
                              const SizedBox(height: 24),

                              // 로그인 버튼
                              SizedBox(
                                width: double.infinity,
                                height: 56,
                                child: ElevatedButton(
                                  onPressed: _isLoading ? null : _handleLogin,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor:
                                        Theme.of(context).colorScheme.secondary,
                                    foregroundColor:
                                        Theme.of(context).colorScheme.onSecondary,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    elevation: 0,
                                  ),
                                  child: _isLoading
                                      ? SizedBox(
                                          height: 24,
                                          width: 24,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            valueColor:
                                                AlwaysStoppedAnimation<Color>(
                                              Theme.of(context)
                                                  .colorScheme
                                                  .onSecondary,
                                            ),
                                          ),
                                        )
                                      : const Text(
                                          '시작하기',
                                          style: TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                ),
                              ),
                              const SizedBox(height: 16),

                              // 안내 문구
                              Text(
                                '현재는 로컬 로그인만 지원됩니다.\n추후 계정 연동 기능이 추가될 예정입니다.',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurface
                                      .withOpacity(0.5),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
