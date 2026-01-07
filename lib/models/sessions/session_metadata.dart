import 'package:hive/hive.dart';

part 'session_metadata.g.dart';

/// 운동 세션의 최소 메타데이터 (인메모리 인덱싱용)
@HiveType(typeId: 9)
class SessionMetadata extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final DateTime startTime;

  @HiveField(2)
  final String category; // 'Endurance', 'Strength', 'Hybrid'

  @HiveField(3)
  final String? healthKitId;

  SessionMetadata({
    required this.id,
    required this.startTime,
    required this.category,
    this.healthKitId,
  });

  factory SessionMetadata.fromSession(dynamic session) {
    return SessionMetadata(
      id: session.id,
      startTime: session.startTime,
      category: session.category,
      healthKitId: session.healthKitWorkoutId,
    );
  }
}
