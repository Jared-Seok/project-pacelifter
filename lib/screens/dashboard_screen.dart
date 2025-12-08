import 'package:flutter/material.dart';
import 'package:health/health.dart';
import 'package:pacelifter/services/health_service.dart';
import 'package:pacelifter/services/auth_service.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:google_fonts/google_fonts.dart';

/// 재설계된 대시보드 화면
///
/// Strength/Endurance 비율, 운동 피드를 표시합니다.
class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

enum TimePeriod { week, month, year }

class _DashboardScreenState extends State<DashboardScreen> {
  final HealthService _healthService = HealthService();
  final AuthService _authService = AuthService();
  List<HealthDataPoint> _workoutData = [];
  bool _isLoading = false;
  TimePeriod _selectedPeriod = TimePeriod.week;

  // 통계 데이터
  double _strengthPercentage = 0.0;
  double _endurancePercentage = 0.0;
  int _totalWorkouts = 0;

  @override
  void initState() {
    super.initState();
    _checkFirstLoginAndSync();
  }

  /// 첫 로그인 확인 및 동기화 팝업 표시
  Future<void> _checkFirstLoginAndSync() async {
    final isFirstLogin = await _authService.isFirstLogin();
    final isSyncCompleted = await _authService.isHealthSyncCompleted();

    if (isFirstLogin && !isSyncCompleted && mounted) {
      await Future.delayed(const Duration(milliseconds: 500));
      if (mounted) {
        _showHealthSyncDialog();
      }
    } else if (isSyncCompleted) {
      _loadHealthData();
    }
  }

