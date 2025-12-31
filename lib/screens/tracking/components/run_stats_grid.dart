import 'package:flutter/material.dart';

class RunStatsGrid extends StatelessWidget {
  final String pace;
  final String avgPace;
  final double elevation;
  final String calories;
  final double distance;

  const RunStatsGrid({
    super.key,
    required this.pace,
    required this.avgPace,
    required this.elevation,
    required this.calories,
    required this.distance,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        children: [
          Row(
            children: [
              _buildGridMetric(context, 'PACE', pace, '/km'),
              _buildGridMetric(context, 'AVG PACE', avgPace, '/km'),
            ],
          ),
          const SizedBox(height: 32),
          Row(
            children: [
              _buildGridMetric(context, 'ELEVATION', elevation.toStringAsFixed(0), 'm'),
              _buildGridMetric(context, 'CALORIES', calories, 'kcal'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildGridMetric(BuildContext context, String label, String value, String unit) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              color: Colors.grey,
              fontWeight: FontWeight.bold,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                value,
                style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900),
              ),
              const SizedBox(width: 4),
              Text(
                unit,
                style: const TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
