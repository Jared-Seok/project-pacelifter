import 'package:hive/hive.dart';

part 'exercise_record.g.dart';

/// 개별 운동 기록 모델
/// Strength 운동의 세트/렙/무게 등을 기록
@HiveType(typeId: 5)
class ExerciseRecord extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String exerciseId; // Exercise ID 참조

  @HiveField(2)
  final String exerciseName; // 운동 이름 (삭제된 운동 대비)

  @HiveField(3)
  final List<SetRecord> sets; // 세트 기록 리스트

  @HiveField(4)
  final int order; // 운동 순서

  @HiveField(5)
  final String? notes; // 메모

  @HiveField(6)
  final DateTime timestamp; // 기록 시간

  @HiveField(7)
  final double? estimated1RM; // 추정 1RM (계산됨)

  @HiveField(8)
  final bool isPR; // Personal Record 달성 여부

  ExerciseRecord({
    required this.id,
    required this.exerciseId,
    required this.exerciseName,
    required this.sets,
    required this.order,
    this.notes,
    required this.timestamp,
    this.estimated1RM,
    this.isPR = false,
  });

  /// JSON에서 운동 기록 생성
  factory ExerciseRecord.fromJson(Map<String, dynamic> json) {
    return ExerciseRecord(
      id: json['id'] as String,
      exerciseId: json['exerciseId'] as String,
      exerciseName: json['exerciseName'] as String,
      sets: (json['sets'] as List)
          .map((set) => SetRecord.fromJson(set as Map<String, dynamic>))
          .toList(),
      order: json['order'] as int,
      notes: json['notes'] as String?,
      timestamp: DateTime.parse(json['timestamp'] as String),
      estimated1RM: json['estimated1RM'] != null
          ? (json['estimated1RM'] as num).toDouble()
          : null,
      isPR: json['isPR'] as bool? ?? false,
    );
  }

  /// JSON으로 변환
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'exerciseId': exerciseId,
      'exerciseName': exerciseName,
      'sets': sets.map((set) => set.toJson()).toList(),
      'order': order,
      'notes': notes,
      'timestamp': timestamp.toIso8601String(),
      'estimated1RM': estimated1RM,
      'isPR': isPR,
    };
  }

  /// 총 볼륨 계산 (kg)
  double get totalVolume {
    return sets.fold(0.0, (sum, set) {
      if (set.weight != null && set.repsCompleted != null) {
        return sum + (set.weight! * set.repsCompleted!);
      }
      return sum;
    });
  }

  /// 총 세트 수
  int get totalSets => sets.length;

  /// 총 반복 횟수
  int get totalReps {
    return sets.fold(0, (sum, set) => sum + (set.repsCompleted ?? 0));
  }

  /// 운동 기록 복사본 생성
  ExerciseRecord copyWith({
    String? id,
    String? exerciseId,
    String? exerciseName,
    List<SetRecord>? sets,
    int? order,
    String? notes,
    DateTime? timestamp,
    double? estimated1RM,
    bool? isPR,
  }) {
    return ExerciseRecord(
      id: id ?? this.id,
      exerciseId: exerciseId ?? this.exerciseId,
      exerciseName: exerciseName ?? this.exerciseName,
      sets: sets ?? this.sets,
      order: order ?? this.order,
      notes: notes ?? this.notes,
      timestamp: timestamp ?? this.timestamp,
      estimated1RM: estimated1RM ?? this.estimated1RM,
      isPR: isPR ?? this.isPR,
    );
  }
}

/// 개별 세트 기록 모델
@HiveType(typeId: 6)
class SetRecord extends HiveObject {
  @HiveField(0)
  final int setNumber; // 세트 번호

  @HiveField(1)
  final int? repsTarget; // 목표 반복 횟수

  @HiveField(2)
  final int? repsCompleted; // 완료한 반복 횟수

  @HiveField(3)
  final double? weight; // 무게 (kg)

  @HiveField(4)
  final String? weightType; // 'fixed', 'percent_1rm', 'bodyweight'

  @HiveField(5)
  final int? restSeconds; // 세트 후 휴식 시간

  @HiveField(6)
  final bool isWarmup; // 워밍업 세트 여부

  @HiveField(7)
  final String? rpe; // Rate of Perceived Exertion (6-10)

  @HiveField(8)
  final String? notes; // 메모

  SetRecord({
    required this.setNumber,
    this.repsTarget,
    this.repsCompleted,
    this.weight,
    this.weightType,
    this.restSeconds,
    this.isWarmup = false,
    this.rpe,
    this.notes,
  });

  /// JSON에서 세트 기록 생성
  factory SetRecord.fromJson(Map<String, dynamic> json) {
    return SetRecord(
      setNumber: json['setNumber'] as int,
      repsTarget: json['repsTarget'] as int?,
      repsCompleted: json['repsCompleted'] as int?,
      weight: json['weight'] != null ? (json['weight'] as num).toDouble() : null,
      weightType: json['weightType'] as String?,
      restSeconds: json['restSeconds'] as int?,
      isWarmup: json['isWarmup'] as bool? ?? false,
      rpe: json['rpe'] as String?,
      notes: json['notes'] as String?,
    );
  }

  /// JSON으로 변환
  Map<String, dynamic> toJson() {
    return {
      'setNumber': setNumber,
      'repsTarget': repsTarget,
      'repsCompleted': repsCompleted,
      'weight': weight,
      'weightType': weightType,
      'restSeconds': restSeconds,
      'isWarmup': isWarmup,
      'rpe': rpe,
      'notes': notes,
    };
  }

  /// 세트 볼륨 계산
  double get volume {
    if (weight != null && repsCompleted != null) {
      return weight! * repsCompleted!;
    }
    return 0.0;
  }

  /// 세트 기록 복사본 생성
  SetRecord copyWith({
    int? setNumber,
    int? repsTarget,
    int? repsCompleted,
    double? weight,
    String? weightType,
    int? restSeconds,
    bool? isWarmup,
    String? rpe,
    String? notes,
  }) {
    return SetRecord(
      setNumber: setNumber ?? this.setNumber,
      repsTarget: repsTarget ?? this.repsTarget,
      repsCompleted: repsCompleted ?? this.repsCompleted,
      weight: weight ?? this.weight,
      weightType: weightType ?? this.weightType,
      restSeconds: restSeconds ?? this.restSeconds,
      isWarmup: isWarmup ?? this.isWarmup,
      rpe: rpe ?? this.rpe,
      notes: notes ?? this.notes,
    );
  }
}
