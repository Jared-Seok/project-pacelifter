import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:pacelifter/screens/workout_setup_screen.dart';
import 'package:pacelifter/models/templates/workout_template.dart';
import 'package:pacelifter/models/templates/template_phase.dart';
import 'package:pacelifter/models/templates/template_block.dart';
import 'package:pacelifter/services/workout_tracking_service.dart';
import 'package:pacelifter/widgets/interval_set_edit_dialog.dart';

// Simple Mock for WorkoutTrackingService
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
  testWidgets('Endurance Interval Set Edit Dialog closes before Confirmation Dialog opens', (WidgetTester tester) async {
    // 1. Setup Data
    final template = WorkoutTemplate(
      id: 'test_template',
      name: 'Test Endurance',
      description: 'Testing sets',
      category: 'Endurance',
      environmentType: 'Indoor', // Avoid Map/Geolocator
      phases: [
        TemplatePhase(
          id: 'phase1',
          name: 'Main Set',
          blocks: [
            // Create a group (Work + Rest) repeated
            TemplateBlock(id: '1', name: 'Run', type: 'endurance', targetDuration: 60, intensityZone: 'Z3', order: 1),
            TemplateBlock(id: '2', name: 'Rest', type: 'rest', targetDuration: 30, order: 2),
            TemplateBlock(id: '3', name: 'Run', type: 'endurance', targetDuration: 60, intensityZone: 'Z3', order: 3),
            TemplateBlock(id: '4', name: 'Rest', type: 'rest', targetDuration: 30, order: 4),
          ],
          order: 1,
        ),
      ],
      // description already set above
    );

    // 2. Build Widget
    // Set a larger surface size to avoid overflow in test
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

    // 3. Find and Tap Edit Group Button
    await tester.pumpAndSettle();
    
    // Check for grouping text (2 sets) - might appear in Phase subtitle and Group title
    expect(find.textContaining('2 세트'), findsAtLeastNWidgets(1));
    
    final groupEditButton = find.byTooltip('전체 세트 수정');
    expect(groupEditButton, findsOneWidget);

    await tester.tap(groupEditButton);
    await tester.pumpAndSettle();

    // 4. Verify Dialog is open
    expect(find.byType(IntervalSetEditDialog), findsOneWidget);

    // 5. Tap "적용" (Apply)
    final applyButton = find.text('적용');
    await tester.tap(applyButton);
    
    // 6. Verify flow
    await tester.pumpAndSettle(); // Ensure animations (pop and showDialog) complete

    // IntervalSetEditDialog should be GONE
    expect(find.byType(IntervalSetEditDialog), findsNothing);

    // Confirmation AlertDialog should be PRESENT
    expect(find.text('템플릿 저장'), findsOneWidget);
    expect(find.textContaining('나만의 템플릿으로 저장'), findsOneWidget);
  });
}
