import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:pacelifter/screens/workout_start_screen.dart';
import 'package:pacelifter/screens/endurance_environment_screen.dart';
import 'package:pacelifter/screens/strength_template_screen.dart';
import 'package:pacelifter/screens/hybrid_template_screen.dart';
import 'package:pacelifter/models/templates/workout_template.dart';
import 'package:pacelifter/models/templates/template_phase.dart';
import 'package:pacelifter/models/templates/template_block.dart';
import 'package:pacelifter/services/template_service.dart';

// Mock TemplateService or ensure Hive is initialized
void main() {
  setUpAll(() async {
    // Hive initialization for tests
    Hive.init('test/hive_test_data');
    if (!Hive.isAdapterRegistered(0)) Hive.registerAdapter(WorkoutTemplateAdapter());
    if (!Hive.isAdapterRegistered(1)) Hive.registerAdapter(TemplatePhaseAdapter());
    if (!Hive.isAdapterRegistered(2)) Hive.registerAdapter(TemplateBlockAdapter());
    
    // Open boxes if they are not already open
    if (!Hive.isBoxOpen('workout_templates')) {
      await Hive.openBox<WorkoutTemplate>('workout_templates');
    }
  });

  tearDownAll(() async {
    await Hive.deleteFromDisk();
  });

  testWidgets('WorkoutStartScreen has Endurance, Strength, and Hybrid options', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const MaterialApp(home: WorkoutStartScreen()));

    // Verify that the options are present
    expect(find.text('Endurance'), findsOneWidget);
    expect(find.text('Strength'), findsOneWidget);
    expect(find.text('Hybrid'), findsOneWidget);
  });

  testWidgets('Tapping Endurance navigates to EnduranceEnvironmentScreen', (WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(home: WorkoutStartScreen()));

    // Tap Endurance
    await tester.tap(find.text('Endurance'));
    await tester.pumpAndSettle();

    // Verify navigation
    expect(find.byType(EnduranceEnvironmentScreen), findsOneWidget);
    expect(find.text('로드'), findsOneWidget);
    expect(find.text('트레일'), findsOneWidget);
    expect(find.text('실내'), findsOneWidget);
  });

  testWidgets('Tapping Strength navigates to StrengthTemplateScreen', (WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(home: WorkoutStartScreen()));

    // Tap Strength
    await tester.tap(find.text('Strength'));
    await tester.pumpAndSettle();

    // Verify navigation
    expect(find.byType(StrengthTemplateScreen), findsOneWidget);
  });

  testWidgets('Tapping Hybrid navigates to HybridTemplateScreen', (WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(home: WorkoutStartScreen()));

    // Tap Hybrid
    await tester.tap(find.text('Hybrid'));
    await tester.pumpAndSettle();

    // Verify navigation
    expect(find.byType(HybridTemplateScreen), findsOneWidget);
  });
}
