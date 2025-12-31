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
import 'package:pacelifter/models/workout_data_wrapper.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:pacelifter/models/sessions/route_point.dart';
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

  HealthDataPoint? get _workoutData => widget.dataWrapper.healthData;

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
  Duration? _nativeElapsedTime;
  Duration? _nativePausedDuration;
  bool _hasNativeDuration = false;

  // 차트 인터랙션 동기화를 위한 공유 상태
  double? _touchedTimestamp; // 현재 터치된 지점의 x축 값 (초 단위)

  WorkoutSession? _session;

  @override
  void initState() {
    super.initState();
    _initializeData();
  }

  Future<void> _initializeData() async {
    // Fetch linked session
    await _fetchLinkedSession();

    if (_workoutData == null) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _isPaceLoading = false;
          if (_session != null) {
            _avgHeartRate = _session!.averageHeartRate?.toDouble() ?? 0;
            // averagePace is in seconds/km in WorkoutSession
            _avgPace = _session!.averagePace != null ? _session!.averagePace! / 60 : 0;
          }
        });
      }
      return;
    }

    // Fetch native duration first to ensure accurate pace calculation
    await _fetchNativeDuration();

    // Then fetch heart rate and pace data
    _fetchHeartRateData();
    _fetchPaceData();
  }

  Future<void> _fetchLinkedSession() async {
    final session = await WorkoutHistoryService().getSessionByHealthKitId(widget.dataWrapper.uuid);
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
          widget.dataWrapper.dateFrom,
          widget.dataWrapper.dateTo,
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
    final workout = _workoutData?.value as WorkoutHealthValue?;
    final totalDistance = workout?.totalDistance ?? _session?.totalDistance; // 미터

    print('🔍 [PACE DEBUG] Starting pace fetch');
    print('🔍 [PACE DEBUG] Total distance: $totalDistance meters');
    print('🔍 [PACE DEBUG] Workout source: ${widget.dataWrapper.sourceName}');
    print('🔍 [PACE DEBUG] Workout dateFrom: ${widget.dataWrapper.dateFrom}');
    print('🔍 [PACE DEBUG] Workout dateTo: ${widget.dataWrapper.dateTo}');

    // 거리 데이터 확인
    if (totalDistance == null || totalDistance == 0) {
      print('❌ [PACE DEBUG] No distance data available');
      if (mounted) {
        setState(() {
          _paceError = '거리 데이터가 없습니다.';
          _isPaceLoading = false;
        });
      }
      return;
    }

    // Use native active duration (excluding pauses) for accurate pace calculation
    // Priority 1: Native HKWorkout duration (most accurate)
    // Priority 2: Fallback to elapsed time (dateTo - dateFrom)
    final workoutDuration = _nativeActiveDuration ??
        widget.dataWrapper.dateTo.difference(widget.dataWrapper.dateFrom);

    print('🔍 [PACE DEBUG] Workout duration: ${workoutDuration.inSeconds} seconds');
    print('🔍 [PACE DEBUG] Using ${_nativeActiveDuration != null ? "native active duration" : "elapsed time (fallback)"}');

    // 평균 페이스 계산 (분/km) - 운동 시간(활동 시간) 기준
    double avgPaceMinPerKm = 0;
    if (workoutDuration.inSeconds > 0 && totalDistance > 0) {
      avgPaceMinPerKm = (workoutDuration.inSeconds / 60) / (totalDistance / 1000);
      print('🔍 [PACE DEBUG] Average pace calculated: $avgPaceMinPerKm min/km');
      print('🔍 [PACE DEBUG] Calculation: (${workoutDuration.inSeconds} / 60) / ($totalDistance / 1000)');
    }

    // DISTANCE_WALKING_RUNNING 샘플 데이터로 페이스 차트 생성
    try {
      final granted = await _healthService.requestAuthorization();
      print('🔍 [PACE DEBUG] Authorization granted: $granted');

      if (granted) {
        // 거리 샘플 데이터로 페이스 계산
        final distanceData = await _healthService.getHealthDataFromTypes(
          widget.dataWrapper.dateFrom,
          widget.dataWrapper.dateTo,
          [HealthDataType.DISTANCE_WALKING_RUNNING],
        );

        print('🔍 [PACE DEBUG] Distance samples loaded: ${distanceData.length}');

        if (distanceData.isNotEmpty) {
          print('🔍 [PACE DEBUG] First sample: ${(distanceData.first.value as NumericHealthValue).numericValue}m at ${distanceData.first.dateFrom}');
          print('🔍 [PACE DEBUG] Last sample: ${(distanceData.last.value as NumericHealthValue).numericValue}m at ${distanceData.last.dateFrom}');

          for (int i = 0; i < distanceData.length && i < 5; i++) {
            final distance = (distanceData[i].value as NumericHealthValue).numericValue;
            print('🔍 [PACE DEBUG] Sample $i: ${distance}m at ${distanceData[i].dateFrom}');
          }
        }

        // 시간 순서대로 정렬 (과거 → 최신)
        distanceData.sort((a, b) => a.dateFrom.compareTo(b.dateFrom));
        print('🔍 [PACE DEBUG] After sorting - First: ${(distanceData.first.value as NumericHealthValue).numericValue}m at ${distanceData.first.dateFrom}');
        print('🔍 [PACE DEBUG] After sorting - Last: ${(distanceData.last.value as NumericHealthValue).numericValue}m at ${distanceData.last.dateFrom}');

        // 거리 샘플에서 페이스 데이터 생성
        final paceDataPoints = _calculatePaceFromDistance(distanceData);
        print('🔍 [PACE DEBUG] Pace points generated: ${paceDataPoints.length}');

        if (mounted) {
          setState(() {
            _paceData = paceDataPoints;
            _avgPace = avgPaceMinPerKm;
            _movingTime = workoutDuration;
            _isPaceLoading = false;
          });
        }

        print('✅ [PACE DEBUG] State updated - paceData: ${paceDataPoints.length}, avgPace: $avgPaceMinPerKm');
      } else {
        print('❌ [PACE DEBUG] Authorization denied');
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
      print('❌ [PACE DEBUG] Error: $e');
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

  /// Fetch native HKWorkout duration data via HealthKit Bridge
  Future<void> _fetchNativeDuration() async {
    try {
      final workoutUuid = widget.dataWrapper.uuid;
      print('🔍 [NATIVE DURATION] Fetching duration for workout UUID: $workoutUuid');

      final details = await _healthKitBridge.getWorkoutDetails(workoutUuid);

      if (details != null) {
        final parsed = _healthKitBridge.parseWorkoutDetails(details);

        if (parsed != null) {
          print('✅ [NATIVE DURATION] Active: ${parsed.activeDuration.inSeconds}s, '
              'Elapsed: ${parsed.elapsedTime.inSeconds}s, '
              'Paused: ${parsed.pausedDuration.inSeconds}s');

          if (mounted) {
            setState(() {
              _nativeActiveDuration = parsed.activeDuration;
              _nativeElapsedTime = parsed.elapsedTime;
              _nativePausedDuration = parsed.pausedDuration;
              _hasNativeDuration = true;
            });
          }
        } else {
          print('⚠️ [NATIVE DURATION] Failed to parse workout details');
        }
      } else {
        print('⚠️ [NATIVE DURATION] No details returned (might be Android or error)');
      }
    } catch (e) {
      print('❌ [NATIVE DURATION] Error: $e');
    }
  }

  /// 거리 샘플 데이터에서 페이스를 계산하여 HealthDataPoint 형식으로 반환
  List<HealthDataPoint> _calculatePaceFromDistance(List<HealthDataPoint> distanceData) {
    print('🔍 [PACE CALC] Starting pace calculation from distance samples');
    print('🔍 [PACE CALC] Input distance samples: ${distanceData.length}');

    if (distanceData.length < 2) {
      print('⚠️ [PACE CALC] Not enough samples (need at least 2, got ${distanceData.length})');
      return [];
    }

    final pacePoints = <HealthDataPoint>[];
    int skippedCount = 0;

    // DISTANCE_WALKING_RUNNING은 구간 거리이므로 누적 거리로 변환
    double cumulativeDistance = 0;
    final cumulativeDistances = <double>[];

    for (var point in distanceData) {
      final distance = (point.value as NumericHealthValue).numericValue.toDouble();
      cumulativeDistance += distance;
      cumulativeDistances.add(cumulativeDistance);
    }

    if (cumulativeDistances.isNotEmpty) {
      print('🔍 [PACE CALC] Cumulative distance - First: ${cumulativeDistances.first}m, Last: ${cumulativeDistances.last}m');
    }

    // 누적 거리 데이터를 인접한 샘플 간 속도로 변환
    for (int i = 1; i < distanceData.length; i++) {
      final prevPoint = distanceData[i - 1];
      final currPoint = distanceData[i];

      final prevDistance = cumulativeDistances[i - 1];
      final currDistance = cumulativeDistances[i];
      final distanceDiff = currDistance - prevDistance;
      final timeDiff = currPoint.dateFrom.difference(prevPoint.dateFrom).inSeconds;

      if (i <= 3) {
        print('🔍 [PACE CALC] Sample $i: prev=${prevDistance}m, curr=${currDistance}m, diff=${distanceDiff}m, time=${timeDiff}s');
      }

      if (timeDiff > 0 && distanceDiff > 0) {
        // 속도 (m/s) 계산
        final speedMs = distanceDiff / timeDiff;
        final paceMinPerKm = 1000 / (speedMs * 60);

        if (i <= 3) {
          print('🔍 [PACE CALC] Calculated: speed=${speedMs}m/s, pace=${paceMinPerKm}min/km');
        }

        // HealthDataPoint 형식으로 변환 (RUNNING_SPEED와 동일한 형식)
        pacePoints.add(
          HealthDataPoint(
            uuid: '${currPoint.uuid}_pace',
            value: NumericHealthValue(numericValue: speedMs),
            type: HealthDataType.RUNNING_SPEED,
            unit: HealthDataUnit.METER_PER_SECOND,
            dateFrom: currPoint.dateFrom,
            dateTo: currPoint.dateTo,
            sourcePlatform: currPoint.sourcePlatform,
            sourceDeviceId: currPoint.sourceDeviceId,
            sourceId: currPoint.sourceId,
            sourceName: currPoint.sourceName,
          ),
        );
      } else {
        skippedCount++;
        if (i <= 3) {
          print('⚠️ [PACE CALC] Skipped sample $i (invalid: timeDiff=$timeDiff, distanceDiff=$distanceDiff)');
        }
      }
    }

    print('✅ [PACE CALC] Generated ${pacePoints.length} pace points (skipped $skippedCount)');
    return pacePoints;
  }

  void _showTemplateSelectionDialog(BuildContext context) {
    final workout = _workoutData?.value as WorkoutHealthValue?;
    final type = workout?.workoutActivityType.name ?? _session?.category ?? 'Unknown';
    final category = _getWorkoutCategory(type);
    
    // 해당 카테고리의 템플릿만 로드 (없으면 전체 로드)
    final templates = TemplateService.getTemplatesByCategory(category);
    if (templates.isEmpty) {
      templates.addAll(TemplateService.getAllTemplates());
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
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
                  child: Text(
                    '템플릿 설정',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
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
                          // 템플릿 연결
                          await WorkoutHistoryService().linkTemplateToWorkout(
                            healthKitId: widget.dataWrapper.uuid,
                            template: template,
                            startTime: widget.dataWrapper.dateFrom,
                            endTime: widget.dataWrapper.dateTo,
                            totalDistance: (workout?.totalDistance ?? _session?.totalDistance ?? 0).toDouble(),
                            calories: (workout?.totalEnergyBurned ?? _session?.calories ?? 0).toDouble(),
                          );
                          
                          if (mounted) {
                            Navigator.pop(context);
                            _fetchLinkedSession(); // 세션 정보 새로고침
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('${template.name} 템플릿으로 설정되었습니다.')),
                            );
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
    final workout = _workoutData?.value as WorkoutHealthValue?;
    final workoutType = workout?.workoutActivityType.name ?? _session?.category ?? 'Unknown';
    // 세션에 저장된 카테고리가 있다면 이를 최우선으로 사용
    final workoutCategory = _session?.category ?? _getWorkoutCategory(workoutType);
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
          IconButton(
            icon: const Icon(Icons.share),
            onPressed: _handleShareWorkout,
          ),
        ],
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
                          color: color.withValues(alpha: 0.2),
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
                      const SizedBox(height: 16),
                      // 템플릿 설정/표시 버튼
                      InkWell(
                        onTap: () => _showTemplateSelectionDialog(context),
                        borderRadius: BorderRadius.circular(20),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            border: Border.all(
                              color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.5),
                            ),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.bookmark_border,
                                size: 18,
                                color: _session != null ? color : Colors.grey,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                _session != null 
                                  ? _session!.templateName 
                                  : '템플릿 설정하기',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: _session != null ? FontWeight.bold : FontWeight.normal,
                                  color: _session != null ? color : Colors.grey,
                                ),
                              ),
                              const SizedBox(width: 4),
                              Icon(
                                Icons.arrow_drop_down,
                                size: 20,
                                color: _session != null ? color : Colors.grey,
                              ),
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
            // 운동 경로 지도 (세션 데이터가 있고 경로가 있는 경우)
            if (_session?.routePoints != null && _session!.routePoints!.isNotEmpty) ...[
              _buildRouteMap(context, _session!.routePoints!),
              const SizedBox(height: 16),
            ],
            // 운동 데이터
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (workoutCategory == 'Strength' && _session != null) ...[
                      _buildStrengthSummary(_session!),
                      const Divider(height: 32),
                    ],
                    const Text(
                      '운동 데이터',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    ..._buildTimeSection(),
                    const Divider(height: 24),
                    _buildInfoRow(
                      Icons.access_time,
                      '날짜 및 시간',
                      '${DateFormat('yyyy년 MM월 dd일').format(widget.dataWrapper.dateFrom)}\n${DateFormat('HH:mm').format(widget.dataWrapper.dateFrom)} ~ ${DateFormat('HH:mm').format(widget.dataWrapper.dateTo)}',
                    ),
                    if (workout?.totalDistance != null || _session?.totalDistance != null) ...[
                      const Divider(height: 24),
                      _buildInfoRow(
                        Icons.straighten,
                        '총 거리',
                        '${(((workout?.totalDistance ?? _session?.totalDistance) ?? 0) / 1000).toStringAsFixed(2)} km',
                      ),
                    ],
                    if (workout?.totalEnergyBurned != null || _session?.calories != null) ...[
                      const Divider(height: 24),
                      _buildInfoRow(
                        Icons.local_fire_department,
                        '소모 칼로리',
                        '${((workout?.totalEnergyBurned ?? _session?.calories) ?? 0).toStringAsFixed(0)} kcal',
                      ),
                    ],
                    if (_session?.totalVolume != null) ...[
                      const Divider(height: 24),
                      _buildInfoRow(
                        Icons.fitness_center,
                        '총 볼륨',
                        _session!.totalVolume! >= 1000 
                          ? '${(_session!.totalVolume! / 1000).toStringAsFixed(2)} t' 
                          : '${_session!.totalVolume!.toStringAsFixed(0)} kg',
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
                      SizedBox(height: 200, child: _buildPaceSection()),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],
            // 상세 운동 기록 (Strength 전용)
            if (_session?.exerciseRecords != null && _session!.exerciseRecords!.isNotEmpty) ...[
              _buildStrengthRecordsSection(),
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
                      widget.dataWrapper.sourceName,
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

  Widget _buildStrengthRecordsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 4.0, vertical: 8.0),
          child: Text(
            '운동 기록 상세',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
        ),
        ..._session!.exerciseRecords!.map((record) {
          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            child: ExpansionTile(
              initiallyExpanded: true,
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: SvgPicture.asset(
                  'assets/images/strength/lifter-icon.svg',
                  width: 24, height: 24,
                  colorFilter: ColorFilter.mode(Theme.of(context).colorScheme.primary, BlendMode.srcIn),
                ),
              ),
              title: Text(record.exerciseName, style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text(
                '${record.sets.length} 세트 | 총 ${record.totalVolume >= 1000 ? (record.totalVolume / 1000).toStringAsFixed(2) + " t" : record.totalVolume.toStringAsFixed(0) + " kg"}',
                style: const TextStyle(fontSize: 12, color: Colors.grey)
              ),
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                  child: Column(
                    children: [
                      const Divider(),
                      const Row(
                        children: [
                          SizedBox(width: 40, child: Text('SET', style: TextStyle(fontSize: 11, color: Colors.grey))),
                          Expanded(child: Text('무게', textAlign: TextAlign.center, style: TextStyle(fontSize: 11, color: Colors.grey))),
                          Expanded(child: Text('횟수', textAlign: TextAlign.center, style: TextStyle(fontSize: 11, color: Colors.grey))),
                        ],
                      ),
                      const SizedBox(height: 8),
                      ...record.sets.asMap().entries.map((entry) {
                        final idx = entry.key;
                        final set = entry.value;
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4.0),
                          child: Row(
                            children: [
                              SizedBox(width: 40, child: Text('${idx + 1}', textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.bold))),
                              Expanded(child: Text('${set.weight?.toStringAsFixed(1).replaceAll(RegExp(r'\.0$'), '') ?? 0} kg', textAlign: TextAlign.center)),
                              Expanded(child: Text('${set.repsCompleted ?? set.repsTarget ?? 0} 회', textAlign: TextAlign.center)),
                            ],
                          ),
                        );
                      }),
                    ],
                  ),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  Widget _buildRouteMap(BuildContext context, List<RoutePoint> routePoints) {
    final List<LatLng> points = routePoints.map((p) => LatLng(p.latitude, p.longitude)).toList();
    
    LatLngBounds bounds;
    if (points.length > 1) {
      double minLat = points.first.latitude;
      double maxLat = points.first.latitude;
      double minLng = points.first.longitude;
      double maxLng = points.first.longitude;

      for (var p in points) {
        if (p.latitude < minLat) minLat = p.latitude;
        if (p.latitude > maxLat) maxLat = p.latitude;
        if (p.longitude < minLng) minLng = p.longitude;
        if (p.longitude > maxLng) maxLng = p.longitude;
      }
      bounds = LatLngBounds(
        southwest: LatLng(minLat, minLng),
        northeast: LatLng(maxLat, maxLng),
      );
    } else {
      bounds = LatLngBounds(southwest: points.first, northeast: points.first);
    }

    return Card(
      child: Container(
        height: 250,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
        ),
        clipBehavior: Clip.antiAlias,
        child: GoogleMap(
          initialCameraPosition: CameraPosition(target: points.first, zoom: 15),
          polylines: {
            Polyline(
              polylineId: const PolylineId('detail_route'),
              points: points,
              color: Theme.of(context).colorScheme.secondary,
              width: 4,
              jointType: JointType.round,
            ),
          },
          myLocationEnabled: false,
          zoomControlsEnabled: false,
          mapToolbarEnabled: false,
          onMapCreated: (controller) {
            if (points.length > 1) {
              Future.delayed(const Duration(milliseconds: 500), () {
                controller.animateCamera(CameraUpdate.newLatLngBounds(bounds, 40));
              });
            }
          },
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
    final workoutStartTime = widget.dataWrapper.dateFrom;
    final workout = _workoutData?.value as WorkoutHealthValue?;
    final workoutType = workout?.workoutActivityType.name ?? _session?.category ?? 'Unknown';
    final workoutCategory = _session?.category ?? _getWorkoutCategory(workoutType);
    final color = _getWorkoutColor(context, workoutCategory);

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
    final workoutEndTime = widget.dataWrapper.dateTo;
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
            // 운동 종료 시점 표시 (일시정지가 있는 경우)
            if (_hasNativeDuration &&
                _nativeActiveDuration != null &&
                _nativePausedDuration != null &&
                _nativePausedDuration! > Duration.zero)
              VerticalLine(
                x: _nativeActiveDuration!.inSeconds.toDouble(),
                color: Colors.orange.withValues(alpha: 0.8),
                strokeWidth: 2,
                dashArray: [8, 4],
                label: VerticalLineLabel(
                  show: true,
                  alignment: Alignment.topRight,
                  padding: const EdgeInsets.only(right: 4, bottom: 4),
                  style: const TextStyle(
                    color: Colors.orange,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                  labelResolver: (line) => '운동 종료',
                ),
              ),
            // 차트 인터랙션 동기화: 터치된 지점 표시
            if (_touchedTimestamp != null)
              VerticalLine(
                x: _touchedTimestamp!,
                color: Colors.red.withValues(alpha: 0.7),
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

                // 운동 종료 수직바 이전인지 확인 (활동 시간 내)
                final isWithinActiveTime = _nativeActiveDuration == null ||
                    spot.x <= _nativeActiveDuration!.inSeconds.toDouble();

                // 활동 시간 내에서만 페이스 정보 표시
                String paceText = '';
                if (isWithinActiveTime) {
                  final paceInfo = _getPaceAtTimestamp(spot.x);
                  paceText = paceInfo != null ? '\n$paceInfo' : '';
                }

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
            color: color, // Use dynamic category color
            barWidth: 3,
            isStrokeCapRound: true,
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(
              show: true,
              color: color.withValues(alpha: 0.2),
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

    // 상세 페이스 데이터가 있으면 차트 표시
    if (_paceData.isNotEmpty) {
      return _buildPaceChart();
    }

    // 상세 데이터는 없지만 평균 페이스는 있는 경우
    if (_avgPace > 0) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.speed,
              size: 40,
              color: Theme.of(context).colorScheme.secondary.withValues(alpha: 0.6),
            ),
            const SizedBox(height: 8),
            Text(
              '평균 페이스',
              style: TextStyle(
                fontSize: 13,
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              _formatPace(_avgPace),
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.secondary,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              '상세 페이스 차트는 PaceLifter로\n기록한 운동에서 표시됩니다',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 11,
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
              ),
            ),
          ],
        ),
      );
    }

    // 페이스 데이터가 전혀 없는 경우
    return const Center(child: Text('페이스 데이터가 없습니다.'));
  }

  Widget _buildPaceChart() {
    final workout = _workoutData?.value as WorkoutHealthValue?;
    final workoutType = workout?.workoutActivityType.name ?? _session?.category ?? 'Unknown';
    final workoutCategory = _session?.category ?? _getWorkoutCategory(workoutType);
    final color = _getWorkoutColor(context, workoutCategory);

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

    // 3. 활동 시간 계산 (X축 범위 결정)
    final workoutStartTime = widget.dataWrapper.dateFrom;
    final activeDurationSeconds = _nativeActiveDuration?.inSeconds.toDouble() ??
        widget.dataWrapper.dateTo.difference(workoutStartTime).inSeconds.toDouble();
    final maxXSeconds = activeDurationSeconds == 0 ? 1.0 : activeDurationSeconds;

    // 4. 스무딩된 데이터를 FlSpot으로 변환 (활동 시간 내의 데이터만 포함)
    final spots = <FlSpot>[];

    for (int i = 0; i < smoothedPaces.length; i++) {
      // 원본 데이터의 타임스탬프를 사용
      final originalDataPoint = _paceData[i];
      final elapsedSeconds = originalDataPoint.dateFrom
          .difference(workoutStartTime)
          .inSeconds
          .toDouble();

      // 활동 시간 범위 내의 데이터만 포함 (일시정지 구간 제외)
      if (elapsedSeconds <= maxXSeconds) {
        // Y축 반전을 위해 음수 값 사용
        spots.add(FlSpot(elapsedSeconds, -smoothedPaces[i]));
      }
    }

    if (spots.isEmpty) {
      return const Center(child: Text('유효한 페이스 데이터가 없습니다.'));
    }

    // Y축 범위 계산
    final minPace = spots.map((e) => e.y).reduce(min);
    final maxPace = spots.map((e) => e.y).reduce(max);

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
            // 페이스 차트는 활동 시간만 표시하므로 운동 종료 수직선 불필요
            // 차트 인터랙션 동기화: 터치된 지점 표시
            if (_touchedTimestamp != null && _touchedTimestamp! <= maxXSeconds)
              VerticalLine(
                x: _touchedTimestamp!,
                color: Colors.red.withValues(alpha: 0.7),
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
            color: color, // Use dynamic category color (Deep Teal for Endurance)
            barWidth: 3,
            isStrokeCapRound: true,
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(
              show: true,
              color: color.withValues(alpha: 0.2),
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

    final workoutStartTime = widget.dataWrapper.dateFrom;

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

    final workoutStartTime = widget.dataWrapper.dateFrom;

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

  /// 운동 공유 처리
  Future<void> _handleShareWorkout() async {
    if (_workoutData == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('건강 데이터가 없는 운동은 공유할 수 없습니다.')),
      );
      return;
    }

    // 운동 공유 화면으로 이동
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => WorkoutShareScreen(
          workoutData: _workoutData!,
          heartRateData: _heartRateData,
          avgHeartRate: _avgHeartRate,
          paceData: _paceData,
          avgPace: _avgPace,
          movingTime: _movingTime,
          templateName: _session?.templateName, // 템플릿 이름 전달
          environmentType: _session?.environmentType, // 환경 타입 전달
        ),
      ),
    );
  }

  Widget _buildStrengthSummary(WorkoutSession session) {
    final vol = session.totalVolume ?? 0;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: [
        _buildSummaryStat('총 볼륨', vol >= 1000 ? '${(vol / 1000).toStringAsFixed(2)}t' : '${vol.toInt()}kg'),
        _buildSummaryStat('총 세트', '${session.totalSets ?? 0}회'),
        _buildSummaryStat('총 횟수', '${session.totalReps ?? 0}회'),
      ],
    );
  }

  Widget _buildSummaryStat(String label, String value) {
    return Column(
      children: [
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
        const SizedBox(height: 4),
        Text(value, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.primary)),
      ],
    );
  }

  List<Widget> _buildTimeSection() {
    Duration activeDuration;
    Duration? elapsedTime;
    Duration? pausedDuration;

    // Priority 1: Use native HKWorkout duration (most accurate)
    if (_hasNativeDuration && _nativeActiveDuration != null) {
      activeDuration = _nativeActiveDuration!;
      elapsedTime = _nativeElapsedTime;
      pausedDuration = _nativePausedDuration;
      print('ℹ️ [TIME SECTION] Using native HKWorkout duration');
    } else {
      // Priority 2: Try PaceLifter metadata
      activeDuration = _movingTime ??
          widget.dataWrapper.dateTo.difference(widget.dataWrapper.dateFrom);

      try {
        final metadata = _workoutData?.metadata;
        if (metadata != null && metadata.containsKey('PaceLifter_PausedDuration')) {
          final pausedSeconds = metadata['PaceLifter_PausedDuration'];
          if (pausedSeconds is int) {
            pausedDuration = Duration(seconds: pausedSeconds);
            elapsedTime = activeDuration + pausedDuration;
            print('ℹ️ [TIME SECTION] Using PaceLifter metadata for pause duration');
          } else if (pausedSeconds is double) {
            pausedDuration = Duration(seconds: pausedSeconds.toInt());
            elapsedTime = activeDuration + pausedDuration;
            print('ℹ️ [TIME SECTION] Using PaceLifter metadata for pause duration');
          }
        }
      } catch (e) {
        print('⚠️ [TIME SECTION] Could not extract pause duration from metadata: $e');
      }
    }

    final List<Widget> timeWidgets = [];

    // Always show active time (운동 시간)
    timeWidgets.add(
      _buildInfoRow(
        Icons.play_circle_outline,
        '운동 시간',
        _formatDuration(activeDuration),
      ),
    );

    return timeWidgets;
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
        return Theme.of(context).colorScheme.primary; // Orange
      case 'Endurance':
        return Theme.of(context).colorScheme.tertiary; // Deep Teal
      case 'Hybrid':
        return Theme.of(context).colorScheme.secondary; // Neon Green
      default:
        return Theme.of(context).colorScheme.secondary;
    }
  }

  String _getWorkoutIconPath(String type) {
    final upperType = type.toUpperCase();
    if (upperType.contains('CORE') || upperType.contains('FUNCTIONAL')) {
      return 'assets/images/strength/core-icon.svg';
    } else if (upperType.contains('STRENGTH') ||
        upperType.contains('WEIGHT') ||
        upperType.contains('TRADITIONAL_STRENGTH_TRAINING')) {
      return 'assets/images/strength/lifter-icon.svg';
    } else {
      return 'assets/images/endurance/runner-icon.svg';
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
