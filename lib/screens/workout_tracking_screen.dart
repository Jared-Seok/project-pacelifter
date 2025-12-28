import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../models/sessions/route_point.dart';
import '../services/workout_tracking_service.dart';
import '../services/heart_rate_service.dart';
import '../widgets/heart_rate_monitor_widget.dart';
import 'dart:async';

/// 실시간 운동 추적 화면
///
/// 개선사항:
/// - 3초 카운트다운 추가
/// - 대시보드 톤 통일 (카키/연두색, SVG 아이콘)
/// - 더 직관적인 UI
class WorkoutTrackingScreen extends StatefulWidget {
  const WorkoutTrackingScreen({super.key});

  @override
  State<WorkoutTrackingScreen> createState() => _WorkoutTrackingScreenState();
}

class _WorkoutTrackingScreenState extends State<WorkoutTrackingScreen> with SingleTickerProviderStateMixin {
  late WorkoutTrackingService _service;
  final HeartRateService _hrService = HeartRateService();
  WorkoutState? _currentState;

  // 카운트다운 관련
  bool _showCountdown = true;
  int _countdown = 3;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _service = Provider.of<WorkoutTrackingService>(context, listen: false);

    // 펄스 애니메이션 설정
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _pulseAnimation = Tween<double>(begin: 0.8, end: 1.2).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    // 카운트다운 시작
    _startCountdown();

    // 실시간 업데이트 리스닝
    _service.workoutStateStream.listen((state) {
      if (mounted) {
        setState(() {
          _currentState = state;
        });
      }
    });

