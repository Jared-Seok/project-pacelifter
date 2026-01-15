import 'package:flutter/material.dart';
import 'dart:async';
import '../../../models/templates/template_block.dart';
import '../../../services/workout_tracking_service.dart';

class IntervalTrackingBody extends StatefulWidget {
  final WorkoutState currentState;
  final TemplateBlock currentBlock;
  final int currentBlockIndex;
  final int totalBlocks;
  final VoidCallback onNextBlock;

  const IntervalTrackingBody({
    super.key,
    required this.currentState,
    required this.currentBlock,
    required this.currentBlockIndex,
    required this.totalBlocks,
    required this.onNextBlock,
  });

  @override
  State<IntervalTrackingBody> createState() => _IntervalTrackingBodyState();
}

class _IntervalTrackingBodyState extends State<IntervalTrackingBody> {
  // 상태 제어
  bool _isPreStartCountdown = false;
  int _countdownValue = 10;
  Timer? _countdownTimer;

  bool _isLapSummary = false;
  int _summaryCountdown = 10;
  Timer? _summaryTimer;

  // 랩 통계 저장 (요약용)
  String _lastLapPace = "--:--";
  int? _lastLapHeartRate;
  Duration _lastLapDuration = Duration.zero;

  int _lastProcessedBlockIndex = -1;

  @override
  void initState() {
    super.initState();
    _handleBlockTransition(null);
  }

