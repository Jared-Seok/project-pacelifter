import 'package:flutter/material.dart';
import '../../../../providers/workout_detail_provider.dart';

/// 유산소 운동 전용 고도화된 대시보드 (Hero Distance + 6-Metric Grid)
class EnduranceDashboard extends StatelessWidget {
  final WorkoutDetailProvider provider;
  final Color themeColor;

  const EnduranceDashboard({
    super.key,
    required this.provider,
    required this.themeColor,
  });

  @override
  Widget build(BuildContext context) {
    final session = provider.session;
    final totalDistanceKm = (session?.totalDistance ?? 0) / 1000;
    final activeDuration = provider.activeDuration ?? 
        Duration(seconds: session?.activeDuration ?? 0);
    
    // 페이스 계산 로직
    double calculatedPaceMinKm = provider.avgPace;
    if (calculatedPaceMinKm <= 0 && totalDistanceKm > 0 && activeDuration.inSeconds > 0) {
      calculatedPaceMinKm = (activeDuration.inSeconds / 60) / totalDistanceKm;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 1. Hero Section: 총 거리 (독립적 강조)
        _buildHeroDistance(context, totalDistanceKm),
        
        const SizedBox(height: 24),
        
        // 2. 6-Metric Grid Section (3개씩 2줄)
        Container(
          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 8),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.2),
            borderRadius: BorderRadius.circular(24),
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildGridStat(context, '페이스', _formatPace(calculatedPaceMinKm), '/km', Icons.speed),
                  _buildGridStat(context, '시간', _formatDuration(activeDuration), '', Icons.timer_outlined),
                  _buildGridStat(context, '칼로리', '${(session?.calories ?? provider.dataWrapper.calories).round()}', 'kcal', Icons.local_fire_department),
                ],
              ),
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 20, horizontal: 24),
                child: Divider(height: 1, thickness: 0.5),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildGridStat(context, '심박수', '${provider.avgHeartRate.round()}', 'BPM', Icons.favorite),
                  _buildGridStat(context, '케이던스', '${provider.avgCadence}', 'SPM', Icons.directions_run),
                  _buildGridStat(context, '상승 고도', '${provider.elevationGain.round()}', 'm', Icons.terrain),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildHeroDistance(BuildContext context, double distanceKm) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            'TOTAL DISTANCE',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w900,
              color: themeColor.withOpacity(0.8),
              letterSpacing: 2.0,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                distanceKm.toStringAsFixed(2),
                style: const TextStyle(
                  fontSize: 72,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -2,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'km',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.onSurface.withOpacity(0.3),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildGridStat(BuildContext context, String label, String value, String unit, IconData icon) {
    return Expanded(
      child: Column(
        children: [
          Icon(icon, size: 16, color: themeColor.withOpacity(0.7)),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            '$label $unit'.trim(),
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.4),
            ),
          ),
        ],
      ),
    );
  }

  String _formatPace(double paceMinKm) {
    if (paceMinKm <= 0 || paceMinKm.isInfinite || paceMinKm.isNaN) return "--'--\"";
    int totalSeconds = (paceMinKm * 60).round();
    int minutes = totalSeconds ~/ 60;
    int seconds = totalSeconds % 60;
    if (minutes >= 60) return "--'--\"";
    return "${minutes.toString().padLeft(2, '0')}'${seconds.toString().padLeft(2, '0')}\"";
  }

  String _formatDuration(Duration d) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    if (d.inHours > 0) return "${d.inHours}:${twoDigits(d.inMinutes.remainder(60))}:${twoDigits(d.inSeconds.remainder(60))}";
    return "${twoDigits(d.inMinutes.remainder(60))}:${twoDigits(d.inSeconds.remainder(60))}";
  }
}
