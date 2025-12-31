import 'package:flutter/material.dart';
import '../../../services/workout_tracking_service.dart';
import 'run_stats_grid.dart';

class FreeRunBody extends StatelessWidget {
  final WorkoutState currentState;

  const FreeRunBody({super.key, required this.currentState});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          'DISTANCE',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w900,
            color: Theme.of(context).colorScheme.tertiary.withValues(alpha: 0.6),
            letterSpacing: 2,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(
              currentState.distanceKm,
              style: TextStyle(
                fontSize: 100, // 초대형 폰트
                fontWeight: FontWeight.w900,
                color: Theme.of(context).colorScheme.tertiary,
                height: 1,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              'km',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.tertiary.withValues(alpha: 0.7),
              ),
            ),
          ],
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
