import 'package:hive/hive.dart';

part 'template_block.g.dart';

/// 템플릿 블록 모델
/// 각 페이즈 내의 개별 운동 블록 (인터벌, LSD 구간 등)
@HiveType(typeId: 2)
class TemplateBlock extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String name;

  @HiveField(2)
  final String type; // 'endurance', 'strength', 'rest'

  @HiveField(3)
  final String? description;

  // Endurance 관련 필드
  @HiveField(4)
  final double? targetDistance; // 목표 거리 (미터)

  @HiveField(5)
  final int? targetDuration; // 목표 시간 (초)

  @HiveField(6)
  final double? targetPace; // 목표 페이스 (초/km)

  @HiveField(7)
  final String? intensityZone; // 'Z1', 'Z2', 'Z3', 'Z4', 'Z5'

  @HiveField(8)
  final int? targetHeartRate; // 목표 심박수 (bpm)

  // Strength 관련 필드
  @HiveField(9)
  final String? exerciseId; // exercises box의 exercise ID 참조

  @HiveField(10)
  final int? sets; // 세트 수

  @HiveField(11)
  final int? reps; // 반복 횟수

  @HiveField(12)
  final double? weight; // 무게 (kg)

  @HiveField(13)
  final String? weightType; // 'fixed', 'percent_1rm', 'bodyweight'

  @HiveField(14)
  final int? restSeconds; // 세트 간 휴식 시간

  @HiveField(17)
  final List<String>? selectedVariations; // 선택된 세부 설정 (예: ["경사도: 인클라인"])

  // 공통 필드
  @HiveField(15)
  final int order; // 블록 순서

  @HiveField(16)
  final String? notes; // 추가 메모

  TemplateBlock({
    required this.id,
    required this.name,
    required this.type,
    this.description,
    this.targetDistance,
    this.targetDuration,
    this.targetPace,
    this.intensityZone,
    this.targetHeartRate,
    this.exerciseId,
    this.sets,
    this.reps,
    this.weight,
    this.weightType,
    this.restSeconds,
    this.selectedVariations,
    required this.order,
    this.notes,
  });

  /// JSON에서 블록 생성
  factory TemplateBlock.fromJson(Map<String, dynamic> json) {
    return TemplateBlock(
      id: json['id'] as String,
      name: json['name'] as String,
      type: json['type'] as String,
      description: json['description'] as String?,
      targetDistance: json['targetDistance'] != null
          ? (json['targetDistance'] as num).toDouble()
          : null,
      targetDuration: json['targetDuration'] as int?,
      targetPace: json['targetPace'] != null
          ? (json['targetPace'] as num).toDouble()
          : null,
      intensityZone: json['intensityZone'] as String?,
      targetHeartRate: json['targetHeartRate'] as int?,
      exerciseId: json['exerciseId'] as String?,
      sets: json['sets'] as int?,
      reps: json['reps'] as int?,
      weight: json['weight'] != null ? (json['weight'] as num).toDouble() : null,
      weightType: json['weightType'] as String?,
      restSeconds: json['restSeconds'] as int?,
      selectedVariations: json['selectedVariations'] != null 
          ? List<String>.from(json['selectedVariations'] as List) 
          : null,
      order: json['order'] as int,
      notes: json['notes'] as String?,
    );
  }

  /// JSON으로 변환
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'type': type,
      'description': description,
      'targetDistance': targetDistance,
      'targetDuration': targetDuration,
      'targetPace': targetPace,
      'intensityZone': intensityZone,
      'targetHeartRate': targetHeartRate,
      'exerciseId': exerciseId,
      'sets': sets,
      'reps': reps,
      'weight': weight,
      'weightType': weightType,
      'restSeconds': restSeconds,
      'selectedVariations': selectedVariations,
      'order': order,
      'notes': notes,
    };
  }

  /// 블록 복사본 생성
  TemplateBlock copyWith({
    String? id,
    String? name,
    String? type,
    String? description,
    double? targetDistance,
    int? targetDuration,
    double? targetPace,
    String? intensityZone,
    int? targetHeartRate,
    String? exerciseId,
    int? sets,
    int? reps,
    double? weight,
    String? weightType,
    int? restSeconds,
    List<String>? selectedVariations,
    int? order,
    String? notes,
  }) {
    return TemplateBlock(
      id: id ?? this.id,
      name: name ?? this.name,
      type: type ?? this.type,
      description: description ?? this.description,
      targetDistance: targetDistance ?? this.targetDistance,
      targetDuration: targetDuration ?? this.targetDuration,
      targetPace: targetPace ?? this.targetPace,
      intensityZone: intensityZone ?? this.intensityZone,
      targetHeartRate: targetHeartRate ?? this.targetHeartRate,
      exerciseId: exerciseId ?? this.exerciseId,
      sets: sets ?? this.sets,
      reps: reps ?? this.reps,
      weight: weight ?? this.weight,
      weightType: weightType ?? this.weightType,
      restSeconds: restSeconds ?? this.restSeconds,
      selectedVariations: selectedVariations ?? this.selectedVariations,
      order: order ?? this.order,
      notes: notes ?? this.notes,
    );
  }
}
