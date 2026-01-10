import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:watch_connectivity/watch_connectivity.dart';

/// Apple Watch와의 통신을 담당하는 서비스
///
/// 역할:
/// 1. Watch로 운동 시작/종료 명령 전송
/// 2. Watch로부터 실시간 심박수 데이터 수신
/// 3. Application Context 동기화 (설정 등)
class WatchConnectivityService {
  static final WatchConnectivityService _instance =
      WatchConnectivityService._internal();

  factory WatchConnectivityService() => _instance;

  WatchConnectivityService._internal();

  final WatchConnectivity _watch = WatchConnectivity();

  // 심박수 스트림 컨트롤러
  final _heartRateController = StreamController<int>.broadcast();
  Stream<int> get heartRateStream => _heartRateController.stream;

  // 연결 상태
  bool _isReachable = false;
  bool _isPaired = false;
  bool _isWatchAppInstalled = false;

  /// 서비스 초기화 및 리스너 등록
  Future<void> init() async {
    if (defaultTargetPlatform != TargetPlatform.iOS) return;

    // 1. 초기 상태 확인
    _isPaired = await _watch.isPaired;
    _isReachable = await _watch.isReachable;
    _isWatchAppInstalled = await _watch.isWatchAppInstalled;

    debugPrint('⌚ Watch Connectivity Init: Paired=$_isPaired, AppInstalled=$_isWatchAppInstalled');

    // 2. 메시지 수신 리스너 등록
    _watch.messageStream.listen(_handleMessage);
    
    // 3. 컨텍스트 수신 리스너 등록 (필요시)
    _watch.contextStream.listen(_handleContext);
  }

  /// Watch로부터 수신된 메시지 처리
  void _handleMessage(Map<String, dynamic> message) {
    debugPrint('⌚ Received message from Watch: $message');

    if (message.containsKey('heartRate')) {
      final heartRate = message['heartRate'];
      if (heartRate is int) {
        _heartRateController.add(heartRate);
      } else if (heartRate is double) {
        _heartRateController.add(heartRate.toInt());
      }
    }
  }

  /// Watch로부터 수신된 컨텍스트 처리
  void _handleContext(Map<String, dynamic> context) {
    debugPrint('⌚ Received context from Watch: $context');
    // TODO: 설정 동기화 등 처리
  }

  /// Watch로 메시지 전송 (즉시 전송 시도)
  /// - reachable 상태여야 함
  Future<void> sendMessage(Map<String, dynamic> message) async {
    if (defaultTargetPlatform != TargetPlatform.iOS) return;

    try {
      await _watch.sendMessage(message);
    } catch (e) {
      debugPrint('❌ Failed to send message to Watch: $e');
    }
  }

  /// Watch로 Application Context 업데이트 (백그라운드 동기화)
  /// - reachable 아니어도 큐에 쌓였다가 연결 시 전송됨
  Future<void> updateApplicationContext(Map<String, dynamic> context) async {
    if (defaultTargetPlatform != TargetPlatform.iOS) return;

    try {
      await _watch.updateApplicationContext(context);
    } catch (e) {
      debugPrint('❌ Failed to update context to Watch: $e');
    }
  }

  /// 운동 시작 명령 전송
  Future<void> startWatchWorkout({required String activityType}) async {
    await sendMessage({
      'command': 'START_WORKOUT',
      'activityType': activityType,
      'timestamp': DateTime.now().toIso8601String(),
    });
  }

  /// 운동 종료 명령 전송
  Future<void> stopWatchWorkout() async {
    await sendMessage({
      'command': 'STOP_WORKOUT',
      'timestamp': DateTime.now().toIso8601String(),
    });
  }
}
