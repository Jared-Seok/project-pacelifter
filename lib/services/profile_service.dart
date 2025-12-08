import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pacelifter/models/user_profile.dart';

/// 사용자 프로필 데이터를 관리하는 서비스
class ProfileService {
  static const _profileKey = 'user_profile';
  static const _setupCompleteKey = 'is_profile_setup_completed';

  /// 사용자 프로필 정보를 디바이스에 저장합니다.
  Future<void> saveProfile(UserProfile profile) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = jsonEncode(profile.toJson());
    await prefs.setString(_profileKey, jsonString);
  }

  /// 디바이스에서 사용자 프로필 정보를 불러옵니다.
  /// 정보가 없으면 null을 반환합니다.
  Future<UserProfile?> getProfile() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString(_profileKey);
    if (jsonString != null) {
      return UserProfile.fromJson(jsonDecode(jsonString));
    }
    return null;
  }

  /// 프로필 설정 완료 여부 플래그를 설정합니다.
  Future<void> setProfileSetupCompleted(bool isCompleted) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_setupCompleteKey, isCompleted);
  }

  /// 프로필 설정이 완료되었는지 확인합니다.
  /// 기본값은 false입니다.
  Future<bool> isProfileSetupCompleted() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_setupCompleteKey) ?? false;
  }
}
