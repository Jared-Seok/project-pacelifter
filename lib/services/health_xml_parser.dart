import 'dart:io';
import 'dart:convert';
import 'dart:typed_data';
import 'package:xml/xml.dart';
import '../models/health_workout.dart';
import '../models/health_record.dart';

class HealthXmlParser {
  List<HealthWorkout> workouts = [];
  List<HealthRecord> records = [];

  int totalWorkouts = 0;
  int totalRecords = 0;

  bool _isParsing = false;
  double _progress = 0.0;

  bool get isParsing => _isParsing;
  double get progress => _progress;

  // 웹용: 바이트 데이터로 파싱
  Future<void> parseBytes(Uint8List bytes, {
    bool includeWorkouts = true,
    bool includeRecords = false,
    List<String>? recordTypes,
  }) async {
    _isParsing = true;
    _progress = 0.0;
    workouts.clear();
    records.clear();

    try {
      _progress = 0.1;

      // 바이트를 문자열로 변환
      final xmlString = utf8.decode(bytes);
      _progress = 0.3;

      // XML 파싱
      await _parseXmlString(xmlString, includeWorkouts, includeRecords, recordTypes);

      _progress = 1.0;
    } catch (e) {
      _isParsing = false;
      rethrow;
    } finally {
      _isParsing = false;
    }
  }

  // 모바일용: 파일 경로로 파싱
  Future<void> parseFile(String filePath, {
    bool includeWorkouts = true,
    bool includeRecords = false,
    List<String>? recordTypes,
  }) async {
    _isParsing = true;
    _progress = 0.0;
    workouts.clear();
    records.clear();

    try {
      final file = File(filePath);
      if (!await file.exists()) {
        throw Exception('File not found: $filePath');
      }

      _progress = 0.1;

      // XML 파일 읽기
      final xmlString = await file.readAsString();
      _progress = 0.3;

      // XML 파싱
      await _parseXmlString(xmlString, includeWorkouts, includeRecords, recordTypes);

      _progress = 1.0;
    } catch (e) {
      _isParsing = false;
      rethrow;
    } finally {
      _isParsing = false;
    }
  }

  // 공통 파싱 로직
  Future<void> _parseXmlString(
    String xmlString,
    bool includeWorkouts,
    bool includeRecords,
    List<String>? recordTypes,
  ) async {
    final document = XmlDocument.parse(xmlString);
    _progress = 0.5;

    if (includeWorkouts) {
      _parseWorkouts(document);
    }

    _progress = 0.7;

    if (includeRecords) {
      _parseRecords(document, recordTypes: recordTypes);
    }
  }

  void _parseWorkouts(XmlDocument document) {
    final workoutElements = document.findAllElements('Workout');

    totalWorkouts = workoutElements.length;

    for (final element in workoutElements) {
      try {
        final attributes = <String, dynamic>{};
        for (final attr in element.attributes) {
          attributes[attr.name.local] = attr.value;
        }

        workouts.add(HealthWorkout.fromXml(attributes));
      } catch (e) {
        print('Error parsing workout: $e');
      }
    }
  }

  void _parseRecords(XmlDocument document, {List<String>? recordTypes}) {
    final recordElements = document.findAllElements('Record');

    totalRecords = recordElements.length;

    for (final element in recordElements) {
      try {
        final attributes = <String, dynamic>{};
        for (final attr in element.attributes) {
          attributes[attr.name.local] = attr.value;
        }

        final type = attributes['type'] as String?;

        // 특정 타입만 필터링
        if (recordTypes != null && recordTypes.isNotEmpty) {
          if (type == null || !recordTypes.any((t) => type.contains(t))) {
            continue;
          }
        }

        records.add(HealthRecord.fromXml(attributes));
      } catch (e) {
        print('Error parsing record: $e');
      }
    }
  }

  // 통계 생성
  Map<String, dynamic> getWorkoutStatistics() {
    if (workouts.isEmpty) {
      return {
        'totalWorkouts': 0,
        'totalDistance': 0.0,
        'totalDuration': 0,
        'byType': {},
      };
    }

    final byType = <String, List<HealthWorkout>>{};
    double totalDistance = 0.0;
    int totalDuration = 0;

    for (final workout in workouts) {
      if (!byType.containsKey(workout.workoutType)) {
        byType[workout.workoutType] = [];
      }
      byType[workout.workoutType]!.add(workout);

      if (workout.distance != null) {
        totalDistance += workout.distance!;
      }
      totalDuration += workout.duration.inSeconds;
    }

    final stats = <String, dynamic>{};
    byType.forEach((type, workoutList) {
      final typeDistance = workoutList
          .where((w) => w.distance != null)
          .fold<double>(0.0, (sum, w) => sum + w.distance!);

      final typeDuration = workoutList
          .fold<int>(0, (sum, w) => sum + w.duration.inSeconds);

      final avgPace = workoutList
          .where((w) => w.averagePace != null)
          .map((w) => w.averagePace!)
          .fold<double>(0.0, (sum, pace) => sum + pace) /
          workoutList.where((w) => w.averagePace != null).length;

      stats[type] = {
        'count': workoutList.length,
        'totalDistance': typeDistance / 1000, // km
        'totalDuration': typeDuration ~/ 60, // minutes
        'avgPace': avgPace.isFinite ? avgPace : null,
      };
    });

    return {
      'totalWorkouts': workouts.length,
      'totalDistance': totalDistance / 1000, // km
      'totalDuration': totalDuration ~/ 60, // minutes
      'byType': stats,
    };
  }

  // 러닝 데이터만 필터링
  List<HealthWorkout> getRunningWorkouts() {
    return workouts.where((w) =>
      w.workoutType.contains('Running') ||
      w.workoutType.contains('Run')
    ).toList();
  }

  // 최근 N개의 운동 가져오기
  List<HealthWorkout> getRecentWorkouts(int count) {
    final sorted = List<HealthWorkout>.from(workouts)
      ..sort((a, b) => b.startDate.compareTo(a.startDate));
    return sorted.take(count).toList();
  }

  // 특정 기간의 운동 가져오기
  List<HealthWorkout> getWorkoutsByDateRange(DateTime start, DateTime end) {
    return workouts.where((w) =>
      w.startDate.isAfter(start) && w.startDate.isBefore(end)
    ).toList();
  }
}
