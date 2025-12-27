import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:uuid/uuid.dart';
import '../models/templates/workout_template.dart';
import '../models/templates/template_block.dart';
import '../models/exercises/exercise.dart';
import '../models/sessions/workout_session.dart';
import '../models/sessions/exercise_record.dart';
import '../services/template_service.dart';

enum WorkoutStatus { warmup, ready, active, rest, finished }

class StrengthTrackingScreen extends StatefulWidget {
  final WorkoutTemplate template;
  final Map<String, List<SetRecord>>? manualPlan;

  const StrengthTrackingScreen({
    super.key,
    required this.template,
    this.manualPlan,
  });

  @override
  State<StrengthTrackingScreen> createState() => _StrengthTrackingScreenState();
}

class _StrengthTrackingScreenState extends State<StrengthTrackingScreen> {
  late List<TemplateBlock> _blocks;
  final Map<String, List<SetRecord>> _workoutPlan = {};
  
  int _currentBlockIndex = 0;
  int _currentSetIndex = 0;
  WorkoutStatus _status = WorkoutStatus.warmup;

  DateTime? _startTime;
  DateTime? _setStartTime;
  Timer? _totalTimer;
  Duration _elapsed = Duration.zero;
  Duration _setElapsed = Duration.zero;
  
  Timer? _restTimer;
  int _restSecondsRemaining = 0;

  @override
  void initState() {
    super.initState();
    _startTime = DateTime.now();
    _blocks = widget.template.phases.expand((p) => p.blocks).where((b) => b.type == 'strength').toList();
    _initializePlan();
    _startTimers();
  }

  void _initializePlan() {
    if (widget.manualPlan != null) {
      widget.manualPlan!.forEach((key, value) {
        _workoutPlan[key] = List.from(value);
      });
    } else {
      for (var block in _blocks) {
        if (block.exerciseId != null) {
          _workoutPlan[block.id] = List.generate(
            block.sets ?? 3,
            (index) => SetRecord(
              setNumber: index + 1,
              repsTarget: block.reps,
              weight: block.weight,
              restSeconds: block.restSeconds ?? 60,
            ),
          );
        }
      }
    }
  }

