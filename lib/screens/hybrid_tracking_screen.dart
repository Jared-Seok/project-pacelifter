import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:uuid/uuid.dart';
import '../models/templates/workout_template.dart';
import '../models/templates/template_block.dart';
import '../models/sessions/workout_session.dart';
import '../models/sessions/exercise_record.dart';
import '../services/workout_tracking_service.dart';
import '../services/heart_rate_service.dart';
import '../widgets/heart_rate_monitor_widget.dart';
import '../services/workout_history_service.dart';
import '../services/scoring_engine.dart';

/// 하이브리드 전용 통합 트래킹 화면
/// 블록 타입(Endurance/Strength)에 따라 UI가 동적으로 전환됨
class HybridTrackingScreen extends StatefulWidget {
  final WorkoutTemplate template;

  const HybridTrackingScreen({super.key, required this.template});

  @override
  State<HybridTrackingScreen> createState() => _HybridTrackingScreenState();
}

class _HybridTrackingScreenState extends State<HybridTrackingScreen> with SingleTickerProviderStateMixin {
  late List<TemplateBlock> _allBlocks;
  int _currentBlockIndex = 0;
  
  // 상태 관리
  DateTime? _startTime;
  Timer? _totalTimer;
  Duration _elapsed = Duration.zero;
  
  final HeartRateService _hrService = HeartRateService();
  late WorkoutTrackingService _gpsService;
  
  // Endurance 데이터 구독
  WorkoutState? _gpsState;

  @override
  void initState() {
    super.initState();
    _startTime = DateTime.now();
    _allBlocks = widget.template.phases.expand((p) => p.blocks).toList();
    _gpsService = Provider.of<WorkoutTrackingService>(context, listen: false);
    
    _startTimers();
    _hrService.startMonitoring();
    
    // GPS 데이터 리스닝
    _gpsService.workoutStateStream.listen((state) {
      if (mounted) setState(() => _gpsState = state);
    });
  }

  void _startTimers() {
    _totalTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) setState(() => _elapsed = DateTime.now().difference(_startTime!));
    });
  }

  @override
  void dispose() {
    _totalTimer?.cancel();
    _hrService.stopMonitoring();
    super.dispose();
  }

  void _nextBlock() {
    if (_currentBlockIndex < _allBlocks.length - 1) {
      setState(() {
        _currentBlockIndex++;
        // 지구력 블록 시작 시 GPS 서비스 가동 등의 제어 가능
      });
    } else {
      _finishWorkout();
    }
  }

  Future<void> _finishWorkout() async {
    // 종료 및 저장 로직 (통합 데이터 생성)
    final endTime = DateTime.now();
    _hrService.stopMonitoring();
    _gpsService.stopWorkout(); // GPS 종료

    // 세션 저장... (기존 로직 통합 적용)
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    final currentBlock = _allBlocks[_currentBlockIndex];
    final bool isEndurance = currentBlock.type == 'endurance';

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: SafeArea(
        child: Column(
          children: [
            _buildSlimHeader(),
            _buildProgressBar(),
            Expanded(
              child: isEndurance 
                ? _buildEnduranceContent(currentBlock) 
                : _buildStrengthContent(currentBlock),
            ),
            _buildBottomAction(currentBlock),
          ],
        ),
      ),
    );
  }

  Widget _buildSlimHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          HeartRateMonitorWidget(),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              const Text('TOTAL TIME', style: TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.bold)),
              Text(_formatDuration(_elapsed), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, fontFamily: 'monospace')),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildProgressBar() {
    return LinearProgressIndicator(
      value: (_currentBlockIndex + 1) / _allBlocks.length,
      backgroundColor: Colors.white10,
      valueColor: AlwaysStoppedAnimation<Color>(Theme.of(context).colorScheme.secondary),
      minHeight: 4,
    );
  }

  // 지구력 블록용 레이아웃 (Deep Teal 테마)
  Widget _buildEnduranceContent(TemplateBlock block) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(block.name.toUpperCase(), style: TextStyle(color: Theme.of(context).colorScheme.tertiary, fontWeight: FontWeight.bold, letterSpacing: 2)),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(_gpsState?.distanceKm ?? '0.00', style: TextStyle(fontSize: 80, fontWeight: FontWeight.w900, color: Theme.of(context).colorScheme.tertiary)),
            const SizedBox(width: 8),
            const Text('KM', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.grey)),
          ],
        ),
        const SizedBox(height: 32),
        _buildMetricRow('PACE', _gpsState?.currentPace ?? '--:--', '/km'),
      ],
    );
  }

  // 근력/동작 블록용 레이아웃 (Vivid Orange 테마)
  Widget _buildStrengthContent(TemplateBlock block) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(block.name.toUpperCase(), style: TextStyle(color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.bold, letterSpacing: 2)),
        const SizedBox(height: 16),
        if (block.type == 'rest')
          Text('REST', style: TextStyle(fontSize: 80, fontWeight: FontWeight.w900, color: Colors.orangeAccent))
        else
          Column(
            children: [
              Text('${block.reps ?? 0}', style: const TextStyle(fontSize: 100, fontWeight: FontWeight.w900)),
              const Text('REPS', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.grey)),
            ],
          ),
      ],
    );
  }

  Widget _buildMetricRow(String label, String value, String unit) {
    return Column(
      children: [
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.bold)),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(value, style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w900)),
            const SizedBox(width: 4),
            Text(unit, style: const TextStyle(fontSize: 14, color: Colors.grey)),
          ],
        ),
      ],
    );
  }

  Widget _buildBottomAction(TemplateBlock block) {
    final bool isEndurance = block.type == 'endurance';
    final color = isEndurance ? Theme.of(context).colorScheme.tertiary : Theme.of(context).colorScheme.primary;

    return Container(
      padding: const EdgeInsets.all(24),
      child: SafeArea(
        child: ElevatedButton(
          onPressed: _nextBlock,
          style: ElevatedButton.styleFrom(
            backgroundColor: color,
            padding: const EdgeInsets.symmetric(vertical: 20),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          ),
          child: const Center(child: Text('NEXT STEP', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black))),
        ),
      ),
    );
  }

  String _formatDuration(Duration d) {
    String two(int n) => n.toString().padLeft(2, '0');
    return "${two(d.inMinutes.remainder(60))}:${two(d.inSeconds.remainder(60))}";
  }
}
