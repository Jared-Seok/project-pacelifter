import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:hive/hive.dart';
import 'package:pacelifter/screens/workout_setup_screen.dart';
import 'package:pacelifter/models/templates/workout_template.dart';
import 'package:pacelifter/models/templates/template_phase.dart';
import 'package:pacelifter/models/templates/template_block.dart';
import 'package:pacelifter/models/templates/custom_phase_preset.dart';
import 'package:pacelifter/services/workout_tracking_service.dart';

// Improved Mock that stores state
class MockWorkoutTrackingService extends ChangeNotifier implements WorkoutTrackingService {
  double? _goalDistance;
  Duration? _goalTime;
  Pace? _goalPace;

  @override
  double? get goalDistance => _goalDistance;
  @override
  Duration? get goalTime => _goalTime;
  @override
  Pace? get goalPace => _goalPace;

  @override
  void setGoals({double? distance, Duration? time, Pace? pace}) {
    if (distance != null) _goalDistance = distance;
    if (time != null) _goalTime = time;
    if (pace != null) _goalPace = pace;
    notifyListeners();
  }
  
  @override
  Future<void> startWorkout() async {}
  
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  setUpAll(() async {
    Hive.init('test/hive_test_data_basic_run');
    if (!Hive.isAdapterRegistered(0)) Hive.registerAdapter(WorkoutTemplateAdapter());
    if (!Hive.isAdapterRegistered(1)) Hive.registerAdapter(TemplatePhaseAdapter());
    if (!Hive.isAdapterRegistered(2)) Hive.registerAdapter(TemplateBlockAdapter());
    if (!Hive.isAdapterRegistered(7)) Hive.registerAdapter(CustomPhasePresetAdapter());

    if (!Hive.isBoxOpen('workout_templates')) await Hive.openBox<WorkoutTemplate>('workout_templates');
    if (!Hive.isBoxOpen('custom_phase_presets')) await Hive.openBox<CustomPhasePreset>('custom_phase_presets');
  });

  tearDownAll(() async {
    await Hive.deleteFromDisk();
  });

  testWidgets('Basic Run UI calculates Time from Distance and Pace', (WidgetTester tester) async {
    // 1. Setup Basic Run Template
    final template = WorkoutTemplate(
      id: 'basic_run_test',
      name: 'Basic Run',
      category: 'Endurance',
      subCategory: 'Basic Run',
      description: 'Test Basic Run',
      phases: [],
      isCustom: false,
    );

    final mockService = MockWorkoutTrackingService();

    // 2. Build Widget
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<WorkoutTrackingService>(
            create: (_) => mockService,
          ),
        ],
        child: MaterialApp(
          home: WorkoutSetupScreen(template: template),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // 3. Verify Initial State
    expect(find.text('선택'), findsNWidgets(3)); // Distance, Pace, Time

    // 4. Set Distance (10km) via Service (Simulating Picker)
    mockService.setGoals(distance: 10000);
    await tester.pumpAndSettle();
    expect(find.text('10.00 km'), findsOneWidget);

    // 5. Set Pace (5:00) via Service
    mockService.setGoals(pace: Pace(minutes: 5, seconds: 0));
    await tester.pumpAndSettle();
    expect(find.text('5:00'), findsOneWidget);

    // 6. Verify Time is Calculated (50 mins = 00:50:00)
    // The UI formats time as HH:MM:SS
    expect(find.text('00:50:00'), findsOneWidget);
    
    // Verify Auto-Awesome Icon appears for Calculated Value (Time)
    // We check for icon specific to Time card. 
    // It's hard to target specific card's icon without keys, but we can check if 1 auto_awesome exists.
    expect(find.byIcon(Icons.auto_awesome), findsOneWidget);
  });
}
