import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:pacelifter/services/auth_service.dart';
import 'package:pacelifter/models/user_profile.dart';
import 'package:pacelifter/services/profile_service.dart';
import 'package:intl/intl.dart';

/// 애슬릿 화면 (개인 정보 및 운동 기록)
class AthleteScreen extends StatefulWidget {
  const AthleteScreen({super.key});

  @override
  State<AthleteScreen> createState() => _AthleteScreenState();
}

class _AthleteScreenState extends State<AthleteScreen> with SingleTickerProviderStateMixin {
  final AuthService _authService = AuthService();
  final ProfileService _profileService = ProfileService();

  UserProfile? _userProfile;
  String? _username;
  bool _isLoading = true;

  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadUserData();
    _loadProfileData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : NestedScrollView(
              headerSliverBuilder: (context, innerBoxIsScrolled) {
                return [
                  SliverAppBar(
                    expandedHeight: 280,
                    floating: false,
                    pinned: true,
                    backgroundColor: Theme.of(context).colorScheme.surface,
                    foregroundColor: Theme.of(context).colorScheme.onSurface,
                    flexibleSpace: FlexibleSpaceBar(
                      background: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Theme.of(context).colorScheme.primary.withValues(alpha: 0.2),
                              Theme.of(context).colorScheme.surface,
                            ],
                          ),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.only(bottom: 48.0),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const SizedBox(height: 40),
                              CircleAvatar(
                                radius: 40,
                                backgroundColor: Theme.of(context).colorScheme.secondary,
                                child: Icon(
                                  Icons.person,
                                  size: 40,
                                  color: Theme.of(context).colorScheme.onSecondary,
                                ),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                _username ?? '애슬릿',
                                style: const TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'Hybrid Athlete',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Theme.of(context).colorScheme.primary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    bottom: TabBar(
                      controller: _tabController,
                      indicatorColor: Theme.of(context).colorScheme.secondary,
                      labelColor: Theme.of(context).colorScheme.secondary,
                      unselectedLabelColor: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                      tabs: const [
                        Tab(text: '개인 정보'),
                        Tab(text: '운동 기록'),
                      ],
                    ),
                  ),
                ];
              },
              body: TabBarView(
                controller: _tabController,
                children: [
                  _buildPersonalInfoTab(),
                  _buildPerformanceTab(),
                ],
              ),
            ),
    );
  }

  // ==================== Tab 1: 개인 정보 ====================
  Widget _buildPersonalInfoTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildEditableSection(
            title: '기본 정보',
            icon: Icons.person_outline,
            items: [
              _buildEditableItem(
                label: '성별',
                value: _userProfile?.gender == 'male' ? '남성' : (_userProfile?.gender == 'female' ? '여성' : '미설정'),
                onTap: () => _editGender(),
              ),
              _buildEditableItem(
                label: '생년월일',
                value: _userProfile?.birthDate != null ? DateFormat('yyyy - MM - dd').format(_userProfile!.birthDate!) : '미설정',
                onTap: () => _editBirthDate(),
              ),
              _buildEditableItem(
                label: '만 나이',
                value: _userProfile?.age != null ? '${_userProfile!.age} 세' : '미설정',
                onTap: () => _editBirthDate(),
              ),
              _buildEditableItem(
                label: '최대 심박수 (예상)',
                value: _userProfile?.maxHeartRate != null ? '${_userProfile!.maxHeartRate} BPM' : '미설정',
                onTap: () {}, // 자동 계산 항목
              ),
              _buildEditableItem(
                label: '키',
                value: _userProfile?.height != null ? '${_userProfile!.height!.toStringAsFixed(1)} cm' : '미설정',
                onTap: () => _editHeight(),
              ),
              _buildEditableItem(
                label: '체중',
                value: _userProfile?.weight != null ? '${_userProfile!.weight!.toStringAsFixed(1)} kg' : '미설정',
                onTap: () => _editWeight(),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildEditableSection(
            title: '러닝 프로필',
            svgIcon: 'assets/images/endurance/runner-icon.svg',
            items: [
              _buildEditableItem(
                label: '러닝 구력',
                value: _userProfile?.runningExperience != null ? '${_userProfile!.runningExperience!.toStringAsFixed(1)} 년' : '미설정',
                onTap: () => _editExperience('running'),
              ),
              _buildEditableItem(
                label: '러닝 실력',
                value: _formatLevel(_userProfile?.runningLevel),
                onTap: () => _editLevel('running'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildEditableSection(
            title: '웨이트 프로필',
            svgIcon: 'assets/images/strength/lifter-icon.svg',
            items: [
              _buildEditableItem(
                label: '웨이트 구력',
                value: _userProfile?.strengthExperience != null ? '${_userProfile!.strengthExperience!.toStringAsFixed(1)} 년' : '미설정',
                onTap: () => _editExperience('strength'),
              ),
              _buildEditableItem(
                label: '웨이트 실력',
                value: _formatLevel(_userProfile?.strengthLevel),
                onTap: () => _editLevel('strength'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildEditableSection(
            title: '인바디 정보',
            svgIcon: 'assets/images/pllogo.svg',
            items: [
              _buildEditableItem(
                label: '골격근량',
                value: _userProfile?.skeletalMuscleMass != null ? '${_userProfile!.skeletalMuscleMass!.toStringAsFixed(1)} kg' : '미설정',
                onTap: () => _editSkeletalMuscleMass(),
              ),
              _buildEditableItem(
                label: '체지방률',
                value: _userProfile?.bodyFatPercentage != null ? '${_userProfile!.bodyFatPercentage!.toStringAsFixed(1)} %' : '미설정',
                onTap: () => _editBodyFatPercentage(),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ==================== Tab 2: 운동 기록 ====================
  Widget _buildPerformanceTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildEditableSection(
            title: '러닝 최고 기록',
            svgIcon: 'assets/images/endurance/runner-icon.svg',
            items: [
              _buildEditableItem(
                label: 'Full Marathon',
                value: _formatDuration(_userProfile?.fullMarathonTime),
                onTap: () => _editRunningRecord('fullMarathon'),
              ),
              _buildEditableItem(
                label: 'Half Marathon',
                value: _formatDuration(_userProfile?.halfMarathonTime),
                onTap: () => _editRunningRecord('halfMarathon'),
              ),
              _buildEditableItem(
                label: '10K',
                value: _formatDuration(_userProfile?.tenKmTime),
                onTap: () => _editRunningRecord('10K'),
              ),
              _buildEditableItem(
                label: '5K',
                value: _formatDuration(_userProfile?.fiveKmTime),
                onTap: () => _editRunningRecord('5K'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildEditableSection(
            title: '맨몸 운동',
            svgIcon: 'assets/images/strength/pullup-icon.svg',
            items: [
              _buildEditableItem(
                label: '턱걸이 (최대)',
                value: _userProfile?.maxPullUps != null ? '${_userProfile!.maxPullUps} 회' : '미설정',
                onTap: () => _editBodyweightExercise('pullUps'),
              ),
              _buildEditableItem(
                label: '푸쉬업 (최대)',
                value: _userProfile?.maxPushUps != null ? '${_userProfile!.maxPushUps} 회' : '미설정',
                onTap: () => _editBodyweightExercise('pushUps'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildEditableSection(
            title: '3RM (3회 최대 중량)',
            svgIcon: 'assets/images/strength/lifter-icon.svg',
            items: [
              _buildEditableItem(
                label: '스쿼트',
                value: _userProfile?.squat3RM != null ? '${_userProfile!.squat3RM!.toStringAsFixed(1)} kg' : '미설정',
                onTap: () => _edit3RM('squat'),
              ),
              _buildEditableItem(
                label: '벤치프레스',
                value: _userProfile?.benchPress3RM != null ? '${_userProfile!.benchPress3RM!.toStringAsFixed(1)} kg' : '미설정',
                onTap: () => _edit3RM('benchPress'),
              ),
              _buildEditableItem(
                label: '데드리프트',
                value: _userProfile?.deadlift3RM != null ? '${_userProfile!.deadlift3RM!.toStringAsFixed(1)} kg' : '미설정',
                onTap: () => _edit3RM('deadlift'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ==================== UI Helper Methods ====================

  Widget _buildEditableSection({
    required String title,
    IconData? icon,
    String? svgIcon,
    required List<Widget> items,
  }) {
    return Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Row(
              children: [
                if (svgIcon != null)
                  SvgPicture.asset(
                    svgIcon,
                    width: 20,
                    height: 20,
                    colorFilter: ColorFilter.mode(
                      Theme.of(context).colorScheme.secondary,
                      BlendMode.srcIn,
                    ),
                  )
                else if (icon != null)
                  Icon(icon, size: 20, color: Theme.of(context).colorScheme.secondary),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          ...items,
        ],
      ),
    );
  }

  Widget _buildEditableItem({
    required String label,
    required String value,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            Row(
              children: [
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.secondary,
                  ),
                ),
                const SizedBox(width: 8),
                Icon(
                  Icons.chevron_right,
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.3),
                  size: 20,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _formatDuration(Duration? duration) {
    if (duration == null) return '미설정';
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final hours = twoDigits(duration.inHours);
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return '$hours:$minutes:$seconds';
  }

  String _formatLevel(String? level) {
    if (level == null) return '미설정';
    switch (level) {
      case 'beginner': return '초급';
      case 'intermediate': return '중급';
      case 'advanced': return '고급';
      default: return level;
    }
  }

  // ==================== Edit Methods ====================

  void _editGender() {
    showCupertinoModalPopup(
      context: context,
      builder: (context) {
        return CupertinoActionSheet(
          title: const Text('성별 선택'),
          actions: [
            CupertinoActionSheetAction(
              child: const Text('남성'),
              onPressed: () {
                _saveProfile(_userProfile?.copyWith(gender: 'male'));
                Navigator.pop(context);
              },
            ),
            CupertinoActionSheetAction(
              child: const Text('여성'),
              onPressed: () {
                _saveProfile(_userProfile?.copyWith(gender: 'female'));
                Navigator.pop(context);
              },
            ),
          ],
          cancelButton: CupertinoActionSheetAction(
            child: const Text('취소'),
            onPressed: () => Navigator.pop(context),
          ),
        );
      },
    );
  }

  void _editBirthDate() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('생년월일 선택'),
        content: SizedBox(
          height: 200,
          width: double.maxFinite,
          child: Localizations.override(
            context: context,
            locale: const Locale('ko', 'KR'),
            child: CupertinoDatePicker(
              mode: CupertinoDatePickerMode.date,
              initialDateTime: _userProfile?.birthDate ?? DateTime(1995, 1, 1),
              minimumYear: 1950,
              maximumDate: DateTime.now(),
              onDateTimeChanged: (DateTime newDate) {
                _saveProfile(_userProfile?.copyWith(birthDate: newDate));
              },
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('저장'),
          ),
        ],
      ),
    );
  }

  void _editHeight() {
    final controller = TextEditingController(
      text: _userProfile?.height?.toStringAsFixed(1) ?? '',
    );

    _showNumericInputDialog(
      title: '키 입력',
      hint: '키를 입력하세요 (cm)',
      controller: controller,
      onSave: (value) {
        final height = double.tryParse(value);
        if (height != null && height > 0) {
          _saveProfile(_userProfile?.copyWith(height: height));
        }
      },
    );
  }

  void _editWeight() {
    final controller = TextEditingController(
      text: _userProfile?.weight?.toStringAsFixed(1) ?? '',
    );

    _showNumericInputDialog(
      title: '체중 입력',
      hint: '체중을 입력하세요 (kg)',
      controller: controller,
      onSave: (value) {
        final weight = double.tryParse(value);
        if (weight != null && weight > 0) {
          _saveProfile(_userProfile?.copyWith(weight: weight));
        }
      },
    );
  }

  void _editExperience(String type) {
    double? currentValue = type == 'running' ? _userProfile?.runningExperience : _userProfile?.strengthExperience;
    final controller = TextEditingController(
      text: currentValue?.toStringAsFixed(1) ?? '',
    );

    _showNumericInputDialog(
      title: type == 'running' ? '러닝 구력 입력' : '웨이트 구력 입력',
      hint: '구력을 입력하세요 (년)',
      controller: controller,
      onSave: (value) {
        final exp = double.tryParse(value);
        if (exp != null && exp >= 0) {
          if (type == 'running') {
            _saveProfile(_userProfile?.copyWith(runningExperience: exp));
          } else {
            _saveProfile(_userProfile?.copyWith(strengthExperience: exp));
          }
        }
      },
    );
  }

  void _editLevel(String type) {
    showCupertinoModalPopup(
      context: context,
      builder: (context) {
        return CupertinoActionSheet(
          title: Text(type == 'running' ? '러닝 실력 선택' : '웨이트 실력 선택'),
          actions: [
            CupertinoActionSheetAction(
              child: const Text('초급'),
              onPressed: () {
                if (type == 'running') _saveProfile(_userProfile?.copyWith(runningLevel: 'beginner'));
                else _saveProfile(_userProfile?.copyWith(strengthLevel: 'beginner'));
                Navigator.pop(context);
              },
            ),
            CupertinoActionSheetAction(
              child: const Text('중급'),
              onPressed: () {
                if (type == 'running') _saveProfile(_userProfile?.copyWith(runningLevel: 'intermediate'));
                else _saveProfile(_userProfile?.copyWith(strengthLevel: 'intermediate'));
                Navigator.pop(context);
              },
            ),
            CupertinoActionSheetAction(
              child: const Text('고급'),
              onPressed: () {
                if (type == 'running') _saveProfile(_userProfile?.copyWith(runningLevel: 'advanced'));
                else _saveProfile(_userProfile?.copyWith(strengthLevel: 'advanced'));
                Navigator.pop(context);
              },
            ),
          ],
          cancelButton: CupertinoActionSheetAction(
            child: const Text('취소'),
            onPressed: () => Navigator.pop(context),
          ),
        );
      },
    );
  }

  void _editSkeletalMuscleMass() {
    final controller = TextEditingController(
      text: _userProfile?.skeletalMuscleMass?.toStringAsFixed(1) ?? '',
    );

    _showNumericInputDialog(
      title: '골격근량 입력',
      hint: '골격근량을 입력하세요 (kg)',
      controller: controller,
      onSave: (value) {
        final mass = double.tryParse(value);
        if (mass != null && mass > 0) {
          _saveProfile(_userProfile?.copyWith(skeletalMuscleMass: mass));
        }
      },
    );
  }

  void _editBodyFatPercentage() {
    final controller = TextEditingController(
      text: _userProfile?.bodyFatPercentage?.toStringAsFixed(1) ?? '',
    );

    _showNumericInputDialog(
      title: '체지방률 입력',
      hint: '체지방률을 입력하세요 (%)',
      controller: controller,
      onSave: (value) {
        final percentage = double.tryParse(value);
        if (percentage != null && percentage > 0 && percentage < 100) {
          _saveProfile(_userProfile?.copyWith(bodyFatPercentage: percentage));
        }
      },
    );
  }

  void _editRunningRecord(String type) {
    Duration? currentTime;
    switch (type) {
      case 'fullMarathon':
        currentTime = _userProfile?.fullMarathonTime;
        break;
      case 'halfMarathon':
        currentTime = _userProfile?.halfMarathonTime;
        break;
      case '10K':
        currentTime = _userProfile?.tenKmTime;
        break;
      case '5K':
        currentTime = _userProfile?.fiveKmTime;
        break;
    }

    _showTimeInputDialog(
      title: '기록 입력',
      currentTime: currentTime,
      onSave: (duration) {
        UserProfile? updated;
        switch (type) {
          case 'fullMarathon':
            updated = _userProfile?.copyWith(fullMarathonTime: duration);
            break;
          case 'halfMarathon':
            updated = _userProfile?.copyWith(halfMarathonTime: duration);
            break;
          case '10K':
            updated = _userProfile?.copyWith(tenKmTime: duration);
            break;
          case '5K':
            updated = _userProfile?.copyWith(fiveKmTime: duration);
            break;
        }
        if (updated != null) {
          _saveProfile(updated);
        }
      },
    );
  }

  void _editBodyweightExercise(String type) {
    int? currentValue;
    String title;

    if (type == 'pullUps') {
      currentValue = _userProfile?.maxPullUps;
      title = '최대 턱걸이 횟수';
    } else {
      currentValue = _userProfile?.maxPushUps;
      title = '최대 푸쉬업 횟수';
    }

    final controller = TextEditingController(
      text: currentValue?.toString() ?? '',
    );

    _showNumericInputDialog(
      title: title,
      hint: '횟수를 입력하세요',
      controller: controller,
      isInteger: true,
      onSave: (value) {
        final reps = int.tryParse(value);
        if (reps != null && reps >= 0) {
          UserProfile? updated;
          if (type == 'pullUps') {
            updated = _userProfile?.copyWith(maxPullUps: reps);
          } else {
            updated = _userProfile?.copyWith(maxPushUps: reps);
          }
          if (updated != null) {
            _saveProfile(updated);
          }
        }
      },
    );
  }

  void _edit3RM(String type) {
    double? currentValue;
    String title;

    switch (type) {
      case 'squat':
        currentValue = _userProfile?.squat3RM;
        title = '스쿼트 3RM';
        break;
      case 'benchPress':
        currentValue = _userProfile?.benchPress3RM;
        title = '벤치프레스 3RM';
        break;
      case 'deadlift':
        currentValue = _userProfile?.deadlift3RM;
        title = '데드리프트 3RM';
        break;
      default:
        return;
    }

    final controller = TextEditingController(
      text: currentValue?.toStringAsFixed(1) ?? '',
    );

    _showNumericInputDialog(
      title: title,
      hint: '중량을 입력하세요 (kg)',
      controller: controller,
      onSave: (value) {
        final weight = double.tryParse(value);
        if (weight != null && weight > 0) {
          UserProfile? updated;
          switch (type) {
            case 'squat':
              updated = _userProfile?.copyWith(squat3RM: weight);
              break;
            case 'benchPress':
              updated = _userProfile?.copyWith(benchPress3RM: weight);
              break;
            case 'deadlift':
              updated = _userProfile?.copyWith(deadlift3RM: weight);
              break;
          }
          if (updated != null) {
            _saveProfile(updated);
          }
        }
      },
    );
  }

  // ==================== Dialog Helpers ====================

  void _showNumericInputDialog({
    required String title,
    required String hint,
    required TextEditingController controller,
    required Function(String) onSave,
    bool isInteger = false,
  }) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          title,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: TextField(
          controller: controller,
          decoration: InputDecoration(
            hintText: hint,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: Theme.of(context).colorScheme.secondary,
                width: 2,
              ),
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          ),
          keyboardType: TextInputType.numberWithOptions(decimal: !isInteger),
          autofocus: true,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
            },
            child: Text(
              '취소',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                fontSize: 16,
              ),
            ),
          ),
          FilledButton(
            onPressed: () {
              final value = controller.text;
              Navigator.pop(context);
              onSave(value);
            },
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.secondary,
              foregroundColor: Colors.black,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
            child: const Text('저장', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _showTimeInputDialog({
    required String title,
    Duration? currentTime,
    required Function(Duration) onSave,
  }) {
    int hours = currentTime?.inHours ?? 0;
    int minutes = currentTime?.inMinutes.remainder(60) ?? 0;
    int seconds = currentTime?.inSeconds.remainder(60) ?? 0;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          title,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Container(
          height: 200,
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Expanded(
                child: CupertinoPicker(
                  itemExtent: 40,
                  scrollController: FixedExtentScrollController(initialItem: hours),
                  onSelectedItemChanged: (value) => hours = value,
                  children: List.generate(24, (index) => Center(child: Text('$index', style: const TextStyle(fontSize: 18)))),
                ),
              ),
              Text(':', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.secondary)),
              Expanded(
                child: CupertinoPicker(
                  itemExtent: 40,
                  scrollController: FixedExtentScrollController(initialItem: minutes),
                  onSelectedItemChanged: (value) => minutes = value,
                  children: List.generate(60, (index) => Center(child: Text(index.toString().padLeft(2, '0'), style: const TextStyle(fontSize: 18)))),
                ),
              ),
              Text(':', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.secondary)),
              Expanded(
                child: CupertinoPicker(
                  itemExtent: 40,
                  scrollController: FixedExtentScrollController(initialItem: seconds),
                  onSelectedItemChanged: (value) => seconds = value,
                  children: List.generate(60, (index) => Center(child: Text(index.toString().padLeft(2, '0'), style: const TextStyle(fontSize: 18)))),
                ),
              ),
            ],
          ),
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              '취소',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                fontSize: 16,
              ),
            ),
          ),
          FilledButton(
            onPressed: () {
              final duration = Duration(hours: hours, minutes: minutes, seconds: seconds);
              onSave(duration);
              Navigator.pop(context);
            },
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.secondary,
              foregroundColor: Colors.black,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
            child: const Text('저장', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Future<void> _saveProfile(UserProfile? profile) async {
    if (profile == null) return;

    await _profileService.saveProfile(profile);
    setState(() {
      _userProfile = profile;
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('저장되었습니다'),
          backgroundColor: Theme.of(context).colorScheme.secondary,
          duration: const Duration(seconds: 1),
        ),
      );
    }
  }
}