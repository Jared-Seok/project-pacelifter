// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'template_block.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class TemplateBlockAdapter extends TypeAdapter<TemplateBlock> {
  @override
  final int typeId = 2;

  @override
  TemplateBlock read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return TemplateBlock(
      id: fields[0] as String,
      name: fields[1] as String,
      type: fields[2] as String,
      description: fields[3] as String?,
      targetDistance: fields[4] as double?,
      targetDuration: fields[5] as int?,
      targetPace: fields[6] as double?,
      intensityZone: fields[7] as String?,
      targetHeartRate: fields[8] as int?,
      exerciseId: fields[9] as String?,
      sets: fields[10] as int?,
      reps: fields[11] as int?,
      weight: fields[12] as double?,
      weightType: fields[13] as String?,
      restSeconds: fields[14] as int?,
      selectedVariations: (fields[17] as List?)?.cast<String>(),
      order: fields[15] as int,
      notes: fields[16] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, TemplateBlock obj) {
    writer
      ..writeByte(18)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.name)
      ..writeByte(2)
      ..write(obj.type)
      ..writeByte(3)
      ..write(obj.description)
      ..writeByte(4)
      ..write(obj.targetDistance)
      ..writeByte(5)
      ..write(obj.targetDuration)
      ..writeByte(6)
      ..write(obj.targetPace)
      ..writeByte(7)
      ..write(obj.intensityZone)
      ..writeByte(8)
      ..write(obj.targetHeartRate)
      ..writeByte(9)
      ..write(obj.exerciseId)
      ..writeByte(10)
      ..write(obj.sets)
      ..writeByte(11)
      ..write(obj.reps)
      ..writeByte(12)
      ..write(obj.weight)
      ..writeByte(13)
      ..write(obj.weightType)
      ..writeByte(14)
      ..write(obj.restSeconds)
      ..writeByte(15)
      ..write(obj.order)
      ..writeByte(16)
      ..write(obj.notes)
      ..writeByte(17)
      ..write(obj.selectedVariations);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TemplateBlockAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
