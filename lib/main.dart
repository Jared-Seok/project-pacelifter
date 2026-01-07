import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'services/workout_tracking_service.dart';
import 'services/template_service.dart';
import 'services/auth_service.dart';
import 'screens/splash_screen.dart';
import 'screens/add_workout_screen.dart';
import 'screens/main_navigation.dart';
import 'screens/login_screen.dart';
import 'providers/strength_routine_provider.dart';

// Hive 모델 임포트
import 'models/templates/workout_template.dart';
import 'models/templates/template_phase.dart';
import 'models/templates/template_block.dart';
import 'models/templates/custom_phase_preset.dart';
import 'models/exercises/exercise.dart';
import 'models/sessions/workout_session.dart';
import 'models/sessions/exercise_record.dart';
import 'models/sessions/route_point.dart';
import 'models/scoring/performance_scores.dart';

void main() {
  // 1. 엔진 초기화 (최소한의 필수 작업만 수행)
  print('🚀 [App] Starting main()...');
  WidgetsFlutterBinding.ensureInitialized();
  
  // 2. 앱 즉시 실행 (하얀 화면 방지)
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => WorkoutTrackingService()),
        ChangeNotifierProvider(create: (_) => StrengthRoutineProvider()),
      ],
      child: const MyApp(),
    ),
  );
}

class AppInitializer {
  static bool _isInitialized = false;

  static Future<void> init() async {
    if (_isInitialized) return;
    
    try {
      print('📦 [AppInitializer] Starting initialization...');
      
      // 1. Hive 초기화
      print('📦 [AppInitializer] Initializing Hive...');
      await Hive.initFlutter();
      
      // 2. 어댑터 등록
      _registerHiveAdapters();

      // 3. 박스 오픈 (타임아웃 적용 및 강제 복구 로직)
      print('📦 [AppInitializer] Opening Boxes...');
      const boxTimeout = Duration(seconds: 5);

      await _forceOpenBox<WorkoutTemplate>('workout_templates', timeout: boxTimeout);
      await _forceOpenBox<CustomPhasePreset>('custom_phase_presets', timeout: boxTimeout);
      await _forceOpenBox<Exercise>('exercises', timeout: boxTimeout);
      await _forceOpenBox<PerformanceScores>('user_scores', timeout: boxTimeout);
      await _forceOpenLazyBox<WorkoutSession>('user_workout_history', timeout: boxTimeout);
      await _forceOpenLazyBox<ExerciseRecord>('user_exercise_records', timeout: boxTimeout);

      // 4. 데이터 로드 (TemplateService)
      print('📦 [AppInitializer] Loading Templates...');
      await TemplateService.loadAllTemplatesAndExercises().timeout(
        const Duration(seconds: 15),
        onTimeout: () => print('⚠️ [AppInitializer] Template loading timed out'),
      );
      
      _isInitialized = true;
      print('✅ [AppInitializer] Completed Successfully');
    } catch (e, stack) {
      print('❌ [AppInitializer] Critical Failure: $e');
      print(stack);
      _isInitialized = true; // 에러가 나더라도 앱은 띄우도록 설정
    }
  }

  static Future<void> _forceOpenBox<T>(String name, {required Duration timeout}) async {
    try {
      if (Hive.isBoxOpen(name)) return;
      print('📦 Opening Box: $name');
      await Hive.openBox<T>(name).timeout(timeout);
    } catch (e) {
      print('🚨 Box $name corrupted. Recreating...');
      try {
        await Hive.deleteBoxFromDisk(name);
        await Hive.openBox<T>(name).timeout(timeout);
      } catch (e2) {
        print('❌ Failed to open box $name: $e2');
      }
    }
  }

  static Future<void> _forceOpenLazyBox<T>(String name, {required Duration timeout}) async {
    try {
      if (Hive.isBoxOpen(name)) return;
      print('📦 Opening LazyBox: $name');
      await Hive.openLazyBox<T>(name).timeout(timeout);
    } catch (e) {
      print('🚨 LazyBox $name corrupted. Recreating...');
      try {
        await Hive.deleteBoxFromDisk(name);
        await Hive.openLazyBox<T>(name).timeout(timeout);
      } catch (_) {}
    }
  }

  static void _registerHiveAdapters() {
    try {
      if (!Hive.isAdapterRegistered(0)) Hive.registerAdapter(WorkoutTemplateAdapter());
      if (!Hive.isAdapterRegistered(1)) Hive.registerAdapter(TemplatePhaseAdapter());
      if (!Hive.isAdapterRegistered(2)) Hive.registerAdapter(TemplateBlockAdapter());
      if (!Hive.isAdapterRegistered(8)) Hive.registerAdapter(CustomPhasePresetAdapter());
      if (!Hive.isAdapterRegistered(3)) Hive.registerAdapter(ExerciseAdapter());
      if (!Hive.isAdapterRegistered(4)) Hive.registerAdapter(WorkoutSessionAdapter());
      if (!Hive.isAdapterRegistered(5)) Hive.registerAdapter(ExerciseRecordAdapter());
      if (!Hive.isAdapterRegistered(6)) Hive.registerAdapter(SetRecordAdapter());
      if (!Hive.isAdapterRegistered(7)) Hive.registerAdapter(RoutePointAdapter());
      if (!Hive.isAdapterRegistered(40)) Hive.registerAdapter(PerformanceScoresAdapter());
    } catch (e) {
      print('⚠️ Adapter registration warning: $e');
    }
  }
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  bool _initialized = false;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'PaceLifter',
      debugShowCheckedModeBanner: false,
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('ko', 'KR'), Locale('en', 'US')],
      locale: const Locale('ko', 'KR'),
      theme: ThemeData(
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFFFF9100),
          secondary: Color(0xFFD4E157),
          tertiary: Color(0xFF00BFA5),
          surface: Color(0xFF121212),
        ),
        useMaterial3: true,
        progressIndicatorTheme: const ProgressIndicatorThemeData(
          color: Color(0xFFD4E157), // Neon Green (Highlight)
        ),
      ),
      // 초기화 전에는 Splash, 후에는 Router 표시
      home: _initialized 
          ? const InitialNavigationRouter() 
          : SplashScreen(onInitComplete: () {
              if (mounted) {
                setState(() => _initialized = true);
              }
            }),
      routes: {'/add-workout': (context) => const AddWorkoutScreen()},
    );
  }
}

class InitialNavigationRouter extends StatelessWidget {
  const InitialNavigationRouter({super.key});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: AuthService().isLoggedIn(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(backgroundColor: Color(0xFF121212));
        }
        return snapshot.data == true ? const MainNavigation() : const LoginScreen();
      },
    );
  }
}