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
    final permissions = [HealthDataAccess.READ];

    final granted = await _healthService.requestAuthorization(
        types: types, permissions: permissions);
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

    final types = [HealthDataType.RUNNING_SPEED];
    final permissions = [HealthDataAccess.READ];

    final granted = await _healthService.requestAuthorization(
        types: types, permissions: permissions);

    print('✅ 권한 부여: $granted');

    if (granted) {
      try {
        final speedData = await _healthService.getHealthDataFromTypes(
          widget.workoutData.dateFrom,
          widget.workoutData.dateTo,
          types,
        );

        print('📊 RUNNING_SPEED 데이터 개수: ${speedData.length}');

        if (speedData.isEmpty) {
          // RUNNING_SPEED 데이터가 없으면 WALKING_SPEED 시도
          print('⚠️ RUNNING_SPEED 데이터 없음, WALKING_SPEED 시도');
          final walkingSpeedData = await _healthService.getHealthDataFromTypes(
            widget.workoutData.dateFrom,
            widget.workoutData.dateTo,
            [HealthDataType.WALKING_SPEED],
          );

          print('📊 WALKING_SPEED 데이터 개수: ${walkingSpeedData.length}');

          if (walkingSpeedData.isNotEmpty) {
            _processPaceData(walkingSpeedData);
            return;
          }
        } else {
          _processPaceData(speedData);
          return;
        }

        // 둘 다 없으면 에러 메시지
        if (mounted) {
          setState(() {
            _paceError = '페이스 데이터가 없습니다.\n(Apple Watch로 기록한 운동만 지원)';
          });
        }
      } catch (e) {
        print('❌ 에러 발생: $e');
        if (mounted) {
          setState(() {
            _paceError = '페이스 데이터를 가져오는 데 실패했습니다: $e';
          });
        }
      }
    } else {
      if (mounted) {
        setState(() {
          _paceError = '페이스 접근 권한이 거부되었습니다.';
        });
      }
    }
    if (mounted) {
      setState(() {
        _isPaceLoading = false;
      });
    }
  }

  void _processPaceData(List<HealthDataPoint> speedData) {
    print('🔄 페이스 데이터 처리 중: ${speedData.length}개');

    // 필터링: 최소 속도 1.5 m/s (약 10분/km) 이상만 사용
    // 이는 정지/걷기 구간을 제외하고 실제 달리기 구간만 사용
    const double minSpeed = 1.5; // m/s

    List<HealthDataPoint> validData = [];
    double sum = 0;
    int filteredCount = 0;

    for (var data in speedData) {
      final speedMs = (data.value as NumericHealthValue).numericValue.toDouble();

      if (speedMs >= minSpeed) {
        // 페이스 = 1000 / (속도 * 60) 분/km
        final pace = 1000 / (speedMs * 60);
        sum += pace;
        validData.add(data);
      } else {
        filteredCount++;
      }
    }

    print('✅ 유효한 데이터: ${validData.length}개 (필터링: $filteredCount개)');

    if (validData.isEmpty) {
      if (mounted) {
        setState(() {
          _paceError = '유효한 페이스 데이터가 없습니다.\n(달리기 속도가 감지되지 않음)';
          _isPaceLoading = false;
        });
      }
      return;
    }

    final avgPace = sum / validData.length;
    print('✅ 평균 페이스: ${_formatPace(avgPace)}');
    print('   최소 속도: ${validData.map((d) => (d.value as NumericHealthValue).numericValue).reduce((a, b) => a < b ? a : b).toStringAsFixed(2)} m/s');
    print('   최대 속도: ${validData.map((d) => (d.value as NumericHealthValue).numericValue).reduce((a, b) => a > b ? a : b).toStringAsFixed(2)} m/s');

    if (mounted) {
      setState(() {
        _paceData = validData;
        _avgPace = avgPace;
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
    // Calculate relative time in minutes
    final workoutStartTimeMillis =
        widget.workoutData.dateFrom.millisecondsSinceEpoch;

    for (var data in _paceData) {
      final relativeTimeMinutes =
          (data.dateFrom.millisecondsSinceEpoch - workoutStartTimeMillis) /
              (1000 * 60);
      final speedMs = (data.value as NumericHealthValue).numericValue.toDouble();
      // 속도(m/s)를 페이스(분/km)로 변환
      final pace = speedMs > 0 ? 1000 / (speedMs * 60) : 0.0;
      if (pace > 0) {
        spots.add(FlSpot(relativeTimeMinutes, pace.toDouble()));
      }
    }

    if (spots.isEmpty) {
      return const Center(child: Text('유효한 페이스 데이터가 없습니다.'));
    }

    // Calculate min/max pace for Y-axis
    final minPace = spots.map((e) => e.y).reduce(min);
    final maxPace = spots.map((e) => e.y).reduce(max);

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
            : totalWorkoutDurationMinutes,
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
              interval: max(1, (totalWorkoutDurationMinutes / 5).floorToDouble()),
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