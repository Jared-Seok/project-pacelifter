import 'package:flutter/material.dart';
import '../services/workout_tracking_service.dart';

/// 실시간 운동 추적 화면
///
/// NRC/Strava UI 벤치마킹:
/// - 큰 숫자로 핵심 지표 표시 (거리, 시간, 페이스)
/// - 하단에 일시정지/종료 버튼
/// - 심플하고 집중된 레이아웃
class WorkoutTrackingScreen extends StatefulWidget {
  const WorkoutTrackingScreen({super.key});

  @override
  State<WorkoutTrackingScreen> createState() => _WorkoutTrackingScreenState();
}

class _WorkoutTrackingScreenState extends State<WorkoutTrackingScreen> {
  final WorkoutTrackingService _service = WorkoutTrackingService();
  WorkoutState? _currentState;
  bool _isStarting = false;

  @override
  void initState() {
    super.initState();

    // 실시간 업데이트 리스닝
    _service.workoutStateStream.listen((state) {
      if (mounted) {
        setState(() {
          _currentState = state;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: SafeArea(
        child: _currentState == null
            ? _buildStartScreen()
            : _buildTrackingScreen(),
      ),
    );
  }

  /// 운동 시작 전 화면
  Widget _buildStartScreen() {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.directions_run,
            size: 120,
            color: Theme.of(context).colorScheme.secondary,
          ),
          const SizedBox(height: 32),
          Text(
            '러닝 준비',
            style: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'GPS와 건강 데이터 권한이 필요합니다',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 16,
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
            ),
          ),
          const SizedBox(height: 48),
          _isStarting
              ? const CircularProgressIndicator()
              : ElevatedButton(
                  onPressed: _startWorkout,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.secondary,
                    foregroundColor: Theme.of(context).colorScheme.onSecondary,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 48,
                      vertical: 20,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                  ),
                  child: const Text(
                    '운동 시작',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                ),
          const SizedBox(height: 16),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('취소'),
          ),
        ],
      ),
    );
  }

  /// 운동 시작 처리
  Future<void> _startWorkout() async {
    setState(() {
      _isStarting = true;
    });

    try {
      await _service.startWorkout();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('오류: $e'), backgroundColor: Colors.red),
        );
        setState(() {
          _isStarting = false;
        });
      }
    }
  }

  /// 운동 중 추적 화면
  Widget _buildTrackingScreen() {
    if (_currentState == null) return const SizedBox();

    return Column(
      children: [
        // 상단: 상태 표시
        _buildHeader(),

        // 메인: 핵심 지표
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              children: [
                // 시간
                _buildMetricCard(
                  label: '시간',
                  value: _currentState!.durationFormatted,
                  icon: Icons.timer,
                ),
                const SizedBox(height: 20),

                // 거리
                _buildMetricCard(
                  label: '거리',
                  value: _currentState!.distanceKm,
                  unit: 'km',
                  icon: Icons.straighten,
                ),
                const SizedBox(height: 20),

                // 페이스 (현재 / 평균)
                Row(
                  children: [
                    Expanded(
                      child: _buildMetricCard(
                        label: '현재 페이스',
                        value: _currentState!.currentPace,
                        unit: '/km',
                        icon: Icons.speed,
                        compact: true,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildMetricCard(
                        label: '평균 페이스',
                        value: _currentState!.averagePace,
                        unit: '/km',
                        icon: Icons.trending_flat,
                        compact: true,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // 칼로리 & 심박수
                Row(
                  children: [
                    Expanded(
                      child: _buildMetricCard(
                        label: '칼로리',
                        value: _currentState!.caloriesFormatted,
                        unit: 'kcal',
                        icon: Icons.local_fire_department,
                        compact: true,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildMetricCard(
                        label: '심박수',
                        value: _currentState!.heartRate?.toString() ?? '--',
                        unit: 'bpm',
                        icon: Icons.favorite,
                        compact: true,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // GPS 포인트
                _buildInfoText('GPS 포인트: ${_currentState!.routePointsCount}개'),
              ],
            ),
          ),
        ),

        // 하단: 컨트롤 버튼
        _buildControls(),
      ],
    );
  }

  /// 헤더 (일시정지 상태 표시)
  Widget _buildHeader() {
    final isPaused = _currentState?.isPaused ?? false;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isPaused
            ? Colors.orange.withOpacity(0.2)
            : Theme.of(context).colorScheme.secondary.withOpacity(0.1),
        border: Border(
          bottom: BorderSide(
            color: isPaused
                ? Colors.orange
                : Theme.of(context).colorScheme.secondary,
            width: 2,
          ),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Icon(
                isPaused ? Icons.pause_circle : Icons.play_circle,
                color: isPaused
                    ? Colors.orange
                    : Theme.of(context).colorScheme.secondary,
                size: 28,
              ),
              const SizedBox(width: 8),
              Text(
                isPaused ? '일시정지됨' : '운동 중',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: isPaused
                      ? Colors.orange
                      : Theme.of(context).colorScheme.secondary,
                ),
              ),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.close),
            onPressed: _showStopConfirmation,
          ),
        ],
      ),
    );
  }

  /// 지표 카드
  Widget _buildMetricCard({
    required String label,
    required String value,
    String? unit,
    required IconData icon,
    bool compact = false,
  }) {
    return Container(
      padding: EdgeInsets.all(compact ? 16 : 24),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border.all(
          color: Theme.of(context).colorScheme.onSurface.withOpacity(0.2),
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: compact ? 20 : 24,
                color: Theme.of(context).colorScheme.secondary,
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  fontSize: compact ? 14 : 16,
                  color: Theme.of(
                    context,
                  ).colorScheme.onSurface.withOpacity(0.7),
                ),
              ),
            ],
          ),
          SizedBox(height: compact ? 8 : 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                value,
                style: TextStyle(
                  fontSize: compact ? 32 : 48,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              if (unit != null) ...[
                const SizedBox(width: 8),
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    unit,
                    style: TextStyle(
                      fontSize: compact ? 16 : 20,
                      color: Theme.of(
                        context,
                      ).colorScheme.onSurface.withOpacity(0.6),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  /// 정보 텍스트
  Widget _buildInfoText(String text) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 14,
        color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
      ),
    );
  }

  /// 컨트롤 버튼
  Widget _buildControls() {
    final isPaused = _currentState?.isPaused ?? false;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          // 일시정지/재개 버튼
          ElevatedButton.icon(
            onPressed: isPaused ? _resumeWorkout : _pauseWorkout,
            icon: Icon(isPaused ? Icons.play_arrow : Icons.pause),
            label: Text(isPaused ? '재개' : '일시정지'),
            style: ElevatedButton.styleFrom(
              backgroundColor: isPaused
                  ? Theme.of(context).colorScheme.secondary
                  : Colors.orange,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(30),
              ),
            ),
          ),

          // 종료 버튼
          OutlinedButton.icon(
            onPressed: _showStopConfirmation,
            icon: const Icon(Icons.stop),
            label: const Text('종료'),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.red,
              side: const BorderSide(color: Colors.red),
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(30),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 일시정지
  void _pauseWorkout() {
    _service.pauseWorkout();
  }

  /// 재개
  void _resumeWorkout() {
    _service.resumeWorkout();
  }

  /// 종료 확인 다이얼로그
  Future<void> _showStopConfirmation() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('운동 종료'),
        content: const Text('운동을 종료하시겠습니까?\n데이터가 저장됩니다.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('취소'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('종료'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      await _stopWorkout();
    }
  }

  /// 운동 종료
  Future<void> _stopWorkout() async {
    try {
      final summary = await _service.stopWorkout();

      if (mounted) {
        // 결과 화면으로 이동
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => WorkoutSummaryScreen(summary: summary),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('운동 종료 오류: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  void dispose() {
    _service.dispose();
    super.dispose();
  }
}

/// 운동 완료 요약 화면
class WorkoutSummaryScreen extends StatelessWidget {
  final WorkoutSummary summary;

  const WorkoutSummaryScreen({super.key, required this.summary});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        title: const Text('운동 완료'),
        backgroundColor: Theme.of(context).colorScheme.surface,
        foregroundColor: Theme.of(context).colorScheme.onSurface,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 완료 아이콘
            Icon(
              Icons.check_circle,
              size: 80,
              color: Theme.of(context).colorScheme.secondary,
            ),
            const SizedBox(height: 16),
            Text(
              '수고하셨습니다!',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'HealthKit에 저장되었습니다',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
              ),
            ),
            const SizedBox(height: 32),

            // 거리
            _buildSummaryCard(
              context,
              '거리',
              summary.distanceKm,
              'km',
              Icons.straighten,
            ),
            const SizedBox(height: 16),

            // 시간
            _buildSummaryCard(
              context,
              '시간',
              summary.durationFormatted,
              '',
              Icons.timer,
            ),
            const SizedBox(height: 16),

            // 페이스
            _buildSummaryCard(
              context,
              '평균 페이스',
              summary.averagePace,
              '/km',
              Icons.speed,
            ),
            const SizedBox(height: 16),

            // 칼로리
            _buildSummaryCard(
              context,
              '칼로리',
              summary.calories.toStringAsFixed(0),
              'kcal',
              Icons.local_fire_department,
            ),
            const SizedBox(height: 32),

            // 상세 정보
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(
                  context,
                ).colorScheme.onSurface.withOpacity(0.05),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildDetailRow('시작 시간', _formatTime(summary.startTime)),
                  const Divider(),
                  _buildDetailRow('종료 시간', _formatTime(summary.endTime)),
                  const Divider(),
                  _buildDetailRow('GPS 포인트', '${summary.routePoints.length}개'),
                  if (summary.pausedDuration.inSeconds > 0) ...[
                    const Divider(),
                    _buildDetailRow(
                      '일시정지',
                      _formatDuration(summary.pausedDuration),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 32),

            // 홈으로 버튼
            ElevatedButton(
              onPressed: () {
                Navigator.popUntil(context, (route) => route.isFirst);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.secondary,
                foregroundColor: Theme.of(context).colorScheme.onSecondary,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30),
                ),
              ),
              child: const Text(
                '홈으로',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryCard(
    BuildContext context,
    String label,
    String value,
    String unit,
    IconData icon,
  ) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border.all(
          color: Theme.of(context).colorScheme.onSurface.withOpacity(0.2),
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Icon(icon, size: 32, color: Theme.of(context).colorScheme.secondary),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 14,
                    color: Theme.of(
                      context,
                    ).colorScheme.onSurface.withOpacity(0.6),
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      value,
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                    if (unit.isNotEmpty) ...[
                      const SizedBox(width: 8),
                      Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Text(
                          unit,
                          style: TextStyle(
                            fontSize: 16,
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurface.withOpacity(0.6),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 14)),
          Text(
            value,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  String _formatTime(DateTime time) {
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }

  String _formatDuration(Duration duration) {
    int minutes = duration.inMinutes;
    int seconds = duration.inSeconds.remainder(60);
    return '$minutes분 $seconds초';
  }
}
