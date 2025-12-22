// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'performance_scores.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class PerformanceScoresAdapter extends TypeAdapter<PerformanceScores> {
  @override
  final int typeId = 40;

  @override
  PerformanceScores read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return PerformanceScores(
      enduranceScore: fields[0] as double,
      strengthScore: fields[1] as double,
      conditioningScore: fields[2] as double,
      hybridBalanceScore: fields[3] as double,
      lastUpdated: fields[4] as DateTime,
      vo2MaxScore: fields[5] as double?,
      paceScore: fields[6] as double?,
      relativeStrengthScore: fields[7] as double?,
      recoveryScore: fields[8] as double?,
    );
  }

  @override
  void write(BinaryWriter writer, PerformanceScores obj) {
    writer
      ..writeByte(9)
      ..writeByte(0)
      ..write(obj.enduranceScore)
      ..writeByte(1)
      ..write(obj.strengthScore)
      ..writeByte(2)
      ..write(obj.conditioningScore)
      ..writeByte(3)
      ..write(obj.hybridBalanceScore)
      ..writeByte(4)
      ..write(obj.lastUpdated)
      ..writeByte(5)
      ..write(obj.vo2MaxScore)
      ..writeByte(6)
      ..write(obj.paceScore)
      ..writeByte(7)
      ..write(obj.relativeStrengthScore)
      ..writeByte(8)
      ..write(obj.recoveryScore);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PerformanceScoresAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
