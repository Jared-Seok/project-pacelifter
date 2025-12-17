import 'package:flutter/material.dart';
import 'package:health/health.dart';
import 'package:intl/intl.dart';
import 'package:pacelifter/screens/workout_detail_screen.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:pacelifter/models/time_period.dart';

class WorkoutFeedScreen extends StatelessWidget {
  final List<HealthDataPoint> workoutData;
  final TimePeriod period;
  final String dateRangeText;
  final String? raceName; // 레이스 이름 (선택적)

  const WorkoutFeedScreen({
    super.key,
    required this.workoutData,
    required this.period,
    required this.dateRangeText,
    this.raceName,
  });

  String get periodTitle {
    // 레이스 이름이 있으면 레이스 이름 사용, 없으면 기간 표시
    if (raceName != null) {
      return raceName!;
    }
    switch (period) {
      case TimePeriod.week:
        return '주간';
      case TimePeriod.month:
        return '월간';
      case TimePeriod.year:
        return '연간';
    }
  }

  bool _isStrengthWorkout(String type) {
    final upperType = type.toUpperCase();
    return upperType.contains('STRENGTH') ||
        upperType.contains('WEIGHT') ||
        upperType.contains('FUNCTIONAL') ||
        upperType.contains('CORE') ||
        upperType.contains('TRADITIONAL_STRENGTH_TRAINING');
  }

  String _getWorkoutCategory(String type) {
    final upperType = type.toUpperCase();
    if (upperType.contains('CORE') ||
        upperType.contains('FUNCTIONAL') ||
        upperType.contains('STRENGTH') ||
        upperType.contains('WEIGHT') ||
        upperType.contains('TRADITIONAL_STRENGTH_TRAINING')) {
      return 'Strength';
    } else {
      return 'Endurance';
    }
  }

  Color _getCategoryColor(String category, BuildContext context) {
    switch (category) {
      case 'Strength':
        return Theme.of(context).colorScheme.primary;
      case 'Endurance':
        return Theme.of(context).colorScheme.secondary;
      default:
        return Theme.of(context).colorScheme.secondary;
    }
  }

  Widget _getWorkoutIconWidget(String type, Color color, {double iconSize = 24}) {
    final upperType = type.toUpperCase();

    if (upperType.contains('RUNNING') ||
        upperType.contains('WALKING') ||
        upperType.contains('HIKING')) {
      return SvgPicture.asset(
        'assets/images/runner-icon.svg',
        width: iconSize,
        height: iconSize,
        colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
      );
    }

    // CORE TRAINING은 core-icon.svg 사용
    if (upperType.contains('CORE') || upperType.contains('FUNCTIONAL')) {
      return SvgPicture.asset(
        'assets/images/core-icon.svg',
        width: iconSize,
        height: iconSize,
        colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
      );
    }

    // 나머지 Strength 운동은 lifter-icon.svg 사용
    if (upperType.contains('STRENGTH') || upperType.contains('WEIGHT')) {
      return SvgPicture.asset(
        'assets/images/lifter-icon.svg',
        width: iconSize,
        height: iconSize,
        colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
      );
    }

    return Icon(Icons.fitness_center, size: iconSize, color: color);
  }

