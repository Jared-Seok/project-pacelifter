import 'package:flutter/material.dart';
import 'package:pacelifter/models/user_profile.dart';
import 'package:pacelifter/services/profile_service.dart';
import 'package:pacelifter/screens/main_navigation.dart';

/// 사용자 프로필 설정을 위한 다단계 화면
class ProfileSetupScreen extends StatefulWidget {
  const ProfileSetupScreen({super.key});

  @override
  State<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends State<ProfileSetupScreen>
    with SingleTickerProviderStateMixin {
  final PageController _pageController = PageController();
  final ProfileService _profileService = ProfileService();
  UserProfile _userProfile = UserProfile();

  int _currentPage = 0;
  final int _totalPages = 5;

  late AnimationController _progressAnimationController;
  late Animation<double> _progressAnimation;

  @override
  void initState() {
    super.initState();
    _progressAnimationController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );
    _progressAnimation = Tween<double>(begin: 0.0, end: 1.0 / _totalPages)
        .animate(
          CurvedAnimation(
            parent: _progressAnimationController,
            curve: Curves.easeInOut,
          ),
        );
    _progressAnimationController.forward();
  }

  @override
  void dispose() {
    _progressAnimationController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  void _nextPage() {
    if (_currentPage < _totalPages - 1) {
      setState(() {
        _currentPage++;
      });
      _progressAnimation =
          Tween<double>(
            begin: _currentPage / _totalPages,
            end: (_currentPage + 1) / _totalPages,
          ).animate(
            CurvedAnimation(
              parent: _progressAnimationController,
              curve: Curves.easeInOut,
            ),
          );
      _progressAnimationController.reset();
      _progressAnimationController.forward();

      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  Future<void> _finishSetup() async {
    await _profileService.saveProfile(_userProfile);
    await _profileService.setProfileSetupCompleted(true);

    if (!mounted) return;

    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (context) => const MainNavigation()),
    );
  }

  /// hh:mm:ss 형식의 문자열을 Duration으로 변환합니다.
  Duration? _parseDuration(String? time) {
    if (time == null || time.isEmpty) return null;
    final parts = time.split(':');
    if (parts.length != 3) return null;

    final hours = int.tryParse(parts[0]);
    final minutes = int.tryParse(parts[1]);
    final seconds = int.tryParse(parts[2]);

    if (hours == null || minutes == null || seconds == null) return null;

    return Duration(hours: hours, minutes: minutes, seconds: seconds);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('프로필 설정'),
        automaticallyImplyLeading: false,
      ),
      body: Column(
        children: [
          AnimatedBuilder(
            animation: _progressAnimation,
            builder: (context, child) {
              return LinearProgressIndicator(
                value: _progressAnimation.value,
                minHeight: 8,
                backgroundColor: Colors.white,
                valueColor: AlwaysStoppedAnimation<Color>(
                  Theme.of(context).colorScheme.secondary,
                ),
              );
            },
          ),
          Expanded(
            child: PageView(
              controller: _pageController,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                _buildStep1(),
                _buildStep2(),
                _buildStep3(),
                _buildStep4(),
                _buildStep5(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStep1() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '기본 정보 입력',
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            '정확한 분석을 위해 기본 신체 정보를 입력해주세요.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 32),
          Text('성별', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          SegmentedButton<String>(
            emptySelectionAllowed: true,
            segments: const [
              ButtonSegment(
                value: 'male',
                label: Text('남성'),
                icon: Icon(Icons.male),
              ),
              ButtonSegment(
                value: 'female',
                label: Text('여성'),
                icon: Icon(Icons.female),
              ),
            ],
            selected: _userProfile.gender != null ? {_userProfile.gender!} : {},
            onSelectionChanged: (Set<String> newSelection) {
              setState(() {
                _userProfile = _userProfile.copyWith(
                  gender: newSelection.first,
                );
              });
            },
            style: SegmentedButton.styleFrom(
              minimumSize: const Size(double.infinity, 48),
            ),
          ),
          const SizedBox(height: 24),
          Text('키 (cm)', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          TextField(
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              hintText: '예: 175',
              border: OutlineInputBorder(),
            ),
            onChanged: (value) {
              setState(() {
                _userProfile = _userProfile.copyWith(
                  height: double.tryParse(value),
                );
              });
            },
          ),
          const SizedBox(height: 24),
          Text('체중 (kg)', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          TextField(
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              hintText: '예: 70.5',
              border: OutlineInputBorder(),
            ),
            onChanged: (value) {
              setState(() {
                _userProfile = _userProfile.copyWith(
                  weight: double.tryParse(value),
                );
              });
            },
          ),
          const SizedBox(height: 48),
          Center(
            child: Text(
              '애슬릿의 모든 정보는 디바이스에 저장되며, 서버가 수집하지 않습니다.',
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: Colors.grey),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton(
              onPressed:
                  (_userProfile.gender != null &&
                      _userProfile.height != null &&
                      _userProfile.weight != null)
                  ? _nextPage
                  : null,
              style: ElevatedButton.styleFrom(
                backgroundColor:
                    (_userProfile.gender != null &&
                        _userProfile.height != null &&
                        _userProfile.weight != null)
                    ? Theme.of(context).colorScheme.secondary
                    : Colors.grey,
                foregroundColor:
                    (_userProfile.gender != null &&
                        _userProfile.height != null &&
                        _userProfile.weight != null)
                    ? Colors.black
                    : Colors.white,
                disabledBackgroundColor: Colors.grey,
                disabledForegroundColor: Colors.white,
              ),
              child: const Text(
                '다음',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStep2() {
    final hasInput =
        _userProfile.skeletalMuscleMass != null ||
        _userProfile.bodyFatPercentage != null;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '인바디 정보 입력 (선택)',
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            '더욱 정확한 퍼포먼스 분석을 위해 인바디 정보를 입력할 수 있습니다.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 32),
          Text('골격근량 (kg)', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          TextField(
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              hintText: '예: 35.5',
              border: OutlineInputBorder(),
            ),
            onChanged: (value) {
              setState(() {
                _userProfile = _userProfile.copyWith(
                  skeletalMuscleMass: double.tryParse(value),
                );
              });
            },
          ),
          const SizedBox(height: 24),
          Text('체지방률 (%)', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          TextField(
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              hintText: '예: 15.2',
              border: OutlineInputBorder(),
            ),
            onChanged: (value) {
              setState(() {
                _userProfile = _userProfile.copyWith(
                  bodyFatPercentage: double.tryParse(value),
                );
              });
            },
          ),
          const SizedBox(height: 48),
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton(
              onPressed: _nextPage,
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(
                  context,
                ).colorScheme.primary.withValues(alpha: 0.7),
                foregroundColor: Colors.white,
              ),
              child: const Text(
                '건너뛰기',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton(
              onPressed: hasInput ? _nextPage : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: hasInput
                    ? Theme.of(context).colorScheme.secondary
                    : Colors.grey,
                foregroundColor: hasInput ? Colors.black : Colors.white,
                disabledBackgroundColor: Colors.grey,
                disabledForegroundColor: Colors.white,
              ),
              child: const Text(
                '다음',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStep3() {
    final hasInput =
        _userProfile.fullMarathonTime != null ||
        _userProfile.halfMarathonTime != null ||
        _userProfile.tenKmTime != null ||
        _userProfile.fiveKmTime != null;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '러닝 최고 기록 (선택)',
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            '러닝 퍼포먼스 분석에 사용됩니다. 없으면 건너뛸 수 있습니다.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 32),
          Text(
            'Full (42.195km)',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          TextField(
            keyboardType: TextInputType.datetime,
            decoration: const InputDecoration(
              hintText: '예: 03:30:00',
              border: OutlineInputBorder(),
            ),
            onChanged: (value) {
              setState(() {
                _userProfile = _userProfile.copyWith(
                  fullMarathonTime: _parseDuration(value),
                );
              });
            },
          ),
          const SizedBox(height: 24),
          Text('Half', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          TextField(
            keyboardType: TextInputType.datetime,
            decoration: const InputDecoration(
              hintText: '예: 01:45:00',
              border: OutlineInputBorder(),
            ),
            onChanged: (value) {
              setState(() {
                _userProfile = _userProfile.copyWith(
                  halfMarathonTime: _parseDuration(value),
                );
              });
            },
          ),
          const SizedBox(height: 24),
          Text('10K', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          TextField(
            keyboardType: TextInputType.datetime,
            decoration: const InputDecoration(
              hintText: '예: 00:45:00',
              border: OutlineInputBorder(),
            ),
            onChanged: (value) {
              setState(() {
                _userProfile = _userProfile.copyWith(
                  tenKmTime: _parseDuration(value),
                );
              });
            },
          ),
          const SizedBox(height: 24),
          Text('5K', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          TextField(
            keyboardType: TextInputType.datetime,
            decoration: const InputDecoration(
              hintText: '예: 00:21:00',
              border: OutlineInputBorder(),
            ),
            onChanged: (value) {
              setState(() {
                _userProfile = _userProfile.copyWith(
                  fiveKmTime: _parseDuration(value),
                );
              });
            },
          ),
          const SizedBox(height: 48),
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton(
              onPressed: _nextPage,
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(
                  context,
                ).colorScheme.primary.withValues(alpha: 0.7),
                foregroundColor: Colors.white,
              ),
              child: const Text(
                '건너뛰기',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton(
              onPressed: hasInput ? _nextPage : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: hasInput
                    ? Theme.of(context).colorScheme.secondary
                    : Colors.grey,
                foregroundColor: hasInput ? Colors.black : Colors.white,
                disabledBackgroundColor: Colors.grey,
                disabledForegroundColor: Colors.white,
              ),
              child: const Text(
                '다음',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStep4() {
    final hasInput =
        _userProfile.maxPullUps != null || _userProfile.maxPushUps != null;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '맨몸 운동 능력 (선택)',
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            '현재 수행 가능한 최대 횟수를 입력해주세요.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 32),
          Text(
            '턱걸이 (Pull-ups)',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          TextField(
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              hintText: '예: 10',
              border: OutlineInputBorder(),
            ),
            onChanged: (value) {
              setState(() {
                _userProfile = _userProfile.copyWith(
                  maxPullUps: int.tryParse(value),
                );
              });
            },
          ),
          const SizedBox(height: 24),
          Text(
            '푸쉬업 (Push-ups)',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          TextField(
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              hintText: '예: 30',
              border: OutlineInputBorder(),
            ),
            onChanged: (value) {
              setState(() {
                _userProfile = _userProfile.copyWith(
                  maxPushUps: int.tryParse(value),
                );
              });
            },
          ),
          const SizedBox(height: 48),
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton(
              onPressed: _nextPage,
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(
                  context,
                ).colorScheme.primary.withValues(alpha: 0.7),
                foregroundColor: Colors.white,
              ),
              child: const Text(
                '건너뛰기',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton(
              onPressed: hasInput ? _nextPage : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: hasInput
                    ? Theme.of(context).colorScheme.secondary
                    : Colors.grey,
                foregroundColor: hasInput ? Colors.black : Colors.white,
                disabledBackgroundColor: Colors.grey,
                disabledForegroundColor: Colors.white,
              ),
              child: const Text(
                '다음',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStep5() {
    final hasInput =
        _userProfile.squat3RM != null ||
        _userProfile.benchPress3RM != null ||
        _userProfile.deadlift3RM != null;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '3대 운동 3RM (선택)',
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            '3회 반복 가능한 최대 무게(3RM)를 입력해주세요.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 32),
          Text('스쿼트 (kg)', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          TextField(
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              hintText: '예: 100',
              border: OutlineInputBorder(),
            ),
            onChanged: (value) {
              setState(() {
                _userProfile = _userProfile.copyWith(
                  squat3RM: double.tryParse(value),
                );
              });
            },
          ),
          const SizedBox(height: 24),
          Text('벤치프레스 (kg)', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          TextField(
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              hintText: '예: 80',
              border: OutlineInputBorder(),
            ),
            onChanged: (value) {
              setState(() {
                _userProfile = _userProfile.copyWith(
                  benchPress3RM: double.tryParse(value),
                );
              });
            },
          ),
          const SizedBox(height: 24),
          Text('데드리프트 (kg)', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          TextField(
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              hintText: '예: 120',
              border: OutlineInputBorder(),
            ),
            onChanged: (value) {
              setState(() {
                _userProfile = _userProfile.copyWith(
                  deadlift3RM: double.tryParse(value),
                );
              });
            },
          ),
          const SizedBox(height: 48),
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton(
              onPressed: _finishSetup,
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(
                  context,
                ).colorScheme.primary.withValues(alpha: 0.7),
                foregroundColor: Colors.white,
              ),
              child: const Text(
                '건너뛰기',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton(
              onPressed: hasInput ? _finishSetup : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: hasInput
                    ? Theme.of(context).colorScheme.secondary
                    : Colors.grey,
                foregroundColor: hasInput ? Colors.black : Colors.white,
                disabledBackgroundColor: Colors.grey,
                disabledForegroundColor: Colors.white,
              ),
              child: const Text(
                '완료',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
