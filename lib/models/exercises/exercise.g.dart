// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'exercise.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class ExerciseAdapter extends TypeAdapter<Exercise> {
  @override
  final int typeId = 3;

  @override
  Exercise read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Exercise(
      id: fields[0] as String,
      name: fields[1] as String,
      nameKo: fields[2] as String,
      category: fields[3] as String,
      movementPattern: fields[4] as String,
      primaryMuscles: (fields[5] as List).cast<String>(),
      secondaryMuscles: (fields[6] as List).cast<String>(),
      equipment: fields[7] as String,
      difficulty: fields[8] as String,
      description: fields[9] as String?,
      videoUrl: fields[10] as String?,
      imagePath: fields[11] as String?,
      cues: (fields[12] as List?)?.cast<String>(),
      isCompound: fields[13] as bool,
      isUnilateral: fields[14] as bool,
      tags: (fields[15] as List?)?.cast<String>(),
      variations: (fields[16] as List).cast<String>(),
      group: fields[17] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, Exercise obj) {
    writer
      ..writeByte(18)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.name)
      ..writeByte(2)
      ..write(obj.nameKo)
      ..writeByte(3)
      ..write(obj.category)
      ..writeByte(4)
      ..write(obj.movementPattern)
      ..writeByte(5)
      ..write(obj.primaryMuscles)
      ..writeByte(6)
      ..write(obj.secondaryMuscles)
      ..writeByte(7)
      ..write(obj.equipment)
      ..writeByte(8)
      ..write(obj.difficulty)
      ..writeByte(9)
      ..write(obj.description)
      ..writeByte(10)
      ..write(obj.videoUrl)
      ..writeByte(11)
      ..write(obj.imagePath)
      ..writeByte(12)
      ..write(obj.cues)
      ..writeByte(13)
      ..write(obj.isCompound)
      ..writeByte(14)
      ..write(obj.isUnilateral)
      ..writeByte(15)
      ..write(obj.tags)
      ..writeByte(16)
      ..write(obj.variations)
      ..writeByte(17)
      ..write(obj.group);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ExerciseAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
