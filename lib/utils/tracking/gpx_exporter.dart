import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:xml/xml.dart';
import 'package:intl/intl.dart';
import '../../models/sessions/route_point.dart';
import '../../models/sessions/workout_session.dart';

/// 운동 경로 데이터를 GPX 1.1 포맷으로 변환 및 내보내기 하는 유틸리티
class GpxExporter {
  /// WorkoutSession 데이터를 GPX 파일로 변환하여 임시 파일 경로 반환
  static Future<File> generateGpxFile(WorkoutSession session) async {
    if (session.routePoints == null || session.routePoints!.isEmpty) {
      throw Exception('경로 데이터가 없습니다.');
    }

    final builder = XmlBuilder();
    builder.processing('xml', 'version="1.0" encoding="UTF-8"');
    
    builder.element('gpx', attributes: {
      'version': '1.1',
      'creator': 'PaceLifter',
      'xmlns': 'http://www.topografix.com/GPX/1/1',
      'xmlns:xsi': 'http://www.w3.org/2001/XMLSchema-instance',
      'xsi:schemaLocation': 'http://www.topografix.com/GPX/1/1 http://www.topografix.com/GPX/1/1/gpx.xsd',
    }, nest: () {
      // 1. 메타데이터
      builder.element('metadata', nest: () {
        builder.element('name', nest: session.templateName);
        builder.element('time', nest: session.startTime.toUtc().toIso8601String());
      });

      // 2. 트랙 데이터
      builder.element('trk', nest: () {
        builder.element('name', nest: '${session.templateName} - ${DateFormat('yyyy-MM-dd HH:mm').format(session.startTime)}');
        builder.element('type', nest: session.category == 'Endurance' ? '9' : '1'); // 9 is running in some conventions

        builder.element('trkseg', nest: () {
          for (var point in session.routePoints!) {
            builder.element('trkpt', attributes: {
              'lat': point.latitude.toString(),
              'lon': point.longitude.toString(),
            }, nest: () {
              // 고도 (미터)
              builder.element('ele', nest: point.altitude.toStringAsFixed(1));
              // 시간 (UTC ISO8601)
              builder.element('time', nest: point.timestamp.toUtc().toIso8601String());
              
              // 확장 데이터 (속도 등 - 일부 플랫폼 지원)
              builder.element('extensions', nest: () {
                builder.element('speed', nest: point.speed.toStringAsFixed(2));
              });
            });
          }
        });
      });
    });

    final gpxXml = builder.buildDocument();
    
    // 임시 디렉토리에 파일 저장
    final tempDir = await getTemporaryDirectory();
    final fileName = 'PaceLifter_${session.id.substring(0, 8)}_${DateFormat('yyyyMMdd').format(session.startTime)}.gpx';
    final file = File('${tempDir.path}/$fileName');
    
    return await file.writeAsString(gpxXml.toXmlString(pretty: true));
  }
}
