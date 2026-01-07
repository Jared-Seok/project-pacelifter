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
      enduranceScore: fields[0] as num,
      strengthScore: fields[1] as num,
      conditioningScore: fields[2] as num,
      hybridBalanceScore: fields[3] as num,
      lastUpdated: fields[4] as DateTime,
      enduranceWeeklyFreq: fields[9] as num,
      enduranceBaselineFreq: fields[10] as num,
      totalDistanceKm: fields[11] as num,
      strengthWeeklyFreq: fields[12] as num,
      strengthBaselineFreq: fields[13] as num,
      totalVolumeTon: fields[14] as num,
      acwr: fields[15] as num,
      avgRestingHeartRate: fields[16] as num?,
      avgHRV: fields[17] as num?,
    );
  }

  @override
  void write(BinaryWriter writer, PerformanceScores obj) {
    writer
      ..writeByte(14)
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
      ..writeByte(9)
      ..write(obj.enduranceWeeklyFreq)
      ..writeByte(10)
      ..write(obj.enduranceBaselineFreq)
      ..writeByte(11)
      ..write(obj.totalDistanceKm)
      ..writeByte(12)
      ..write(obj.strengthWeeklyFreq)
      ..writeByte(13)
      ..write(obj.strengthBaselineFreq)
      ..writeByte(14)
      ..write(obj.totalVolumeTon)
      ..writeByte(15)
      ..write(obj.acwr)
      ..writeByte(16)
      ..write(obj.avgRestingHeartRate)
      ..writeByte(17)
      ..write(obj.avgHRV);
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
