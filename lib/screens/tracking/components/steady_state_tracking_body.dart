import 'package:flutter/material.dart';
import '../../../models/templates/template_block.dart';
import '../../../services/workout_tracking_service.dart';
import 'run_stats_grid.dart';

class SteadyStateTrackingBody extends StatelessWidget {
  final WorkoutState currentState;
  final TemplateBlock currentBlock;

  const SteadyStateTrackingBody({
    super.key,
    required this.currentState,
    required this.currentBlock,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Placeholder for Zone Meter
        Text(
          'TARGET ZONE: ${currentBlock.intensityZone ?? "Free"}',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Theme.of(context).colorScheme.tertiary,
          ),
        ),
        const SizedBox(height: 24),
        Container(
          height: 150,
          width: 300,
          decoration: BoxDecoration(
            color: Colors.grey.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.grey.withValues(alpha: 0.3)),
          ),
          child: const Center(child: Text('Zone Meter Placeholder')),
        ),
        const SizedBox(height: 48),

        RunStatsGrid(
          pace: currentState.currentPace,
          avgPace: currentState.averagePace,
          elevation: currentState.elevationGain,
          calories: currentState.caloriesFormatted,
          distance: currentState.distanceMeters,
        ),
      ],
    );
  }
}
