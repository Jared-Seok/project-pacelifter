import 'package:flutter/material.dart';
import 'package:health/health.dart';
import 'package:intl/intl.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:pacelifter/services/health_service.dart';
import 'package:pacelifter/services/healthkit_bridge_service.dart';
import 'package:pacelifter/screens/workout_share_screen.dart';
import 'package:pacelifter/services/workout_history_service.dart';
import 'package:pacelifter/models/sessions/workout_session.dart';
import 'package:pacelifter/services/template_service.dart';
import 'package:pacelifter/models/templates/workout_template.dart';
import 'package:pacelifter/models/workout_data_wrapper.dart';
import 'dart:math';

/// 운동 세부 정보 화면
class WorkoutDetailScreen extends StatefulWidget {
  final WorkoutDataWrapper dataWrapper;

  const WorkoutDetailScreen({super.key, required this.dataWrapper});

  @override
  State<WorkoutDetailScreen> createState() => _WorkoutDetailScreenState();
}

class _WorkoutDetailScreenState extends State<WorkoutDetailScreen> {
  final HealthService _healthService = HealthService();
  final HealthKitBridgeService _healthKitBridge = HealthKitBridgeService();

  List<HealthDataPoint> _heartRateData = [];
  double _avgHeartRate = 0;
  bool _isLoading = true;
  String? _heartRateError;

  List<HealthDataPoint> _paceData = [];
  double _avgPace = 0;
  bool _isPaceLoading = true;
  String? _paceError;
  Duration? _movingTime;

  // Native HealthKit duration data
  Duration? _nativeActiveDuration;
  Duration? _nativePausedDuration;
  bool _hasNativeDuration = false;

  // 차트 인터랙션 동기화를 위한 공유 상태
  double? _touchedTimestamp; // 현재 터치된 지점의 x축 값 (초 단위)

  WorkoutSession? _session;
  HealthDataPoint? _workoutData;

  @override
  void initState() {
    super.initState();
    _workoutData = widget.dataWrapper.healthData;
    _session = widget.dataWrapper.session;
    _initializeData();
  }

