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

// Import generated part files if necessary or rely on adapter logic
// Since we are in a test environment and might not run build_runner for tests properly,
// we rely on the fact that we ran it earlier.

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
    Hive.init('test/hive_test_data_presets');
    
    // Register Adapters
    if (!Hive.isAdapterRegistered(0)) Hive.registerAdapter(WorkoutTemplateAdapter());
    if (!Hive.isAdapterRegistered(1)) Hive.registerAdapter(TemplatePhaseAdapter());
    if (!Hive.isAdapterRegistered(2)) Hive.registerAdapter(TemplateBlockAdapter());
    if (!Hive.isAdapterRegistered(7)) Hive.registerAdapter(CustomPhasePresetAdapter());

    // Open Boxes
    if (!Hive.isBoxOpen('workout_templates')) await Hive.openBox<WorkoutTemplate>('workout_templates');
    if (!Hive.isBoxOpen('custom_phase_presets')) await Hive.openBox<CustomPhasePreset>('custom_phase_presets');
  });

  tearDownAll(() async {
    await Hive.deleteFromDisk();
  });

  testWidgets('Preset Menu appears and opens Save Dialog', (WidgetTester tester) async {
    // 1. Setup Data
    final template = WorkoutTemplate(
      id: 'test_template_preset',
      name: 'Test Preset UI',
      description: 'Testing presets',
      category: 'Endurance',
      phases: [
        TemplatePhase(
          id: 'phase1',
          name: 'Main Set',
          blocks: [
            TemplateBlock(id: '1', name: 'Run', type: 'endurance', targetDuration: 60, intensityZone: 'Z3', order: 1),
          ],
          order: 1,
        ),
      ],
    );

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

    // 3. Find Menu Button (more_horiz) in the phase header
    final menuButton = find.byIcon(Icons.more_horiz);
    expect(menuButton, findsOneWidget);

    // 4. Tap Menu Button
    await tester.tap(menuButton);
    await tester.pumpAndSettle();

    // 5. Verify Menu Items
    expect(find.text('현재 구성 저장'), findsOneWidget);
    expect(find.text('프리셋 불러오기'), findsOneWidget);

    // 6. Tap Save
    await tester.tap(find.text('현재 구성 저장'));
    await tester.pumpAndSettle();

    // 7. Verify Save Dialog
    expect(find.text('현재 구성을 프리셋으로 저장'), findsOneWidget);
    expect(find.byType(TextField), findsOneWidget);
    expect(find.text('저장'), findsOneWidget);
  });
}
