import 'package:hive/hive.dart';
import 'exercise_record.dart';
import 'route_point.dart';

part 'workout_session.g.dart';

/// 운동 세션 모델
/// 사용자가 완료한 실제 운동 기록
@HiveType(typeId: 4)
class WorkoutSession extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String templateId; // 사용한 템플릿 ID

  @HiveField(2)
  final String templateName; // 템플릿 이름 (삭제된 템플릿 대비)

  @HiveField(3)
  final String category; // 'Endurance', 'Strength', 'Hybrid'

  @HiveField(4)
  final DateTime startTime; // 운동 시작 시간

  @HiveField(5)
  final DateTime endTime; // 운동 종료 시간

  @HiveField(6)
  final int activeDuration; // 실제 활동 시간 (초, 휴식 제외)

  @HiveField(7)
  final int totalDuration; // 전체 소요 시간 (초, 휴식 포함)

  // Endurance 관련 필드
  @HiveField(8)
  final double? totalDistance; // 총 거리 (미터)

  @HiveField(9)
  final double? averagePace; // 평균 페이스 (초/km)

  @HiveField(10)
  final int? averageHeartRate; // 평균 심박수

  @HiveField(11)
  final int? maxHeartRate; // 최대 심박수

  @HiveField(12)
  final double? calories; // 소모 칼로리

  @HiveField(13)
  final String? environmentType; // 'Indoor', 'Outdoor', 'Track'

  @HiveField(24)
  final List<RoutePoint>? routePoints; // 운동 경로 데이터

  @HiveField(25)
  final double? elevationGain; // 누적 상승 고도 (미터)

  // Strength 관련 필드
  @HiveField(14)
  final List<ExerciseRecord>? exerciseRecords; // 개별 운동 기록 리스트

  @HiveField(15)
  final double? totalVolume; // 총 볼륨 (kg)

  @HiveField(16)
  final int? totalSets; // 총 세트 수

  @HiveField(17)
  final int? totalReps; // 총 반복 횟수

  // 공통 필드
  @HiveField(18)
  final String? notes; // 메모

  @HiveField(19)
  final int? perceivedExertion; // RPE (1-10)

  @HiveField(20)
  final String? mood; // 'great', 'good', 'okay', 'tired', 'poor'

  @HiveField(21)
  final List<String>? tags; // 태그 ('PR', 'great_session', etc.)

  @HiveField(22)
  final String? healthKitWorkoutId; // HealthKit UUID (있는 경우)

  @HiveField(23)
  final bool isCompleted; // 완료 여부

  WorkoutSession({
    required this.id,
    required this.templateId,
    required this.templateName,
    required this.category,
    required this.startTime,
    required this.endTime,
    required this.activeDuration,
    required this.totalDuration,
    this.totalDistance,
    this.averagePace,
    this.averageHeartRate,
    this.maxHeartRate,
    this.calories,
    this.environmentType,
    this.exerciseRecords,
    this.totalVolume,
    this.totalSets,
    this.totalReps,
    this.notes,
    this.perceivedExertion,
    this.mood,
    this.tags,
    this.healthKitWorkoutId,
    this.isCompleted = true,
    this.routePoints,
    this.elevationGain,
  });

  /// JSON에서 세션 생성
  factory WorkoutSession.fromJson(Map<String, dynamic> json) {
    return WorkoutSession(
      id: json['id'] as String,
      templateId: json['templateId'] as String,
      templateName: json['templateName'] as String,
      category: json['category'] as String,
      startTime: DateTime.parse(json['startTime'] as String),
      endTime: DateTime.parse(json['endTime'] as String),
      activeDuration: json['activeDuration'] as int,
      totalDuration: json['totalDuration'] as int,
      totalDistance: json['totalDistance'] != null
          ? (json['totalDistance'] as num).toDouble()
          : null,
      averagePace: json['averagePace'] != null
          ? (json['averagePace'] as num).toDouble()
          : null,
      averageHeartRate: json['averageHeartRate'] as int?,
      maxHeartRate: json['maxHeartRate'] as int?,
      calories: json['calories'] != null
          ? (json['calories'] as num).toDouble()
          : null,
      environmentType: json['environmentType'] as String?,
      exerciseRecords: json['exerciseRecords'] != null
          ? (json['exerciseRecords'] as List)
              .map((record) => ExerciseRecord.fromJson(record as Map<String, dynamic>))
              .toList()
          : null,
      totalVolume: json['totalVolume'] != null
          ? (json['totalVolume'] as num).toDouble()
          : null,
      totalSets: json['totalSets'] as int?,
      totalReps: json['totalReps'] as int?,
      notes: json['notes'] as String?,
      perceivedExertion: json['perceivedExertion'] as int?,
      mood: json['mood'] as String?,
      tags: json['tags'] != null ? List<String>.from(json['tags'] as List) : null,
      healthKitWorkoutId: json['healthKitWorkoutId'] as String?,
      isCompleted: json['isCompleted'] as bool? ?? true,
      routePoints: json['routePoints'] != null
          ? (json['routePoints'] as List)
              .map((rp) => RoutePoint.fromJson(rp as Map<String, dynamic>))
              .toList()
          : null,
      elevationGain: json['elevationGain'] != null
          ? (json['elevationGain'] as num).toDouble()
          : null,
    );
  }

  /// JSON으로 변환
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'templateId': templateId,
      'templateName': templateName,
      'category': category,
      'startTime': startTime.toIso8601String(),
      'endTime': endTime.toIso8601String(),
      'activeDuration': activeDuration,
      'totalDuration': totalDuration,
      'totalDistance': totalDistance,
      'averagePace': averagePace,
      'averageHeartRate': averageHeartRate,
      'maxHeartRate': maxHeartRate,
      'calories': calories,
      'environmentType': environmentType,
      'exerciseRecords': exerciseRecords?.map((record) => record.toJson()).toList(),
      'totalVolume': totalVolume,
      'totalSets': totalSets,
      'totalReps': totalReps,
      'notes': notes,
      'perceivedExertion': perceivedExertion,
      'mood': mood,
      'tags': tags,
      'healthKitWorkoutId': healthKitWorkoutId,
      'isCompleted': isCompleted,
      'routePoints': routePoints?.map((rp) => rp.toJson()).toList(),
      'elevationGain': elevationGain,
    };
  }

  /// 세션 복사본 생성
  WorkoutSession copyWith({
    String? id,
    String? templateId,
    String? templateName,
    String? category,
    DateTime? startTime,
    DateTime? endTime,
    int? activeDuration,
    int? totalDuration,
    double? totalDistance,
    double? averagePace,
    int? averageHeartRate,
    int? maxHeartRate,
    double? calories,
    String? environmentType,
    List<ExerciseRecord>? exerciseRecords,
    double? totalVolume,
    int? totalSets,
    int? totalReps,
    String? notes,
    int? perceivedExertion,
    String? mood,
    List<String>? tags,
    String? healthKitWorkoutId,
    bool? isCompleted,
    List<RoutePoint>? routePoints,
    double? elevationGain,
  }) {
    return WorkoutSession(
      id: id ?? this.id,
      templateId: templateId ?? this.templateId,
      templateName: templateName ?? this.templateName,
      category: category ?? this.category,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      activeDuration: activeDuration ?? this.activeDuration,
      totalDuration: totalDuration ?? this.totalDuration,
      totalDistance: totalDistance ?? this.totalDistance,
      averagePace: averagePace ?? this.averagePace,
      averageHeartRate: averageHeartRate ?? this.averageHeartRate,
      maxHeartRate: maxHeartRate ?? this.maxHeartRate,
      calories: calories ?? this.calories,
      environmentType: environmentType ?? this.environmentType,
      exerciseRecords: exerciseRecords ?? this.exerciseRecords,
      totalVolume: totalVolume ?? this.totalVolume,
      totalSets: totalSets ?? this.totalSets,
      totalReps: totalReps ?? this.totalReps,
      notes: notes ?? this.notes,
      perceivedExertion: perceivedExertion ?? this.perceivedExertion,
      mood: mood ?? this.mood,
      tags: tags ?? this.tags,
      healthKitWorkoutId: healthKitWorkoutId ?? this.healthKitWorkoutId,
      isCompleted: isCompleted ?? this.isCompleted,
      routePoints: routePoints ?? this.routePoints,
      elevationGain: elevationGain ?? this.elevationGain,
    );
  }
}
