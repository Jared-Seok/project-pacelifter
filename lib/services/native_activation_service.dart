import 'dart:io';
import 'package:flutter/services.dart';

/// 네이티브 플러그인(Google Maps, Live Activities) 동적 활성화를 위한 서비스
class NativeActivationService {
  static final NativeActivationService _instance = NativeActivationService._internal();
  factory NativeActivationService() => _instance;
  NativeActivationService._internal();

  static const _controlChannel = MethodChannel("com.jared.pacelifter/control");
  
  bool _isMapsActivated = false;
  bool _isLiveActivitiesActivated = false;

  /// Google Maps 플러그인 활성화
  Future<void> activateGoogleMaps() async {
    if (!Platform.isIOS || _isMapsActivated) return;
    try {
      print('🚀 NativeActivationService: Requesting Google Maps activation...');
      final bool result = await _controlChannel.invokeMethod("activateGoogleMaps");
      if (result) {
        _isMapsActivated = true;
        print('✅ NativeActivationService: Google Maps Activated');
      }
    } catch (e) {
      print('⚠️ NativeActivationService: Google Maps activation failed/already active: $e');
    }
  }

  /// Live Activities 플러그인 활성화
  Future<void> activateLiveActivities() async {
    if (!Platform.isIOS || _isLiveActivitiesActivated) return;
    try {
      print('🚀 NativeActivationService: Requesting Live Activities activation...');
      final bool result = await _controlChannel.invokeMethod("activateLiveActivities");
      if (result) {
        _isLiveActivitiesActivated = true;
        print('✅ NativeActivationService: Live Activities Activated');
      }
    } catch (e) {
      print('⚠️ NativeActivationService: Live Activities activation failed/already active: $e');
    }
  }

  /// 미디어 피커 및 공유 플러그인 활성화 (UI 진입 시 호출)
  Future<void> activateMediaPicker() async {
    if (!Platform.isIOS) return;
    try {
      print('🚀 NativeActivationService: Requesting Media & Share activation...');
      await _controlChannel.invokeMethod("activateMediaPicker");
    } catch (e) {
      print('⚠️ NativeActivationService: Media activation failed: $e');
    }
  }
}
