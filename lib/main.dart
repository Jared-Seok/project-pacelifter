import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'services/workout_tracking_service.dart';
import 'services/template_service.dart';
import 'screens/health_import_screen.dart';
import 'screens/splash_screen.dart';
import 'screens/add_workout_screen.dart';
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

void main() async {
  // 1. Flutter 엔진 초기화
  WidgetsFlutterBinding.ensureInitialized();

  try {
    // 2. Hive 기본 초기화
    await Hive.initFlutter();

    // 3. Adapter 등록
    _registerHiveAdapters();

    // 4. 필수 박스들을 우선적으로 열기 (UI가 바로 필요로 하는 것들)
    // 이 작업이 완료되어야 하얀 화면을 방지하고 정상적인 데이터 접근이 가능함
    await Future.wait([
      Hive.openBox<WorkoutTemplate>('workout_templates'),
      Hive.openBox<CustomPhasePreset>('custom_phase_presets'),
      Hive.openBox<Exercise>('exercises'),
      Hive.openBox<WorkoutSession>('user_workout_history'),
      Hive.openBox<ExerciseRecord>('user_exercise_records'),
      Hive.openBox<PerformanceScores>('user_scores'),
    ]);

    // 5. 템플릿 및 운동 데이터 로드
    await TemplateService.loadAllTemplatesAndExercises();

    runApp(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (context) => WorkoutTrackingService()),
          ChangeNotifierProvider(create: (context) => StrengthRoutineProvider()),
        ],
        child: const MyApp(),
      ),
    );
    
  } catch (e) {
    debugPrint('❌ Critical Initialization Error: $e');
    runApp(MaterialApp(home: Scaffold(body: Center(child: Text('앱 초기화 오류: $e')))));
  }
}

void _registerHiveAdapters() {
  Hive.registerAdapter(WorkoutTemplateAdapter());
  Hive.registerAdapter(TemplatePhaseAdapter());
  Hive.registerAdapter(TemplateBlockAdapter());
  Hive.registerAdapter(CustomPhasePresetAdapter());
  Hive.registerAdapter(ExerciseAdapter());
  Hive.registerAdapter(WorkoutSessionAdapter());
  Hive.registerAdapter(ExerciseRecordAdapter());
  Hive.registerAdapter(SetRecordAdapter());
  Hive.registerAdapter(PerformanceScoresAdapter());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'PaceLifter',
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('ko', 'KR'),
        Locale('en', 'US'),
      ],
      locale: const Locale('ko', 'KR'),
      theme: ThemeData(
        colorScheme: const ColorScheme(
          brightness: Brightness.dark,
          primary: Color(0xFFFF9100),
          onPrimary: Colors.black,
          secondary: Color(0xFFD4E157),
          onSecondary: Colors.black,
          tertiary: Color(0xFF00BFA5),
          onTertiary: Colors.black,
          surface: Color(0xFF121212),
          onSurface: Color(0xFFEEEEEE),
          error: Colors.red,
          onError: Colors.white,
        ),
        textSelectionTheme: const TextSelectionThemeData(
          cursorColor: Color(0xFFD4E157),
          selectionColor: Color(0x66D4E157),
          selectionHandleColor: Color(0xFFD4E157),
        ),
        progressIndicatorTheme: const ProgressIndicatorThemeData(
          color: Color(0xFFD4E157),
        ),
        useMaterial3: true,
      ),
      home: const SplashScreen(),
      routes: {
        '/add-workout': (context) => const AddWorkoutScreen(),
      },
    );
  }
}
