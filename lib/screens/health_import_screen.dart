import 'package:flutter/material.dart';
import 'package:health/health.dart';
import '../services/health_service.dart';
import '../services/workout_history_service.dart';
import '../models/sessions/workout_session.dart';
import '../models/health_workout.dart';
import 'package:uuid/uuid.dart';

class HealthImportScreen extends StatefulWidget {
  const HealthImportScreen({super.key});

  @override
  State<HealthImportScreen> createState() => _HealthImportScreenState();
}

enum AppState {
  initial,
  fetchingData,
  dataReady,
  error,
}

class _HealthImportScreenState extends State<HealthImportScreen> {
  final HealthService _healthService = HealthService();
  AppState _state = AppState.initial;
  List<HealthWorkout> _workouts = [];
  Map<String, dynamic>? _statistics;
  String? _errorMessage;

  Future<void> _fetchData() async {
    setState(() {
      _state = AppState.fetchingData;
      _errorMessage = null;
    });

    try {
      // 건강 데이터 접근 권한 요청
      final bool granted = await _healthService.requestAuthorization();

      if (granted) {
        // 운동 데이터 가져오기
        final healthData = await _healthService.fetchWorkoutData();
        
        // HealthDataPoint를 HealthWorkout 모델로 변환
        final workouts = healthData.map<HealthWorkout>((e) {
          final workoutData = e.value is WorkoutHealthValue ? e.value as WorkoutHealthValue : null;
          final totalDistance = workoutData?.totalDistance?.toDouble();
          final totalEnergyBurned = workoutData?.totalEnergyBurned?.toDouble();
          
          String workoutType = workoutData?.workoutActivityType.name ?? 'Unknown';
          
          // Apple HealthKit의 실내/실외 메타데이터 확인하여 보정
          if (workoutType.contains('RUNNING')) {
            final isIndoor = e.metadata?['HKMetadataKeyIndoorWorkout'] == 1 || 
                             e.metadata?['HKIndoorWorkout'] == true;
            if (isIndoor) {
              workoutType = 'RUNNING_TREADMILL';
            }
          }

          return HealthWorkout(
            workoutType: workoutType,
            startDate: e.dateFrom,
            endDate: e.dateTo,
            distance: totalDistance,
            totalEnergyBurned: totalEnergyBurned,
            sourceName: e.sourceName,
            metadata: e.metadata ?? {},
          );
        }).toList();

        // 통계 계산
        _calculateStatistics(workouts);

        // ----------------------------------------------------
        // [추가] Hive DB에 영구 저장 로직
        // ----------------------------------------------------
        final historyService = WorkoutHistoryService();
        for (var workout in workouts) {
          final session = WorkoutSession(
            id: const Uuid().v4(),
            templateId: 'health_kit_import',
            category: workout.workoutType.contains('RUNNING') 
                ? 'Endurance' 
                : (workout.workoutType.contains('STRENGTH') ? 'Strength' : 'Other'),
            templateName: workout.workoutType,
            startTime: workout.startDate,
            endTime: workout.endDate,
            activeDuration: workout.duration.inSeconds,
            totalDuration: workout.duration.inSeconds,
            totalDistance: workout.distance ?? 0,
            calories: workout.totalEnergyBurned ?? 0,
            exerciseRecords: [],
            healthKitWorkoutId: workout.metadata['HKWorkoutUUID'], // 중복 방지용 ID 저장
          );
          await historyService.saveSession(session);
        }
        // ----------------------------------------------------

        setState(() {
          _workouts = workouts;
          _state = AppState.dataReady;
        });
      } else {
        throw Exception('건강 데이터 접근 권한이 거부되었습니다.');
      }
    } catch (e) {
      setState(() {
        _errorMessage = '데이터 가져오기 오류: $e';
        _state = AppState.error;
      });
    }
  }

