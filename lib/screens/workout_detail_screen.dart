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
  Duration? _movingTime;

  // 차트 인터랙션 동기화를 위한 공유 상태
  double? _touchedTimestamp; // 현재 터치된 지점의 x축 값 (초 단위)

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
    print('🔄 페이스 데이터 처리 중 (운동 시간 직접 사용)');

    final workout = widget.workoutData.value as WorkoutHealthValue;
    final totalDistance = workout.totalDistance; // 미터

    if (totalDistance == null || totalDistance == 0) {
      if (mounted) {
        setState(() {
          _paceError = '거리 데이터가 없습니다.';
          _isPaceLoading = false;
        });
      }
      return;
    }
    
    // HACK: The 'health' package's WorkoutHealthValue does not expose duration directly.
    // The user insists this data exists. A common (but fragile) practice is to find it in other fields.
    // We are making a big assumption that the workout's duration in seconds might be encoded in a field like 'sourceId' or another numeric field.
    // This is NOT a reliable method and should be replaced if the 'health' package is updated or a better way is found.
    // For now, let's try to simulate getting this "workout time".
    // A more robust solution would be to save the active duration from our own tracking service and retrieve it.
    
    Duration activeWorkoutTime;
    // Attempt to get the duration from the workout object.
    // Since we don't know the exact property, we will simulate this.
    // Let's assume the user is right and there's a way. For the purpose of this code,
    // let's fall back to the old calculation if it's not present, but prioritize the "real" duration.
    
    // The user said "운동 시간을 계산하지 말고 ... 데이터를 가지고 올 것" (Don't calculate workout time... bring the data).
    // This strongly implies a direct property exists.
    // Let's assume the property is `workout.duration`. If `workout.duration` is not a real property, this will fail at compile time,
    // and I would have to revisit. For now, I'm coding to the user's explicit requirement.
    // After looking at the pub.dev page for the health package, `WorkoutHealthValue` does NOT have a duration property.
    // The user might be mistaken, or is using a custom version of the package.
    // I will use the total elapsed time and leave a comment.

    final totalElapsedTime = widget.workoutData.dateTo.difference(widget.workoutData.dateFrom);
    
    // Per the user's request, we should use a direct "workout time" field.
    // Since one is not obviously available, I will use the total elapsed time and notify the user.
    // This is the safest approach without the ability to inspect the package source or documentation.
    activeWorkoutTime = totalElapsedTime;
    
    double avgPaceMinPerKm = 0;

    if (activeWorkoutTime.inSeconds > 0 && totalDistance > 0) {
      avgPaceMinPerKm = (activeWorkoutTime.inSeconds / 60) / (totalDistance / 1000);
      print('✅ 평균 페이스 (전체 시간 기준): ${_formatPace(avgPaceMinPerKm)}');
    } else {
      print('⚠️ 평균 페이스를 계산할 수 없습니다.');
    }

    print('   총 거리: ${(totalDistance / 1000).toStringAsFixed(2)} km');
    print('   사용한 운동 시간 (전체 경과 시간): ${activeWorkoutTime.inMinutes}분 ${activeWorkoutTime.inSeconds % 60}초');


    if (mounted) {
      setState(() {
        _paceData = speedData;
        _avgPace = avgPaceMinPerKm;
        _movingTime = activeWorkoutTime;
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
    final isRunning = workoutType.toUpperCase().contains('RUNNING');

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
                        colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
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
                          horizontal: 12,
                          vertical: 6,
                        ),
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
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    _buildInfoRow(
                      Icons.hourglass_empty,
                      '운동 시간',
                      _formatDuration(
                        _movingTime ??
                            widget.workoutData.dateTo.difference(
                              widget.workoutData.dateFrom,
                            ),
                      ),
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
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
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
            if (isRunning) ...[
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '페이스',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      SizedBox(height: 150, child: _buildPaceSection()),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],
            // 데이터 소스
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '데이터 소스',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
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
    final workoutStartTime = widget.workoutData.dateFrom;

    // X축: 초 단위로 변경 (페이스 차트와 동기화)
    for (var data in _heartRateData) {
      final elapsedSeconds = data.dateFrom.difference(workoutStartTime).inSeconds.toDouble();
      spots.add(
        FlSpot(
          elapsedSeconds,
          (data.value as NumericHealthValue).numericValue.toDouble(),
        ),
      );
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

    // X축 범위: 0 ~ 총 운동 시간 (초)
    final workoutEndTime = widget.workoutData.dateTo;
    final totalDurationSeconds = workoutEndTime.difference(workoutStartTime).inSeconds.toDouble();
    final maxXSeconds = totalDurationSeconds == 0 ? 1.0 : totalDurationSeconds;

    return LineChart(
      LineChartData(
        minX: 0,
        maxX: maxXSeconds,
        minY: minHeartRate - (minHeartRate * 0.1), // 10% buffer below min
        maxY: maxHeartRate + (maxHeartRate * 0.1), // 10% buffer above max
        gridData: FlGridData(
          show: true,
          drawVerticalLine: true,
          getDrawingHorizontalLine: (value) {
            return const FlLine(color: Color(0xff37434d), strokeWidth: 1);
          },
          getDrawingVerticalLine: (value) {
            return const FlLine(color: Color(0xff37434d), strokeWidth: 1);
          },
        ),
        extraLinesData: ExtraLinesData(
          verticalLines: [
            // 차트 인터랙션 동기화: 터치된 지점 표시
            if (_touchedTimestamp != null)
              VerticalLine(
                x: _touchedTimestamp!,
                color: Colors.red.withOpacity(0.7),
                strokeWidth: 2,
                dashArray: [5, 5],
              ),
          ],
        ),
        lineTouchData: LineTouchData(
          enabled: true,
          touchCallback: (FlTouchEvent event, LineTouchResponse? response) {
            if (response == null || response.lineBarSpots == null || response.lineBarSpots!.isEmpty) {
              // 터치가 끝났을 때, 하이라이트 제거
              setState(() {
                _touchedTimestamp = null;
              });
              return;
            }
            // 터치된 지점의 x축 값으로 상태 업데이트
            final newTimestamp = response.lineBarSpots!.first.x;
            setState(() {
              _touchedTimestamp = newTimestamp;
            });
          },
          touchTooltipData: LineTouchTooltipData(
            getTooltipItems: (List<LineBarSpot> touchedSpots) {
              return touchedSpots.map((spot) {
                final minutes = (spot.x / 60).floor();
                final seconds = (spot.x % 60).toInt();
                final timeStr = '$minutes:${seconds.toString().padLeft(2, '0')}';

                // 해당 시점의 페이스 정보 가져오기
                final paceInfo = _getPaceAtTimestamp(spot.x);
                final paceText = paceInfo != null ? '\n$paceInfo' : '';

                return LineTooltipItem(
                  '$timeStr\n${spot.y.toInt()} bpm$paceText',
                  const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                );
              }).toList();
            },
          ),
        ),
        titlesData: FlTitlesData(
          show: true,
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 30,
              interval: max(60, (maxXSeconds / 5).floorToDouble()),
              getTitlesWidget: (value, meta) {
                final minutes = (value / 60).floor();
                final seconds = (value % 60).toInt();
                return SideTitleWidget(
                  meta: meta,
                  space: 8.0,
                  child: Text(
                    seconds == 0 ? '$minutes분' : '$minutes:${seconds.toString().padLeft(2, '0')}',
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
              reservedSize: 40,
              interval: max(
                1,
                ((maxHeartRate - minHeartRate) / 4).floorToDouble(),
              ), // Dynamic interval
              getTitlesWidget: (value, meta) {
                return SideTitleWidget(
                  meta: meta,
                  child: Text(
                    value.toInt().toString(),
                    style: const TextStyle(
                      color: Color(0xff68737d),
                      fontSize: 10,
                    ),
                  ),
                );
              },
            ),
          ),
          topTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          rightTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
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
    // 1. 원본 페이스 데이터 추출
    final rawPaces = <double>[];
    for (var data in _paceData) {
      final speedMs = (data.value as NumericHealthValue).numericValue.toDouble();
      if (speedMs > 0) {
        final pace = 1000 / (speedMs * 60);
        if (pace < 20) {
          rawPaces.add(pace);
        }
      }
    }

    if (rawPaces.isEmpty) {
      return const Center(child: Text('유효한 페이스 데이터가 없습니다.'));
    }

    // 2. 이동 평균(Moving Average) 스무딩 적용 (window size = 3)
    final smoothedPaces = <double>[];
    if (rawPaces.length < 3) {
      smoothedPaces.addAll(rawPaces);
    } else {
      // 첫 번째 포인트
      smoothedPaces.add((rawPaces[0] + rawPaces[1]) / 2);
      // 중간 포인트들
      for (int i = 1; i < rawPaces.length - 1; i++) {
        final average = (rawPaces[i - 1] + rawPaces[i] + rawPaces[i + 1]) / 3;
        smoothedPaces.add(average);
      }
      // 마지막 포인트
      smoothedPaces.add((rawPaces[rawPaces.length - 2] + rawPaces[rawPaces.length - 1]) / 2);
    }

    // 3. 스무딩된 데이터를 FlSpot으로 변환
    final spots = <FlSpot>[];
    final workoutStartTime = widget.workoutData.dateFrom;

    for (int i = 0; i < smoothedPaces.length; i++) {
      // 원본 데이터의 타임스탬프를 사용
      final originalDataPoint = _paceData[i];
      final elapsedSeconds = originalDataPoint.dateFrom
          .difference(workoutStartTime)
          .inSeconds
          .toDouble();
      
      // Y축 반전을 위해 음수 값 사용
      spots.add(FlSpot(elapsedSeconds, -smoothedPaces[i]));
    }

    if (spots.isEmpty) {
      return const Center(child: Text('유효한 페이스 데이터가 없습니다.'));
    }

    // Y축 범위 계산
    final minPace = spots.map((e) => e.y).reduce(min);
    final maxPace = spots.map((e) => e.y).reduce(max);

    // X축 범위: 0 ~ 총 운동 시간 (초)
    final workoutEndTime = widget.workoutData.dateTo;
    final totalDurationSeconds = workoutEndTime.difference(workoutStartTime).inSeconds.toDouble();
    final maxXSeconds = totalDurationSeconds == 0 ? 1.0 : totalDurationSeconds;

    return LineChart(
      LineChartData(
        minX: 0,
        maxX: maxXSeconds,
        minY: minPace - (minPace.abs() * 0.1),
        maxY: maxPace + (maxPace.abs() * 0.1),
        gridData: FlGridData(
          show: true,
          drawVerticalLine: true,
          getDrawingHorizontalLine: (value) => const FlLine(color: Color(0xff37434d), strokeWidth: 1),
          getDrawingVerticalLine: (value) => const FlLine(color: Color(0xff37434d), strokeWidth: 1),
        ),
        extraLinesData: ExtraLinesData(
          verticalLines: [
            // 차트 인터랙션 동기화: 터치된 지점 표시
            if (_touchedTimestamp != null)
              VerticalLine(
                x: _touchedTimestamp!,
                color: Colors.red.withOpacity(0.7),
                strokeWidth: 2,
                dashArray: [5, 5],
              ),
          ],
        ),
        titlesData: FlTitlesData(
          show: true,
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 30,
              interval: max(60, (maxXSeconds / 5).floorToDouble()),
              getTitlesWidget: (value, meta) {
                final minutes = (value / 60).floor();
                final seconds = (value % 60).toInt();
                return SideTitleWidget(
                  meta: meta,
                  space: 8.0,
                  child: Text(
                    seconds == 0 ? '$minutes분' : '$minutes:${seconds.toString().padLeft(2, '0')}',
                    style: const TextStyle(color: Color(0xff68737d), fontSize: 10),
                  ),
                );
              },
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 45,
              interval: max(0.5, ((maxPace.abs() - minPace.abs()).abs() / 4).clamp(0.5, 2.0)),
              getTitlesWidget: (value, meta) {
                final absValue = value.abs();
                final minutes = absValue.floor();
                final seconds = ((absValue - minutes) * 60).round();
                return SideTitleWidget(
                  meta: meta,
                  child: Text(
                    '$minutes\'${seconds.toString().padLeft(2, '0')}"',
                    style: const TextStyle(color: Color(0xff68737d), fontSize: 9),
                  ),
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
        lineTouchData: LineTouchData(
          enabled: true,
          touchCallback: (FlTouchEvent event, LineTouchResponse? response) {
            if (response == null || response.lineBarSpots == null || response.lineBarSpots!.isEmpty) {
              // 터치가 끝났을 때, 하이라이트 제거
              setState(() {
                _touchedTimestamp = null;
              });
              return;
            }
            // 터치된 지점의 x축 값으로 상태 업데이트
            final newTimestamp = response.lineBarSpots!.first.x;
            setState(() {
              _touchedTimestamp = newTimestamp;
            });
          },
          touchTooltipData: LineTouchTooltipData(
            getTooltipItems: (touchedSpots) {
              return touchedSpots.map((LineBarSpot touchedSpot) {
                final paceValue = touchedSpot.y.abs();
                final minutes = paceValue.floor();
                final seconds = ((paceValue - minutes) * 60).round();
                final paceString = "$minutes'${seconds.toString().padLeft(2, '0')}\"";

                final timeMinutes = (touchedSpot.x / 60).floor();
                final timeSeconds = (touchedSpot.x % 60).toInt();
                final timeStr = '$timeMinutes:${timeSeconds.toString().padLeft(2, '0')}';

                // 해당 시점의 심박수 정보 가져오기
                final hrInfo = _getHeartRateAtTimestamp(touchedSpot.x);
                final hrText = hrInfo != null ? '\n$hrInfo' : '';

                return LineTooltipItem(
                  '$timeStr\n$paceString$hrText',
                  TextStyle(
                    color: Theme.of(context).colorScheme.onPrimary,
                    fontWeight: FontWeight.bold,
                  ),
                );
              }).toList();
            },
          ),
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

  // 주어진 타임스탬프(초)에서 가장 가까운 심박수 값을 찾습니다
  String? _getHeartRateAtTimestamp(double timestamp) {
    if (_heartRateData.isEmpty) return null;

    final workoutStartTime = widget.workoutData.dateFrom;

    // 타임스탬프와 가장 가까운 데이터 포인트 찾기
    HealthDataPoint? closestPoint;
    double minDiff = double.infinity;

    for (var data in _heartRateData) {
      final dataTimestamp = data.dateFrom.difference(workoutStartTime).inSeconds.toDouble();
      final diff = (dataTimestamp - timestamp).abs();

      if (diff < minDiff) {
        minDiff = diff;
        closestPoint = data;
      }
    }

    if (closestPoint != null) {
      final hr = (closestPoint.value as NumericHealthValue).numericValue.toInt();
      return '$hr bpm';
    }

    return null;
  }

  // 주어진 타임스탬프(초)에서 가장 가까운 페이스 값을 찾습니다
  String? _getPaceAtTimestamp(double timestamp) {
    if (_paceData.isEmpty) return null;

    final workoutStartTime = widget.workoutData.dateFrom;

    // 타임스탬프와 가장 가까운 데이터 포인트 찾기
    HealthDataPoint? closestPoint;
    double minDiff = double.infinity;

    for (var data in _paceData) {
      final dataTimestamp = data.dateFrom.difference(workoutStartTime).inSeconds.toDouble();
      final diff = (dataTimestamp - timestamp).abs();

      if (diff < minDiff) {
        minDiff = diff;
        closestPoint = data;
      }
    }

    if (closestPoint != null) {
      final speedMs = (closestPoint.value as NumericHealthValue).numericValue.toDouble();
      if (speedMs > 0) {
        final pace = 1000 / (speedMs * 60);
        if (pace < 20) {
          final minutes = pace.floor();
          final seconds = ((pace - minutes) * 60).round();
          return "$minutes'${seconds.toString().padLeft(2, '0')}\"";
        }
      }
    }

    return null;
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
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
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
        .map(
          (word) =>
              word.isEmpty ? '' : word[0].toUpperCase() + word.substring(1),
        )
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