  @override
  void didUpdateWidget(IntervalTrackingBody oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.currentBlockIndex != oldWidget.currentBlockIndex) {
      _handleBlockTransition(oldWidget.currentBlock);
    }
  }

  void _handleBlockTransition(TemplateBlock? previousBlock) {
    if (_lastProcessedBlockIndex == widget.currentBlockIndex) return;
    _lastProcessedBlockIndex = widget.currentBlockIndex;

    // 1. Fast(인터벌) 블록이 끝난 경우 -> 요약 화면 시작
    if (previousBlock != null && _isFastBlock(previousBlock)) {
      _saveLapStats();
      _startLapSummary();
    } 
    // 2. 현재 블록이 Fast인데, 웜업/쿨다운에서 바로 넘어온 경우 등 (Summary가 없을 때만)
    else if (_isFastBlock(widget.currentBlock) && !_isLapSummary) {
      _startPreWorkCountdown();
    } 
    // 3. 그 외 (Recovery 진입 등) -> 카운트다운 중지 (build()에서 잔여시간 기반 제어)
    else {
      _stopCountdowns();
    }
  }

  void _saveLapStats() {
    _lastLapDuration = widget.currentState.lastBlockDuration ?? Duration.zero;
    _lastLapPace = widget.currentState.currentPace;
    _lastLapHeartRate = widget.currentState.heartRate;
  }

  bool _isFastBlock(TemplateBlock block) {
    if (block.type == 'rest') return false;
    final name = block.name.toLowerCase();
    if (name.contains('warm') || name.contains('cool') || name.contains('jog') || name.contains('easy') || name.contains('slow')) return false;
    return true;
  }

  bool _isRestBlock(TemplateBlock block) {
    return block.type == 'rest' || block.name.toLowerCase().contains('recovery') || block.name.toLowerCase().contains('rest');
  }

  // --- 타이머 ---
  void _startPreWorkCountdown() {
    _stopCountdowns();
    if (!mounted) return;
    setState(() {
      _isPreStartCountdown = true;
      _countdownValue = 10;
    });
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      setState(() {
        if (_countdownValue > 1) {
          _countdownValue--;
        } else {
          _isPreStartCountdown = false;
          timer.cancel();
        }
      });
    });
  }

  void _startLapSummary() {
    _stopCountdowns();
    if (!mounted) return;
    setState(() {
      _isLapSummary = true;
      _summaryCountdown = 10;
    });
    _summaryTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      setState(() {
        if (_summaryCountdown > 1) {
          _summaryCountdown--;
        } else {
          _isLapSummary = false;
          timer.cancel();
          // 요약이 끝났는데 다음 블록이 바로 Fast라면 카운트다운 시작
          if (_isFastBlock(widget.currentBlock)) {
            _startPreWorkCountdown();
          }
        }
      });
    });
  }

  void _stopCountdowns() {
    _countdownTimer?.cancel();
    _summaryTimer?.cancel();
    if (mounted) {
      setState(() {
        _isPreStartCountdown = false;
        _isLapSummary = false;
      });
    }
  }

  @override
  void dispose() {
    _stopCountdowns();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLapSummary) return _buildLapSummaryOverlay();

    // Recovery(Rest) 블록 특수 처리: 10초 전 카운트다운
    if (_isRestBlock(widget.currentBlock)) {
      final target = widget.currentBlock.targetDuration ?? 0;
      final elapsed = widget.currentState.currentBlockDuration.inSeconds;
      final remaining = (target - elapsed).clamp(0, target);

      if (remaining <= 10 && remaining > 0) {
        return _buildCountdownOverlay(remaining);
      }
      return _buildRestUI(remaining);
    }

    // 일반 Fast 블록 시작 전 카운트다운
    if (_isPreStartCountdown) return _buildCountdownOverlay(_countdownValue);

    if (_isFastBlock(widget.currentBlock)) {
      return _buildWorkUI();
    } else {
      return _buildJogUI(); // Warm-up, Cool-down
    }
  }

  // --- UI Components ---

  Widget _buildCountdownOverlay(int seconds) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text('GET READY', style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.orangeAccent, letterSpacing: 2)),
          const SizedBox(height: 20),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text('$seconds', style: const TextStyle(fontSize: 140, fontWeight: FontWeight.w900)),
          ),
          const SizedBox(height: 20),
          Text("NEXT: ${widget.currentBlock.name.toUpperCase()}", style: const TextStyle(fontSize: 18, color: Colors.grey)),
        ],
      ),
    );
  }

  Widget _buildLapSummaryOverlay() {
    final dur = _lastLapDuration;
    final timeStr = "${dur.inMinutes}:${(dur.inSeconds % 60).toString().padLeft(2, '0')}";
    return Container(
      color: Colors.black,
      width: double.infinity,
      child: Column(
        children: [
          const SizedBox(height: 40),
          const Text('LAP COMPLETED', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.greenAccent, letterSpacing: 1.2)),
          const Spacer(flex: 2),
          _buildSummaryRow("TIME", timeStr),
          const SizedBox(height: 30),
          _buildSummaryRow("PACE", _lastLapPace),
          const SizedBox(height: 30),
          _buildSummaryRow("AVG HR", "${_lastLapHeartRate ?? '--'} bpm"),
          const Spacer(flex: 3),
          Text("Next step in $_summaryCountdown...", style: const TextStyle(color: Colors.grey, fontSize: 16)),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildSummaryRow(String label, String value) {
    return Column(
      children: [
        Text(label, style: const TextStyle(color: Colors.grey, fontSize: 14, fontWeight: FontWeight.bold)),
        Text(value, style: const TextStyle(fontSize: 52, fontWeight: FontWeight.w900, color: Colors.white)),
      ],
    );
  }

  Widget _buildWorkUI() {
    final themeColor = Colors.orangeAccent;
    return Column(
      children: [
        const SizedBox(height: 20),
        _buildHeader(themeColor),
        const Spacer(),
        _buildLargeMetric(widget.currentState.currentPace, "/km", themeColor),
        const SizedBox(height: 20),
        _buildHRDisplay(56),
        const Spacer(),
        _buildActionButton("LAP", themeColor, widget.onNextBlock),
        const SizedBox(height: 40),
      ],
    );
  }

  Widget _buildRestUI(int remaining) {
    final themeColor = Colors.lightBlueAccent;
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Text('RECOVERY', style: TextStyle(fontSize: 32, fontWeight: FontWeight.w900, color: Colors.lightBlueAccent, letterSpacing: 4)),
        const SizedBox(height: 40),
        Text(
          "${remaining ~/ 60}:${(remaining % 60).toString().padLeft(2, '0')}",
          style: const TextStyle(fontSize: 120, fontWeight: FontWeight.bold, fontFamily: 'monospace'),
        ),
        const SizedBox(height: 20),
        _buildHRDisplay(40),
        const SizedBox(height: 60),
        TextButton(onPressed: widget.onNextBlock, child: const Text("SKIP REST", style: TextStyle(color: Colors.lightBlueAccent, fontSize: 18))),
      ],
    );
  }

  Widget _buildJogUI() {
    final themeColor = Theme.of(context).colorScheme.tertiary;
    final elapsed = widget.currentState.currentBlockDuration;
    return Column(
      children: [
        const SizedBox(height: 20),
        _buildHeader(themeColor),
        const Spacer(),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _buildSmallMetric("PACE", widget.currentState.currentPace),
            _buildSmallMetric("TIME", "${elapsed.inMinutes}:${(elapsed.inSeconds % 60).toString().padLeft(2, '0')}"),
          ],
        ),
        const SizedBox(height: 40),
        _buildHRDisplay(48),
        const Spacer(),
        _buildActionButton("NEXT", themeColor, widget.onNextBlock),
        const SizedBox(height: 40),
      ],
    );
  }

  Widget _buildHeader(Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(20), border: Border.all(color: color.withOpacity(0.5))),
      child: Text('${widget.currentBlockIndex + 1}/${widget.totalBlocks} • ${widget.currentBlock.name.toUpperCase()}', style: TextStyle(fontWeight: FontWeight.bold, color: color)),
    );
  }

  Widget _buildLargeMetric(String value, String unit, Color color) {
    return FittedBox(
      fit: BoxFit.scaleDown,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          Text(value, style: TextStyle(fontSize: 110, fontWeight: FontWeight.w900, color: color, height: 1)),
          const SizedBox(width: 8),
          Text(unit, style: TextStyle(fontSize: 28, color: color.withOpacity(0.7))),
        ],
      ),
    );
  }

  Widget _buildHRDisplay(double fontSize) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.favorite, color: Colors.red, size: 32),
        const SizedBox(width: 12),
        Text(widget.currentState.heartRate?.toString() ?? '--', style: TextStyle(fontSize: fontSize, fontWeight: FontWeight.bold)),
        const SizedBox(width: 6),
        const Text('bpm', style: TextStyle(color: Colors.grey, fontSize: 18)),
      ],
    );
  }

  Widget _buildSmallMetric(String label, String value) {
    return Column(
      children: [
        Text(label, style: const TextStyle(color: Colors.grey, fontSize: 14, fontWeight: FontWeight.bold)),
        Text(value, style: const TextStyle(fontSize: 40, fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _buildActionButton(String label, Color color, VoidCallback onPressed) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: SizedBox(
        width: double.infinity,
        height: 80,
        child: ElevatedButton(
          onPressed: onPressed,
          style: ElevatedButton.styleFrom(backgroundColor: color, foregroundColor: Colors.black, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20))),
          child: Text(label, style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w900, letterSpacing: 2)),
        ),
      ),
    );
  }
}