  Future<void> _initializeData() async {
    if (_session == null && _workoutData != null) {
      _fetchLinkedSession();
    }

    if (_workoutData != null) {
      await _fetchNativeDuration();
      _fetchHeartRateData();
      _fetchPaceData();
    } else {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _isPaceLoading = false;
        });
      }
    }
  }

  void _fetchLinkedSession() {
    if (_workoutData == null) return;
    final session = WorkoutHistoryService().getSessionByHealthKitId(_workoutData!.uuid);
    if (mounted) {
      setState(() {
        _session = session;
      });
    }
  }

  Future<void> _fetchHeartRateData() async {
    if (_workoutData == null) return;
    final types = [HealthDataType.HEART_RATE];

    final granted = await _healthService.requestAuthorization();
    if (granted) {
      try {
        final heartRateData = await _healthService.getHealthDataFromTypes(
          _workoutData!.dateFrom,
          _workoutData!.dateTo,
          types,
        );

        if (heartRateData.isNotEmpty) {
          double sum = 0;
          for (var data in heartRateData) {
            sum += (data.value as NumericHealthValue).numericValue;
          }
          if (mounted) {
            setState(() {
              _heartRateData = heartRateData;
              _avgHeartRate = sum / _heartRateData.length;
            });
          }
        }
      } catch (e) {
        if (mounted) {
          setState(() {
            _heartRateError = '심박수 데이터를 가져오는 데 실패했습니다.';
          });
        }
      }
    } else {
      if (mounted) {
        setState(() {
          _heartRateError = '심박수 접근 권한이 거부되었습니다.';
        });
      }
    }
    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _fetchPaceData() async {
    if (_workoutData == null) return;
    final workout = _workoutData!.value as WorkoutHealthValue;
    final totalDistance = (workout.totalDistance ?? 0).toDouble();

    if (totalDistance <= 0) {
      if (mounted) {
        setState(() {
          _paceError = '거리 데이터가 없습니다.';
          _isPaceLoading = false;
        });
      }
      return;
    }

    final workoutDuration = _nativeActiveDuration ??
        _workoutData!.dateTo.difference(_workoutData!.dateFrom);

    double avgPaceMinPerKm = 0;
    if (workoutDuration.inSeconds > 0 && totalDistance > 0) {
      avgPaceMinPerKm = (workoutDuration.inSeconds / 60) / (totalDistance / 1000);
    }

    try {
      final granted = await _healthService.requestAuthorization();
      if (granted) {
        final distanceData = await _healthService.getHealthDataFromTypes(
          _workoutData!.dateFrom,
          _workoutData!.dateTo,
          [HealthDataType.DISTANCE_WALKING_RUNNING],
        );

        distanceData.sort((a, b) => a.dateFrom.compareTo(b.dateFrom));
        final paceDataPoints = _calculatePaceFromDistance(distanceData, totalDistance);

        if (mounted) {
          setState(() {
            _paceData = paceDataPoints;
            _avgPace = avgPaceMinPerKm;
            _movingTime = workoutDuration;
            _isPaceLoading = false;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _paceData = [];
            _avgPace = avgPaceMinPerKm;
            _movingTime = workoutDuration;
            _isPaceLoading = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _paceData = [];
          _avgPace = avgPaceMinPerKm;
          _movingTime = workoutDuration;
          _isPaceLoading = false;
        });
      }
    }
  }

  Future<void> _fetchNativeDuration() async {
    if (_workoutData == null) return;
    try {
      final workoutUuid = _workoutData!.uuid;
      final details = await _healthKitBridge.getWorkoutDetails(workoutUuid);

      if (details != null) {
        final parsed = _healthKitBridge.parseWorkoutDetails(details);
        if (parsed != null && mounted) {
          setState(() {
            _nativeActiveDuration = parsed.activeDuration;
            _nativePausedDuration = parsed.pausedDuration;
            _hasNativeDuration = true;
          });
        }
      }
    } catch (e) { /* ignore */ }
  }

  List<HealthDataPoint> _calculatePaceFromDistance(List<HealthDataPoint> distanceData, double workoutTotalDistance) {
    if (distanceData.length < 2 || workoutTotalDistance <= 0) return [];

    distanceData.sort((a, b) => a.dateTo.compareTo(b.dateTo));

    final startTime = widget.dataWrapper.dateFrom;
    final endTime = widget.dataWrapper.dateTo;
    final totalDurationSec = endTime.difference(startTime).inSeconds;
    
    if (totalDurationSec <= 0) return [];

    double rawSampleSum = 0;
    final timeline = <_TimeDistance>[];
    timeline.add(_TimeDistance(0, 0));

    for (var data in distanceData) {
      final offset = data.dateTo.difference(startTime).inSeconds;
      if (offset <= 0) continue;
      rawSampleSum += (data.value as NumericHealthValue).numericValue.toDouble();
      timeline.add(_TimeDistance(offset, rawSampleSum));
    }

    if (rawSampleSum <= 0) return [];
    final scalingFactor = workoutTotalDistance / rawSampleSum;

    final pacePoints = <HealthDataPoint>[];
    const int step = 10; 
    double lastDistance = 0;
    
    for (int t = step; t <= totalDurationSec; t += step) {
      double currentCumulativeDist = _interpolateDistance(timeline, t) * scalingFactor;
      double distanceInInterval = currentCumulativeDist - lastDistance;
      
      if (distanceInInterval > 0) {
        double speedMs = distanceInInterval / step;
        double paceMinPerKm = 1000 / (speedMs * 60);

        if (paceMinPerKm >= 2.0 && paceMinPerKm <= 20.0) {
          pacePoints.add(
            HealthDataPoint(
              uuid: 'rs_$t',
              value: NumericHealthValue(numericValue: speedMs),
              type: HealthDataType.RUNNING_SPEED,
              unit: HealthDataUnit.METER_PER_SECOND,
              dateFrom: startTime.add(Duration(seconds: t - step)),
              dateTo: startTime.add(Duration(seconds: t)),
              sourcePlatform: distanceData.first.sourcePlatform,
              sourceDeviceId: 'PaceLifter_Resampler',
              sourceId: 'PaceLifter_Resampler',
              sourceName: 'PaceLifter_Resampler',
            ),
          );
        }
      }
      lastDistance = currentCumulativeDist;
    }
    return pacePoints;
  }

  double _interpolateDistance(List<_TimeDistance> timeline, int t) {
    if (t <= 0) return 0;
    if (t >= timeline.last.time) return timeline.last.distance;

    for (int i = 0; i < timeline.length - 1; i++) {
      if (t >= timeline[i].time && t <= timeline[i + 1].time) {
        final t0 = timeline[i].time;
        final t1 = timeline[i + 1].time;
        final d0 = timeline[i].distance;
        final d1 = timeline[i + 1].distance;
        return d0 + (t - t0) * (d1 - d0) / (t1 - t0);
      }
    }
    return timeline.last.distance;
  }

  void _showTemplateSelectionDialog(BuildContext context) {
    final String workoutType;
    final double? totalDistance;
    final double? totalEnergyBurned;

    if (_workoutData != null) {
      final workout = _workoutData!.value as WorkoutHealthValue;
      workoutType = workout.workoutActivityType.name;
      totalDistance = (workout.totalDistance ?? 0).toDouble();
      totalEnergyBurned = (workout.totalEnergyBurned ?? 0).toDouble();
    } else {
      workoutType = _session?.category == 'Strength' ? 'TRADITIONAL_STRENGTH_TRAINING' : 'RUNNING';
      totalDistance = _session?.totalDistance;
      totalEnergyBurned = _session?.calories;
    }

    final category = _getWorkoutCategory(workoutType);
    final templates = TemplateService.getTemplatesByCategory(category);
    if (templates.isEmpty) {
      templates.addAll(TemplateService.getAllTemplates());
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.7,
          minChildSize: 0.5,
          maxChildSize: 0.9,
          expand: false,
          builder: (context, scrollController) {
            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Text('템플릿 설정', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.onSurface)),
                ),
                Expanded(
                  child: ListView.builder(
                    controller: scrollController,
                    itemCount: templates.length,
                    itemBuilder: (context, index) {
                      final template = templates[index];
                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor: Theme.of(context).colorScheme.secondary.withValues(alpha: 0.1),
                          child: Icon(Icons.bookmark_border, color: Theme.of(context).colorScheme.secondary),
                        ),
                        title: Text(template.name),
                        subtitle: Text(template.description, maxLines: 1, overflow: TextOverflow.ellipsis),
                        onTap: () async {
                          await WorkoutHistoryService().linkTemplateToWorkout(
                            healthKitId: widget.dataWrapper.uuid,
                            template: template,
                            startTime: widget.dataWrapper.dateFrom,
                            endTime: widget.dataWrapper.dateTo,
                            totalDistance: totalDistance ?? 0,
                            calories: totalEnergyBurned ?? 0,
                          );
                          if (mounted) {
                            Navigator.pop(context);
                            _fetchLinkedSession();
                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${template.name} 템플릿으로 설정되었습니다.')));
                          }
                        },
                      );
                    },
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_workoutData == null && _session == null) {
      return const Scaffold(body: Center(child: Text('운동 데이터를 찾을 수 없습니다.')));
    }

    final String workoutType;
    final double? totalDistance;
    final double? totalEnergyBurned;

    if (_workoutData != null) {
      final workout = _workoutData!.value as WorkoutHealthValue;
      workoutType = workout.workoutActivityType.name;
      totalDistance = (workout.totalDistance ?? 0).toDouble();
      totalEnergyBurned = (workout.totalEnergyBurned ?? 0).toDouble();
    } else {
      workoutType = _session!.category == 'Strength' ? 'TRADITIONAL_STRENGTH_TRAINING' : 'RUNNING';
      totalDistance = _session!.totalDistance;
      totalEnergyBurned = _session!.calories;
    }

    final workoutCategory = _getWorkoutCategory(workoutType);
    final color = _getWorkoutColor(context, workoutCategory);
    final iconPath = _getWorkoutIconPath(workoutType);
    final isRunning = workoutType.toUpperCase().contains('RUNNING');

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        title: const Text('운동 세부 정보'),
        backgroundColor: Theme.of(context).colorScheme.surface,
        foregroundColor: Theme.of(context).colorScheme.onSurface,
        actions: [
          IconButton(icon: const Icon(Icons.share), onPressed: _handleShareWorkout),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      SvgPicture.asset(iconPath, width: 80, height: 80, colorFilter: ColorFilter.mode(color, BlendMode.srcIn)),
                      const SizedBox(height: 16),
                      Text(_formatWorkoutType(workoutType), style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: color), textAlign: TextAlign.center),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(color: color.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(12)),
                        child: Text(workoutCategory, style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: color)),
                      ),
                      const SizedBox(height: 16),
                      InkWell(
                        onTap: () => _showTemplateSelectionDialog(context),
                        borderRadius: BorderRadius.circular(20),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          decoration: BoxDecoration(border: Border.all(color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.5)), borderRadius: BorderRadius.circular(20)),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.bookmark_border, size: 18, color: _session != null ? color : Colors.grey),
                              const SizedBox(width: 8),
                              Text(_session != null ? _session!.templateName : '템플릿 설정하기', style: TextStyle(fontSize: 14, fontWeight: _session != null ? FontWeight.bold : FontWeight.normal, color: _session != null ? color : Colors.grey)),
                              const SizedBox(width: 4),
                              Icon(Icons.arrow_drop_down, size: 20, color: _session != null ? color : Colors.grey),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('운동 데이터', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 16),
                    if (totalDistance != null && totalDistance > 0 && workoutCategory == 'Endurance') ...[
                      _buildInfoRow(Icons.straighten, '총 거리', '${(totalDistance / 1000).toStringAsFixed(2)} km'),
                      const Divider(height: 24),
                    ],
                    ..._buildTimeSection(),
                    const Divider(height: 24),
                    _buildInfoRow(Icons.access_time, '날짜 및 시간', '${DateFormat('yyyy년 MM월 dd일').format(widget.dataWrapper.dateFrom)}\n${DateFormat('HH:mm').format(widget.dataWrapper.dateFrom)} ~ ${DateFormat('HH:mm').format(widget.dataWrapper.dateTo)}'),
                    if (totalDistance != null && totalDistance > 0 && workoutCategory != 'Strength' && workoutCategory != 'Endurance') ...[
                      const Divider(height: 24),
                      _buildInfoRow(Icons.straighten, '총 거리', '${(totalDistance / 1000).toStringAsFixed(2)} km'),
                    ],
                    if (totalEnergyBurned != null && totalEnergyBurned > 0) ...[
                      const Divider(height: 24),
                      _buildInfoRow(Icons.local_fire_department, '소모 칼로리', '${totalEnergyBurned.toStringAsFixed(0)} kcal'),
                    ],
                    if (_avgHeartRate > 0) ...[
                      const Divider(height: 24),
                      _buildInfoRow(Icons.favorite, '평균 심박수', '${_avgHeartRate.toStringAsFixed(1)} BPM'),
                    ],
                    if (_avgPace > 0) ...[
                      const Divider(height: 24),
                      _buildInfoRow(Icons.speed, '평균 페이스', _formatPace(_avgPace)),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            if (_workoutData != null || _heartRateData.isNotEmpty)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('심박수', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 16),
                    SizedBox(height: 150, child: _buildHeartRateSection()),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            if (isRunning && (_workoutData != null || _paceData.isNotEmpty)) ...[
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('페이스', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 16),
                      SizedBox(height: 200, child: _buildPaceSection()),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('데이터 소스', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 16),
                    _buildInfoRow(Icons.phone_iphone, '기기/앱', widget.dataWrapper.sourceName),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeartRateSection() {
    if (_isLoading) return const Center(child: CircularProgressIndicator());
    if (_heartRateError != null) return Center(child: Text(_heartRateError!));
    if (_heartRateData.isEmpty) return const Center(child: Text('심박수 데이터가 없습니다.'));
    return _buildHeartRateChart();
  }

  Widget _buildHeartRateChart() {
    final spots = <FlSpot>[];
    final workoutStartTime = widget.dataWrapper.dateFrom;
    for (var data in _heartRateData) {
      final elapsedSeconds = data.dateFrom.difference(workoutStartTime).inSeconds.toDouble();
      spots.add(FlSpot(elapsedSeconds, (data.value as NumericHealthValue).numericValue.toDouble()));
    }
    final minHeartRate = _heartRateData.map((e) => (e.value as NumericHealthValue).numericValue).reduce(min).floorToDouble();
    final maxHeartRate = _heartRateData.map((e) => (e.value as NumericHealthValue).numericValue).reduce(max).ceilToDouble();
    final workoutEndTime = widget.dataWrapper.dateTo;
    final totalDurationSeconds = workoutEndTime.difference(workoutStartTime).inSeconds.toDouble();
    final maxXSeconds = totalDurationSeconds == 0 ? 1.0 : totalDurationSeconds;

    return LineChart(
      LineChartData(
        minX: 0, maxX: maxXSeconds,
        minY: minHeartRate - (minHeartRate * 0.1), maxY: maxHeartRate + (maxHeartRate * 0.1),
        gridData: const FlGridData(show: true, drawVerticalLine: true),
        extraLinesData: ExtraLinesData(
          verticalLines: [if (_touchedTimestamp != null) VerticalLine(x: _touchedTimestamp!, color: Colors.red.withValues(alpha: 0.7), strokeWidth: 2, dashArray: [5, 5])],
        ),
        lineTouchData: LineTouchData(
          enabled: true,
          touchCallback: (FlTouchEvent event, LineTouchResponse? response) {
            if (response == null || response.lineBarSpots == null || response.lineBarSpots!.isEmpty) {
              setState(() { _touchedTimestamp = null; });
              return;
            }
            setState(() { _touchedTimestamp = response.lineBarSpots!.first.x; });
          },
          touchTooltipData: LineTouchTooltipData(
            getTooltipItems: (List<LineBarSpot> touchedSpots) {
              return touchedSpots.map((spot) {
                final minutes = (spot.x / 60).floor();
                final seconds = (spot.x % 60).toInt();
                return LineTooltipItem('${minutes}:${seconds.toString().padLeft(2, '0')}\n${spot.y.toInt()} bpm', const TextStyle(color: Colors.white, fontWeight: FontWeight.bold));
              }).toList();
            },
          ),
        ),
        titlesData: FlTitlesData(
          show: true,
          bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 30, interval: max(60, (maxXSeconds / 5).floorToDouble()), getTitlesWidget: (value, meta) {
            final minutes = (value / 60).floor();
            final seconds = (value % 60).toInt();
            return SideTitleWidget(meta: meta, space: 8.0, child: Text(seconds == 0 ? '$minutes분' : '$minutes:${seconds.toString().padLeft(2, '0')}', style: const TextStyle(color: Color(0xff68737d), fontSize: 10)));
          })),
          leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 40, interval: max(1, ((maxHeartRate - minHeartRate) / 4).floorToDouble()), getTitlesWidget: (value, meta) {
            return SideTitleWidget(meta: meta, child: Text(value.toInt().toString(), style: const TextStyle(color: Color(0xff68737d), fontSize: 10)));
          })),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        borderData: FlBorderData(show: true, border: Border.all(color: const Color(0xff37434d), width: 1)),
        lineBarsData: [
          LineChartBarData(
            spots: spots, isCurved: true, color: Theme.of(context).colorScheme.primary, barWidth: 3, isStrokeCapRound: true, dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(show: true, color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.2)),
          ),
        ],
      ),
    );
  }

  Widget _buildPaceSection() {
    if (_isPaceLoading) return const Center(child: CircularProgressIndicator());
    if (_paceError != null) return Center(child: Text(_paceError!));
    if (_paceData.isNotEmpty) return _buildPaceChart();
    if (_avgPace > 0) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.speed, size: 40, color: Theme.of(context).colorScheme.secondary.withValues(alpha: 0.6)),
            const SizedBox(height: 8),
            Text('평균 페이스', style: TextStyle(fontSize: 13, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6))),
            const SizedBox(height: 4),
            Text(_formatPace(_avgPace), style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.secondary)),
          ],
        ),
      );
    }
    return const Center(child: Text('페이스 데이터가 없습니다.'));
  }

  Widget _buildPaceChart() {
    final rawPaces = <double>[];
    for (var data in _paceData) {
      final speedMs = (data.value as NumericHealthValue).numericValue.toDouble();
      if (speedMs > 0) rawPaces.add(1000 / (speedMs * 60));
    }
    if (rawPaces.isEmpty) return const Center(child: Text('유효한 페이스 데이터가 없습니다.'));
    final smoothedPaces = <double>[];
    if (rawPaces.length < 3) smoothedPaces.addAll(rawPaces);
    else {
      smoothedPaces.add((rawPaces[0] + rawPaces[1]) / 2);
      for (int i = 1; i < rawPaces.length - 1; i++) smoothedPaces.add((rawPaces[i - 1] + rawPaces[i] + rawPaces[i + 1]) / 3);
      smoothedPaces.add((rawPaces[rawPaces.length - 2] + rawPaces[rawPaces.length - 1]) / 2);
    }
    final workoutStartTime = widget.dataWrapper.dateFrom;
    final activeDurationSeconds = _nativeActiveDuration?.inSeconds.toDouble() ?? widget.dataWrapper.dateTo.difference(workoutStartTime).inSeconds.toDouble();
    final maxXSeconds = activeDurationSeconds == 0 ? 1.0 : activeDurationSeconds;
    final spots = <FlSpot>[];
    for (int i = 0; i < smoothedPaces.length; i++) {
      final elapsedSeconds = _paceData[i].dateFrom.difference(workoutStartTime).inSeconds.toDouble();
      if (elapsedSeconds <= maxXSeconds) spots.add(FlSpot(elapsedSeconds, -smoothedPaces[i]));
    }
    if (spots.isEmpty) return const Center(child: Text('유효한 페이스 데이터가 없습니다.'));
    final minPace = spots.map((e) => e.y).reduce(min);
    final maxPace = spots.map((e) => e.y).reduce(max);
    return LineChart(
      LineChartData(
        minX: 0, maxX: maxXSeconds, minY: minPace - (minPace.abs() * 0.1), maxY: maxPace + (maxPace.abs() * 0.1),
        gridData: const FlGridData(show: true, drawVerticalLine: true),
        extraLinesData: ExtraLinesData(verticalLines: [if (_touchedTimestamp != null && _touchedTimestamp! <= maxXSeconds) VerticalLine(x: _touchedTimestamp!, color: Colors.red.withValues(alpha: 0.7), strokeWidth: 2, dashArray: [5, 5])]),
        titlesData: FlTitlesData(
          show: true,
          bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 30, interval: max(60, (maxXSeconds / 5).floorToDouble()), getTitlesWidget: (value, meta) {
            final minutes = (value / 60).floor();
            final seconds = (value % 60).toInt();
            return SideTitleWidget(meta: meta, space: 8.0, child: Text(seconds == 0 ? '$minutes분' : '$minutes:${seconds.toString().padLeft(2, '0')}', style: const TextStyle(color: Color(0xff68737d), fontSize: 10)));
          })),
          leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 45, interval: max(0.5, ((maxPace.abs() - minPace.abs()).abs() / 4).clamp(0.5, 2.0)), getTitlesWidget: (value, meta) {
            final absValue = value.abs();
            final minutes = absValue.floor();
            final seconds = ((absValue - minutes) * 60).round();
            return SideTitleWidget(meta: meta, child: Text('$minutes\'${seconds.toString().padLeft(2, '0')}"', style: const TextStyle(color: Color(0xff68737d), fontSize: 9)));
          })),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        borderData: FlBorderData(show: true, border: Border.all(color: const Color(0xff37434d), width: 1)),
        lineTouchData: LineTouchData(
          enabled: true,
          touchCallback: (FlTouchEvent event, LineTouchResponse? response) {
            if (response == null || response.lineBarSpots == null || response.lineBarSpots!.isEmpty) {
              setState(() { _touchedTimestamp = null; });
              return;
            }
            setState(() { _touchedTimestamp = response.lineBarSpots!.first.x; });
          },
          touchTooltipData: LineTouchTooltipData(
            getTooltipItems: (touchedSpots) {
              return touchedSpots.map((LineBarSpot touchedSpot) {
                final paceValue = touchedSpot.y.abs();
                final minutes = paceValue.floor();
                final seconds = ((paceValue - minutes) * 60).round();
                final timeMinutes = (touchedSpot.x / 60).floor();
                final timeSeconds = (touchedSpot.x % 60).toInt();
                return LineTooltipItem('${timeMinutes}:${timeSeconds.toString().padLeft(2, '0')}\n$minutes\'${seconds.toString().padLeft(2, '0')}"', const TextStyle(color: Colors.white, fontWeight: FontWeight.bold));
              }).toList();
            },
          ),
        ),
        lineBarsData: [LineChartBarData(spots: spots, isCurved: true, color: Theme.of(context).colorScheme.secondary, barWidth: 3, isStrokeCapRound: true, dotData: const FlDotData(show: false), belowBarData: BarAreaData(show: true, color: Theme.of(context).colorScheme.secondary.withValues(alpha: 0.2)))],
      ),
    );
  }

  String _formatPace(double paceMinutesPerKm) {
    final minutes = paceMinutesPerKm.floor();
    final seconds = ((paceMinutesPerKm - minutes) * 60).round();
    return '$minutes\'${seconds.toString().padLeft(2, '0')}"/km';
  }

  Future<void> _handleShareWorkout() async {
    if (_workoutData != null) {
      Navigator.push(context, MaterialPageRoute(builder: (context) => WorkoutShareScreen(
        workoutData: _workoutData!,
        heartRateData: _heartRateData,
        avgHeartRate: _avgHeartRate,
        paceData: _paceData,
        avgPace: _avgPace,
        movingTime: _movingTime,
        templateName: _session?.templateName,
        environmentType: _session?.environmentType,
      )));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('HealthKit 데이터가 없는 운동은 공유할 수 없습니다.')));
    }
  }

  List<Widget> _buildTimeSection() {
    Duration activeDuration;
    if (_hasNativeDuration && _nativeActiveDuration != null) {
      activeDuration = _nativeActiveDuration!;
    } else {
      activeDuration = _movingTime ?? widget.dataWrapper.dateTo.difference(widget.dataWrapper.dateFrom);
    }
    return [_buildInfoRow(Icons.play_circle_outline, '운동 시간', _formatDuration(activeDuration))];
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 24, color: Colors.grey[600]),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
              const SizedBox(height: 4),
              Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
            ],
          ),
        ),
      ],
    );
  }

  String _getWorkoutCategory(String type) {
    final upperType = type.toUpperCase();
    if (upperType.contains('CORE') || upperType.contains('FUNCTIONAL') || upperType.contains('STRENGTH') || upperType.contains('WEIGHT') || upperType.contains('TRADITIONAL_STRENGTH_TRAINING')) {
      return 'Strength';
    } else {
      return 'Endurance';
    }
  }

  Color _getWorkoutColor(BuildContext context, String category) {
    return category == 'Strength' ? Theme.of(context).colorScheme.primary : Theme.of(context).colorScheme.secondary;
  }

  String _getWorkoutIconPath(String type) {
    final upperType = type.toUpperCase();
    if (upperType.contains('CORE') || upperType.contains('FUNCTIONAL')) return 'assets/images/strength/core-icon.svg';
    if (upperType.contains('STRENGTH') || upperType.contains('WEIGHT') || upperType.contains('TRADITIONAL_STRENGTH_TRAINING')) return 'assets/images/strength/lifter-icon.svg';
    return 'assets/images/endurance/runner-icon.svg';
  }

  String _formatWorkoutType(String type) {
    final upperType = type.toUpperCase();
    if (type == 'TRADITIONAL_STRENGTH_TRAINING') return 'STRENGTH TRAINING';
    if (type == 'CORE_TRAINING') return 'CORE TRAINING';
    if (upperType.contains('RUNNING')) return 'RUNNING';
    return type.replaceAll('WORKOUT_ACTIVITY_TYPE_', '').replaceAll('_', ' ').toLowerCase().split(' ').map((word) => word.isEmpty ? '' : word[0].toUpperCase() + word.substring(1)).join(' ');
  }

  String _formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);
    if (hours > 0) return '$hours시간 $minutes분 $seconds초';
    if (minutes > 0) return '$minutes분 $seconds초';
    return '$seconds초';
  }
}

class _TimeDistance {
  final int time;
  final double distance;
  _TimeDistance(this.time, this.distance);
}