  void _startTimers() {
    _totalTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          _elapsed = DateTime.now().difference(_startTime!);
          if (_status == WorkoutStatus.active && _setStartTime != null) {
            _setElapsed = DateTime.now().difference(_setStartTime!);
          }
        });
      }
    });
  }

  void _startRestTimer(int seconds) {
    _restTimer?.cancel();
    setState(() {
      _restSecondsRemaining = seconds;
      _status = WorkoutStatus.rest;
    });

    _restTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          if (_restSecondsRemaining > 0) {
            _restSecondsRemaining--;
          } else {
            _restTimer?.cancel();
            _goToNextSet();
          }
        });
      }
    });
  }

  void _goToNextSet() {
    final currentBlock = _blocks[_currentBlockIndex];
    final sets = _workoutPlan[currentBlock.id]!;

    if (_currentSetIndex < sets.length - 1) {
      setState(() {
        _currentSetIndex++;
        _status = WorkoutStatus.ready;
        _setElapsed = Duration.zero;
      });
    } else if (_currentBlockIndex < _blocks.length - 1) {
      setState(() {
        _currentBlockIndex++;
        _currentSetIndex = 0;
        _status = WorkoutStatus.ready;
        _setElapsed = Duration.zero;
      });
    } else {
      setState(() {
        _status = WorkoutStatus.finished;
      });
    }
  }

  void _startSet() {
    setState(() {
      _status = WorkoutStatus.active;
      _setStartTime = DateTime.now();
      _setElapsed = Duration.zero;
    });
  }

  void _completeSet() {
    final currentBlock = _blocks[_currentBlockIndex];
    final sets = _workoutPlan[currentBlock.id]!;
    final currentSet = sets[_currentSetIndex];

    _workoutPlan[currentBlock.id]![_currentSetIndex] = currentSet.copyWith(
      repsCompleted: currentSet.repsTarget,
    );

    _startRestTimer(currentSet.restSeconds ?? 60);
  }

  Future<void> _finishWorkout() async {
    _totalTimer?.cancel();
    _restTimer?.cancel();
    
    final endTime = DateTime.now();
    final exerciseRecords = <ExerciseRecord>[];
    int order = 0;

    _workoutPlan.forEach((blockId, sets) {
      final block = _blocks.firstWhere((b) => b.id == blockId);
      final completedSets = sets.where((s) => s.repsCompleted != null).toList();
      
      if (completedSets.isNotEmpty) {
        exerciseRecords.add(ExerciseRecord(
          id: const Uuid().v4(),
          exerciseId: block.exerciseId!,
          exerciseName: block.name,
          sets: completedSets,
          order: order++,
          timestamp: endTime,
        ));
      }
    });

    final session = WorkoutSession(
      id: const Uuid().v4(),
      templateId: widget.template.id,
      templateName: widget.template.name,
      category: 'Strength',
      startTime: _startTime!,
      endTime: endTime,
      activeDuration: _elapsed.inSeconds,
      totalDuration: _elapsed.inSeconds,
      exerciseRecords: exerciseRecords,
      totalVolume: exerciseRecords.fold<double>(0.0, (sum, r) => sum + r.totalVolume),
      totalSets: exerciseRecords.fold<int>(0, (sum, r) => sum + r.sets.length),
    );

    final box = await Hive.openBox<WorkoutSession>('user_workout_history');
    await box.put(session.id, session);

    if (mounted) {
      Navigator.of(context).popUntil((route) => route.isFirst);
    }
  }

  @override
  void dispose() {
    _totalTimer?.cancel();
    _restTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        title: Text(widget.template.name, style: const TextStyle(fontSize: 16)),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => Navigator.pop(context),
          )
        ],
      ),
      body: Column(
        children: [
          _buildTotalTimeBanner(),
          _buildProgressIndicator(),
          Expanded(
            child: _buildMainContent(),
          ),
          _buildBottomAction(),
        ],
      ),
    );
  }

  Widget _buildTotalTimeBanner() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16),
      width: double.infinity,
      color: Theme.of(context).colorScheme.surfaceContainer,
      child: Column(
        children: [
          const Text('전체 운동 시간', style: TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text(
            _formatDuration(_elapsed),
            style: const TextStyle(fontSize: 42, fontWeight: FontWeight.black, fontFamily: 'monospace', letterSpacing: 2),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressIndicator() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(_blocks.length, (index) {
          final isCurrent = index == _currentBlockIndex;
          final isCompleted = index < _currentBlockIndex;
          return Container(
            margin: const EdgeInsets.symmetric(horizontal: 4),
            width: 30,
            height: 6,
            decoration: BoxDecoration(
              color: isCurrent 
                ? Theme.of(context).colorScheme.primary 
                : (isCompleted ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.4) : Colors.grey[800]),
              borderRadius: BorderRadius.circular(3),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildMainContent() {
    if (_status == WorkoutStatus.warmup) return _buildWarmupView();
    if (_status == WorkoutStatus.finished) return _buildFinishedView();
    if (_status == WorkoutStatus.rest) return _buildRestView();

    final currentBlock = _blocks[_currentBlockIndex];
    final exercise = TemplateService.getExerciseById(currentBlock.exerciseId!);
    final sets = _workoutPlan[currentBlock.id]!;
    final currentSet = sets[_currentSetIndex];

    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildExerciseHeader(exercise, currentBlock),
            const SizedBox(height: 24),
            
            // 세트 타이머 (Active 일 때 크게 표시)
            if (_status == WorkoutStatus.active) ...[
              const Text('세트 진행 시간', style: TextStyle(fontSize: 14, color: Colors.blueAccent, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text(
                _formatDurationShort(_setElapsed),
                style: const TextStyle(fontSize: 72, fontWeight: FontWeight.bold, fontFamily: 'monospace', color: Colors.white),
              ),
            ] else ...[
              Text('SET ${_currentSetIndex + 1} / ${sets.length}', 
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.grey)),
              const SizedBox(height: 12),
              const Text('준비 되셨나요?', style: TextStyle(fontSize: 16, color: Colors.white70)),
            ],
            
            const SizedBox(height: 32),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildInfoBit('${currentSet.weight?.toStringAsFixed(1).replaceAll(RegExp(r'\.0$'), '') ?? 0}', 'KG'),
                Container(width: 1, height: 60, color: Colors.grey[800], margin: const EdgeInsets.symmetric(horizontal: 32)),
                _buildInfoBit('${currentSet.repsTarget ?? 0}', 'REPS'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRestView() {
    TemplateBlock nextBlock = _blocks[_currentBlockIndex];
    int nextSetIdx = _currentSetIndex + 1;
    final currentSets = _workoutPlan[nextBlock.id]!;

    if (nextSetIdx >= currentSets.length) {
      if (_currentBlockIndex < _blocks.length - 1) {
        nextBlock = _blocks[_currentBlockIndex + 1];
        nextSetIdx = 0;
      } else {
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('마지막 휴식', style: TextStyle(fontSize: 24, color: Colors.grey)),
              const SizedBox(height: 24),
              Text(_formatRestTime(_restSecondsRemaining), 
                style: const TextStyle(fontSize: 100, fontWeight: FontWeight.black, fontFamily: 'monospace', color: Colors.orangeAccent)),
            ],
          ),
        );
      }
    }

    final exercise = TemplateService.getExerciseById(nextBlock.exerciseId!);
    final nextSet = _workoutPlan[nextBlock.id]![nextSetIdx];

    return SingleChildScrollView(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text('휴식 중', style: TextStyle(fontSize: 20, color: Colors.grey, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text(_formatRestTime(_restSecondsRemaining), 
            style: const TextStyle(fontSize: 100, fontWeight: FontWeight.black, fontFamily: 'monospace', color: Colors.orangeAccent)),
          const SizedBox(height: 24),
          const Divider(indent: 40, endIndent: 40),
          const SizedBox(height: 16),
          const Text('다음 세트 편집', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.blueAccent)),
          const SizedBox(height: 12),
          _buildExerciseHeader(exercise, nextBlock, small: true),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildUpcomingAdjuster('무게', nextSet.weight ?? 0, (val) {
                setState(() {
                  _workoutPlan[nextBlock.id]![nextSetIdx] = nextSet.copyWith(weight: (val * 10).round() / 10.0);
                });
              }, 2.5, 'kg'),
              const SizedBox(width: 24),
              _buildUpcomingAdjuster('횟수', (nextSet.repsTarget ?? 0).toDouble(), (val) {
                setState(() {
                  _workoutPlan[nextBlock.id]![nextSetIdx] = nextSet.copyWith(repsTarget: val.toInt());
                });
              }, 1, '회'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildUpcomingAdjuster(String label, double value, Function(double) onChanged, double step, String unit) {
    return Column(
      children: [
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(color: Colors.grey[900], borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.white10)),
          child: Row(
            children: [
              IconButton(onPressed: () => onChanged(value - step), icon: const Icon(Icons.remove, size: 18, color: Colors.redAccent)),
              Text('${value.toStringAsFixed(1).replaceAll(RegExp(r'\.0$'), '')}$unit', 
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              IconButton(onPressed: () => onChanged(value + step), icon: const Icon(Icons.add, size: 18, color: Colors.blueAccent)),
            ],
          ),
        )
      ],
    );
  }

  Widget _buildExerciseHeader(Exercise? exercise, TemplateBlock block, {bool small = false}) {
    return Column(
      children: [
        Container(
          width: small ? 50 : 80, height: small ? 50 : 80,
          padding: EdgeInsets.all(small ? 10 : 16),
          decoration: BoxDecoration(color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1), shape: BoxShape.circle),
          child: SvgPicture.asset(exercise?.imagePath ?? 'assets/images/strength/lifter-icon.svg', 
            colorFilter: ColorFilter.mode(Theme.of(context).colorScheme.primary, BlendMode.srcIn)),
        ),
        SizedBox(height: small ? 10 : 20),
        Text(exercise?.nameKo ?? block.name.split(' (')[0], 
          style: TextStyle(fontSize: small ? 18 : 26, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
        if (!small) ...[
          const SizedBox(height: 6),
          Text(block.name.contains(' (') ? block.name.substring(block.name.indexOf(' (') + 1, block.name.length - 1) : (block.selectedVariations?.join(', ') ?? '기본 설정'),
            style: TextStyle(fontSize: 15, color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.w500)),
        ]
      ],
    );
  }

  Widget _buildInfoBit(String value, String unit) {
    return Column(
      children: [
        Text(value, style: const TextStyle(fontSize: 56, fontWeight: FontWeight.black)),
        Text(unit, style: const TextStyle(fontSize: 14, color: Colors.grey, fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _buildWarmupView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.wb_sunny_outlined, size: 100, color: Colors.orangeAccent),
          const SizedBox(height: 24),
          const Text('웜업 스테이지', style: TextStyle(fontSize: 36, fontWeight: FontWeight.black)),
          const SizedBox(height: 16),
          const Text('가벼운 스트레칭으로\n부상을 예방하고 근육을 활성화하세요', textAlign: TextAlign.center, style: TextStyle(fontSize: 18, color: Colors.grey)),
        ],
      ),
    );
  }

  Widget _buildFinishedView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.check_circle_outline, size: 100, color: Colors.greenAccent),
          const SizedBox(height: 24),
          const Text('모든 운동 완료!', style: TextStyle(fontSize: 36, fontWeight: FontWeight.black)),
          const SizedBox(height: 16),
          const Text('수고하셨습니다.\n오늘의 기록을 저장하고 마무리하세요.', textAlign: TextAlign.center, style: TextStyle(fontSize: 18, color: Colors.grey)),
        ],
      ),
    );
  }

  Widget _buildBottomAction() {
    String label = "";
    VoidCallback? onPressed;
    Color color = Theme.of(context).colorScheme.primary;

    switch (_status) {
      case WorkoutStatus.warmup: label = "운동 시작하기"; onPressed = () => setState(() => _status = WorkoutStatus.ready); break;
      case WorkoutStatus.ready: label = "세트 시작"; onPressed = _startSet; break;
      case WorkoutStatus.active: label = "세트 완료"; onPressed = _completeSet; color = Colors.green; break;
      case WorkoutStatus.rest: label = "휴식 건너뛰기"; onPressed = () => setState(() { _restTimer?.cancel(); _goToNextSet(); }); color = Colors.orange; break;
      case WorkoutStatus.finished: label = "기록 저장 및 종료"; onPressed = _finishWorkout; color = Colors.blue; break;
    }

    return Container(
      padding: const EdgeInsets.all(24),
      width: double.infinity,
      child: SafeArea(
        child: ElevatedButton(
          onPressed: onPressed,
          style: ElevatedButton.styleFrom(
            backgroundColor: color,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 22),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            elevation: 8,
          ),
          child: Text(label, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
        ),
      ),
    );
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, "0");
    return "${twoDigits(duration.inHours)}:${twoDigits(duration.inMinutes.remainder(60))}:${twoDigits(duration.inSeconds.remainder(60))}";
  }

  String _formatDurationShort(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, "0");
    return "${twoDigits(duration.inMinutes.remainder(60))}:${twoDigits(duration.inSeconds.remainder(60))}";
  }

  String _formatRestTime(int seconds) {
    int min = seconds ~/ 60;
    int sec = seconds % 60;
    return "$min:${sec.toString().padLeft(2, '0')}";
  }
}
