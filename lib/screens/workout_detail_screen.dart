import 'package:flutter/material.dart';
import 'package:health/health.dart';
import 'package:intl/intl.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:pacelifter/services/health_service.dart';
import 'dart:math';

/// 운동 세부 정보 화면
class WorkoutDetailScreen extends StatefulWidget {
  final HealthDataPoint workoutData;

  const WorkoutDetailScreen({super.key, required this.workoutData});

  @override
  State<WorkoutDetailScreen> createState() => _WorkoutDetailScreenState();
}

class _WorkoutDetailScreenState extends State<WorkoutDetailScreen> {
  final HealthService _healthService = HealthService();
  List<HealthDataPoint> _heartRateData = [];
  double _avgHeartRate = 0;
  bool _isLoading = true;
  String? _heartRateError;

  List<HealthDataPoint> _paceData = [];
  double _avgPace = 0;
  bool _isPaceLoading = true;
  String? _paceError;

  @override
  void initState() {
    super.initState();
    _fetchHeartRateData();
    _fetchPaceData();
  }

  Future<void> _fetchHeartRateData() async {
    final types = [HealthDataType.HEART_RATE];

    final granted = await _healthService.requestAuthorization();
    if (granted) {
      try {
        final heartRateData = await _healthService.getHealthDataFromTypes(
          widget.workoutData.dateFrom,
          widget.workoutData.dateTo,
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
    print('🏃 페이스 데이터 가져오기 시작');
    print('📅 운동 시작: ${widget.workoutData.dateFrom}');
    print('📅 운동 종료: ${widget.workoutData.dateTo}');

    // HealthKit RUNNING_SPEED 데이터만 사용 (WALKING_SPEED 제외)
    final types = [HealthDataType.RUNNING_SPEED];

    final granted = await _healthService.requestAuthorization();

    print('✅ 권한 부여: $granted');

    if (granted) {
      try {
        final speedData = await _healthService.getHealthDataFromTypes(
          widget.workoutData.dateFrom,
          widget.workoutData.dateTo,
          types,
        );

        print('📊 RUNNING_SPEED 데이터 개수: ${speedData.length}');

        if (speedData.isNotEmpty) {
          _processPaceData(speedData);
        } else {
          // RUNNING_SPEED 데이터 없음
          if (mounted) {
            setState(() {
              _paceError = '러닝 속도 데이터가 없습니다.\n(PaceLifter 앱으로 기록한 운동에서만 표시됩니다)';
              _isPaceLoading = false;
            });
          }
        }
      } catch (e) {
        print('❌ 에러 발생: $e');
        if (mounted) {
          setState(() {
            _paceError = '페이스 데이터를 가져오는 데 실패했습니다: $e';
            _isPaceLoading = false;
          });
        }
      }
    } else {
      if (mounted) {
        setState(() {
          _paceError = '페이스 접근 권한이 거부되었습니다.';
          _isPaceLoading = false;
        });
      }
    }
  }

  void _processPaceData(List<HealthDataPoint> speedData) {
    print('🔄 페이스 데이터 처리 중: ${speedData.length}개');

    // 거리 가중 평균 페이스 계산 (NRC/Strava 방식)
    // 평균 페이스 = 총 운동 시간 / 총 거리
    final workout = widget.workoutData.value as WorkoutHealthValue;
    final totalDistance = workout.totalDistance; // 미터
    final totalDuration = widget.workoutData.dateTo.difference(widget.workoutData.dateFrom);

    if (totalDistance == null || totalDistance == 0) {
      if (mounted) {
        setState(() {
          _paceError = '거리 데이터가 없습니다.';
          _isPaceLoading = false;
        });
      }
      return;
    }

    // 거리 가중 평균 페이스 (분/km)
    final avgPaceMinPerKm = (totalDuration.inSeconds / 60) / (totalDistance / 1000);

    print('✅ 평균 페이스: ${_formatPace(avgPaceMinPerKm)}');
    print('   총 거리: ${(totalDistance / 1000).toStringAsFixed(2)} km');
    print('   총 시간: ${totalDuration.inMinutes}분 ${totalDuration.inSeconds % 60}초');

    if (mounted) {
      setState(() {
        _paceData = speedData;
        _avgPace = avgPaceMinPerKm;
        _isPaceLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final workout = widget.workoutData.value as WorkoutHealthValue;
    final workoutType = workout.workoutActivityType.name;
    final workoutCategory = _getWorkoutCategory(workoutType);
    final color = _getWorkoutColor(context, workoutCategory);
    final iconPath = _getWorkoutIconPath(workoutType);

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        title: const Text('운동 세부 정보'),
        backgroundColor: Theme.of(context).colorScheme.surface,
        foregroundColor: Theme.of(context).colorScheme.onSurface,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 상단 카드: 아이콘 및 운동 타입
            Card(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      SvgPicture.asset(
                        iconPath,
                        width: 80,
                        height: 80,
                        colorFilter: ColorFilter.mode(
                          color,
                          BlendMode.srcIn,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        _formatWorkoutType(workoutType),
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: color,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: color.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          workoutCategory,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: color,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            // 운동 데이터
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '운동 데이터',
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 16),
                    _buildInfoRow(
                      Icons.hourglass_empty,
                      '운동 시간',
                      _formatDuration(widget.workoutData.dateTo
                          .difference(widget.workoutData.dateFrom)),
                    ),
                    const Divider(height: 24),
                    _buildInfoRow(
                      Icons.access_time,
                      '날짜 및 시간',
                      '${DateFormat('yyyy년 MM월 dd일').format(widget.workoutData.dateFrom)}\n${DateFormat('HH:mm').format(widget.workoutData.dateFrom)} ~ ${DateFormat('HH:mm').format(widget.workoutData.dateTo)}',
                    ),
                    if (workout.totalDistance != null) ...[
                      const Divider(height: 24),
                      _buildInfoRow(
                        Icons.straighten,
                        '총 거리',
                        '${(workout.totalDistance! / 1000).toStringAsFixed(2)} km',
                      ),
                    ],
                    if (workout.totalEnergyBurned != null) ...[
                      const Divider(height: 24),
                      _buildInfoRow(
                        Icons.local_fire_department,
                        '소모 칼로리',
                        '${workout.totalEnergyBurned!.toStringAsFixed(0)} kcal',
                      ),
                    ],
                    if (_avgHeartRate > 0) ...[
                      const Divider(height: 24),
                      _buildInfoRow(
                        Icons.favorite,
                        '평균 심박수',
                        '${_avgHeartRate.toStringAsFixed(1)} BPM',
                      ),
                    ],
                    if (_avgPace > 0) ...[
                      const Divider(height: 24),
                      _buildInfoRow(
                        Icons.speed,
                        '평균 페이스',
                        _formatPace(_avgPace),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            // 심박수 데이터
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '심박수',
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      height: 150, // Reduced height
                      child: _buildHeartRateSection(),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            // 페이스 데이터
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '페이스',
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      height: 150,
                      child: _buildPaceSection(),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            // 데이터 소스
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '데이터 소스',
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 16),
                    _buildInfoRow(
                      Icons.phone_iphone,
                      '기기/앱',
                      widget.workoutData.sourceName,
                    ),
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
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_heartRateError != null) {
      return Center(child: Text(_heartRateError!));
    }
    if (_heartRateData.isEmpty) {
      return const Center(child: Text('심박수 데이터가 없습니다.'));
    }
    return _buildHeartRateChart();
  }

  Widget _buildHeartRateChart() {
    final spots = <FlSpot>[];
    // Calculate relative time in minutes
    final workoutStartTimeMillis =
        widget.workoutData.dateFrom.millisecondsSinceEpoch;
    for (var data in _heartRateData) {
      final relativeTimeMinutes =
          (data.dateFrom.millisecondsSinceEpoch - workoutStartTimeMillis) /
              (1000 * 60);
      spots.add(FlSpot(
        relativeTimeMinutes,
        (data.value as NumericHealthValue).numericValue.toDouble(),
      ));
    }

    // Calculate min/max heart rate for Y-axis
    final minHeartRate = _heartRateData
        .map((e) => (e.value as NumericHealthValue).numericValue)
        .reduce(min)
        .floorToDouble();
    final maxHeartRate = _heartRateData
        .map((e) => (e.value as NumericHealthValue).numericValue)
        .reduce(max)
        .ceilToDouble();

    // Calculate total workout duration in minutes for X-axis
    final totalWorkoutDurationMinutes = widget.workoutData.dateTo
        .difference(widget.workoutData.dateFrom)
        .inMinutes
        .toDouble();

    return LineChart(
      LineChartData(
        minX: 0,
        maxX: totalWorkoutDurationMinutes == 0
            ? 1
            : totalWorkoutDurationMinutes, // Avoid maxX being 0
        minY: minHeartRate - (minHeartRate * 0.1), // 10% buffer below min
        maxY: maxHeartRate + (maxHeartRate * 0.1), // 10% buffer above max
        gridData: FlGridData(
          show: true,
          drawVerticalLine: true,
          getDrawingHorizontalLine: (value) {
            return const FlLine(
              color: Color(0xff37434d),
              strokeWidth: 1,
            );
          },
          getDrawingVerticalLine: (value) {
            return const FlLine(
              color: Color(0xff37434d),
              strokeWidth: 1,
            );
          },
        ),
        titlesData: FlTitlesData(
          show: true,
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 30,
              interval: max(1, (totalWorkoutDurationMinutes / 5).floorToDouble()), // Dynamic interval
              getTitlesWidget: (value, meta) {
                return SideTitleWidget(
                  meta: meta,
                  space: 8.0,
                  child: Text('${value.toInt()}분',
                      style: const TextStyle(
                          color: Color(0xff68737d), fontSize: 10)),
                );
              },
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 40,
              interval: max(1, ((maxHeartRate - minHeartRate) / 4).floorToDouble()), // Dynamic interval
              getTitlesWidget: (value, meta) {
                return SideTitleWidget(
                  meta: meta,
                  child: Text(value.toInt().toString(),
                      style: const TextStyle(
                          color: Color(0xff68737d), fontSize: 10)),
                );
              },
            ),
          ),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        borderData: FlBorderData(
          show: true,
          border: Border.all(color: const Color(0xff37434d), width: 1),
        ),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            color: Theme.of(context).colorScheme.primary,
            barWidth: 3,
            isStrokeCapRound: true,
            dotData: FlDotData(show: false),
            belowBarData: BarAreaData(
              show: true,
              color: Theme.of(context).colorScheme.primary.withOpacity(0.2),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaceSection() {
    if (_isPaceLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_paceError != null) {
      return Center(child: Text(_paceError!));
    }
    if (_paceData.isEmpty) {
      return const Center(child: Text('페이스 데이터가 없습니다.'));
    }
    return _buildPaceChart();
  }

  Widget _buildPaceChart() {
    final spots = <FlSpot>[];

    // 운동 시작 시간 기준
    final workoutStartTime = widget.workoutData.dateFrom;
    final workoutEndTime = widget.workoutData.dateTo;
    final totalDurationSeconds = workoutEndTime.difference(workoutStartTime).inSeconds;

    // 데이터 포인트를 운동 시간 기준으로 변환
    for (var data in _paceData) {
      // X축: 운동 시작 이후 경과 시간 (초)
      final elapsedSeconds = data.dateFrom.difference(workoutStartTime).inSeconds.toDouble();

      // Y축: 페이스 (분/km)
      final speedMs = (data.value as NumericHealthValue).numericValue.toDouble();

      // 속도(m/s)를 페이스(분/km)로 변환
      if (speedMs > 0) {
        final pace = 1000 / (speedMs * 60);

        // 유효한 페이스만 추가 (비정상적으로 느린 페이스 제외)
        if (pace < 20) {
          spots.add(FlSpot(elapsedSeconds, pace));
        }
      }
    }

    if (spots.isEmpty) {
      return const Center(child: Text('유효한 페이스 데이터가 없습니다.'));
    }

    // Y축 범위 계산
    final minPace = spots.map((e) => e.y).reduce(min);
    final maxPace = spots.map((e) => e.y).reduce(max);

    // X축 범위: 0 ~ 총 운동 시간 (초)
    final maxXSeconds = totalDurationSeconds.toDouble();

    return LineChart(
      LineChartData(
        minX: 0,
        maxX: maxXSeconds == 0 ? 1 : maxXSeconds,
        minY: minPace - (minPace * 0.1), // 10% buffer below min
        maxY: maxPace + (maxPace * 0.1), // 10% buffer above max
        gridData: FlGridData(
          show: true,
          drawVerticalLine: true,
          getDrawingHorizontalLine: (value) {
            return const FlLine(
              color: Color(0xff37434d),
              strokeWidth: 1,
            );
          },
          getDrawingVerticalLine: (value) {
            return const FlLine(
              color: Color(0xff37434d),
              strokeWidth: 1,
            );
          },
        ),
        titlesData: FlTitlesData(
          show: true,
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 30,
              interval: max(60, (maxXSeconds / 5).floorToDouble()), // 60초 단위 간격
              getTitlesWidget: (value, meta) {
                // 초를 분:초 형식으로 변환
                final minutes = (value / 60).floor();
                final seconds = (value % 60).toInt();
                return SideTitleWidget(
                  meta: meta,
                  space: 8.0,
                  child: Text(
                    seconds == 0 ? '${minutes}분' : '${minutes}:${seconds.toString().padLeft(2, '0')}',
                    style: const TextStyle(
                      color: Color(0xff68737d),
                      fontSize: 10,
                    ),
                  ),
                );
              },
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 45,
              interval: max(0.5, ((maxPace - minPace) / 4)),
              getTitlesWidget: (value, meta) {
                // 페이스를 분'초" 형식으로 표시
                final minutes = value.floor();
                final seconds = ((value - minutes) * 60).round();
                return SideTitleWidget(
                  meta: meta,
                  child: Text('$minutes\'${seconds.toString().padLeft(2, '0')}"',
                      style: const TextStyle(
                          color: Color(0xff68737d), fontSize: 9)),
                );
              },
            ),
          ),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        borderData: FlBorderData(
          show: true,
          border: Border.all(color: const Color(0xff37434d), width: 1),
        ),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            color: Theme.of(context).colorScheme.secondary,
            barWidth: 3,
            isStrokeCapRound: true,
            dotData: FlDotData(show: false),
            belowBarData: BarAreaData(
              show: true,
              color: Theme.of(context).colorScheme.secondary.withOpacity(0.2),
            ),
          ),
        ],
      ),
    );
  }

  String _formatPace(double paceMinutesPerKm) {
    final minutes = paceMinutesPerKm.floor();
    final seconds = ((paceMinutesPerKm - minutes) * 60).round();
    return '$minutes\'${seconds.toString().padLeft(2, '0')}"/km';
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
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ],
    );
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

  Color _getWorkoutColor(BuildContext context, String category) {
    switch (category) {
      case 'Strength':
        return Theme.of(context).colorScheme.primary;
      case 'Endurance':
        return Theme.of(context).colorScheme.secondary;
      default:
        return Theme.of(context).colorScheme.secondary;
    }
  }

  String _getWorkoutIconPath(String type) {
    final upperType = type.toUpperCase();
    if (upperType.contains('CORE') || upperType.contains('FUNCTIONAL')) {
      return 'assets/images/core-icon.svg';
    } else if (upperType.contains('STRENGTH') ||
        upperType.contains('WEIGHT') ||
        upperType.contains('TRADITIONAL_STRENGTH_TRAINING')) {
      return 'assets/images/lifter-icon.svg';
    } else {
      return 'assets/images/runner-icon.svg';
    }
  }

  String _formatWorkoutType(String type) {
    final upperType = type.toUpperCase();
    if (type == 'TRADITIONAL_STRENGTH_TRAINING') {
      return 'STRENGTH TRAINING';
    }
    if (type == 'CORE_TRAINING') {
      return 'CORE TRAINING';
    }
    if (upperType.contains('RUNNING')) {
      return 'RUNNING';
    }
    return type
        .replaceAll('WORKOUT_ACTIVITY_TYPE_', '')
        .replaceAll('_', ' ')
        .toLowerCase()
        .split(' ')
        .map((word) => word.isEmpty ? '' : word[0].toUpperCase() + word.substring(1))
        .join(' ');
  }

  String _formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);

    if (hours > 0) {
      return '$hours시간 $minutes분 $seconds초';
    } else if (minutes > 0) {
      return '$minutes분 $seconds초';
    } else {
      return '$seconds초';
    }
  }
}