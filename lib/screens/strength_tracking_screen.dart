import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:pacelifter/models/templates/workout_template.dart';
import 'package:pacelifter/models/templates/template_block.dart';
import 'package:pacelifter/models/sessions/workout_session.dart';
import 'package:pacelifter/models/sessions/exercise_record.dart';
import 'package:pacelifter/services/workout_history_service.dart';
import 'package:pacelifter/services/template_service.dart';
import 'package:uuid/uuid.dart';

class StrengthTrackingScreen extends StatefulWidget {
  final WorkoutTemplate template;

  const StrengthTrackingScreen({
    super.key,
    required this.template,
  });

  @override
  State<StrengthTrackingScreen> createState() => _StrengthTrackingScreenState();
}

class _StrengthTrackingScreenState extends State<StrengthTrackingScreen> {
  // 상태 관리
  final Map<String, List<SetRecord>> _setRecords = {}; // exerciseId -> sets
  final Map<String, bool> _completedExercises = {};
  
  DateTime? _startTime;
  Timer? _timer;
  Duration _elapsed = Duration.zero;
  
  // 휴식 타이머
  Timer? _restTimer;
  int _restSecondsRemaining = 0;
  bool _isResting = false;

  @override
  void initState() {
    super.initState();
    _startTime = DateTime.now();
    _startTimer();
    _initializeRecords();
  }

