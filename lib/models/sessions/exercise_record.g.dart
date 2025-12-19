// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'exercise_record.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class ExerciseRecordAdapter extends TypeAdapter<ExerciseRecord> {
  @override
  final int typeId = 5;

  @override
  ExerciseRecord read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return ExerciseRecord(
      id: fields[0] as String,
      exerciseId: fields[1] as String,
      exerciseName: fields[2] as String,
      sets: (fields[3] as List).cast<SetRecord>(),
      order: fields[4] as int,
      notes: fields[5] as String?,
      timestamp: fields[6] as DateTime,
      estimated1RM: fields[7] as double?,
      isPR: fields[8] as bool,
    );
  }

  @override
  void write(BinaryWriter writer, ExerciseRecord obj) {
    writer
      ..writeByte(9)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.exerciseId)
      ..writeByte(2)
      ..write(obj.exerciseName)
      ..writeByte(3)
      ..write(obj.sets)
      ..writeByte(4)
      ..write(obj.order)
      ..writeByte(5)
      ..write(obj.notes)
      ..writeByte(6)
      ..write(obj.timestamp)
      ..writeByte(7)
      ..write(obj.estimated1RM)
      ..writeByte(8)
      ..write(obj.isPR);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ExerciseRecordAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class SetRecordAdapter extends TypeAdapter<SetRecord> {
  @override
  final int typeId = 6;

  @override
  SetRecord read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return SetRecord(
      setNumber: fields[0] as int,
      repsTarget: fields[1] as int?,
      repsCompleted: fields[2] as int?,
      weight: fields[3] as double?,
      weightType: fields[4] as String?,
      restSeconds: fields[5] as int?,
      isWarmup: fields[6] as bool,
      rpe: fields[7] as String?,
      notes: fields[8] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, SetRecord obj) {
    writer
      ..writeByte(9)
      ..writeByte(0)
      ..write(obj.setNumber)
      ..writeByte(1)
      ..write(obj.repsTarget)
      ..writeByte(2)
      ..write(obj.repsCompleted)
      ..writeByte(3)
      ..write(obj.weight)
      ..writeByte(4)
      ..write(obj.weightType)
      ..writeByte(5)
      ..write(obj.restSeconds)
      ..writeByte(6)
      ..write(obj.isWarmup)
      ..writeByte(7)
      ..write(obj.rpe)
      ..writeByte(8)
      ..write(obj.notes);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SetRecordAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