  void _calculateStatistics(List<HealthWorkout> workouts) {
    if (workouts.isEmpty) {
      _statistics = null;
      return;
    }

    double totalDistance = 0;
    int totalDurationMinutes = 0;
    final Map<String, Map<String, dynamic>> byType = {};

    for (var workout in workouts) {
      if (workout.distance != null) {
        totalDistance += workout.distance!;
      }
      totalDurationMinutes += workout.duration.inMinutes;

      final type = workout.workoutType;
      byType.putIfAbsent(type, () => {'count': 0, 'totalDistance': 0.0});
      byType[type]!['count'] += 1;
      if (workout.distance != null) {
        byType[type]!['totalDistance'] += workout.distance!;
      }
    }

    _statistics = {
      'totalWorkouts': workouts.length,
      'totalDistance': totalDistance / 1000, // km로 변환
      'totalDuration': totalDurationMinutes,
      'byType': byType,
    };
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('건강 데이터 연동'),
        backgroundColor: Theme.of(context).colorScheme.secondary,
        foregroundColor: Theme.of(context).colorScheme.onSecondary,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildInstructions(),
            const SizedBox(height: 24),
            _buildSyncButton(),
            const SizedBox(height: 16),
            if (_state == AppState.error) _buildErrorMessage(),
            if (_state == AppState.fetchingData) _buildLoadingIndicator(),
            if (_state == AppState.dataReady && _statistics != null) ...[
              _buildStatistics(),
              const SizedBox(height: 16),
              _buildWorkoutsList(),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildInstructions() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.info_outline, color: Theme.of(context).colorScheme.secondary),
                const SizedBox(width: 8),
                const Text(
                  'Apple Health 데이터 연동하기',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Text(
              '아래 버튼을 눌러 iPhone의 건강 앱에 저장된 운동 데이터를 직접 가져와 분석합니다.',
              style: TextStyle(fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSyncButton() {
    return ElevatedButton.icon(
      onPressed: _state == AppState.fetchingData ? null : _fetchData,
      icon: const Icon(Icons.sync),
      label: const Text('건강 앱 데이터 동기화'),
      style: ElevatedButton.styleFrom(
        backgroundColor: Theme.of(context).colorScheme.secondary,
        foregroundColor: Theme.of(context).colorScheme.onSecondary,
        padding: const EdgeInsets.all(16),
        textStyle: const TextStyle(fontSize: 16),
      ),
    );
  }

  Widget _buildErrorMessage() {
    return Card(
      color: Colors.red[50],
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.red),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                _errorMessage!,
                style: const TextStyle(color: Colors.red),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingIndicator() {
    return const Card(
      child: Padding(
        padding: EdgeInsets.all(32.0),
        child: Column(
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('건강 앱에서 데이터를 가져오는 중...'),
          ],
        ),
      ),
    );
  }

  Widget _buildStatistics() {
    final stats = _statistics!;
    final totalWorkouts = stats['totalWorkouts'] as int;
    final totalDistance = stats['totalDistance'] as double;
    final totalDuration = stats['totalDuration'] as int;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '운동 통계',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            _buildStatItem(Icons.fitness_center, '총 운동 횟수', '$totalWorkouts회'),
            _buildStatItem(Icons.directions_run, '총 거리', '${totalDistance.toStringAsFixed(1)} km'),
            _buildStatItem(Icons.timer, '총 운동 시간', '${(totalDuration ~/ 60)} 시간 ${totalDuration % 60} 분'),
            const Divider(height: 24),
            const Text('운동 유형별', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            ...((stats['byType'] as Map<String, dynamic>).entries.map((entry) {
              final typeStats = entry.value as Map<String, dynamic>;
              return _buildTypeItem(entry.key, typeStats);
            }).toList()),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          Icon(icon, size: 24, color: Theme.of(context).colorScheme.secondary),
          const SizedBox(width: 12),
          Text(label, style: const TextStyle(fontSize: 14)),
          const Spacer(),
          Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
  
  Widget _buildTypeItem(String type, Map<String, dynamic> stats) {
    final count = stats['count'] as int;
    final distance = stats['totalDistance'] as double;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        children: [
          Expanded(flex: 2, child: Text(_formatWorkoutType(type), style: const TextStyle(fontSize: 13))),
          Expanded(child: Text('$count회', style: const TextStyle(fontSize: 12), textAlign: TextAlign.right)),
          Expanded(child: Text('${(distance / 1000).toStringAsFixed(1)} km', style: const TextStyle(fontSize: 12), textAlign: TextAlign.right)),
        ],
      ),
    );
  }


  Widget _buildWorkoutsList() {
    final recentWorkouts = (_workouts..sort((a, b) => b.startDate.compareTo(a.startDate))).take(10).toList();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('최근 운동 기록', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                TextButton(
                  onPressed: () {
                     Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => WorkoutListScreen(workouts: _workouts),
                      ),
                    );
                  },
                  child: const Text('전체보기'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ...recentWorkouts.map((workout) => _buildWorkoutItem(workout)),
          ],
        ),
      ),
    );
  }

  Widget _buildWorkoutItem(HealthWorkout workout) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4.0),
      child: ListTile(
        leading: Icon(_getWorkoutIcon(workout.workoutType), color: Theme.of(context).colorScheme.secondary),
        title: Text(_formatWorkoutType(workout.workoutType)),
        subtitle: Text('${_formatDate(workout.startDate)} • ${workout.duration.inMinutes} 분'),
        trailing: (workout.distance != null)
            ? Text('${(workout.distance! / 1000).toStringAsFixed(2)} km', style: const TextStyle(fontWeight: FontWeight.bold))
            : null,
      ),
    );
  }

  String _formatWorkoutType(String type) {
    return type.replaceAll('WORKOUT_ACTIVITY_TYPE_', '').replaceAll('_', ' ').toLowerCase().capitalize();
  }

  IconData _getWorkoutIcon(String type) {
    if (type.contains('RUNNING')) return Icons.directions_run;
    if (type.contains('WALKING')) return Icons.directions_walk;
    if (type.contains('CYCLING')) return Icons.directions_bike;
    if (type.contains('SWIMMING')) return Icons.pool;
    if (type.contains('HIKING')) return Icons.terrain;
    return Icons.fitness_center;
  }

  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }
}

