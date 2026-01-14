import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // Added
import 'package:provider/provider.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../models/templates/workout_template.dart';
import '../models/templates/template_block.dart';
import '../services/workout_tracking_service.dart';
import '../services/heart_rate_service.dart';
import '../widgets/heart_rate_monitor_widget.dart';
import 'tracking/components/free_run_body.dart';
import 'tracking/components/interval_tracking_body.dart';
import 'tracking/components/steady_state_tracking_body.dart';
import 'package:pacelifter/services/native_activation_service.dart';
import 'dart:async';

/// 실시간 운동 추적 화면
class EnduranceTrackingScreen extends StatefulWidget {
  final WorkoutTemplate? template; // 추가: 템플릿 정보

  const EnduranceTrackingScreen({super.key, this.template});

  @override
  State<EnduranceTrackingScreen> createState() => _EnduranceTrackingScreenState();
}

class _EnduranceTrackingScreenState extends State<EnduranceTrackingScreen> with SingleTickerProviderStateMixin {
  late WorkoutTrackingService _service;
  final HeartRateService _hrService = HeartRateService();
  WorkoutState? _currentState;

  // 템플릿 진행 관련
  List<TemplateBlock> _blocks = [];
  int _currentBlockIndex = 0;
  bool _isTemplateMode = false;

  // 카운트다운 관련
  bool _showCountdown = true;
  int _countdown = 3;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _activateMaps();
    _service = Provider.of<WorkoutTrackingService>(context, listen: false);

