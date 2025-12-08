import 'package:flutter/material.dart';
import 'package:pacelifter/services/auth_service.dart';
import 'package:pacelifter/screens/login_screen.dart';
import 'package:pacelifter/models/user_profile.dart';
import 'package:pacelifter/services/profile_service.dart';

/// 프로필 화면
///
/// 사용자 정보 및 설정 기능이 구현될 화면입니다.
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final AuthService _authService = AuthService();
  final ProfileService _profileService = ProfileService();
  UserProfile? _userProfile;
  String? _username;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadUserData();
    _loadProfileData();
  }

  Future<void> _loadUserData() async {
    final username = await _authService.getUsername();
    setState(() {
      _username = username;
    });
  }

  Future<void> _loadProfileData() async {
    final profile = await _profileService.getProfile();
    setState(() {
      _userProfile = profile;
      _isLoading = false;
    });
  }

  Future<void> _handleLogout() async {
    await _authService.logout();
    if (mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => const LoginScreen()),
        (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        title: const Text('프로필'),
        backgroundColor: Theme.of(context).colorScheme.surface,
        foregroundColor: Theme.of(context).colorScheme.onSurface,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  const SizedBox(height: 24),
                  CircleAvatar(
                    radius: 50,
                    backgroundColor: Theme.of(context).colorScheme.secondary,
                    child: Icon(
                      Icons.person,
                      size: 50,
                      color: Theme.of(context).colorScheme.onSecondary,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    _username ?? '사용자',
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Hybrid Athlete',
                    style: TextStyle(
                      fontSize: 14,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                  const SizedBox(height: 32),
                  
                  // Profile cards will be here
                  _buildBasicInfoCard(),
                  const SizedBox(height: 16),
                  _buildBodyCompositionCard(),
                  const SizedBox(height: 16),
                  _buildRunningRecordsCard(),
                  const SizedBox(height: 16),
                  _buildBodyweightCard(),
                  const SizedBox(height: 16),
                  _build3RMCard(),
                  const SizedBox(height: 16),

                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: _handleLogout,
                      icon: const Icon(Icons.logout),
                      label: const Text('로그아웃'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        foregroundColor: Colors.red,
                        side: const BorderSide(color: Colors.red),
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  // Helper methods for building profile cards

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 16.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: Theme.of(context).textTheme.titleMedium),
          Text(value, style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  String _formatDuration(Duration? duration) {
    if (duration == null) return '-';
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final hours = twoDigits(duration.inHours);
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return '$hours:$minutes:$seconds';
  }

  Widget _buildSectionCard({required String title, required List<Widget> children}) {
    return Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text(
              title,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
            ),
          ),
          const Divider(),
          ...children,
        ],
      ),
    );
  }

  Widget _buildBasicInfoCard() {
    if (_userProfile == null) return const SizedBox.shrink();
    return _buildSectionCard(
      title: '기본 정보',
      children: [
        _buildInfoRow('성별', _userProfile!.gender == 'male' ? '남성' : (_userProfile!.gender == 'female' ? '여성' : '-')),
        _buildInfoRow('키', '${_userProfile!.height?.toStringAsFixed(1) ?? '-'} cm'),
        _buildInfoRow('체중', '${_userProfile!.weight?.toStringAsFixed(1) ?? '-'} kg'),
      ],
    );
  }

  Widget _buildBodyCompositionCard() {
    if (_userProfile == null || (_userProfile!.skeletalMuscleMass == null && _userProfile!.bodyFatPercentage == null)) {
      return const SizedBox.shrink();
    }
    return _buildSectionCard(
      title: '인바디 정보',
      children: [
        if (_userProfile!.skeletalMuscleMass != null)
          _buildInfoRow('골격근량', '${_userProfile!.skeletalMuscleMass?.toStringAsFixed(1)} kg'),
        if (_userProfile!.bodyFatPercentage != null)
          _buildInfoRow('체지방률', '${_userProfile!.bodyFatPercentage?.toStringAsFixed(1)} %'),
      ],
    );
  }

  Widget _buildRunningRecordsCard() {
    if (_userProfile == null || (_userProfile!.fullMarathonTime == null && _userProfile!.halfMarathonTime == null && _userProfile!.tenKmTime == null && _userProfile!.fiveKmTime == null)) {
      return const SizedBox.shrink();
    }
    return _buildSectionCard(
      title: '러닝 기록',
      children: [
        if (_userProfile!.fullMarathonTime != null)
          _buildInfoRow('Full', _formatDuration(_userProfile!.fullMarathonTime)),
        if (_userProfile!.halfMarathonTime != null)
          _buildInfoRow('Half', _formatDuration(_userProfile!.halfMarathonTime)),
        if (_userProfile!.tenKmTime != null)
          _buildInfoRow('10K', _formatDuration(_userProfile!.tenKmTime)),
        if (_userProfile!.fiveKmTime != null)
          _buildInfoRow('5K', _formatDuration(_userProfile!.fiveKmTime)),
      ],
    );
  }

  Widget _buildBodyweightCard() {
    if (_userProfile == null || (_userProfile!.maxPullUps == null && _userProfile!.maxPushUps == null)) {
      return const SizedBox.shrink();
    }
    return _buildSectionCard(
      title: '맨몸 운동',
      children: [
        if (_userProfile!.maxPullUps != null)
          _buildInfoRow('턱걸이', '${_userProfile!.maxPullUps} 회'),
        if (_userProfile!.maxPushUps != null)
          _buildInfoRow('푸쉬업', '${_userProfile!.maxPushUps} 회'),
      ],
    );
  }

  Widget _build3RMCard() {
    if (_userProfile == null || (_userProfile!.squat3RM == null && _userProfile!.benchPress3RM == null && _userProfile!.deadlift3RM == null)) {
      return const SizedBox.shrink();
    }
    return _buildSectionCard(
      title: '3RM',
      children: [
        if (_userProfile!.squat3RM != null)
          _buildInfoRow('스쿼트', '${_userProfile!.squat3RM?.toStringAsFixed(1)} kg'),
        if (_userProfile!.benchPress3RM != null)
          _buildInfoRow('벤치프레스', '${_userProfile!.benchPress3RM?.toStringAsFixed(1)} kg'),
        if (_userProfile!.deadlift3RM != null)
          _buildInfoRow('데드리프트', '${_userProfile!.deadlift3RM?.toStringAsFixed(1)} kg'),
      ],
    );
  }
}
