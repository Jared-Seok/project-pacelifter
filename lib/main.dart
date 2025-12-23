import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:path_provider/path_provider.dart';
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
import 'models/exercises/exercise.dart';
import 'models/sessions/workout_session.dart';
import 'models/sessions/exercise_record.dart';
import 'models/scoring/performance_scores.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Hive 초기화 (웹 vs 네이티브 분기 처리)
  if (kIsWeb) {
    await Hive.initFlutter();
  } else {
    final appDocumentDir = await getApplicationDocumentsDirectory();
    await Hive.initFlutter(appDocumentDir.path);
  }

  // TypeAdapter 등록
  Hive.registerAdapter(WorkoutTemplateAdapter());
  Hive.registerAdapter(TemplatePhaseAdapter());
  Hive.registerAdapter(TemplateBlockAdapter());
  Hive.registerAdapter(ExerciseAdapter());
  Hive.registerAdapter(WorkoutSessionAdapter());
  Hive.registerAdapter(ExerciseRecordAdapter());
  Hive.registerAdapter(SetRecordAdapter());
  Hive.registerAdapter(PerformanceScoresAdapter());

  // Hive Box 열기
  await Hive.openBox<WorkoutTemplate>('workout_templates');
  await Hive.openBox<Exercise>('exercises');
  await Hive.openBox<WorkoutSession>('user_workout_history');
  await Hive.openBox<ExerciseRecord>('user_exercise_records');
  await Hive.openBox<PerformanceScores>('user_scores'); // 점수 저장

  // 템플릿 및 운동 데이터 로드
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
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'PaceLifter',
      theme: ThemeData(
        colorScheme: const ColorScheme(
          brightness: Brightness.dark,
          primary: Color(0xFF8F9779), // Khaki
          onPrimary: Color(0xFFEEEEEE), // Text on Khaki
          secondary: Color(0xFFD4E157), // Accent
          onSecondary: Color(0xFF121212), // Text on Accent
          tertiary: Color(0xFFD4E157), // Accent for tertiary
          onTertiary: Color(0xFF121212),
          surface: Color(0xFF121212), // Background
          onSurface: Color(0xFFEEEEEE), // Text on background
          error: Colors.red,
          onError: Colors.white,
        ),
        progressIndicatorTheme: const ProgressIndicatorThemeData(
          color: Color(0xFF8F9779), // 카키색으로 명시적 지정
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

class PaceLifterHome extends StatelessWidget {
  const PaceLifterHome({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        title: const Text('PaceLifter'),
        backgroundColor: Theme.of(context).colorScheme.surface,
        foregroundColor: Theme.of(context).colorScheme.onSurface,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 24),
            Icon(Icons.directions_run, size: 80, color: Theme.of(context).colorScheme.secondary),
            const SizedBox(height: 16),
            const Text(
              'PaceLifter',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              '러닝 & 하이록스 트레이닝 앱',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
            const SizedBox(height: 48),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '주요 기능',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    _buildFeatureItem(
                      context,
                      Icons.upload_file,
                      'Apple Health 데이터 분석',
                      '기존 운동 데이터를 불러와서 분석',
                    ),
                    _buildFeatureItem(
                      context,
                      Icons.gps_fixed,
                      'GPS 러닝 트래킹',
                      '실시간 위치 추적 및 페이스 분석',
                    ),
                    _buildFeatureItem(context, Icons.event, '대회 준비', '목표 레이스에 맞춘 훈련 계획'),
                    _buildFeatureItem(
                      context,
                      Icons.insights,
                      '퍼포먼스 분석',
                      '데이터 기반 운동 인사이트',
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const HealthImportScreen(),
                  ),
                );
              },
              icon: const Icon(Icons.upload_file),
              label: const Text('Apple Health 데이터 불러오기'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.all(16),
                textStyle: const TextStyle(fontSize: 16),
                backgroundColor: Theme.of(context).colorScheme.primary,
                foregroundColor: Theme.of(context).colorScheme.onPrimary,
              ),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('GPS 러닝 기능은 개발 중입니다')),
                );
              },
              icon: const Icon(Icons.gps_fixed),
              label: const Text('GPS 러닝 시작'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.all(16),
                textStyle: const TextStyle(fontSize: 16),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFeatureItem(BuildContext context, IconData icon, String title, String description) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: Theme.of(context).colorScheme.primary, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: const TextStyle(fontSize: 14, color: Colors.grey),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}