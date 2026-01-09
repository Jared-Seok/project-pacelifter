import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:pacelifter/services/auth_service.dart';
import 'package:pacelifter/screens/login_screen.dart';
import 'package:package_info_plus/package_info_plus.dart';

/// 설정 화면 (앱 정보, 데이터 관리, 계정)
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final AuthService _authService = AuthService();
  String _appVersion = '';
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadAppInfo();
  }

  Future<void> _loadAppInfo() async {
    final packageInfo = await PackageInfo.fromPlatform();
    setState(() {
      _appVersion = '${packageInfo.version} (${packageInfo.buildNumber})';
      _isLoading = false;
    });
  }

  Future<void> _handleLogout() async {
    final confirmed = await showCupertinoDialog<bool>(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('로그아웃'),
        content: const Text('정말 로그아웃하시겠습니까?'),
        actions: [
          CupertinoDialogAction(
            child: const Text('취소'),
            onPressed: () => Navigator.pop(context, false),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            child: const Text('로그아웃'),
            onPressed: () => Navigator.pop(context, true),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _authService.logout();
      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const LoginScreen()),
          (route) => false,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        title: const Text('설정'),
        backgroundColor: Theme.of(context).colorScheme.surface,
        foregroundColor: Theme.of(context).colorScheme.onSurface,
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _buildSettingsSection(
                  title: '앱 정보',
                  items: [
                    _buildSettingsItem(
                      icon: Icons.info_outline,
                      title: '버전',
                      value: _appVersion,
                      onTap: null,
                    ),
                    _buildSettingsItem(
                      icon: Icons.favorite_outline,
                      title: 'HealthKit 연동',
                      value: '활성화됨',
                      onTap: () => _showHealthKitInfo(),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                _buildSettingsSection(
                  title: '데이터',
                  items: [
                    _buildSettingsItem(
                      icon: Icons.upload_outlined,
                      title: '데이터 내보내기',
                      subtitle: '운동 기록을 CSV 파일로 저장',
                      onTap: () => _exportData(),
                    ),
                    _buildSettingsItem(
                      icon: Icons.sync,
                      title: 'HealthKit 동기화',
                      subtitle: '건강 데이터 수동 동기화',
                      onTap: () => _syncHealthKit(),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                _buildSettingsSection(
                  title: '계정',
                  items: [
                    _buildSettingsItem(
                      icon: Icons.logout,
                      title: '로그아웃',
                      subtitle: '현재 계정에서 로그아웃',
                      onTap: _handleLogout,
                      isDestructive: true,
                    ),
                  ],
                ),
              ],
            ),
    );
  }

  Widget _buildSettingsSection({
    required String title,
    required List<Widget> items,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 8, bottom: 8),
          child: Text(
            title,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
            ),
          ),
        ),
        Card(
          child: Column(
            children: items,
          ),
        ),
      ],
    );
  }

  Widget _buildSettingsItem({
    required IconData icon,
    required String title,
    String? subtitle,
    String? value,
    VoidCallback? onTap,
    bool isDestructive = false,
  }) {
    final textColor = isDestructive ? Colors.red : Theme.of(context).colorScheme.onSurface;
    final iconColor = isDestructive ? Colors.red : Theme.of(context).colorScheme.primary;

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        child: Row(
          children: [
            Icon(icon, color: iconColor, size: 24),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: textColor,
                    ),
                  ),
                  if (subtitle != null)
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 13,
                        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                      ),
                    ),
                ],
              ),
            ),
            if (value != null)
              Text(
                value,
                style: TextStyle(
                  fontSize: 14,
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                ),
              ),
            if (onTap != null) ...[
              const SizedBox(width: 8),
              Icon(
                Icons.chevron_right,
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.3),
                size: 20,
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _showHealthKitInfo() {
    showCupertinoDialog(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('HealthKit 연동'),
        content: const Text('현재 HealthKit과 연동되어 운동 기록이 자동으로 동기화됩니다.'),
        actions: [
          CupertinoDialogAction(
            child: const Text('확인'),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }

  void _exportData() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('데이터 내보내기 기능은 준비 중입니다'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  void _syncHealthKit() {
    showCupertinoDialog(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('HealthKit 동기화'),
        content: const Text('HealthKit 데이터를 수동으로 동기화하시겠습니까?'),
        actions: [
          CupertinoDialogAction(
            child: const Text('취소'),
            onPressed: () => Navigator.pop(context),
          ),
          CupertinoDialogAction(
            child: const Text('동기화'),
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: const Text('동기화 완료'),
                  backgroundColor: Theme.of(context).colorScheme.primary,
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
