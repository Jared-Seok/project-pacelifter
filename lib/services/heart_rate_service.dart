import 'dart:async';
import 'package:health/health.dart';
import 'package:flutter/foundation.dart';
import 'profile_service.dart';

/// 실시간 심박수 모니터링 및 분석 서비스
class HeartRateService {
  static final HeartRateService _instance = HeartRateService._internal();
  factory HeartRateService() => _instance;
  HeartRateService._internal();

  final Health health = Health();
  final ProfileService _profileService = ProfileService();

  // 스트림 컨트롤러 (초기값 유지 및 여러 위젯 동시 수신을 위해 .broadcast 사용)
  final StreamController<double> _hrController = StreamController<double>.broadcast();
  Stream<double> get heartRateStream => _hrController.stream;

  // 폴링을 위한 타이머
  Timer? _pollingTimer;

  // 현재 세션 데이터 관리
  final List<double> _currentSessionSamples = [];
  DateTime? _lastSampleTime;
  double _lastEmittedValue = 0;
  
  int? _userAge;
  double? _maxHeartRate;

  double get lastValue => _lastEmittedValue;

  /// 모니터링 시작
  Future<void> startMonitoring() async {
    print('💓 HeartRateService: Starting monitoring...');
    _currentSessionSamples.clear();
    _lastSampleTime = null;
    _lastEmittedValue = 0;
    
    // 유저 정보 로드하여 최대 심박수 설정
    final profile = await _profileService.getProfile();
    _userAge = profile?.age ?? 30;
    _maxHeartRate = 220.0 - _userAge!;

    // HealthKit 권한 확인 및 요청
    final types = [HealthDataType.HEART_RATE];
    try {
      bool hasPermissions = await health.hasPermissions(types) ?? false;
      if (!hasPermissions) {
        print('💓 HeartRateService: Requesting permissions...');
        await health.requestAuthorization(types);
      }
    } catch (e) {
      print('💓 HeartRateService: Permission error: $e');
    }

    _pollingTimer?.cancel();
    
    // 5초마다 최신 심박수 데이터 폴링
    _pollingTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      _fetchLatestHeartRate();
    });

    // 초기 실행 시에는 범위를 넓게(1시간) 잡아 최근 값 1개를 즉시 가져옴
    _fetchLatestHeartRate(lookbackMinutes: 60);
  }

  /// 최신 심박수 데이터를 가져와 스트림에 흘려보냄
  Future<void> _fetchLatestHeartRate({int lookbackMinutes = 5}) async {
    final now = DateTime.now();
    final startTime = now.subtract(Duration(minutes: lookbackMinutes));

    try {
      final samples = await health.getHealthDataFromTypes(
        types: [HealthDataType.HEART_RATE],
        startTime: startTime,
        endTime: now,
      );

      if (samples.isNotEmpty) {
        // 시간 순 내림차순 정렬 (가장 최근 것이 맨 앞)
        samples.sort((a, b) => b.dateFrom.compareTo(a.dateFrom));
        final latestSample = samples.first;
        final hrValue = (latestSample.value as NumericHealthValue).numericValue.toDouble();

        if (hrValue > 0) {
          // 1. 새로운 샘플인지 확인 (시간 기준)
          final bool isNewSample = _lastSampleTime == null || latestSample.dateFrom.isAfter(_lastSampleTime!);
          
          if (isNewSample) {
            _lastSampleTime = latestSample.dateFrom;
            _currentSessionSamples.add(hrValue);
            print('💓 HeartRateService: New sample detected -> $hrValue BPM at ${latestSample.dateFrom}');
          }

          // 2. UI 스트림 업데이트
          // 값이 이전과 같더라도, 서비스가 살아있음을 알리고 현재 상태를 갱신하기 위해 매번 push
          _lastEmittedValue = hrValue;
          _hrController.add(hrValue);
        }
      } else {
        // 데이터가 아예 없는 경우 (시뮬레이터 등 대응)
        if (kDebugMode && _currentSessionSamples.isEmpty) {
          // 테스트용 가상 데이터 생성 (70 ~ 80 사이 랜덤)
          final mockHR = 70.0 + (DateTime.now().second % 10);
          _lastEmittedValue = mockHR;
          _hrController.add(mockHR);
          print('💓 HeartRateService: Sending mock data ($mockHR) for testing');
        }
      }
    } catch (e) {
      print('💓 HeartRateService: Error fetching HR samples: $e');
    }
  }

  /// 현재 심박수의 존(Zone) 계산
  int getHeartRateZone(double currentHR) {
    if (_maxHeartRate == null || _maxHeartRate == 0) return 0;
    final percentage = (currentHR / _maxHeartRate!) * 100;

    if (percentage >= 90) return 5;
    if (percentage >= 80) return 4;
    if (percentage >= 70) return 3;
    if (percentage >= 60) return 2;
    if (percentage >= 50) return 1;
    return 0;
  }

  /// 세션 통계 계산
  Map<String, double> getSessionStats() {
    if (_currentSessionSamples.isEmpty) {
      // 데이터가 없으면 마지막으로 표시된 값이라도 활용
      if (_lastEmittedValue > 0) return {'average': _lastEmittedValue, 'max': _lastEmittedValue};
      return {'average': 0, 'max': 0};
    }
    return {
      'average': _currentSessionSamples.reduce((a, b) => a + b) / _currentSessionSamples.length,
      'max': _currentSessionSamples.reduce((a, b) => a > b ? a : b),
    };
  }

  void stopMonitoring() {
    print('💓 HeartRateService: Stopping monitoring...');
    _pollingTimer?.cancel();
    _pollingTimer = null;
  }
}