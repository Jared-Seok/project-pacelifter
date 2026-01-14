import 'dart:math';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:provider/provider.dart';
import 'package:health/health.dart';
import '../../../../providers/workout_detail_provider.dart';

/// 페이스(Area)와 심박수(Line)를 통합하여 보여주는 전문 분석 차트
class PerformanceAnalyticChart extends StatelessWidget {
  final Color themeColor;

  const PerformanceAnalyticChart({super.key, required this.themeColor});

  @override
  Widget build(BuildContext context) {
    return Consumer<WorkoutDetailProvider>(
      builder: (context, provider, child) {
        if (provider.isLoading) return const SizedBox(height: 200, child: Center(child: CircularProgressIndicator()));
        
        final hrData = provider.heartRateData;
        final paceData = provider.paceData;
        if (hrData.isEmpty && paceData.isEmpty) return const SizedBox.shrink();

        final startTime = provider.dataWrapper.dateFrom;
        final activeLimit = provider.activeDuration?.inSeconds.toDouble() ?? 
            provider.dataWrapper.dateTo.difference(startTime).inSeconds.toDouble();

        // 1. 심박수 데이터 처리 (Line)
        final List<FlSpot> hrSpots = _processHeartRateData(hrData, startTime, activeLimit);
        
        // 2. 페이스 데이터 처리 (Area, 반전 Y축)
        final List<FlSpot> paceSpots = _processPaceData(paceData, startTime, activeLimit);

        if (hrSpots.isEmpty && paceSpots.isEmpty) return const SizedBox.shrink();

        // Y축 범위 계산
        final double minHR = hrSpots.isNotEmpty ? hrSpots.map((s) => s.y).reduce(min) : 0;
        final double maxHR = hrSpots.isNotEmpty ? hrSpots.map((s) => s.y).reduce(max) : 200;
        
        final double minPaceY = paceSpots.isNotEmpty ? paceSpots.map((s) => s.y).reduce(min) : -15;
        final double maxPaceY = paceSpots.isNotEmpty ? paceSpots.map((s) => s.y).reduce(max) : -3;

        return Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: Theme.of(context).colorScheme.outline.withOpacity(0.1)),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('퍼포먼스 분석', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Row(
                  children: [
                    _buildLegendItem('심박수', Colors.redAccent),
                    const SizedBox(width: 12),
                    _buildLegendItem('페이스', themeColor),
                  ],
                ),
                const SizedBox(height: 24),
                AspectRatio(
                  aspectRatio: 1.8,
                  child: LineChart(
                    LineChartData(
                      minX: 0, maxX: activeLimit,
                      // 심박수 기준 Y축 설정 (페이스는 내부적으로 스케일링)
                      minY: minHR - 10, maxY: maxHR + 10,
                      gridData: FlGridData(show: true, drawVerticalLine: false, horizontalInterval: 20),
                      titlesData: _buildTitlesData(activeLimit),
                      borderData: FlBorderData(show: false),
                      lineTouchData: _buildTouchData(context, hrSpots, paceSpots),
                      lineBarsData: [
                        // 1. 페이스 (배경 Area)
                        if (paceSpots.isNotEmpty)
                          LineChartBarData(
                            spots: _scalePaceToHR(paceSpots, minPaceY, maxPaceY, minHR, maxHR),
                            isCurved: true,
                            color: themeColor.withOpacity(0.5),
                            barWidth: 0,
                            dotData: const FlDotData(show: false),
                            belowBarData: BarAreaData(
                              show: true, 
                              gradient: LinearGradient(
                                begin: Alignment.topCenter, 
                                end: Alignment.bottomCenter, 
                                colors: [themeColor.withOpacity(0.3), themeColor.withOpacity(0.01)]
                              )
                            ),
                          ),
                        // 2. 심박수 (전경 Line)
                        if (hrSpots.isNotEmpty)
                          LineChartBarData(
                            spots: hrSpots,
                            isCurved: true,
                            color: Colors.redAccent,
                            barWidth: 2,
                            dotData: const FlDotData(show: false),
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

  List<FlSpot> _processHeartRateData(List<HealthDataPoint> data, DateTime start, double limit) {
    final sorted = List<HealthDataPoint>.from(data)..sort((a, b) => a.dateFrom.compareTo(b.dateFrom));
    return sorted.where((d) {
      final elapsed = d.dateFrom.difference(start).inSeconds.toDouble();
      return elapsed >= 0 && elapsed <= limit;
    }).map((d) {
      return FlSpot(
        d.dateFrom.difference(start).inSeconds.toDouble(),
        (d.value as NumericHealthValue).numericValue.toDouble()
      );
    }).toList();
  }

  List<FlSpot> _processPaceData(List<HealthDataPoint> data, DateTime start, double limit) {
    final sorted = List<HealthDataPoint>.from(data)..sort((a, b) => a.dateFrom.compareTo(b.dateFrom));
    final List<FlSpot> spots = [];
    for (var d in sorted) {
      final elapsed = d.dateFrom.difference(start).inSeconds.toDouble();
      if (elapsed < 0 || elapsed > limit) continue;
      final speedMs = (d.value as NumericHealthValue).numericValue.toDouble();
      if (speedMs > 0.5) {
        final pace = 1000 / (speedMs * 60);
        if (pace < 20) spots.add(FlSpot(elapsed, -pace)); // Y축 반전을 위해 마이너스 처리
      }
    }
    return spots;
  }

  // 페이스 데이터를 심박수 Y축 스케일에 맞춰 변환
  List<FlSpot> _scalePaceToHR(List<FlSpot> paceSpots, double minPaceY, double maxPaceY, double minHR, double maxHR) {
    if (maxPaceY == minPaceY) return paceSpots;
    return paceSpots.map((s) {
      final normalized = (s.y - minPaceY) / (maxPaceY - minPaceY);
      final scaledY = minHR + (normalized * (maxHR - minHR));
      return FlSpot(s.x, scaledY);
    }).toList();
  }

  FlTitlesData _buildTitlesData(double maxX) {
    return FlTitlesData(
      show: true,
      topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
      rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
      bottomTitles: AxisTitles(
        sideTitles: SideTitles(
          showTitles: true,
          reservedSize: 22,
          interval: max(1, maxX / 5),
          getTitlesWidget: (v, meta) => Text('${(v / 60).floor()}m', style: const TextStyle(fontSize: 10, color: Colors.grey)),
        ),
      ),
      leftTitles: AxisTitles(
        sideTitles: SideTitles(
          showTitles: true,
          reservedSize: 35,
          getTitlesWidget: (v, meta) => Text(v.toInt().toString(), style: const TextStyle(fontSize: 10, color: Colors.grey)),
        ),
      ),
    );
  }

  LineTouchData _buildTouchData(BuildContext context, List<FlSpot> hrSpots, List<FlSpot> paceSpots) {
    return LineTouchData(
      enabled: true,
      touchTooltipData: LineTouchTooltipData(
        getTooltipColor: (s) => const Color(0xFF2C2C2C),
        getTooltipItems: (List<LineBarSpot> touchedSpots) {
          return touchedSpots.map((spot) {
            // 심박수 바(index 1) 또는 페이스 바(index 0) 구분
            if (spot.barIndex == 1) {
              return LineTooltipItem('${spot.y.round()} BPM', const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold));
            } else {
              // 페이스 데이터 역산 (툴팁에는 실제 페이스 표시 필요)
              return LineTooltipItem('Pace Data', TextStyle(color: themeColor));
            }
          }).toList();
        },
      ),
    );
  }

  Widget _buildLegendItem(String label, Color color) {
    return Row(
      children: [
        Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
      ],
    );
  }
}
