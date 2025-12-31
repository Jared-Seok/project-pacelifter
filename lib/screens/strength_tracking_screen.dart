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
import '../services/workout_history_service.dart';
import '../services/scoring_engine.dart';
import '../services/heart_rate_service.dart';
import '../widgets/heart_rate_monitor_widget.dart';

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
  final HeartRateService _hrService = HeartRateService();

  @override
  void initState() {
    super.initState();
    _startTime = DateTime.now();
    _blocks = widget.template.phases.expand((p) => p.blocks).where((b) => b.type == 'strength').toList();
    _initializePlan();
    _startTimers();
    _hrService.startMonitoring();
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

  Future<void> _completeSet() async {
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
    _hrService.stopMonitoring();
    
    final endTime = DateTime.now();
    final exerciseRecords = <ExerciseRecord>[];
    int order = 0;

    // 심박수 통계 계산
    final hrStats = _hrService.getSessionStats();

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
      totalReps: exerciseRecords.fold<int>(0, (sum, r) => sum + r.totalReps),
      averageHeartRate: hrStats['average']?.toInt(),
      maxHeartRate: hrStats['max']?.toInt(),
    );

    await WorkoutHistoryService().saveSession(session);
    
    // 점수 재계산 트리거 (백그라운드)
    ScoringEngine().calculateAndSaveScores();

    if (mounted) {
      // 결과 화면으로 이동 (직접 팝업하지 않고 요약 화면 노출)
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => StrengthWorkoutSummaryScreen(session: session),
        ),
      );
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
      body: SafeArea(
        child: Column(
          children: [
            _buildSlimHeader(),
            _buildProgressIndicator(),
            Expanded(
              child: _buildMainContent(),
            ),
            _buildBottomAction(),
          ],
        ),
      ),
    );
  }

  Widget _buildSlimHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: Colors.white.withValues(alpha: 0.05))),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          HeartRateMonitorWidget(),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              const Text('TOTAL TIME', style: TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.bold)),
              Text(
                _formatDuration(_elapsed),
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, fontFamily: 'monospace'),
              ),
            ],
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

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // 1. 현재 운동 정보 (상단 고정)
          Text(
            'SET ${_currentSetIndex + 1} OF ${sets.length}',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.primary, letterSpacing: 1.5),
          ),
          const SizedBox(height: 8),
          Text(
            exercise?.nameKo ?? currentBlock.name.split(' (')[0],
            style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 48),
          
          // 2. 메인 수치 (세트 진행 중 vs 준비 중)
          if (_status == WorkoutStatus.active)
            Column(
              children: [
                const Text('SET TIMER', style: TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.bold)),
                Text(
                  _formatDurationShort(_setElapsed),
                  style: TextStyle(fontSize: 100, fontWeight: FontWeight.w900, fontFamily: 'monospace', color: Theme.of(context).colorScheme.primary),
                ),
              ],
            )
          else
            Column(
              children: [
                const Text('GOAL', style: TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text('${currentSet.weight?.toStringAsFixed(1).replaceAll(RegExp(r'\.0$'), '') ?? 0}', 
                      style: const TextStyle(fontSize: 80, fontWeight: FontWeight.w900)),
                    const SizedBox(width: 8),
                    const Text('KG', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.grey)),
                  ],
                ),
                Text('x ${currentSet.repsTarget ?? 0} REPS', 
                  style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.grey)),
              ],
            ),
          
          const SizedBox(height: 64),
        ],
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
                style: const TextStyle(fontSize: 100, fontWeight: FontWeight.w900, fontFamily: 'monospace', color: Colors.orangeAccent)),
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
            style: const TextStyle(fontSize: 100, fontWeight: FontWeight.w900, fontFamily: 'monospace', color: Colors.orangeAccent)),
          const SizedBox(height: 24),
          const Divider(indent: 40, endIndent: 40),
          const SizedBox(height: 16),
          Text('다음 세트 편집', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.primary)),
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
        Text(value, style: const TextStyle(fontSize: 56, fontWeight: FontWeight.w900)),
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
          const Text('웜업 스테이지', style: TextStyle(fontSize: 36, fontWeight: FontWeight.w900)),
          const SizedBox(height: 16),
          const Text('가벼운 스트레칭으로\n부상을 예방하고 근육을 활성화하세요', textAlign: TextAlign.center, style: TextStyle(fontSize: 18, color: Colors.grey)),
        ],
      ),
    );
  }

  Widget _buildFinishedView() {
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

    final totalVolume = exerciseRecords.fold<double>(0.0, (sum, r) => sum + r.totalVolume);
    final totalSets = exerciseRecords.fold<int>(0, (sum, r) => sum + r.sets.length);

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.check_circle_outline, size: 100, color: Colors.greenAccent),
          const SizedBox(height: 24),
          const Text('모든 운동 완료!', style: TextStyle(fontSize: 36, fontWeight: FontWeight.w900)),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildFinishedStat('총 볼륨', totalVolume >= 1000 ? '${(totalVolume / 1000).toStringAsFixed(2)}t' : '${totalVolume.toInt()}kg'),
              const SizedBox(width: 32),
              _buildFinishedStat('총 세트', '$totalSets회'),
            ],
          ),
          const SizedBox(height: 24),
          const Text('수고하셨습니다.\n오늘의 기록을 저장하고 마무리하세요.', textAlign: TextAlign.center, style: TextStyle(fontSize: 18, color: Colors.grey)),
        ],
      ),
    );
  }

  Widget _buildFinishedStat(String label, String value) {
    return Column(
      children: [
        Text(label, style: const TextStyle(fontSize: 14, color: Colors.grey)),
        const SizedBox(height: 4),
        Text(value, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white)),
      ],
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
      case WorkoutStatus.finished: label = "기록 저장 및 종료"; onPressed = _finishWorkout; color = Theme.of(context).colorScheme.primary; break;
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

/// 근력 운동 완료 요약 화면
class StrengthWorkoutSummaryScreen extends StatelessWidget {
  final WorkoutSession session;

  const StrengthWorkoutSummaryScreen({super.key, required this.session});

  @override
  Widget build(BuildContext context) {
    final themeColor = Theme.of(context).colorScheme.primary;
    final totalVol = session.totalVolume ?? 0;

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        title: const Text('근력 운동 완료 리포트'),
        automaticallyImplyLeading: false,
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 1. Hero Metric: Total Volume
            Center(
              child: Column(
                children: [
                  Text(
                    'TOTAL VOLUME',
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
                        totalVol >= 1000 
                          ? (totalVol / 1000).toStringAsFixed(2) 
                          : totalVol.toStringAsFixed(0),
                        style: TextStyle(
                          fontSize: 80,
                          fontWeight: FontWeight.w900,
                          color: themeColor,
                          height: 1,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        totalVol >= 1000 ? 't' : 'kg',
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

            // 2. Stats Grid
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
                      _buildStatItem('TOTAL SETS', '${session.totalSets ?? 0}', '회', Icons.repeat, themeColor),
                      _buildStatItem('TOTAL REPS', '${session.totalReps ?? 0}', '회', Icons.fitness_center, themeColor),
                    ],
                  ),
                  const Padding(padding: EdgeInsets.symmetric(vertical: 20), child: Divider(color: Colors.white10)),
                  Row(
                    children: [
                      _buildStatItem('WORKOUT TIME', _formatDuration(Duration(seconds: session.activeDuration)), '', Icons.timer, themeColor),
                      _buildStatItem('AVG HEART RATE', '${session.averageHeartRate ?? "--"}', 'bpm', Icons.favorite, themeColor),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),

            // 3. Exercise List
            const Text(
              'EXERCISE DETAILS',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey, letterSpacing: 1.2),
            ),
            const SizedBox(height: 12),
            ...session.exerciseRecords?.map((r) => _buildExerciseRow(r, themeColor)) ?? [],
            
            const SizedBox(height: 40),

            // 4. Action Button
            ElevatedButton(
              onPressed: () => Navigator.popUntil(context, (route) => route.isFirst),
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.secondary,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(vertical: 18),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
              ),
              child: const Text('BACK TO HOME', style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.2)),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(String label, String value, String unit, IconData icon, Color color) {
    return Expanded(
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 12, color: Colors.grey),
              const SizedBox(width: 4),
              Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(value, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
              if (unit.isNotEmpty) Text(unit, style: const TextStyle(fontSize: 12, color: Colors.grey)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildExerciseRow(ExerciseRecord record, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(child: Text(record.exerciseName, style: const TextStyle(fontWeight: FontWeight.w600))),
          Text(
            '${record.sets.length} sets',
            style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 13),
          ),
        ],
      ),
    );
  }

  String _formatDuration(Duration d) {
    final m = d.inMinutes;
    final s = d.inSeconds.remainder(60);
    return "$m:$s";
  }
}
