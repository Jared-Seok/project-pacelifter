import 'dart:math';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:provider/provider.dart';
import 'package:health/health.dart';
import '../../../../providers/workout_detail_provider.dart';

/// 고도화된 페이스 시각화 위젯
/// - 일시정지 구간 보정
/// - 활동 시간 가이드라인 추가
class PaceVisualizer extends StatelessWidget {
  final Color themeColor;

  const PaceVisualizer({super.key, required this.themeColor});

  @override
  Widget build(BuildContext context) {
    return Consumer<WorkoutDetailProvider>(
      builder: (context, provider, child) {
        if (provider.isLoading) return const SizedBox(height: 150, child: Center(child: CircularProgressIndicator()));
        
        final data = provider.paceData;
        if (data.isEmpty) return const SizedBox.shrink();

        final workoutStartTime = provider.dataWrapper.dateFrom;
        final totalDurationSeconds = provider.dataWrapper.dateTo.difference(workoutStartTime).inSeconds.toDouble();
        
        // 💡 중요: 실제 활동 시간 (네이티브 브릿지 데이터 활용)
        final activeLimit = provider.activeDuration?.inSeconds.toDouble() ?? totalDurationSeconds;

        final sortedData = List<HealthDataPoint>.from(data)..sort((a, b) => a.dateFrom.compareTo(b.dateFrom));
        final List<FlSpot> rawSpots = [];
        
        for (var d in sortedData) {
          final elapsed = d.dateFrom.difference(workoutStartTime).inSeconds.toDouble();
          
          // 💡 일시정지 필터링: 실제 활동 시간 이후의 데이터는 무시하거나 다르게 처리
          if (elapsed > activeLimit + 5) continue; 

          final value = d.value;
          if (value is NumericHealthValue) {
            final speedMs = value.numericValue.toDouble();
            if (speedMs > 0.5) {
              final pace = 1000 / (speedMs * 60);
              if (pace < 25) {
                rawSpots.add(FlSpot(elapsed, -pace));
              }
            }
          }
        }

        if (rawSpots.isEmpty) return const SizedBox.shrink();

        // 보간 및 스무딩 (기존 로직 유지)
        final List<FlSpot> normalizedSpots = [];
        if (rawSpots.first.x > 30) normalizedSpots.add(FlSpot(0, rawSpots.first.y));
        normalizedSpots.addAll(rawSpots);
        if (normalizedSpots.last.x < activeLimit - 30) normalizedSpots.add(FlSpot(activeLimit, normalizedSpots.last.y));

        final List<FlSpot> smoothedSpots = [];
        for (int i = 0; i < normalizedSpots.length; i++) {
          int start = max(0, i - 2);
          int end = min(normalizedSpots.length, i + 3);
          final avgY = normalizedSpots.sublist(start, end).fold(0.0, (sum, s) => sum + s.y) / (end - start);
          smoothedSpots.add(FlSpot(normalizedSpots[i].x, avgY));
        }

        final double maxX = activeLimit;
        final double minY = smoothedSpots.map((s) => s.y).reduce(min);
        final double maxY = smoothedSpots.map((s) => s.y).reduce(max);
        final double range = (maxY - minY).abs();

        return Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.1)),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 20, 24, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('페이스 변화', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 24),
                AspectRatio(
                  aspectRatio: 2.2,
                  child: LineChart(
                    LineChartData(
                      minX: 0, maxX: maxX,
                      minY: minY - (range * 0.2), maxY: maxY + (range * 0.2),
                      gridData: FlGridData(show: true, drawVerticalLine: false, getDrawingHorizontalLine: (v) => FlLine(color: Colors.white10, strokeWidth: 1)),
                      titlesData: _buildTitlesData(maxX, minY, maxY),
                      borderData: FlBorderData(show: false),
                      lineTouchData: _buildTouchData(context),
                      extraLinesData: ExtraLinesData(
                        verticalLines: [
                          VerticalLine(
                            x: activeLimit,
                            color: Colors.orange.withValues(alpha: 0.5),
                            strokeWidth: 2,
                            dashArray: [5, 5],
                            label: VerticalLineLabel(show: true, labelResolver: (_) => '활동 종료', style: const TextStyle(fontSize: 9, color: Colors.orange)),
                          ),
                        ],
                      ),
                      lineBarsData: [
                        LineChartBarData(
                          spots: smoothedSpots,
                          isCurved: true,
                          color: themeColor,
                          barWidth: 3,
                          dotData: const FlDotData(show: false),
                          belowBarData: BarAreaData(show: true, gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [themeColor.withValues(alpha: 0.2), themeColor.withValues(alpha: 0.0)])),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  FlTitlesData _buildTitlesData(double maxX, double minY, double maxY) {
    return FlTitlesData(
      show: true,
      topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
      rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
      bottomTitles: AxisTitles(
        sideTitles: SideTitles(
          showTitles: true,
          reservedSize: 22,
          interval: max(1, maxX / 4),
          getTitlesWidget: (v, meta) => Text('${(v / 60).floor()}m', style: const TextStyle(fontSize: 10, color: Colors.grey)),
        ),
      ),
      leftTitles: AxisTitles(
        sideTitles: SideTitles(
          showTitles: true,
          reservedSize: 45,
          getTitlesWidget: (v, meta) {
            final pace = v.abs();
            final label = pace.floor().toString() + "'" + ((pace % 1) * 60).round().toString().padLeft(2, '0') + '"';
            if (v == minY || v == maxY) return const SizedBox.shrink();
            return Text(label, style: const TextStyle(fontSize: 9, color: Colors.grey));
          },
        ),
      ),
    );
  }

  LineTouchData _buildTouchData(BuildContext context) {
    return LineTouchData(
      enabled: true,
      touchTooltipData: LineTouchTooltipData(
        getTooltipColor: (s) => const Color(0xFF2C2C2C),
        getTooltipItems: (List<LineBarSpot> touchedSpots) {
          return touchedSpots.map((spot) {
            final pace = spot.y.abs();
            final label = pace.floor().toString() + "'" + ((pace % 1) * 60).round().toString().padLeft(2, '0') + '" /km';
            return LineTooltipItem(label, TextStyle(color: themeColor, fontWeight: FontWeight.bold));
          }).toList();
        },
      ),
    );
  }
}