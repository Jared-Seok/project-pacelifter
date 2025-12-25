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

class MockWorkoutTrackingService extends ChangeNotifier implements WorkoutTrackingService {
  @override
  void setGoals({double? distance, Duration? time, Pace? pace}) {}
  
  @override
  double? get goalDistance => null;
  @override
  Duration? get goalTime => null;
  @override
  Pace? get goalPace => null;
  
  @override
  Future<void> startWorkout() async {}
  
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  setUpAll(() async {
    Hive.init('test/hive_test_data_custom_load');
    
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

  testWidgets('AppBar Menu has Save and Load options', (WidgetTester tester) async {
    // 1. Setup Data
    final template = WorkoutTemplate(
      id: 'standard_interval',
      name: 'Interval',
      category: 'Endurance',
      subCategory: 'Interval',
      description: 'Standard Interval',
      phases: [],
      isCustom: false,
    );

    // Add a custom template to Hive to allow loading
    final customTemplate = WorkoutTemplate(
      id: 'custom_interval',
      name: 'My Interval',
      category: 'Endurance',
      subCategory: 'Interval',
      description: 'My Custom Interval',
      phases: [],
      isCustom: true,
      createdAt: DateTime.now(),
    );
    Hive.box<WorkoutTemplate>('workout_templates').put(customTemplate.id, customTemplate);

    // 2. Build Widget
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<WorkoutTrackingService>(
            create: (_) => MockWorkoutTrackingService(),
          ),
        ],
        child: MaterialApp(
          home: WorkoutSetupScreen(template: template),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // 3. Find AppBar Menu Button (more_vert)
    final menuButton = find.byIcon(Icons.more_vert);
    expect(menuButton, findsOneWidget);

    // 4. Tap Menu
    await tester.tap(menuButton);
    await tester.pumpAndSettle();

    // 5. Verify Options
    expect(find.text('전체 템플릿 저장'), findsOneWidget);
    expect(find.text('나만의 템플릿 불러오기'), findsOneWidget);

    // 6. Tap Load
    await tester.tap(find.text('나만의 템플릿 불러오기'));
    await tester.pumpAndSettle();

    // 7. Verify Bottom Sheet content
    expect(find.text('나만의 템플릿 불러오기'), findsOneWidget); // Sheet Title
    expect(find.text('My Interval'), findsOneWidget); // Custom Template Name
  });
}
