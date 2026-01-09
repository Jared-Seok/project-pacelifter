import 'dart:async';
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

import 'models/sessions/session_metadata.dart';
import 'services/workout_history_service.dart';

void main() {
  // 1. 엔진 초기화만 수행
  WidgetsFlutterBinding.ensureInitialized();
  
  // 2. 즉시 앱 실행 (어떠한 초기화 대기도 없음)
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => WorkoutTrackingService()),
        ChangeNotifierProvider(create: (_) => StrengthRoutineProvider()),
      ],
      child: const MyApp(),
    ),
  );
  
  // 3. 엔진이 구동된 직후(다음 프레임) 초기화 시작
  WidgetsBinding.instance.addPostFrameCallback((_) {
    print('🚀 [App] Engine started. Triggering AppInitializer...');
    AppInitializer.init();
  });
}

class AppInitializer {
  static bool _isInitialized = false;
  static bool _isInitializing = false;
  static Completer<void>? _initCompleter;

  static Future<void> init() async {
    if (_isInitialized) return;
    
    // 이미 초기화 진행 중이면 완료될 때까지 대기
    if (_isInitializing) {
      return _initCompleter?.future;
    }
    
    _isInitializing = true;
    _initCompleter = Completer<void>();
    final stopwatch = Stopwatch()..start();
    
    try {
      print('📦 [AppInitializer] Starting initialization sequence...');
      
      // 1. Hive 기초 초기화
      print('📦 [AppInitializer] Hive.initFlutter()...');
      await Hive.initFlutter().timeout(const Duration(seconds: 3));
      _registerHiveAdapters();

      // 2. 박스 오픈 (최소 필수 데이터만 - 타입 명시)
      print('📦 [AppInitializer] Opening essential boxes...');
      const timeout = Duration(seconds: 2);

      await _forceOpenBox<WorkoutTemplate>('workout_templates', timeout: timeout);
      await _forceOpenBox<Exercise>('exercises', timeout: timeout);
      await _forceOpenBox<PerformanceScores>('user_scores', timeout: timeout);
      await _forceOpenBox<SessionMetadata>('session_metadata_index', timeout: timeout);
      
      // 🚨 'user_workout_history'와 'user_exercise_records'는 여기서 열지 않습니다. (Lazy Loading)

      // 3. 인덱스 자가 복구는 비동기로만 시도
      print('🔍 [AppInitializer] Checking index status...');
      final indexBox = Hive.box<SessionMetadata>('session_metadata_index');
      if (indexBox.isEmpty) {
        print('🔍 [AppInitializer] Index empty, scheduling background rebuild...');
        WorkoutHistoryService().rebuildIndex().catchError((e) => print('⚠️ Index Rebuild Error: $e'));
      }

      // 4. 데이터 로드 (Batch 최적화 버전)
      print('📦 [AppInitializer] TemplateService.loadAllTemplatesAndExercises()...');
      await TemplateService.loadAllTemplatesAndExercises().timeout(
        const Duration(seconds: 5),
        onTimeout: () => print('⚠️ [AppInitializer] Template loading timed out'),
      );
      
      _isInitialized = true;
      print('✅ [AppInitializer] Initialization sequence completed in ${stopwatch.elapsedMilliseconds}ms');
      _initCompleter?.complete();
    } catch (e, stack) {
      print('❌ [AppInitializer] Critical Failure during setup: $e');
      print(stack);
      _initCompleter?.completeError(e, stack);
    } finally {
      _isInitializing = false;
    }
  }

  static Future<void> _forceOpenBox<T>(String name, {required Duration timeout}) async {
    try {
      if (Hive.isBoxOpen(name)) return;
      await Hive.openBox<T>(name).timeout(timeout);
    } catch (e) {
      print('🚨 [AppInitializer] Box $name failed to open: $e');
      // 복구 가능한 에러인 경우에만 삭제 후 재시도
      if (e.toString().contains('corrupted')) {
        try {
          print('🚨 [AppInitializer] Deleting corrupted box: $name');
          await Hive.deleteBoxFromDisk(name);
          await Hive.openBox<T>(name).timeout(timeout);
        } catch (_) {}
      }
    }
  }

  static Future<void> _forceOpenLazyBox<T>(String name, {required Duration timeout}) async {
    try {
      if (Hive.isBoxOpen(name)) return;
      await Hive.openLazyBox<T>(name).timeout(timeout);
    } catch (e) {
      print('🚨 [AppInitializer] LazyBox $name failed: $e');
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
      if (!Hive.isAdapterRegistered(9)) Hive.registerAdapter(SessionMetadataAdapter());
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