    // 서비스의 현재 상태를 즉시 반영
    if (_service.isTracking) {
      // 강제로 첫 상태 업데이트를 요청할 수 있는 메소드가 서비스에 있다면 더 좋음
      // 예: _service.requestUpdate();
    }
  }

  void _startCountdown() {
    _pulseController.repeat(reverse: true);

    Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }

      setState(() {
        if (_countdown > 1) {
          _countdown--;
        } else {
          _showCountdown = false;
          _pulseController.stop();
          _hrService.startMonitoring(); // 심박수 모니터링 시작
          timer.cancel();
        }
      });
    });
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _hrService.stopMonitoring();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: SafeArea(
        child: _showCountdown
            ? _buildCountdownScreen()
            : (_currentState == null || !_currentState!.isTracking
                ? const Center(child: CircularProgressIndicator())
                : _buildTrackingScreen()),
      ),
    );
  }

  /// 카운트다운 화면
  Widget _buildCountdownScreen() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Theme.of(context).colorScheme.primary.withValues(alpha: 0.3),
            Theme.of(context).colorScheme.surface,
          ],
        ),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Runner 아이콘
            SvgPicture.asset(
              'assets/images/endurance/runner-icon.svg',
              width: 100,
              height: 100,
              colorFilter: ColorFilter.mode(
                Theme.of(context).colorScheme.secondary,
                BlendMode.srcIn,
              ),
            ),
            const SizedBox(height: 40),

            // 준비 텍스트
            Text(
              '준비',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w600,
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.8),
                letterSpacing: 2,
              ),
            ),
            const SizedBox(height: 20),

            // 카운트다운 숫자 (펄스 애니메이션)
            AnimatedBuilder(
              animation: _pulseAnimation,
              builder: (context, child) {
                return Transform.scale(
                  scale: _pulseAnimation.value,
                  child: Container(
                    width: 150,
                    height: 150,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Theme.of(context).colorScheme.secondary.withValues(alpha: 0.2),
                      border: Border.all(
                        color: Theme.of(context).colorScheme.secondary,
                        width: 4,
                      ),
                    ),
                    child: Center(
                      child: Text(
                        '$_countdown',
                        style: TextStyle(
                          fontSize: 80,
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.secondary,
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 40),

            // 안내 메시지
            Text(
              '곧 운동이 시작됩니다',
              style: TextStyle(
                fontSize: 16,
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 운동 중 추적 화면 (개선된 UI)
  Widget _buildTrackingScreen() {
    if (_currentState == null) return const SizedBox();

    return Column(
      children: [
        // 상단: 상태 표시
        _buildHeader(),

        // 메인: 핵심 지표
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                // 주요 지표: 거리 (대형)
                _buildPrimaryMetric(
                  value: _currentState!.distanceKm,
                  unit: 'km',
                  label: '거리',
                ),
                const SizedBox(height: 20),

                // 시간과 페이스 (중요 지표 2개)
                Row(
                  children: [
                    Expanded(
                      child: _buildSecondaryMetric(
                        label: '시간',
                        value: _currentState!.durationFormatted,
                        icon: Icons.timer,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildSecondaryMetric(
                        label: '평균 페이스',
                        value: _currentState!.averagePace,
                        unit: '/km',
                        icon: Icons.speed,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // 현재 페이스 (강조)
                _buildCurrentPaceCard(),
                const SizedBox(height: 24),

                // 실시간 심박수 모니터 (Endurance 스타일에 맞게 배치)
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    HeartRateMonitorWidget(),
                  ],
                ),
                const SizedBox(height: 24),

                // 칼로리 & 상승 고도
                Row(
                  children: [
                    Expanded(
                      child: _buildCompactMetric(
                        label: '칼로리',
                        value: _currentState!.caloriesFormatted,
                        unit: 'kcal',
                        icon: Icons.local_fire_department,
                        color: Colors.orange,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildCompactMetric(
                        label: '상승 고도',
                        value: _currentState!.elevationGain.toStringAsFixed(0),
                        unit: 'm',
                        icon: Icons.terrain,
                        color: Colors.cyan,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // GPS 포인트 정보 (텍스트로만 유지)
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.gps_fixed,
                        size: 16,
                        color: Theme.of(context).colorScheme.secondary,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'GPS: ${_currentState!.routePointsCount}개 포인트',
                        style: TextStyle(
                          fontSize: 12,
                          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),

        // 하단: 컨트롤 버튼
        _buildControls(),
      ],
    );
  }

  Widget _buildLiveMap() {
    final route = _service.route;
    final List<LatLng> polylinePoints = route.map((p) => LatLng(p.latitude, p.longitude)).toList();

    return Container(
      height: 250,
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.2)),
      ),
      clipBehavior: Clip.antiAlias,
      child: polylinePoints.isEmpty
          ? Center(
              child: Text(
                '위치 정보를 수집 중입니다...',
                style: TextStyle(color: Colors.grey[600]),
              ),
            )
          : GoogleMap(
              initialCameraPosition: CameraPosition(
                target: polylinePoints.last,
                zoom: 16,
              ),
              polylines: {
                Polyline(
                  polylineId: const PolylineId('workout_route'),
                  points: polylinePoints,
                  color: Theme.of(context).colorScheme.secondary,
                  width: 5,
                  jointType: JointType.round,
                  startCap: Cap.roundCap,
                  endCap: Cap.roundCap,
                ),
              },
              myLocationEnabled: true,
              myLocationButtonEnabled: false,
              zoomControlsEnabled: false,
              mapToolbarEnabled: false,
              onMapCreated: (controller) {
                // 필요시 컨트롤러 관리
              },
            ),
    );
  }

  /// 주요 지표 (대형 - 거리)
  Widget _buildPrimaryMetric({
    required String value,
    required String unit,
    required String label,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Theme.of(context).colorScheme.secondary.withValues(alpha: 0.2),
            Theme.of(context).colorScheme.secondary.withValues(alpha: 0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Theme.of(context).colorScheme.secondary.withValues(alpha: 0.3),
          width: 2,
        ),
      ),
      child: Column(
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                value,
                style: TextStyle(
                  fontSize: 72,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.secondary,
                  height: 1,
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(bottom: 12, left: 8),
                child: Text(
                  unit,
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).colorScheme.secondary.withValues(alpha: 0.7),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// 보조 지표 (중형)
  Widget _buildSecondaryMetric({
    required String label,
    required String value,
    String? unit,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.3),
          width: 1.5,
        ),
      ),
      child: Column(
        children: [
          Icon(
            icon,
            size: 28,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
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
              if (unit != null) ...[
                const SizedBox(width: 4),
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(
                    unit,
                    style: TextStyle(
                      fontSize: 14,
                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
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

  /// 현재 페이스 카드 (강조)
  Widget _buildCurrentPaceCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Theme.of(context).colorScheme.primary,
          width: 2,
        ),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.trending_up,
                size: 20,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Text(
                '현재 페이스',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                _currentState!.currentPace,
                style: TextStyle(
                  fontSize: 40,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(bottom: 6, left: 4),
                child: Text(
                  '/km',
                  style: TextStyle(
                    fontSize: 16,
                    color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.7),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// 컴팩트 지표 (소형)
  Widget _buildCompactMetric({
    required String label,
    required String value,
    required String unit,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: color.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Column(
        children: [
          Icon(icon, size: 24, color: color),
          const SizedBox(height: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
            ),
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                value,
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
              const SizedBox(width: 2),
              Padding(
                padding: const EdgeInsets.only(bottom: 2),
                child: Text(
                  unit,
                  style: TextStyle(
                    fontSize: 11,
                    color: color.withValues(alpha: 0.7),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
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
            ? Colors.orange.withValues(alpha: 0.2)
            : Theme.of(context).colorScheme.secondary.withValues(alpha: 0.1),
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

  /// 컨트롤 버튼 (개선된 UI)
  Widget _buildControls() {
    final isPaused = _currentState?.isPaused ?? false;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            // 일시정지/재개 버튼 (크고 눈에 띄게)
            Expanded(
              flex: 2,
              child: ElevatedButton(
                onPressed: isPaused ? _resumeWorkout : _pauseWorkout,
                style: ElevatedButton.styleFrom(
                  backgroundColor: isPaused
                      ? Theme.of(context).colorScheme.secondary
                      : Theme.of(context).colorScheme.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 0,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      isPaused ? Icons.play_arrow_rounded : Icons.pause_rounded,
                      size: 28,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      isPaused ? '재개' : '일시정지',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 12),

            // 종료 버튼 (작게)
            Expanded(
              child: OutlinedButton(
                onPressed: _showStopConfirmation,
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.red,
                  side: const BorderSide(color: Colors.red, width: 2),
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: const Column(
                  children: [
                    Icon(Icons.stop_rounded, size: 24),
                    SizedBox(height: 2),
                    Text(
                      '종료',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
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
      final hrStats = _hrService.getSessionStats();
      final summary = await _service.stopWorkout(
        avgHeartRate: hrStats['average']?.toInt(),
      );

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
}

/// 운동 완료 요약 화면 (개선된 UI)
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
        automaticallyImplyLeading: false,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 완료 배지 (강조)
            Container(
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Theme.of(context).colorScheme.secondary.withValues(alpha: 0.2),
                    Theme.of(context).colorScheme.secondary.withValues(alpha: 0.05),
                  ],
                ),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: Theme.of(context).colorScheme.secondary.withValues(alpha: 0.3),
                  width: 2,
                ),
              ),
              child: Column(
                children: [
                  // Runner 아이콘
                  SvgPicture.asset(
                    'assets/images/endurance/runner-icon.svg',
                    width: 80,
                    height: 80,
                    colorFilter: ColorFilter.mode(
                      Theme.of(context).colorScheme.secondary,
                      BlendMode.srcIn,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    '수고하셨습니다!',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.secondary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.check_circle_rounded,
                          size: 16,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'HealthKit에 저장 완료',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // 운동 경로 지도 (완료 후 결과로 표시)
            if (summary.routePoints.isNotEmpty) ...[
              _buildResultMap(context, summary.routePoints),
              const SizedBox(height: 24),
            ],

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
            const SizedBox(height: 16),

            // 심박수 (평균)
            _buildSummaryCard(
              context,
              '평균 심박수',
              summary.averageHeartRate?.toString() ?? '--',
              'bpm',
              Icons.favorite,
            ),
            const SizedBox(height: 32),

            // 상세 정보
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(
                  context,
                ).colorScheme.onSurface.withValues(alpha: 0.05),
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
          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.2),
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
                    ).colorScheme.onSurface.withValues(alpha: 0.6),
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
                            ).colorScheme.onSurface.withValues(alpha: 0.6),
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

  Widget _buildResultMap(BuildContext context, List<dynamic> routePoints) {
    final List<LatLng> points = routePoints.map((p) => LatLng(p.latitude, p.longitude)).toList();
    
    // 경로를 포함하는 경계 상자 계산 (카메라 중심 맞추기)
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

    return Container(
      height: 300,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.2)),
      ),
      clipBehavior: Clip.antiAlias,
      child: GoogleMap(
        initialCameraPosition: CameraPosition(target: points.first, zoom: 15),
        polylines: {
          Polyline(
            polylineId: const PolylineId('result_route'),
            points: points,
            color: Theme.of(context).colorScheme.secondary,
            width: 5,
            jointType: JointType.round,
          ),
        },
        myLocationEnabled: false,
        zoomControlsEnabled: false,
        mapToolbarEnabled: false,
        onMapCreated: (controller) {
          if (points.length > 1) {
            Future.delayed(const Duration(milliseconds: 500), () {
              controller.animateCamera(CameraUpdate.newLatLngBounds(bounds, 50));
            });
          }
        },
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
