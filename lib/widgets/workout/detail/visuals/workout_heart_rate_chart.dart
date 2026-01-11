import 'dart:math';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:provider/provider.dart';
import 'package:health/health.dart';
import '../../../../providers/workout_detail_provider.dart';

/// 고품질 심박수 시각화 위젯 (좌우 이탈 방지 정밀 버전)
class HeartRateVisualizer extends StatelessWidget {
  final Color themeColor;

  const HeartRateVisualizer({super.key, required this.themeColor});

  @override
  Widget build(BuildContext context) {
    return Consumer<WorkoutDetailProvider>(
      builder: (context, provider, child) {
        if (provider.isLoading) {
          return const SizedBox(
            height: 150, 
            child: Center(child: CircularProgressIndicator())
          );
        }
        
        final data = provider.heartRateData;
        if (data.isEmpty) return const SizedBox.shrink();

        // 1. 데이터 전처리 및 정렬 (시간순 정렬 보장)
        final sortedData = List<HealthDataPoint>.from(data)
          ..sort((a, b) => a.dateFrom.compareTo(b.dateFrom));

        // 2. 기준 시간 (가장 빠른 데이터 기준)
        final baseTime = sortedData.first.dateFrom;
        
        final List<FlSpot> spots = [];
        for (var d in sortedData) {
          final value = d.value;
          if (value is NumericHealthValue) {
            // baseTime을 0으로 하는 상대적 초 계산 (반드시 양수 보장)
            double elapsed = d.dateFrom.difference(baseTime).inSeconds.toDouble();
            if (elapsed < 0) elapsed = 0; 
            spots.add(FlSpot(elapsed, value.numericValue.toDouble()));
          }
        }

        if (spots.length < 2) return const SizedBox.shrink();

        // 3. 축 범위 확정
        final double maxX = spots.last.x;
        final double minY = spots.map((s) => s.y).reduce(min);
        final double maxY = spots.map((s) => s.y).reduce(max);
        
        double range = maxY - minY;
        double yMin = minY - (range * 0.1);
        double yMax = maxY + (range * 0.1);
        if (range < 10) { yMin -= 10; yMax += 10; }

        return Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.1)),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 20, 24, 12), // 우측 여백을 늘려 잘림 방지
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('심박수', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      Text('${provider.avgHeartRate.toInt()} BPM 평균', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                AspectRatio(
                  aspectRatio: 2.2,
                  child: LineChart(
                    LineChartData(
                      minX: 0,
                      maxX: maxX,
                      minY: yMin.clamp(30, 220),
                      maxY: yMax.clamp(30, 220),
                      gridData: FlGridData(
                        show: true,
                        drawVerticalLine: false,
                        getDrawingHorizontalLine: (value) => FlLine(
                          color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.05),
                          strokeWidth: 1,
                        ),
                      ),
                      titlesData: _buildTitlesData(maxX, yMin, yMax),
                      borderData: FlBorderData(show: false),
                      lineTouchData: _buildTouchData(context),
                      lineBarsData: [
                        LineChartBarData(
                          spots: spots,
                          isCurved: true,
                          curveSmoothness: 0.3,
                          color: themeColor,
                          barWidth: 3,
                          isStrokeCapRound: true,
                          dotData: const FlDotData(show: false),
                          belowBarData: BarAreaData(
                            show: true,
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                themeColor.withValues(alpha: 0.2),
                                themeColor.withValues(alpha: 0.0),
                              ],
                            ),
                          ),
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
          interval: max(1, (maxX / 4)),
          getTitlesWidget: (value, meta) {
            final mins = (value / 60).floor();
            if (value % 60 != 0 && value != 0 && value != maxX) return const SizedBox.shrink();
            return SideTitleWidget(
              meta: meta,
              child: Text('${mins}m', style: const TextStyle(fontSize: 10, color: Colors.grey)),
            );
          },
        ),
      ),
      leftTitles: AxisTitles(
        sideTitles: SideTitles(
          showTitles: true,
          reservedSize: 35,
          interval: max(5, ((maxY - minY) / 3)),
          getTitlesWidget: (value, meta) {
            return Text(value.toInt().toString(), style: const TextStyle(color: Colors.grey, fontSize: 10));
          },
        ),
      ),
    );
  }

  LineTouchData _buildTouchData(BuildContext context) {
    return LineTouchData(
      enabled: true,
      touchTooltipData: LineTouchTooltipData(
        getTooltipColor: (touchedSpot) => const Color(0xFF2C2C2C),
        getTooltipItems: (List<LineBarSpot> touchedSpots) {
          return touchedSpots.map((spot) {
            return LineTooltipItem(
              '${spot.y.toInt()} BPM',
              TextStyle(color: themeColor, fontWeight: FontWeight.bold, fontSize: 14),
            );
          }).toList();
        },
      ),
    );
  }
}
