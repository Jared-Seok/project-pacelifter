import 'package:shared_preferences/shared_preferences.dart';

/// 로컬 로그인 상태 관리 서비스
///
/// 현재는 로컬 로그인만 지원하며, 추후 실제 계정 연동 기능이 추가될 예정입니다.
/// SharedPreferences를 사용하여 로그인 상태를 저장합니다.
class AuthService {
  static const String _keyIsLoggedIn = 'is_logged_in';
  static const String _keyUsername = 'username';
  static const String _keyHealthSyncCompleted = 'health_sync_completed';
  static const String _keyFirstLogin = 'first_login';

  /// 로그인 상태 확인
  Future<bool> isLoggedIn() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyIsLoggedIn) ?? false;
  }

  /// 로컬 로그인 (추후 실제 인증으로 대체 가능)
  ///
  /// [username]에 사용자 이름을 입력받습니다.
  /// 현재는 단순히 로컬 저장만 하지만, 추후 API 호출 등으로 확장 가능합니다.
  Future<void> login(String username) async {
    final prefs = await SharedPreferences.getInstance();

    // 첫 로그인 여부 확인 (기존에 로그인한 적이 없으면 첫 로그인)
    final hasLoggedInBefore = prefs.containsKey(_keyIsLoggedIn);
    if (!hasLoggedInBefore) {
      await prefs.setBool(_keyFirstLogin, true);
    }

    await prefs.setBool(_keyIsLoggedIn, true);
    await prefs.setString(_keyUsername, username);
  }

  /// 로그아웃
  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyIsLoggedIn, false);
    await prefs.remove(_keyUsername);
  }

  /// 저장된 사용자 이름 가져오기
  Future<String?> getUsername() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyUsername);
  }

  /// 첫 로그인 여부 확인
  Future<bool> isFirstLogin() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyFirstLogin) ?? false;
  }

  /// 첫 로그인 플래그 제거 (동기화 팝업 표시 후 호출)
  Future<void> clearFirstLoginFlag() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyFirstLogin);
  }

  /// 헬스 데이터 동기화 완료 여부 확인
  Future<bool> isHealthSyncCompleted() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyHealthSyncCompleted) ?? false;
  }

  /// 헬스 데이터 동기화 완료 표시
  Future<void> setHealthSyncCompleted(bool completed) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyHealthSyncCompleted, completed);
  }
}
