import 'package:hive/hive.dart';

part 'exercise.g.dart';

/// 운동(Exercise) 모델
/// Strength 운동의 라이브러리를 정의
@HiveType(typeId: 3)
class Exercise extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String name;

  @HiveField(2)
  final String nameKo; // 한국어 이름

  @HiveField(3)
  final String category; // 'strength', 'plyometric', 'cardio', 'flexibility'

  @HiveField(4)
  final String movementPattern; // 'push', 'pull', 'squat', 'hinge', 'carry', 'core'

  @HiveField(5)
  final List<String> primaryMuscles; // 주요 근육군

  @HiveField(6)
  final List<String> secondaryMuscles; // 보조 근육군

  @HiveField(7)
  final String equipment; // 'barbell', 'dumbbell', 'bodyweight', 'machine', etc.

  @HiveField(8)
  final String difficulty; // 'beginner', 'intermediate', 'advanced'

  @HiveField(9)
  final String? description; // 운동 설명

  @HiveField(10)
  final String? videoUrl; // 시연 영상 URL

  @HiveField(11)
  final String? imagePath; // 이미지 경로

  @HiveField(12)
  final List<String>? cues; // 운동 큐/팁

  @HiveField(13)
  final bool isCompound; // 복합 운동 여부

  @HiveField(14)
  final bool isUnilateral; // 편측 운동 여부

  @HiveField(15)
  final List<String>? tags; // 검색용 태그

  @HiveField(16)
  final List<String> variations; // 세부 설정 옵션들

  @HiveField(17)
  final String? group; // 운동 그룹 (e.g., Bench Press, Flyes)

  Exercise({
    required this.id,
    required this.name,
    required this.nameKo,
    required this.category,
    required this.movementPattern,
    required this.primaryMuscles,
    required this.secondaryMuscles,
    required this.equipment,
    required this.difficulty,
    this.description,
    this.videoUrl,
    this.imagePath,
    this.cues,
    required this.isCompound,
    required this.isUnilateral,
    this.tags,
    this.variations = const [],
    this.group,
  });

  /// JSON에서 운동 생성
  factory Exercise.fromJson(Map<String, dynamic> json) {
    return Exercise(
      id: json['id'] as String,
      name: json['name'] as String,
      nameKo: json['nameKo'] as String,
      category: json['category'] as String,
      movementPattern: json['movementPattern'] as String,
      primaryMuscles: List<String>.from(json['primaryMuscles'] as List),
      secondaryMuscles: List<String>.from(json['secondaryMuscles'] as List),
      equipment: json['equipment'] as String,
      difficulty: json['difficulty'] as String,
      description: json['description'] as String?,
      videoUrl: json['videoUrl'] as String?,
      imagePath: json['imagePath'] as String?,
      cues: json['cues'] != null ? List<String>.from(json['cues'] as List) : null,
      isCompound: (json['isCompound'] as bool?) ?? false,
      isUnilateral: (json['isUnilateral'] as bool?) ?? false,
      tags: json['tags'] != null ? List<String>.from(json['tags'] as List) : null,
      variations: json['variations'] != null ? List<String>.from(json['variations'] as List) : [],
      group: json['group'] as String?,
    );
  }

  /// JSON으로 변환
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'nameKo': nameKo,
      'category': category,
      'movementPattern': movementPattern,
      'primaryMuscles': primaryMuscles,
      'secondaryMuscles': secondaryMuscles,
      'equipment': equipment,
      'difficulty': difficulty,
      'description': description,
      'videoUrl': videoUrl,
      'imagePath': imagePath,
      'cues': cues,
      'isCompound': isCompound,
      'isUnilateral': isUnilateral,
      'tags': tags,
      'variations': variations,
      'group': group,
    };
  }

  /// 운동 복사본 생성
  Exercise copyWith({
    String? id,
    String? name,
    String? nameKo,
    String? category,
    String? movementPattern,
    List<String>? primaryMuscles,
    List<String>? secondaryMuscles,
    String? equipment,
    String? difficulty,
    String? description,
    String? videoUrl,
    String? imagePath,
    List<String>? cues,
    bool? isCompound,
    bool? isUnilateral,
    List<String>? tags,
    List<String>? variations,
    String? group,
  }) {
    return Exercise(
      id: id ?? this.id,
      name: name ?? this.name,
      nameKo: nameKo ?? this.nameKo,
      category: category ?? this.category,
      movementPattern: movementPattern ?? this.movementPattern,
      primaryMuscles: primaryMuscles ?? this.primaryMuscles,
      secondaryMuscles: secondaryMuscles ?? this.secondaryMuscles,
      equipment: equipment ?? this.equipment,
      difficulty: difficulty ?? this.difficulty,
      description: description ?? this.description,
      videoUrl: videoUrl ?? this.videoUrl,
      imagePath: imagePath ?? this.imagePath,
      cues: cues ?? this.cues,
      isCompound: isCompound ?? this.isCompound,
      isUnilateral: isUnilateral ?? this.isUnilateral,
      tags: tags ?? this.tags,
      variations: variations ?? this.variations,
      group: group ?? this.group,
    );
  }
}
