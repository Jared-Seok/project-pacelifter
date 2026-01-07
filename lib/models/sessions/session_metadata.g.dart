// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'session_metadata.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class SessionMetadataAdapter extends TypeAdapter<SessionMetadata> {
  @override
  final int typeId = 9;

  @override
  SessionMetadata read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return SessionMetadata(
      id: fields[0] as String,
      startTime: fields[1] as DateTime,
      category: fields[2] as String,
      healthKitId: fields[3] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, SessionMetadata obj) {
    writer
      ..writeByte(4)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.startTime)
      ..writeByte(2)
      ..write(obj.category)
      ..writeByte(3)
      ..write(obj.healthKitId);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SessionMetadataAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