class WorkoutListScreen extends StatelessWidget {
  final List<HealthWorkout> workouts;

  const WorkoutListScreen({super.key, required this.workouts});

  @override
  Widget build(BuildContext context) {
    final sortedWorkouts = List<HealthWorkout>.from(workouts)..sort((a, b) => b.startDate.compareTo(a.startDate));

    return Scaffold(
      appBar: AppBar(
        title: Text('전체 운동 기록 (${workouts.length}개)'),
        backgroundColor: Theme.of(context).colorScheme.secondary,
        foregroundColor: Theme.of(context).colorScheme.onSecondary,
      ),
      body: ListView.builder(
        itemCount: sortedWorkouts.length,
        itemBuilder: (context, index) {
          final workout = sortedWorkouts[index];
          return _buildWorkoutCard(context, workout);
        },
      ),
    );
  }

  Widget _buildWorkoutCard(BuildContext context, HealthWorkout workout) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
      child: ListTile(
        leading: Icon(_getWorkoutIcon(workout.workoutType), color: Theme.of(context).colorScheme.secondary),
        title: Text(_formatWorkoutType(workout.workoutType)),
        subtitle: Text('${_formatDateTime(workout.startDate)} • ${workout.duration.inMinutes} 분'),
        trailing: (workout.distance != null)
            ? Text('${(workout.distance! / 1000).toStringAsFixed(2)} km', style: const TextStyle(fontWeight: FontWeight.bold))
            : null,
      ),
    );
  }

  String _formatWorkoutType(String type) {
    return type.replaceAll('WORKOUT_ACTIVITY_TYPE_', '').replaceAll('_', ' ').toLowerCase().capitalize();
  }

  IconData _getWorkoutIcon(String type) {
    if (type.contains('RUNNING')) return Icons.directions_run;
    if (type.contains('WALKING')) return Icons.directions_walk;
    if (type.contains('CYCLING')) return Icons.directions_bike;
    if (type.contains('SWIMMING')) return Icons.pool;
    if (type.contains('HIKING')) return Icons.terrain;
    return Icons.fitness_center;
  }

  String _formatDateTime(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')} '
        '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }
}

extension StringExtension on String {
  String capitalize() {
    return "${this[0].toUpperCase()}${substring(1)}";
  }
}
