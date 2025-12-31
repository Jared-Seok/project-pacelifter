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
import 'models/scoring/performance_scores.dart';

void main() {
  // 1. 최소한의 엔진 초기화 (동기)
  WidgetsFlutterBinding.ensureInitialized();
  
  // 2. Hive 어댑터 미리 등록 (Hot Restart 대응 및 데이터 접근 안전성 확보)
  AppInitializer._registerHiveAdapters();

  // 3. 앱 즉시 실행 (MultiProvider로 감싸 컨텍스트 안정성 확보)
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
    // 어댑터는 main에서 먼저 등록하지만, 안전을 위해 여기서도 호출
    _registerHiveAdapters();
    
    if (_isInitialized) return;
    
    try {
      debugPrint('📦 AppInitializer: Starting Hive...');
      await Hive.initFlutter();

      debugPrint('📦 AppInitializer: Opening Boxes sequentially...');
      
      // Define a standard timeout for each box to prevent infinite hang
      const boxTimeout = Duration(seconds: 5);

      // 1. Regular Boxes
      await _safeOpenBox<WorkoutTemplate>('workout_templates', timeout: boxTimeout);
      await _safeOpenBox<CustomPhasePreset>('custom_phase_presets', timeout: boxTimeout);
      await _safeOpenBox<Exercise>('exercises', timeout: boxTimeout);
      await _safeOpenBox<PerformanceScores>('user_scores', timeout: boxTimeout);
      
      // 2. Large Boxes (Always Lazy)
      await _safeOpenLazyBox<WorkoutSession>('user_workout_history', timeout: boxTimeout);
      await _safeOpenLazyBox<ExerciseRecord>('user_exercise_records', timeout: boxTimeout);

      debugPrint('📦 AppInitializer: Loading Templates...');
      await TemplateService.loadAllTemplatesAndExercises().timeout(
        const Duration(seconds: 10),
        onTimeout: () => debugPrint('⚠️ AppInitializer: Template loading timed out'),
      );
      
      _isInitialized = true;
      debugPrint('✅ AppInitializer: Completed Successfully');
    } catch (e) {
      debugPrint('❌ AppInitializer: Critical Failure: $e');
      rethrow;
    }
  }

  static Future<void> _safeOpenBox<T>(String name, {required Duration timeout}) async {
    try {
      if (Hive.isBoxOpen(name)) return;
      await Hive.openBox<T>(name).timeout(timeout);
      debugPrint('✅ Opened Box: $name');
    } catch (e) {
      debugPrint('⚠️ Failed to open Box $name: $e');
      // If it's already open as LazyBox, try to proceed
    }
  }

  static Future<void> _safeOpenLazyBox<T>(String name, {required Duration timeout}) async {
    try {
      if (Hive.isBoxOpen(name)) return;
      await Hive.openLazyBox<T>(name).timeout(timeout);
      debugPrint('✅ Opened LazyBox: $name');
    } catch (e) {
      debugPrint('⚠️ Failed to open LazyBox $name: $e');
    }
  }

  static void _registerHiveAdapters() {
    try {
      if (!Hive.isAdapterRegistered(0)) Hive.registerAdapter(WorkoutTemplateAdapter());
      if (!Hive.isAdapterRegistered(1)) Hive.registerAdapter(TemplatePhaseAdapter());
      if (!Hive.isAdapterRegistered(2)) Hive.registerAdapter(TemplateBlockAdapter());
      if (!Hive.isAdapterRegistered(3)) Hive.registerAdapter(CustomPhasePresetAdapter());
      if (!Hive.isAdapterRegistered(10)) Hive.registerAdapter(ExerciseAdapter());
      if (!Hive.isAdapterRegistered(4)) Hive.registerAdapter(WorkoutSessionAdapter());
      if (!Hive.isAdapterRegistered(5)) Hive.registerAdapter(ExerciseRecordAdapter());
      if (!Hive.isAdapterRegistered(6)) Hive.registerAdapter(SetRecordAdapter());
      
      // PerformanceScores has typeId 40
      if (!Hive.isAdapterRegistered(40)) Hive.registerAdapter(PerformanceScoresAdapter());
    } catch (_) {}
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