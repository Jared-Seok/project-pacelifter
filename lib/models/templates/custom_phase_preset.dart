import 'package:hive/hive.dart';
import 'template_block.dart';

part 'custom_phase_preset.g.dart';

/// 사용자 정의 페이즈 프리셋 (예: 나만의 인터벌, 나만의 LSD 등)
@HiveType(typeId: 8)
class CustomPhasePreset extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String name; // 예: "고강도 인터벌 10set"

  @HiveField(2)
  final String? description;

  @HiveField(3)
  final String category; // 'Endurance', 'Strength'

  @HiveField(4)
  final List<TemplateBlock> blocks; // 저장된 블록 구성

  @HiveField(5)
  final DateTime createdAt;

  CustomPhasePreset({
    required this.id,
    required this.name,
    this.description,
    required this.category,
    required this.blocks,
    required this.createdAt,
  });
}