    // 템플릿 모드 확인
    if (widget.template != null) {
      final sub = widget.template!.subCategory?.toLowerCase() ?? '';
      if (sub.contains('basic') || sub.contains('free')) {
        _isTemplateMode = false; // Basic Run은 기존 Free Run UI 사용
      } else {
        _isTemplateMode = true;
        _blocks = widget.template!.phases.expand((p) => p.blocks).toList();
      }
    }

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
          if (state.isStructured) {
            _currentBlockIndex = state.currentBlockIndex;
          }
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
    _pulseController.forward();

    Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }

      setState(() {
        if (_countdown > 1) {
          _countdown--;
          _pulseController.reset();
          _pulseController.forward();
          HapticFeedback.mediumImpact(); // 숫자 바뀔 때마다 햅틱
        } else {
          _showCountdown = false;
          _pulseController.stop();
          _hrService.startMonitoring();
          _service.startWorkout(template: widget.template);
          timer.cancel();
        }
      });
    });
  }

  Future<void> _activateMaps() async {
    await NativeActivationService().activateGoogleMaps();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _hrService.stopMonitoring();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // 트래킹 중인지 즉시 확인
    final bool isActuallyTracking = _service.isTracking;

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: SafeArea(
        top: false,
        bottom: false,
        child: _showCountdown
            ? _buildCountdownScreen()
            : (isActuallyTracking
                ? _buildTrackingScreen() // _currentState가 찰나의 순간 null이어도 내부적으로 null check 수행
                : const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(),
                        SizedBox(height: 16),
                        Text('트래킹 엔진을 초기화 중입니다...', style: TextStyle(color: Colors.grey)),
                      ],
                    ),
                  )),
      ),
    );
  }
  /// 카운트다운 화면 (NRC 스타일의 모던 디자인)
  Widget _buildCountdownScreen() {
    return SizedBox.expand( // 전체 화면 확장 강제
      child: Container(
        color: Colors.black,
        child: Stack(
          alignment: Alignment.center,
          children: [
            // 배경 장식 (은은한 그라데이션)
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    colors: [
                      Theme.of(context).colorScheme.tertiary.withValues(alpha: 0.15),
                      Colors.transparent,
                    ],
                    radius: 0.8,
                  ),
                ),
              ),
            ),

            // 상단 타이틀 (더 여유 있는 상단 배치)
            Positioned(
              top: MediaQuery.of(context).padding.top + 60,
              child: Column(
                children: [
                  Text(
                    'READY TO RUN',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 4,
                      color: Theme.of(context).colorScheme.tertiary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    width: 40,
                    height: 2,
                    color: Theme.of(context).colorScheme.tertiary,
                  ),
                ],
              ),
            ),

            // 중앙 숫자 애니메이션 (완전 중앙)
            Center(
              child: AnimatedBuilder(
                animation: _pulseAnimation,
                builder: (context, child) {
                  return Opacity(
                    opacity: (1.5 - _pulseAnimation.value).clamp(0.0, 1.0),
                    child: Transform.scale(
                      scale: _pulseAnimation.value,
                      child: Text(
                        '$_countdown',
                        style: TextStyle(
                          fontSize: 200, // 더 크게
                          fontWeight: FontWeight.w900,
                          color: Theme.of(context).colorScheme.tertiary,
                          fontStyle: FontStyle.italic,
                          height: 1,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),

            // 하단 안내
            Positioned(
              bottom: MediaQuery.of(context).padding.bottom + 80,
              child: Text(
                widget.template?.name.toUpperCase() ?? 'FREE RUN',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.white38,
                  letterSpacing: 2,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 운동 중 추적 화면 (고도화된 퍼포먼스 UI)
  Widget _buildTrackingScreen() {
    // _currentState가 아직 오지 않은 경우(0.1초 미만)를 위한 기본값 처리
    final duration = _currentState?.durationFormatted ?? "00:00:00";
    final isPaused = _currentState?.isPaused ?? false;
    final isAutoPaused = _currentState?.isAutoPaused ?? false;

    return Column(
      children: [
        // 1. 상단 슬림 상태바
        _buildSlimHeader(),
        
        // 2. 템플릿 진행 바
        if (_isTemplateMode) _buildSessionProgressBar(),

        // 3. 메인 지표 영역
        Expanded(
          child: _isTemplateMode 
            ? _buildTemplateTrackingBody() 
            : FreeRunBody(currentState: _currentState ?? _getInitialState()),
        ),

        // 4. 하단 컨트롤 버튼
        _buildControls(),
      ],
    );
  }

  /// 초기 더미 상태 생성 (데이터 지연 방지용)
  WorkoutState _getInitialState() {
    return WorkoutState(
      isTracking: true,
      isPaused: false,
      duration: Duration.zero,
      distanceMeters: 0,
      currentSpeedMs: 0,
      averagePace: "--:--",
      currentPace: "--:--",
      calories: 0,
      routePointsCount: 0,
    );
  }

  Widget _buildSessionProgressBar() {
    return LinearProgressIndicator(
      value: (_currentBlockIndex + 1) / _blocks.length,
      backgroundColor: Colors.white10,
      valueColor: AlwaysStoppedAnimation<Color>(Theme.of(context).colorScheme.tertiary),
      minHeight: 4,
    );
  }

  Widget _buildTemplateTrackingBody() {
    final block = _blocks[_currentBlockIndex];
    final subCategory = widget.template?.subCategory ?? '';

    if (subCategory.contains('Interval') || subCategory.contains('Sprint')) {
      return IntervalTrackingBody(
        currentState: _currentState!,
        currentBlock: block,
        currentBlockIndex: _currentBlockIndex,
        totalBlocks: _blocks.length,
        onNextBlock: _service.advanceBlock,
      );
    } else if (subCategory.contains('LSD') || subCategory.contains('Tempo')) {
      return SteadyStateTrackingBody(
        currentState: _currentState!,
        currentBlock: block,
      );
    } else {
      // Fallback to Free Run style but with block info if possible, or simple interval
      return IntervalTrackingBody(
        currentState: _currentState!,
        currentBlock: block,
        currentBlockIndex: _currentBlockIndex,
        totalBlocks: _blocks.length,
        onNextBlock: _service.advanceBlock,
      );
    }
  }

  Widget _buildSlimHeader() {
    final isPaused = _currentState?.isPaused ?? false;
    final isAutoPaused = _currentState?.isAutoPaused ?? false;
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        color: isPaused 
            ? Colors.orange.withValues(alpha: 0.1) 
            : (isAutoPaused ? Colors.blue.withValues(alpha: 0.1) : Colors.transparent),
        border: Border(bottom: BorderSide(color: Colors.white.withValues(alpha: 0.05))),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Total Distance & Heart Rate
          Row(
            children: [
              if (isAutoPaused)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.blue,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text(
                    'AUTO PAUSE',
                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                )
              else ...[
                HeartRateMonitorWidget(),
                const SizedBox(width: 16),
              ],
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'TOTAL DIST',
                    style: TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.bold),
                  ),
                  Text(
                    _currentState?.distanceKmFormatted ?? '0.00 km',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'monospace',
                    ),
                  ),
                ],
              ),
            ],
          ),
          
          // Elapsed Time
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                'ELAPSED TIME',
                style: TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.bold, letterSpacing: 1),
              ),
              Text(
                _currentState!.durationFormatted,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  fontFamily: 'monospace',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildGridMetric(String label, String value, String unit) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.bold, letterSpacing: 1),
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                value,
                style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900),
              ),
              const SizedBox(width: 4),
              Text(
                unit,
                style: const TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ],
      ),
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
                  color: Theme.of(context).colorScheme.primary,
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
            Theme.of(context).colorScheme.tertiary.withValues(alpha: 0.2),
            Theme.of(context).colorScheme.tertiary.withValues(alpha: 0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Theme.of(context).colorScheme.tertiary.withValues(alpha: 0.3),
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
                  color: Theme.of(context).colorScheme.tertiary,
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
                    color: Theme.of(context).colorScheme.tertiary.withValues(alpha: 0.7),
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
        color: Theme.of(context).colorScheme.tertiary.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Theme.of(context).colorScheme.tertiary,
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
                color: Theme.of(context).colorScheme.tertiary,
              ),
              const SizedBox(width: 8),
              Text(
                '현재 페이스',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).colorScheme.tertiary,
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
                  color: Theme.of(context).colorScheme.tertiary,
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
            : Theme.of(context).colorScheme.tertiary.withValues(alpha: 0.1),
        border: Border(
          bottom: BorderSide(
            color: isPaused
                ? Colors.orange
                : Theme.of(context).colorScheme.tertiary,
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
                    : Theme.of(context).colorScheme.tertiary,
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
                      : Theme.of(context).colorScheme.tertiary,
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
                      : Theme.of(context).colorScheme.tertiary,
                  foregroundColor: Colors.black,
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
    final themeColor = Theme.of(context).colorScheme.tertiary;

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        title: const Text('운동 완료 리포트'),
        backgroundColor: Theme.of(context).colorScheme.surface,
        foregroundColor: Theme.of(context).colorScheme.onSurface,
        automaticallyImplyLeading: false,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 1. Hero Metric: Distance
            Center(
              child: Column(
                children: [
                  Text(
                    'TOTAL DISTANCE',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: themeColor.withValues(alpha: 0.6),
                      letterSpacing: 2,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text(
                        summary.distanceKm,
                        style: TextStyle(
                          fontSize: 80,
                          fontWeight: FontWeight.w900,
                          color: themeColor,
                          height: 1,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'km',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: themeColor.withValues(alpha: 0.7),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 48),

            // 2. Metrics Grid (Row-Column)
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      _buildSummaryGridItem('TIME', summary.durationFormatted, '', Icons.timer, themeColor),
                      _buildSummaryGridItem('AVG PACE', summary.averagePace, '/km', Icons.speed, themeColor),
                    ],
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 20),
                    child: Divider(color: Colors.white10),
                  ),
                  Row(
                    children: [
                      _buildSummaryGridItem('AVG HR', summary.averageHeartRate?.toString() ?? '--', 'bpm', Icons.favorite, themeColor),
                      _buildSummaryGridItem('CALORIES', summary.calories.toStringAsFixed(0), 'kcal', Icons.local_fire_department, themeColor),
                    ],
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 20),
                    child: Divider(color: Colors.white10),
                  ),
                  Row(
                    children: [
                      _buildSummaryGridItem('ELEVATION', summary.elevationGain.toStringAsFixed(0), 'm', Icons.terrain, themeColor),
                      const Expanded(child: SizedBox()), // 여백 채우기
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),

            // 3. Movement Route Map
            if (summary.routePoints.isNotEmpty) ...[
              const Text(
                'MOVEMENT ROUTE',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey, letterSpacing: 1.2),
              ),
              const SizedBox(height: 12),
              _buildResultMap(context, summary.routePoints),
              const SizedBox(height: 32),
            ],

            // 4. Action Button
            ElevatedButton(
              onPressed: () {
                Navigator.popUntil(context, (route) => route.isFirst);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.primary, // Hybrid Color for main action
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(vertical: 18),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30),
                ),
                elevation: 4,
              ),
              child: const Text(
                'BACK TO HOME',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 1.2),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryGridItem(String label, String value, String unit, IconData icon, Color color) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 14, color: Colors.grey),
              const SizedBox(width: 6),
              Text(
                label,
                style: const TextStyle(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                value,
                style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900),
              ),
              if (unit.isNotEmpty) ...[
                const SizedBox(width: 4),
                Text(
                  unit,
                  style: const TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.bold),
                ),
              ],
            ],
          ),
        ],
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
          Icon(icon, size: 32, color: Theme.of(context).colorScheme.tertiary),
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
            color: Theme.of(context).colorScheme.tertiary,
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
