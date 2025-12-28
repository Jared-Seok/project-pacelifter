import 'package:hive/hive.dart';

part 'route_point.g.dart';

/// 경로상의 한 점을 기록하는 모델
@HiveType(typeId: 7)
class RoutePoint extends HiveObject {
  @HiveField(0)
  final double latitude;

  @HiveField(1)
  final double longitude;

  @HiveField(2)
  final double altitude; // 고도 (미터)

  @HiveField(3)
  final DateTime timestamp;

  @HiveField(4)
  final double speed; // m/s

  @HiveField(5)
  final double accuracy; // 정밀도 (미터)

  RoutePoint({
    required this.latitude,
    required this.longitude,
    required this.altitude,
    required this.timestamp,
    required this.speed,
    required this.accuracy,
  });

  factory RoutePoint.fromJson(Map<String, dynamic> json) {
    return RoutePoint(
      latitude: json['latitude'] as double,
      longitude: json['longitude'] as double,
      altitude: json['altitude'] as double,
      timestamp: DateTime.parse(json['timestamp'] as String),
      speed: json['speed'] as double,
      accuracy: json['accuracy'] as double,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'latitude': latitude,
      'longitude': longitude,
      'altitude': altitude,
      'timestamp': timestamp.toIso8601String(),
      'speed': speed,
      'accuracy': accuracy,
    };
  }
}
