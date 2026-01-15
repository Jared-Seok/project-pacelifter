import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../models/tracking/metric_type.dart';
import '../../../services/workout_tracking_service.dart';
import 'dart:async';

class BasicRunBody extends StatefulWidget {
  final WorkoutState currentState;
  final double? goalDistance;

  const BasicRunBody({
    super.key,
    required this.currentState,
    this.goalDistance,
  });

  @override
  State<BasicRunBody> createState() => _BasicRunBodyState();
}

class _BasicRunBodyState extends State<BasicRunBody> {
  // 지표 순서 관리 (첫 번째가 Primary)
  List<MetricType> _metrics = [
    MetricType.distance,
    MetricType.time,
    MetricType.pace,
    MetricType.heartRate,
    MetricType.cadence,
    MetricType.calories,
  ];

  void _swapMetric(int index) {
    if (index == 0) return; // 이미 Primary임

    setState(() {
      final selected = _metrics[index];
      _metrics[index] = _metrics[0];
      _metrics[0] = selected;
      HapticFeedback.selectionClick();
    });
  }

  void _handleMainTap() {
    setState(() {
      // 순환 로직: 0번을 맨 뒤로 보내고 1번을 앞으로 가져옴
      final first = _metrics.removeAt(0);
      _metrics.add(first);
      HapticFeedback.mediumImpact();
    });
  }

  String _getMetricValue(MetricType type) {
    switch (type) {
      case MetricType.distance:
        return widget.currentState.distanceKm;
      case MetricType.time:
        return widget.currentState.durationFormatted;
      case MetricType.pace:
        return widget.currentState.currentPace;
      case MetricType.heartRate:
        return widget.currentState.heartRate?.toString() ?? '--';
      case MetricType.cadence:
        return widget.currentState.cadence?.toString() ?? '--';
      case MetricType.calories:
        return widget.currentState.caloriesFormatted;
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final double screenHeight = constraints.maxHeight;
        
        return Column(
          children: [
            // 1. Primary Metric Section
            Expanded(
              flex: 5,
              child: GestureDetector(
                onTap: _handleMainTap,
                behavior: HitTestBehavior.opaque,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        _metrics[0].label,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey,
                          letterSpacing: 2,
                        ),
                      ),
                      const SizedBox(height: 8),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 300),
                          transitionBuilder: (child, animation) => FadeTransition(
                            opacity: animation,
                            child: ScaleTransition(scale: animation, child: child),
                          ),
                          child: Text(
                            _getMetricValue(_metrics[0]),
                            key: ValueKey(_metrics[0]),
                            style: TextStyle(
                              fontSize: screenHeight * 0.18, // 화면 높이에 비례한 폰트 크기
                              fontWeight: FontWeight.w900,
                              fontStyle: FontStyle.italic,
                              color: Theme.of(context).colorScheme.tertiary,
                              height: 1,
                            ),
                          ),
                        ),
                      ),
                      Text(
                        _metrics[0].unit,
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.tertiary.withOpacity(0.7),
                        ),
                      ),
                      
                      // Progress Bar
                      if (widget.goalDistance != null && widget.goalDistance! > 0)
                        Padding(
                          padding: const EdgeInsets.only(top: 24, left: 40, right: 40),
                          child: Container(
                            height: 6,
                            decoration: BoxDecoration(
                              color: Colors.white10,
                              borderRadius: BorderRadius.circular(3),
                            ),
                            child: LayoutBuilder(
                              builder: (context, barConstraints) {
                                double progress = (widget.currentState.distanceMeters / widget.goalDistance!).clamp(0.0, 1.0);
                                return Stack(
                                  children: [
                                    Container(
                                      width: barConstraints.maxWidth * progress,
                                      decoration: BoxDecoration(
                                        color: Theme.of(context).colorScheme.tertiary,
                                        borderRadius: BorderRadius.circular(3),
                                      ),
                                    ),
                                  ],
                                );
                              },
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),

            // 2. Secondary Metrics Grid
            Expanded(
              flex: 4,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                child: GridView.builder(
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    childAspectRatio: 2.2,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                  ),
                  itemCount: 4,
                  itemBuilder: (context, index) {
                    final metricIndex = index + 1;
                    final type = _metrics[metricIndex];
                    return GestureDetector(
                      onTap: () => _swapMetric(metricIndex),
                      behavior: HitTestBehavior.opaque,
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.03),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.white.withOpacity(0.05)),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              type.label,
                              style: const TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 4),
                            FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 8),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  crossAxisAlignment: CrossAxisAlignment.baseline,
                                  textBaseline: TextBaseline.alphabetic,
                                  children: [
                                    Text(
                                      _getMetricValue(type),
                                      style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                                    ),
                                    if (type.unit.isNotEmpty) ...[
                                      const SizedBox(width: 2),
                                      Text(
                                        type.unit,
                                        style: const TextStyle(fontSize: 12, color: Colors.grey),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ],
        );
      }
    );
  }
}