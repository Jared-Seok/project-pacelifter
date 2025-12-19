import 'package:hive/hive.dart';
import 'template_block.dart';

part 'template_phase.g.dart';

/// 템플릿 페이즈 모델
/// Warm-up, Main Set, Cool-down 등의 운동 단계
@HiveType(typeId: 1)
class TemplatePhase extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String name; // 'Warm-up', 'Main Set', 'Cool-down'

  @HiveField(2)
  final String? description;

  @HiveField(3)
  final List<TemplateBlock> blocks; // 이 페이즈에 포함된 운동 블록들

  @HiveField(4)
  final int order; // 페이즈 순서 (0: Warm-up, 1: Main Set, 2: Cool-down)

  TemplatePhase({
    required this.id,
    required this.name,
    this.description,
    required this.blocks,
    required this.order,
  });

  /// JSON에서 페이즈 생성
  factory TemplatePhase.fromJson(Map<String, dynamic> json) {
    return TemplatePhase(
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String?,
      blocks: (json['blocks'] as List)
          .map((block) => TemplateBlock.fromJson(block as Map<String, dynamic>))
          .toList(),
      order: json['order'] as int,
    );
  }

  /// JSON으로 변환
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'blocks': blocks.map((block) => block.toJson()).toList(),
      'order': order,
    };
  }

  /// 페이즈 복사본 생성
  TemplatePhase copyWith({
    String? id,
    String? name,
    String? description,
    List<TemplateBlock>? blocks,
    int? order,
  }) {
    return TemplatePhase(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      blocks: blocks ?? this.blocks,
      order: order ?? this.order,
    );
  }
}
