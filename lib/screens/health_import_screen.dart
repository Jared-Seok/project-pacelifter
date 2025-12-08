import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../services/health_xml_parser.dart';
import '../models/health_workout.dart';

class HealthImportScreen extends StatefulWidget {
  const HealthImportScreen({super.key});

  @override
  State<HealthImportScreen> createState() => _HealthImportScreenState();
}

class _HealthImportScreenState extends State<HealthImportScreen> {
  final HealthXmlParser _parser = HealthXmlParser();
  bool _isLoading = false;
  String? _selectedFileName;
  Map<String, dynamic>? _statistics;
  String? _errorMessage;

  Future<void> _pickFile() async {
    try {
      setState(() {
        _errorMessage = null;
      });

      debugPrint('파일 선택 시작 (웹: $kIsWeb)');

      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['xml'],
        withData: true, // 항상 데이터 로드
      );

      debugPrint('파일 선택 결과: ${result != null}');

      if (result != null) {
        final file = result.files.single;
        final fileSizeMB = file.size / (1024 * 1024);

        debugPrint('선택된 파일: ${file.name}, 크기: ${file.size} bytes (${fileSizeMB.toStringAsFixed(2)} MB)');

        // 웹에서 큰 파일 체크
        if (kIsWeb && file.size > 100 * 1024 * 1024) {
          // 100MB 이상
          throw Exception(
            '파일이 너무 큽니다!\n\n'
            '파일 크기: ${fileSizeMB.toStringAsFixed(0)} MB\n'
            '웹 브라우저 제한: 100 MB\n\n'
            '해결 방법:\n'
            '1. iPhone이나 Android 앱에서 실행하세요\n'
            '2. 더 작은 기간의 데이터를 export하세요\n\n'
            '모바일 앱에서는 크기 제한이 없습니다.'
          );
        }

        setState(() {
          _selectedFileName = file.name;
          _isLoading = true;
        });

        // 웹과 모바일 분기 처리
        if (kIsWeb) {
          // 웹: bytes 사용
          debugPrint('웹 모드: bytes 확인 중...');

          Uint8List? bytes = file.bytes;

          // bytes가 null이면 다시 읽기 시도
          if (bytes == null) {
            debugPrint('bytes가 null, readAsBytes 시도...');
            try {
              // PlatformFile의 readStream 또는 다른 방법 시도
              if (file.readStream != null) {
                debugPrint('readStream 사용');
                final List<int> allBytes = [];
                await for (final chunk in file.readStream!) {
                  allBytes.addAll(chunk);
                }
                bytes = Uint8List.fromList(allBytes);
              }
            } catch (e) {
              debugPrint('readStream 실패: $e');
            }
          }

          if (bytes != null) {
            debugPrint('파일 크기: ${bytes.length} bytes');
            await _parseBytes(bytes);
          } else {
            throw Exception(
              '파일 데이터를 읽을 수 없습니다.\n'
              '파일 크기: ${file.size} bytes\n'
              'bytes: null\n'
              'readStream: ${file.readStream != null}'
            );
          }
        } else {
          // 모바일: path 사용
          final path = file.path;
          if (path != null) {
            debugPrint('모바일 모드: 파일 경로: $path');
            await _parsePath(path);
          } else {
            throw Exception('파일 경로를 찾을 수 없습니다');
          }
        }
      } else {
        debugPrint('파일 선택 취소됨');
      }
    } catch (e) {
      setState(() {
        _errorMessage = '파일 선택 오류: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _parseBytes(Uint8List bytes) async {
    try {
      debugPrint('파싱 시작: ${bytes.length} bytes');

      await _parser.parseBytes(
        bytes,
        includeWorkouts: true,
        includeRecords: false,
      );

      debugPrint('파싱 완료: ${_parser.workouts.length} workouts');

      setState(() {
        _statistics = _parser.getWorkoutStatistics();
        _isLoading = false;
      });

      debugPrint('통계 생성 완료');
    } catch (e, stackTrace) {
      debugPrint('파싱 오류 발생: $e');
      debugPrint('스택 트레이스: $stackTrace');

      setState(() {
        _errorMessage = '파싱 오류: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _parsePath(String filePath) async {
    try {
      await _parser.parseFile(
        filePath,
        includeWorkouts: true,
        includeRecords: false,
      );

      setState(() {
        _statistics = _parser.getWorkoutStatistics();
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = '파싱 오류: $e';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Apple Health 데이터 Import'),
        backgroundColor: Colors.blue,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildInstructions(),
            const SizedBox(height: 24),
            _buildFilePickerButton(),
            const SizedBox(height: 16),
            if (_errorMessage != null) _buildErrorMessage(),
            if (_isLoading) _buildLoadingIndicator(),
            if (_statistics != null) _buildStatistics(),
            if (_statistics != null) const SizedBox(height: 16),
            if (_statistics != null) _buildWorkoutsList(),
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
                Icon(Icons.info_outline, color: Colors.blue[700]),
                const SizedBox(width: 8),
                const Text(
                  'Apple Health 데이터 가져오기',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Text(
              '1. iPhone의 건강 앱 열기\n'
              '2. 프로필 아이콘 > 건강 데이터 내보내기\n'
              '3. export.zip 파일을 압축 해제\n'
              '4. export.xml 파일을 선택',
              style: TextStyle(fontSize: 14),
            ),
            if (kIsWeb) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange[300]!),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.warning_amber, color: Colors.orange[700], size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '웹 브라우저 제한: 100 MB까지만 가능\n'
                        '큰 파일은 iPhone/Android 앱에서 사용하세요',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.orange[900],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildFilePickerButton() {
    return ElevatedButton.icon(
      onPressed: _isLoading ? null : _pickFile,
      icon: const Icon(Icons.file_upload),
      label: Text(
        _selectedFileName == null
            ? 'export.xml 파일 선택'
            : '$_selectedFileName 선택됨',
      ),
      style: ElevatedButton.styleFrom(
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
            Text('데이터를 분석하는 중...'),
            SizedBox(height: 8),
            Text(
              '큰 파일의 경우 시간이 걸릴 수 있습니다',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
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
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            _buildStatItem(
              Icons.fitness_center,
              '총 운동 횟수',
              '$totalWorkouts회',
            ),
            _buildStatItem(
              Icons.directions_run,
              '총 거리',
              '${totalDistance.toStringAsFixed(1)} km',
            ),
            _buildStatItem(
              Icons.timer,
              '총 운동 시간',
              '${(totalDuration ~/ 60)} 시간 ${totalDuration % 60} 분',
            ),
            const Divider(height: 24),
            const Text(
              '운동 유형별',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
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
          Icon(icon, size: 24, color: Colors.blue[700]),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(fontSize: 14),
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTypeItem(String type, Map<String, dynamic> stats) {
    final count = stats['count'] as int;
    final distance = stats['totalDistance'] as double;
    final avgPace = stats['avgPace'] as double?;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Text(
              _formatWorkoutType(type),
              style: const TextStyle(fontSize: 13),
            ),
          ),
          Expanded(
            child: Text(
              '$count회',
              style: const TextStyle(fontSize: 12),
              textAlign: TextAlign.right,
            ),
          ),
          Expanded(
            child: Text(
              '${distance.toStringAsFixed(1)} km',
              style: const TextStyle(fontSize: 12),
              textAlign: TextAlign.right,
            ),
          ),
          if (avgPace != null)
            Expanded(
              child: Text(
                '${avgPace.toStringAsFixed(1)} min/km',
                style: const TextStyle(fontSize: 12),
                textAlign: TextAlign.right,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildWorkoutsList() {
    final recentWorkouts = _parser.getRecentWorkouts(10);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  '최근 운동 기록',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                TextButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => WorkoutListScreen(
                          workouts: _parser.workouts,
                        ),
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
        leading: Icon(
          _getWorkoutIcon(workout.workoutType),
          color: Colors.blue[700],
        ),
        title: Text(_formatWorkoutType(workout.workoutType)),
        subtitle: Text(
          '${_formatDate(workout.startDate)} • '
          '${workout.duration.inMinutes} 분',
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            if (workout.distance != null)
              Text(
                '${(workout.distance! / 1000).toStringAsFixed(2)} km',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            if (workout.averagePace != null)
              Text(
                '${workout.averagePace!.toStringAsFixed(2)} min/km',
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
          ],
        ),
      ),
    );
  }

  String _formatWorkoutType(String type) {
    if (type.contains('Running')) return '러닝';
    if (type.contains('Walking')) return '걷기';
    if (type.contains('Cycling')) return '사이클';
    if (type.contains('Swimming')) return '수영';
    if (type.contains('Hiking')) return '하이킹';
    return type.replaceAll('HKWorkoutActivityType', '');
  }

  IconData _getWorkoutIcon(String type) {
    if (type.contains('Running')) return Icons.directions_run;
    if (type.contains('Walking')) return Icons.directions_walk;
    if (type.contains('Cycling')) return Icons.directions_bike;
    if (type.contains('Swimming')) return Icons.pool;
    if (type.contains('Hiking')) return Icons.terrain;
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
    final sortedWorkouts = List<HealthWorkout>.from(workouts)
      ..sort((a, b) => b.startDate.compareTo(a.startDate));

    return Scaffold(
      appBar: AppBar(
        title: Text('전체 운동 기록 (${workouts.length}개)'),
        backgroundColor: Colors.blue,
      ),
      body: ListView.builder(
        itemCount: sortedWorkouts.length,
        itemBuilder: (context, index) {
          final workout = sortedWorkouts[index];
          return _buildWorkoutCard(workout);
        },
      ),
    );
  }

  Widget _buildWorkoutCard(HealthWorkout workout) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
      child: ListTile(
        leading: Icon(
          _getWorkoutIcon(workout.workoutType),
          color: Colors.blue[700],
        ),
        title: Text(_formatWorkoutType(workout.workoutType)),
        subtitle: Text(
          '${_formatDateTime(workout.startDate)} • '
          '${workout.duration.inMinutes} 분',
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            if (workout.distance != null)
              Text(
                '${(workout.distance! / 1000).toStringAsFixed(2)} km',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            if (workout.averagePace != null)
              Text(
                '${workout.averagePace!.toStringAsFixed(2)} min/km',
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
          ],
        ),
      ),
    );
  }

  String _formatWorkoutType(String type) {
    if (type.contains('Running')) return '러닝';
    if (type.contains('Walking')) return '걷기';
    if (type.contains('Cycling')) return '사이클';
    if (type.contains('Swimming')) return '수영';
    if (type.contains('Hiking')) return '하이킹';
    return type.replaceAll('HKWorkoutActivityType', '');
  }

  IconData _getWorkoutIcon(String type) {
    if (type.contains('Running')) return Icons.directions_run;
    if (type.contains('Walking')) return Icons.directions_walk;
    if (type.contains('Cycling')) return Icons.directions_bike;
    if (type.contains('Swimming')) return Icons.pool;
    if (type.contains('Hiking')) return Icons.terrain;
    return Icons.fitness_center;
  }

  String _formatDateTime(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')} '
        '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }
}