  /// 헬스 데이터 동기화 다이얼로그 표시
  void _showHealthSyncDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(
              Icons.health_and_safety,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(width: 12),
            const Text('운동 데이터 동기화'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'PaceLifter와 건강 앱을 연동하여\n운동 데이터를 동기화하시겠습니까?',
              style: TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.check_circle_outline,
                        size: 20,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      const SizedBox(width: 8),
                      const Text('운동 기록 자동 분석'),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(
                        Icons.check_circle_outline,
                        size: 20,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      const SizedBox(width: 8),
                      const Text('Strength/Endurance 비율 추적'),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(
                        Icons.check_circle_outline,
                        size: 20,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      const SizedBox(width: 8),
                      const Text('개인화된 훈련 인사이트'),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () async {
              Navigator.of(context).pop();
              await _authService.clearFirstLoginFlag();
              await _authService.setHealthSyncCompleted(false);
            },
            child: const Text('나중에'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.of(context).pop();
              await _authService.clearFirstLoginFlag();
              _syncHealthData();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.secondary,
              foregroundColor: Theme.of(context).colorScheme.onSecondary,
            ),
            child: const Text('동기화 시작'),
          ),
        ],
      ),
    );
  }

  /// 헬스 데이터 동기화
  Future<void> _syncHealthData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final granted = await _healthService.requestAuthorization();
      if (granted) {
        final workoutData = await _healthService.fetchWorkoutData();
        await _authService.setHealthSyncCompleted(true);

        setState(() {
          _workoutData = workoutData;
          _calculateStatistics();
          _isLoading = false;
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${workoutData.length}개의 운동 기록을 동기화했습니다!'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  /// 헬스 데이터 로드
  Future<void> _loadHealthData() async {
    setState(() {
      _isLoading = true;
    });

    final workoutData = await _healthService.fetchWorkoutData();

    setState(() {
      _workoutData = workoutData;
      _calculateStatistics();
      _isLoading = false;
    });
  }

  /// 통계 계산
  void _calculateStatistics() {
    // 선택된 기간에 따라 데이터 필터링
    final now = DateTime.now();
    DateTime startDate;

    switch (_selectedPeriod) {
      case TimePeriod.week:
        startDate = now.subtract(const Duration(days: 7));
        break;
      case TimePeriod.month:
        startDate = now.subtract(const Duration(days: 30));
        break;
      case TimePeriod.year:
        startDate = now.subtract(const Duration(days: 365));
        break;
    }

    final filteredData = _workoutData.where((data) {
      return data.dateFrom.isAfter(startDate);
    }).toList();

    _totalWorkouts = filteredData.length;

    // Strength vs Endurance 분류 (간단한 로직)
    int strengthCount = 0;
    int enduranceCount = 0;

    for (var data in filteredData) {
      if (data.value is WorkoutHealthValue) {
        final workout = data.value as WorkoutHealthValue;
        final type = workout.workoutActivityType.name.toUpperCase();

        // Strength: 웨이트 트레이닝, 근력 운동 등
        if (type.contains('STRENGTH') ||
            type.contains('WEIGHT') ||
            type.contains('FUNCTIONAL')) {
          strengthCount++;
        }
        // Endurance: 러닝, 사이클링, 수영 등
        else if (type.contains('RUNNING') ||
            type.contains('CYCLING') ||
            type.contains('SWIMMING') ||
            type.contains('WALKING') ||
            type.contains('HIKING')) {
          enduranceCount++;
        } else {
          // 기타 운동은 endurance로 분류
          enduranceCount++;
        }
      }
    }

    final total = strengthCount + enduranceCount;
    if (total > 0) {
      _strengthPercentage = (strengthCount / total) * 100;
      _endurancePercentage = (enduranceCount / total) * 100;
    } else {
      _strengthPercentage = 50.0;
      _endurancePercentage = 50.0;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: SafeArea(
        child: _isLoading
            ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(height: 16),
                    const Text('운동 데이터를 동기화하는 중...'),
                  ],
                ),
              )
            : RefreshIndicator(
                onRefresh: _loadHealthData,
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 커스텀 헤더
                      _buildHeader(),

                      // 운동 요약 섹션
                      _buildWorkoutSummarySection(),

                      const SizedBox(height: 24),

                      // 운동 피드
                      _buildWorkoutFeed(),
                    ],
                  ),
                ),
              ),
      ),
    );
  }

  /// 커스텀 헤더
  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'PaceLifter',
            style: GoogleFonts.anton(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.secondary,
            ),
          ),
          IconButton(
            icon: const Icon(Icons.sync),
            onPressed: _isLoading ? null : _syncHealthData,
            tooltip: '동기화',
          ),
        ],
      ),
    );
  }

  /// 운동 요약 섹션
  Widget _buildWorkoutSummarySection() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 타이틀과 기간 선택 버튼
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    '최근 운동 요약',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  _buildPeriodSelector(),
                ],
              ),
              const SizedBox(height: 24),

              // Strength/Endurance 비율 표시
              Row(
                children: [
                  // Strength (좌측)
                  Expanded(
                    child: Column(
                      children: [
                        Icon(
                          Icons.fitness_center,
                          size: 40,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Strength',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${_strengthPercentage.toStringAsFixed(1)}%',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // 원형 차트 (중앙)
                  SizedBox(
                    width: 120,
                    height: 120,
                    child: _buildPieChart(),
                  ),

                  // Endurance (우측)
                  Expanded(
                    child: Column(
                      children: [
                        Icon(
                          Icons.directions_run,
                          size: 40,
                          color: Theme.of(context).colorScheme.secondary,
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Endurance',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${_endurancePercentage.toStringAsFixed(1)}%',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).colorScheme.secondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // 총 운동 횟수
              Center(
                child: Text(
                  '총 $_totalWorkouts회 운동',
                  style: TextStyle(
                    fontSize: 14,
                    color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 기간 선택 버튼
  Widget _buildPeriodSelector() {
    return SegmentedButton<TimePeriod>(
      segments: const [
        ButtonSegment(
          value: TimePeriod.week,
          label: Text('주', style: TextStyle(fontSize: 12)),
        ),
        ButtonSegment(
          value: TimePeriod.month,
          label: Text('월', style: TextStyle(fontSize: 12)),
        ),
        ButtonSegment(
          value: TimePeriod.year,
          label: Text('연', style: TextStyle(fontSize: 12)),
        ),
      ],
      selected: {_selectedPeriod},
      onSelectionChanged: (Set<TimePeriod> newSelection) {
        setState(() {
          _selectedPeriod = newSelection.first;
          _calculateStatistics();
        });
      },
      style: ButtonStyle(
        visualDensity: VisualDensity.compact,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
    );
  }

  /// 원형 차트
  Widget _buildPieChart() {
    return PieChart(
      PieChartData(
        sectionsSpace: 2,
        centerSpaceRadius: 35,
        sections: [
          PieChartSectionData(
            value: _strengthPercentage,
            color: Theme.of(context).colorScheme.primary,
            radius: 20,
            showTitle: false,
          ),
          PieChartSectionData(
            value: _endurancePercentage,
            color: Theme.of(context).colorScheme.secondary,
            radius: 20,
            showTitle: false,
          ),
        ],
      ),
    );
  }

  /// 운동 피드
  Widget _buildWorkoutFeed() {
    // 최근 운동 데이터 (최대 20개)
    final recentWorkouts = _workoutData.take(20).toList();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '운동 피드',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          recentWorkouts.isEmpty
              ? Card(
                  child: Padding(
                    padding: const EdgeInsets.all(32.0),
                    child: Center(
                      child: Column(
                        children: [
                          Icon(
                            Icons.info_outline,
                            size: 48,
                            color: Theme.of(context)
                                .colorScheme
                                .onSurface
                                .withOpacity(0.5),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            '운동 기록이 없습니다',
                            style: TextStyle(
                              fontSize: 16,
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurface
                                  .withOpacity(0.7),
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            '헬스 앱과 동기화하여 운동 기록을 가져오세요',
                            style: TextStyle(fontSize: 12),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  ),
                )
              : Column(
                  children: recentWorkouts.map((data) {
                    final workout = data.value as WorkoutHealthValue;
                    final distance = workout.totalDistance ?? 0.0;
                    final type = workout.workoutActivityType.name;
                    final isStrength = _isStrengthWorkout(type);

                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: ListTile(
                        leading: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: isStrength
                                ? Theme.of(context)
                                    .colorScheme
                                    .primary
                                    .withOpacity(0.2)
                                : Theme.of(context)
                                    .colorScheme
                                    .secondary
                                    .withOpacity(0.2),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            _getWorkoutIcon(type),
                            color: isStrength
                                ? Theme.of(context).colorScheme.primary
                                : Theme.of(context).colorScheme.secondary,
                          ),
                        ),
                        title: Text(
                          type,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text(
                          DateFormat('yyyy-MM-dd HH:mm').format(data.dateFrom),
                        ),
                        trailing: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            if (distance > 0)
                              Text(
                                '${(distance / 1000).toStringAsFixed(2)} km',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                            Text(
                              isStrength ? 'Strength' : 'Endurance',
                              style: TextStyle(
                                fontSize: 12,
                                color: isStrength
                                    ? Theme.of(context).colorScheme.primary
                                    : Theme.of(context).colorScheme.secondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
          const SizedBox(height: 80),
        ],
      ),
    );
  }

  /// 운동 타입이 Strength인지 판단
  bool _isStrengthWorkout(String type) {
    final upperType = type.toUpperCase();
    return upperType.contains('STRENGTH') ||
        upperType.contains('WEIGHT') ||
        upperType.contains('FUNCTIONAL');
  }

  /// 운동 유형에 따른 아이콘 반환
  IconData _getWorkoutIcon(String type) {
    final upperType = type.toUpperCase();
    if (upperType.contains('RUNNING')) return Icons.directions_run;
    if (upperType.contains('WALKING')) return Icons.directions_walk;
    if (upperType.contains('CYCLING')) return Icons.directions_bike;
    if (upperType.contains('SWIMMING')) return Icons.pool;
    if (upperType.contains('HIKING')) return Icons.terrain;
    if (upperType.contains('STRENGTH') || upperType.contains('WEIGHT')) {
      return Icons.fitness_center;
    }
    return Icons.sports;
  }
}
