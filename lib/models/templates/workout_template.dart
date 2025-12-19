import 'package:hive/hive.dart';
import 'template_phase.dart';

part 'workout_template.g.dart';

/// 운동 템플릿 모델
/// Endurance, Strength, Hybrid 운동의 기본 구조를 정의
@HiveType(typeId: 0)
class WorkoutTemplate extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String name;

  @HiveField(2)
  final String category; // 'Endurance', 'Strength', 'Hybrid'

  @HiveField(3)
  final String? environmentType; // 'Indoor', 'Outdoor', 'Track' (Endurance만 해당)

  @HiveField(4)
  final String? subCategory; // LSD, Interval, Tempo 등

  @HiveField(5)
  final String description;

  @HiveField(6)
  final String? imagePath;

  @HiveField(7)
  final List<TemplatePhase> phases; // Warm-up, Main Set, Cool-down

  @HiveField(8)
  final bool isCustom; // 기본 템플릿 vs 사용자 생성

  @HiveField(9)
  final DateTime? createdAt;

  @HiveField(10)
  final DateTime? modifiedAt;

  WorkoutTemplate({
    required this.id,
    required this.name,
    required this.category,
    this.environmentType,
    this.subCategory,
    required this.description,
    this.imagePath,
    required this.phases,
    this.isCustom = false,
    this.createdAt,
    this.modifiedAt,
  });

  /// JSON에서 템플릿 생성 (assets 파일에서 로드)
  factory WorkoutTemplate.fromJson(Map<String, dynamic> json) {
    return WorkoutTemplate(
      id: json['id'] as String,
      name: json['name'] as String,
      category: json['category'] as String,
      environmentType: json['environmentType'] as String?,
      subCategory: json['subCategory'] as String?,
      description: json['description'] as String,
      imagePath: json['imagePath'] as String?,
      phases: (json['phases'] as List)
          .map((phase) => TemplatePhase.fromJson(phase as Map<String, dynamic>))
          .toList(),
      isCustom: json['isCustom'] as bool? ?? false,
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'] as String)
          : null,
      modifiedAt: json['modifiedAt'] != null
          ? DateTime.parse(json['modifiedAt'] as String)
          : null,
    );
  }

  /// JSON으로 변환
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'category': category,
      'environmentType': environmentType,
      'subCategory': subCategory,
      'description': description,
      'imagePath': imagePath,
      'phases': phases.map((phase) => phase.toJson()).toList(),
      'isCustom': isCustom,
      'createdAt': createdAt?.toIso8601String(),
      'modifiedAt': modifiedAt?.toIso8601String(),
    };
  }

  /// 템플릿 복사본 생성 (커스터마이징용)
  WorkoutTemplate copyWith({
    String? id,
    String? name,
    String? category,
    String? environmentType,
    String? subCategory,
    String? description,
    String? imagePath,
    List<TemplatePhase>? phases,
    bool? isCustom,
    DateTime? createdAt,
    DateTime? modifiedAt,
  }) {
    return WorkoutTemplate(
      id: id ?? this.id,
      name: name ?? this.name,
      category: category ?? this.category,
      environmentType: environmentType ?? this.environmentType,
      subCategory: subCategory ?? this.subCategory,
      description: description ?? this.description,
      imagePath: imagePath ?? this.imagePath,
      phases: phases ?? this.phases,
      isCustom: isCustom ?? this.isCustom,
      createdAt: createdAt ?? this.createdAt,
      modifiedAt: modifiedAt ?? this.modifiedAt,
    );
  }
}
