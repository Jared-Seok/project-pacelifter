// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'workout_session.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class WorkoutSessionAdapter extends TypeAdapter<WorkoutSession> {
  @override
  final int typeId = 4;

  @override
  WorkoutSession read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return WorkoutSession(
      id: fields[0] as String,
      templateId: fields[1] as String,
      templateName: fields[2] as String,
      category: fields[3] as String,
      startTime: fields[4] as DateTime,
      endTime: fields[5] as DateTime,
      activeDuration: fields[6] as int,
      totalDuration: fields[7] as int,
      totalDistance: fields[8] as double?,
      averagePace: fields[9] as double?,
      averageHeartRate: fields[10] as int?,
      maxHeartRate: fields[11] as int?,
      calories: fields[12] as double?,
      environmentType: fields[13] as String?,
      exerciseRecords: (fields[14] as List?)?.cast<ExerciseRecord>(),
      totalVolume: fields[15] as double?,
      totalSets: fields[16] as int?,
      totalReps: fields[17] as int?,
      notes: fields[18] as String?,
      perceivedExertion: fields[19] as int?,
      mood: fields[20] as String?,
      tags: (fields[21] as List?)?.cast<String>(),
      healthKitWorkoutId: fields[22] as String?,
      isCompleted: fields[23] as bool,
      routePoints: (fields[24] as List?)?.cast<RoutePoint>(),
      elevationGain: fields[25] as double?,
    );
  }

  @override
  void write(BinaryWriter writer, WorkoutSession obj) {
    writer
      ..writeByte(26)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.templateId)
      ..writeByte(2)
      ..write(obj.templateName)
      ..writeByte(3)
      ..write(obj.category)
      ..writeByte(4)
      ..write(obj.startTime)
      ..writeByte(5)
      ..write(obj.endTime)
      ..writeByte(6)
      ..write(obj.activeDuration)
      ..writeByte(7)
      ..write(obj.totalDuration)
      ..writeByte(8)
      ..write(obj.totalDistance)
      ..writeByte(9)
      ..write(obj.averagePace)
      ..writeByte(10)
      ..write(obj.averageHeartRate)
      ..writeByte(11)
      ..write(obj.maxHeartRate)
      ..writeByte(12)
      ..write(obj.calories)
      ..writeByte(13)
      ..write(obj.environmentType)
      ..writeByte(24)
      ..write(obj.routePoints)
      ..writeByte(25)
      ..write(obj.elevationGain)
      ..writeByte(14)
      ..write(obj.exerciseRecords)
      ..writeByte(15)
      ..write(obj.totalVolume)
      ..writeByte(16)
      ..write(obj.totalSets)
      ..writeByte(17)
      ..write(obj.totalReps)
      ..writeByte(18)
      ..write(obj.notes)
      ..writeByte(19)
      ..write(obj.perceivedExertion)
      ..writeByte(20)
      ..write(obj.mood)
      ..writeByte(21)
      ..write(obj.tags)
      ..writeByte(22)
      ..write(obj.healthKitWorkoutId)
      ..writeByte(23)
      ..write(obj.isCompleted);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is WorkoutSessionAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
