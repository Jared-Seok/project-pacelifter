// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'custom_phase_preset.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class CustomPhasePresetAdapter extends TypeAdapter<CustomPhasePreset> {
  @override
  final int typeId = 7;

  @override
  CustomPhasePreset read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return CustomPhasePreset(
      id: fields[0] as String,
      name: fields[1] as String,
      description: fields[2] as String?,
      category: fields[3] as String,
      blocks: (fields[4] as List).cast<TemplateBlock>(),
      createdAt: fields[5] as DateTime,
    );
  }

  @override
  void write(BinaryWriter writer, CustomPhasePreset obj) {
    writer
      ..writeByte(6)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.name)
      ..writeByte(2)
      ..write(obj.description)
      ..writeByte(3)
      ..write(obj.category)
      ..writeByte(4)
      ..write(obj.blocks)
      ..writeByte(5)
      ..write(obj.createdAt);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CustomPhasePresetAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