  @override
  Widget build(BuildContext context) {
    // Calculate statistics
    int strengthCount = 0;
    int enduranceCount = 0;
    double totalDistance = 0.0;

    for (final data in workoutData) {
      final workout = data.value as WorkoutHealthValue;
      final type = workout.workoutActivityType.name;
      if (_isStrengthWorkout(type)) {
        strengthCount++;
      } else {
        enduranceCount++;
      }
      totalDistance += workout.totalDistance ?? 0.0;
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('$periodTitle 운동 피드'),
        backgroundColor: Theme.of(context).colorScheme.surface,
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () {
              Navigator.of(context).pushNamed('/add-workout');
            },
            tooltip: '운동 추가',
          ),
        ],
      ),
      body: Column(
        children: [
          // Summary Card
          Container(
            margin: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                // 날짜 범위 텍스트를 크고 하얗게 상단 배치
                Text(
                  dateRangeText,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildStatItem(
                      context,
                      '총 운동',
                      '${workoutData.length}회',
                      null,
                      svgPath: 'assets/images/pllogo.svg',
                      iconSize: 36, // 28에서 36으로 증가
                      color: Theme.of(context).colorScheme.secondary,
                    ),
                    _buildStatItem(
                      context,
                      'Endurance',
                      '$enduranceCount회',
                      null,
                      svgPath: 'assets/images/runner-icon.svg',
                      color: Theme.of(context).colorScheme.secondary,
                    ),
                    _buildStatItem(
                      context,
                      'Strength',
                      '$strengthCount회',
                      null,
                      svgPath: 'assets/images/lifter-icon.svg',
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    if (totalDistance > 0)
                      _buildStatItem(
                        context,
                        '총 거리',
                        '${(totalDistance / 1000).toStringAsFixed(1)}km',
                        Icons.straighten,
                      ),
                  ],
                ),
              ],
            ),
          ),
          // Workout List
          Expanded(
            child: workoutData.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.inbox_outlined,
                          size: 64,
                          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.3),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          '운동 기록이 없습니다',
                          style: TextStyle(
                            fontSize: 16,
                            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: workoutData.length,
                    itemBuilder: (context, index) {
                      return _buildWorkoutItem(context, workoutData[index]);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(
    BuildContext context,
    String label,
    String value,
    IconData? icon, {
    String? svgPath,
    Color? color,
    double? iconSize,
  }) {
    final displayColor = color ?? Theme.of(context).colorScheme.primary;
    final size = iconSize ?? 32.0; // 기본 크기를 24에서 32로 증가
    return Column(
      children: [
        if (svgPath != null)
          SvgPicture.asset(
            svgPath,
            width: size,
            height: size,
            colorFilter: ColorFilter.mode(displayColor, BlendMode.srcIn),
          )
        else if (icon != null)
          Icon(icon, size: size, color: displayColor),
        const SizedBox(height: 8), // 4에서 8로 증가
        Text(
          label,
          style: TextStyle(
            fontSize: 13, // 12에서 13으로 증가
            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
          ),
        ),
        const SizedBox(height: 4), // 2에서 4로 증가
        Text(
          value,
          style: TextStyle(
            fontSize: 18, // 16에서 18로 증가
            fontWeight: FontWeight.bold,
            color: displayColor,
          ),
        ),
      ],
    );
  }

  Widget _buildWorkoutItem(BuildContext context, HealthDataPoint data) {
    final workout = data.value as WorkoutHealthValue;
    final distance = workout.totalDistance ?? 0.0;
    final type = workout.workoutActivityType.name;
    final workoutCategory = _getWorkoutCategory(type);
    final color = _getCategoryColor(workoutCategory, context);

    final String displayName;
    final upperType = type.toUpperCase();
    if (type == 'TRADITIONAL_STRENGTH_TRAINING') {
      displayName = 'STRENGTH TRAINING';
    } else if (type == 'CORE_TRAINING') {
      displayName = 'CORE TRAINING';
    } else if (upperType.contains('RUNNING')) {
      displayName = 'RUNNING';
    } else {
      displayName = type;
    }

    final Color backgroundColor;
    final Color iconColor;

    // CORE TRAINING: secondary color 아이콘, primary color 배경 (Strength와 동일)
    if (upperType.contains('CORE') || upperType.contains('FUNCTIONAL')) {
      backgroundColor = Theme.of(context).colorScheme.primary.withValues(alpha: 0.2);
      iconColor = Theme.of(context).colorScheme.secondary;
    } else {
      backgroundColor = color.withValues(alpha: 0.2);
      iconColor = color;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => WorkoutDetailScreen(workoutData: data),
            ),
          );
        },
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: BorderRadius.circular(8),
          ),
          child: _getWorkoutIconWidget(type, iconColor),
        ),
        title: Text(displayName, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(DateFormat('yyyy-MM-dd').format(data.dateFrom)),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            if (distance > 0)
              Text(
                '${(distance / 1000).toStringAsFixed(2)} km',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
            Text(workoutCategory, style: TextStyle(fontSize: 12, color: color)),
          ],
        ),
      ),
    );
  }
}
