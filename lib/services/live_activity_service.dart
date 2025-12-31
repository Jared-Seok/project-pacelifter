import 'dart:io';
import 'package:live_activities/live_activities.dart';
import 'package:flutter/foundation.dart';

/// 실시간 현황(Live Activities - iOS) 및 알림 트래킹(Android) 서비스
class LiveActivityService {
  static final LiveActivityService _instance = LiveActivityService._internal();
  factory LiveActivityService() => _instance;
  LiveActivityService._internal();

  final _liveActivitiesPlugin = LiveActivities();
  String? _latestActivityId;
  bool _isInitialized = false;
  
  // ⚠️ 중요: 이 값은 Xcode > Runner > Signing & Capabilities > App Groups에 등록한 값과 정확히 일치해야 합니다.
  // 사용자의 Bundle ID가 com.admin.pacelifter 라면 group.com.admin.pacelifter 가 일반적입니다.
  static const String _appGroupId = "group.com.admin.pacelifter";
  static const String _workoutActivityId = "workout_tracking";

  /// 초기화 (App Group 연결)
  Future<void> init() async {
    if (!Platform.isIOS || _isInitialized) return;
    try {
      print('🚀 LiveActivityService: Initializing with Group ID: $_appGroupId');
      await _liveActivitiesPlugin.init(appGroupId: _appGroupId);
      _isInitialized = true;
      print('✅ LiveActivityService: Initialization Successful');
    } catch (e) {
      print('❌ LiveActivityService: Initialization Failed: $e');
    }
  }

  /// 실시간 현황 시작
  Future<void> startActivity({
    required String name,
    required String distanceKm,
    required String duration,
    required String pace,
    required int? heartRate,
  }) async {
    if (!Platform.isIOS) return;

    try {
      await init();

      final isSupported = await _liveActivitiesPlugin.areActivitiesSupported();
      if (!isSupported) {
        print('⚠️ LiveActivityService: Live Activities are not supported on this device/OS.');
        return;
      }

      // 기존 액티비티가 있다면 종료
      await endActivity();

      final Map<String, dynamic> activityData = {
        'name': name,
        'distanceKm': distanceKm,
        'duration': duration,
        'pace': pace,
        'heartRate': heartRate?.toString() ?? '--',
      };

      print('🚀 LiveActivityService: Creating Activity with data: $activityData');
      _latestActivityId = await _liveActivitiesPlugin.createActivity(
        _workoutActivityId, 
        activityData,
        removeWhenAppIsKilled: true,
      );
      
      if (_latestActivityId != null) {
        print('✅ LiveActivityService: Activity Started Successfully. ID: $_latestActivityId');
      } else {
        print('❌ LiveActivityService: Failed to create activity (Returned null ID)');
      }
    } catch (e) {
      print('❌ LiveActivityService: Error starting Activity: $e');
    }
  }

  /// 실시간 현황 업데이트
  Future<void> updateActivity({
    required String distanceKm,
    required String duration,
    required String pace,
    required int? heartRate,
  }) async {
    if (!Platform.isIOS || _latestActivityId == null) return;

    try {
      final Map<String, dynamic> updateData = {
        'distanceKm': distanceKm,
        'duration': duration,
        'pace': pace,
        'heartRate': heartRate?.toString() ?? '--',
      };

      print('🔄 LiveActivityService: Updating Activity: $updateData');
      await _liveActivitiesPlugin.updateActivity(_latestActivityId!, updateData);
    } catch (e) {
      print('❌ LiveActivityService: Error updating Activity: $e');
    }
  }

  /// 실시간 현황 종료
  Future<void> endActivity() async {
    if (!Platform.isIOS) return;

    try {
      if (_latestActivityId != null) {
        await _liveActivitiesPlugin.endActivity(_latestActivityId!);
        print('🛑 LiveActivityService: Activity Ended: $_latestActivityId');
        _latestActivityId = null;
      } else {
        // ID를 모를 경우 모든 액티비티 강제 종료
        await _liveActivitiesPlugin.endAllActivities();
      }
    } catch (e) {
      print('❌ LiveActivityService: Error ending Activity: $e');
    }
  }
}