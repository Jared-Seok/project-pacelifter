import 'package:uuid/uuid.dart';

/// 레이스 일정 정보를 담는 모델
class Race {
  final String id;
  final String name;
  final DateTime raceDate;
  final DateTime trainingStartDate;

  Race({
    required this.name,
    required this.raceDate,
    required this.trainingStartDate,
    String? id,
  }) : id = id ?? const Uuid().v4();

  /// Map(JSON)에서 Race 객체를 생성하는 팩토리 생성자
  factory Race.fromJson(Map<String, dynamic> json) {
    return Race(
      id: json['id'],
      name: json['name'],
      raceDate: DateTime.parse(json['raceDate']),
      trainingStartDate: DateTime.parse(json['trainingStartDate']),
    );
  }

  /// Race 객체를 Map(JSON)으로 변환하는 메서드
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'raceDate': raceDate.toIso8601String(),
      'trainingStartDate': trainingStartDate.toIso8601String(),
    };
  }
}
