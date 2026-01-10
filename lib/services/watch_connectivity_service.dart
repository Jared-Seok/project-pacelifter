import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:watch_connectivity/watch_connectivity.dart';

/// Apple Watch와의 통신을 담당하는 서비스
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

  /// 서비스 초기화 및 리스너 등록
  Future<void> init() async {
    if (defaultTargetPlatform != TargetPlatform.iOS) return;

    // 1. 초기 상태 확인 (안정적인 API만 사용)
    _isPaired = await _watch.isPaired;
    _isReachable = await _watch.isReachable;

    debugPrint('⌚ Watch Connectivity Init: Paired=$_isPaired, Reachable=$_isReachable');

    // 2. 메시지 수신 리스너 등록
    _watch.messageStream.listen(_handleMessage);
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

  /// 워치로 명령 전송
  Future<void> sendMessage(Map<String, dynamic> message) async {
    if (defaultTargetPlatform != TargetPlatform.iOS) return;
    try {
      await _watch.sendMessage(message);
    } catch (e) {
      debugPrint('❌ Failed to send message to Watch: $e');
    }
  }

  Future<void> startWatchWorkout({required String activityType}) async {
    await sendMessage({
      'command': 'START_WORKOUT',
      'activityType': activityType,
    });
  }

  Future<void> stopWatchWorkout() async {
    await sendMessage({
      'command': 'STOP_WORKOUT',
    });
  }
}