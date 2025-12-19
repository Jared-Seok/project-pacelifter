// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'template_phase.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class TemplatePhaseAdapter extends TypeAdapter<TemplatePhase> {
  @override
  final int typeId = 1;

  @override
  TemplatePhase read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return TemplatePhase(
      id: fields[0] as String,
      name: fields[1] as String,
      description: fields[2] as String?,
      blocks: (fields[3] as List).cast<TemplateBlock>(),
      order: fields[4] as int,
    );
  }

  @override
  void write(BinaryWriter writer, TemplatePhase obj) {
    writer
      ..writeByte(5)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.name)
      ..writeByte(2)
      ..write(obj.description)
      ..writeByte(3)
      ..write(obj.blocks)
      ..writeByte(4)
      ..write(obj.order);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TemplatePhaseAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