  void _initializeRecords() {
    for (var phase in widget.template.phases) {
      for (var block in phase.blocks) {
        if (block.type == 'strength' && block.exerciseId != null) {
          final exerciseId = block.exerciseId!;
          if (!_setRecords.containsKey(exerciseId)) {
            // 템플릿에 정의된 세트 수만큼 초기화
            _setRecords[exerciseId] = List.generate(
              block.sets ?? 3,
              (index) => SetRecord(
                setNumber: index + 1,
                repsTarget: block.reps,
                weight: block.weight,
                restSeconds: block.restSeconds,
              ),
            );
          }
        }
      }
    }
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          _elapsed = DateTime.now().difference(_startTime!);
        });
      }
    });
  }

  void _startRestTimer(int seconds) {
    _restTimer?.cancel();
    setState(() {
      _restSecondsRemaining = seconds;
      _isResting = true;
    });

    _restTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          if (_restSecondsRemaining > 0) {
            _restSecondsRemaining--;
          } else {
            _isResting = false;
            timer.cancel();
            // 알림음 or 진동 (추후 구현)
          }
        });
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _restTimer?.cancel();
    super.dispose();
  }

  Future<void> _finishWorkout() async {
    _timer?.cancel();
    final endTime = DateTime.now();

    // 세션 저장 로직
    final exerciseRecords = <ExerciseRecord>[];
    int order = 0;

    _setRecords.forEach((exerciseId, sets) {
      // 완료된 세트만 필터링하거나, 입력된 데이터가 있는 세트만 저장
      final completedSets = sets.where((s) => s.repsCompleted != null || s.weight != null).toList();
      
      if (completedSets.isNotEmpty) {
        final exerciseName = TemplateService.getExerciseById(exerciseId)?.name ?? 'Unknown Exercise';
        
        exerciseRecords.add(ExerciseRecord(
          id: const Uuid().v4(),
          exerciseId: exerciseId,
          exerciseName: exerciseName,
          sets: completedSets,
          order: order++,
          timestamp: endTime,
        ));
      }
    });

    // WorkoutSession 생성 및 저장
    // 실제로는 WorkoutHistoryService를 통해 저장
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
      totalVolume: _calculateTotalVolume(exerciseRecords),
      totalSets: exerciseRecords.fold<int>(0, (sum, r) => sum + r.sets.length),
    );

    // TODO: WorkoutHistoryService.saveSession(session);
    // Hive 박스에 직접 저장 (임시)
    final box = Hive.box<WorkoutSession>('user_workout_history');
    await box.put(session.id, session);

    if (mounted) {
      Navigator.of(context).popUntil((route) => route.isFirst);
      // 요약 화면으로 이동 가능
    }
  }

  double _calculateTotalVolume(List<ExerciseRecord> records) {
    double volume = 0;
    for (var record in records) {
      for (var set in record.sets) {
        if (set.weight != null && set.repsCompleted != null) {
          volume += set.weight! * set.repsCompleted!;
        }
      }
    }
    return volume;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.template.name, style: const TextStyle(fontSize: 16)),
            Text(_formatDuration(_elapsed), style: const TextStyle(fontSize: 12, color: Colors.grey)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: _finishWorkout,
            child: const Text('완료'),
          )
        ],
      ),
      body: Column(
        children: [
          if (_isResting)
            Container(
              color: Theme.of(context).colorScheme.primaryContainer,
              padding: const EdgeInsets.all(8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.timer),
                  const SizedBox(width: 8),
                  Text(
                    '휴식 시간: ${_formatRestTime(_restSecondsRemaining)}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(width: 16),
                  TextButton(
                    onPressed: () {
                      _restTimer?.cancel();
                      setState(() => _isResting = false);
                    },
                    child: const Text('건너뛰기'),
                  )
                ],
              ),
            ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: widget.template.phases.expand((phase) {
                return phase.blocks.map((block) {
                  if (block.type != 'strength' || block.exerciseId == null) return const SizedBox.shrink();
                  return _buildExerciseCard(block);
                });
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExerciseCard(TemplateBlock block) {
    final exerciseId = block.exerciseId!;
    final exercise = TemplateService.getExerciseById(exerciseId);
    final sets = _setRecords[exerciseId]!;

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  exercise?.nameKo.isNotEmpty == true ? exercise!.nameKo : block.name,
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                IconButton(
                  icon: const Icon(Icons.info_outline),
                  onPressed: () {
                    // 운동 가이드 팝업
                  },
                ),
              ],
            ),
            if (exercise != null)
              Text(
                exercise.primaryMuscles.isNotEmpty ? exercise.primaryMuscles.join(', ') : '',
                style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.primary),
              ),
            const SizedBox(height: 16),
            
            // 헤더
            const Row(
              children: [
                SizedBox(width: 30, child: Text('Set', textAlign: TextAlign.center)),
                Expanded(child: Text('Previous', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey))),
                SizedBox(width: 80, child: Text('kg', textAlign: TextAlign.center)),
                SizedBox(width: 80, child: Text('Reps', textAlign: TextAlign.center)),
                SizedBox(width: 40), // Checkbox space
              ],
            ),
            const SizedBox(height: 8),

            // 세트 리스트
            ...sets.asMap().entries.map((entry) {
              final index = entry.key;
              final set = entry.value;
              return _buildSetRow(exerciseId, index, set);
            }),

            // 세트 추가 버튼
            TextButton.icon(
              onPressed: () {
                setState(() {
                  _setRecords[exerciseId]!.add(SetRecord(
                    setNumber: sets.length + 1,
                    repsTarget: block.reps,
                    weight: block.weight, // 이전 세트 무게 복사 가능
                  ));
                });
              },
              icon: const Icon(Icons.add),
              label: const Text('세트 추가'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSetRow(String exerciseId, int index, SetRecord set) {
    // 이전 기록 (Mock)
    final previousRecord = index < 2 ? '${set.weight ?? 0}kg x ${set.repsTarget}' : '-';
    
    // 완료 여부 (UI상 임시 처리, 실제로는 repsCompleted 유무로 판단)
    final isCompleted = set.repsCompleted != null;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 30,
            child: Text('${index + 1}', textAlign: TextAlign.center),
          ),
          Expanded(
            child: Text(previousRecord, textAlign: TextAlign.center, style: const TextStyle(color: Colors.grey)),
          ),
          SizedBox(
            width: 80,
            child: TextFormField(
              initialValue: set.weight?.toString(),
              textAlign: TextAlign.center,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                isDense: true,
                contentPadding: EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                border: OutlineInputBorder(),
              ),
              onChanged: (val) {
                set.setWeight(double.tryParse(val)); // SetRecord에 setter 필요하거나 copyWith
              },
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 80,
            child: TextFormField(
              initialValue: set.repsTarget?.toString(), // 초기값은 목표치
              textAlign: TextAlign.center,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                isDense: true,
                contentPadding: EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                border: OutlineInputBorder(),
              ),
              onChanged: (val) {
                // 입력하는 순간 완료된 것으로 간주할지, 체크박스로 할지 결정
                // 여기서는 입력값을 임시 저장
              },
              onFieldSubmitted: (val) {
                 final reps = int.tryParse(val);
                 if (reps != null) {
                   setState(() {
                     // Update record via copyWith or mutable if changed
                     // HiveObject는 mutable하므로 직접 수정 가능
                     // set.repsCompleted = reps; // 필드 접근 제어 필요
                   });
                 }
              },
            ),
          ),
          SizedBox(
            width: 40,
            child: Checkbox(
              value: isCompleted,
              onChanged: (val) {
                setState(() {
                  if (val == true) {
                    // 완료 처리: 현재 입력된 값을 repsCompleted로 확정
                    // 실제 구현 시 컨트롤러를 사용해야 값을 가져오기 쉬움
                    // 여기서는 간소화를 위해 가상의 로직 적용
                    // set.repsCompleted = set.repsTarget; 
                    
                    // 휴식 타이머 시작
                    if (set.restSeconds != null) {
                      _startRestTimer(set.restSeconds!);
                    }
                  } else {
                    // 취소
                    // set.repsCompleted = null;
                  }
                });
              },
            ),
          ),
        ],
      ),
    );
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, "0");
    return "${twoDigits(duration.inHours)}:${twoDigits(duration.inMinutes.remainder(60))}:${twoDigits(duration.inSeconds.remainder(60))}";
  }

  String _formatRestTime(int seconds) {
    int min = seconds ~/ 60;
    int sec = seconds % 60;
    return "$min:${sec.toString().padLeft(2, '0')}";
  }
}

// HiveObject 확장을 위한 임시 헬퍼 (실제 모델 수정 필요할 수 있음)
extension SetRecordHelper on SetRecord {
  void setWeight(double? val) {
    // HiveObject는 final 필드로 생성되었으므로, 실제로는 리스트 내 객체를 교체해야 함
    // 하지만 여기서는 UI 프로토타이핑을 위해 생략
  }
}