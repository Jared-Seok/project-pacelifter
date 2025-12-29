import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:pacelifter/models/user_profile.dart';
import 'package:pacelifter/services/profile_service.dart';
import 'package:pacelifter/screens/main_navigation.dart';
import 'package:intl/intl.dart';

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
  final int _totalPages = 7; // 기본정보, 러닝경험, 웨이트경험, 인바디, 러닝기록, 맨몸운동, 3RM

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

  void _previousPage() {
    if (_currentPage > 0) {
      setState(() {
        _currentPage--;
      });
      _progressAnimation =
          Tween<double>(
            begin: (_currentPage + 1) / _totalPages,
            end: _currentPage / _totalPages,
          ).animate(
            CurvedAnimation(
              parent: _progressAnimationController,
              curve: Curves.easeInOut,
            ),
          );
      _progressAnimationController.reset();
      _progressAnimationController.forward();

      _pageController.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  void _showBirthDatePicker() {
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
              initialDateTime: _userProfile.birthDate ?? DateTime(1995, 1, 1),
              minimumYear: 1950,
              maximumDate: DateTime.now(),
              onDateTimeChanged: (DateTime newDate) {
                setState(() => _userProfile = _userProfile.copyWith(birthDate: newDate));
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

  Future<void> _finishSetup() async {
    await _profileService.saveProfile(_userProfile);
    await _profileService.setProfileSetupCompleted(true);

    if (!mounted) return;

    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (context) => const MainNavigation()),
    );
  }

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
        leading: _currentPage > 0 
          ? IconButton(icon: const Icon(Icons.arrow_back), onPressed: _previousPage)
          : null,
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
                backgroundColor: Colors.white10,
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
                _buildStep1(), // 기본 정보 (성별, 키, 체중, 생년월일)
                _buildStep2(), // 러닝 구력/레벨
                _buildStep3(), // 웨이트 구력/레벨
                _buildStep4(), // 인바디
                _buildStep5(), // 러닝 기록
                _buildStep6(), // 맨몸 운동
                _buildStep7(), // 3RM
              ],
            ),
          ),
        ],
      ),
    );
  }

  // 1단계: 기본 정보 (생년월일 추가)
  Widget _buildStep1() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('기본 정보 입력', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          const Text('정확한 분석 및 최대 심박수 계산을 위해 필요합니다.', style: TextStyle(color: Colors.grey)),
          const SizedBox(height: 32),
          
          Text('성별', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          SegmentedButton<String>(
            emptySelectionAllowed: true,
            segments: const [
              ButtonSegment(value: 'male', label: Text('남성'), icon: Icon(Icons.male)),
              ButtonSegment(value: 'female', label: Text('여성'), icon: Icon(Icons.female)),
            ],
            selected: _userProfile.gender != null ? {_userProfile.gender!} : {},
            onSelectionChanged: (val) => setState(() => _userProfile = _userProfile.copyWith(gender: val.first)),
          ),
          
          const SizedBox(height: 24),
          Text('생년월일', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          InkWell(
            onTap: () => _showBirthDatePicker(),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(border: Border.all(color: Colors.grey), borderRadius: BorderRadius.circular(8)),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(_userProfile.birthDate == null ? '날짜 선택' : DateFormat('yyyy - MM - dd').format(_userProfile.birthDate!)),
                  const Icon(Icons.calendar_today, size: 18),
                ],
              ),
            ),
          ),

          const SizedBox(height: 24),
          Text('키 (cm)', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          TextField(
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(hintText: '예: 175', border: OutlineInputBorder()),
            onChanged: (val) => setState(() => _userProfile = _userProfile.copyWith(height: double.tryParse(val))),
          ),
          
          const SizedBox(height: 24),
          Text('체중 (kg)', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          TextField(
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(hintText: '예: 70', border: OutlineInputBorder()),
            onChanged: (val) => setState(() => _userProfile = _userProfile.copyWith(weight: double.tryParse(val))),
          ),

          const SizedBox(height: 48),
          SizedBox(
            width: double.infinity, height: 56,
            child: ElevatedButton(
              onPressed: (_userProfile.gender != null && _userProfile.birthDate != null && _userProfile.height != null && _userProfile.weight != null) ? _nextPage : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.secondary,
                foregroundColor: Colors.black,
              ),
              child: const Text('다음', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }

  // 2단계: 러닝 구력 및 레벨
  Widget _buildStep2() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('러닝 프로필', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          const Text('귀하의 러닝 경험을 알려주세요.', style: TextStyle(color: Colors.grey)),
          const SizedBox(height: 32),
          
          Text('러닝 구력 (년)', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          TextField(
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(hintText: '예: 1.5', border: OutlineInputBorder(), suffixText: '년'),
            onChanged: (val) => setState(() => _userProfile = _userProfile.copyWith(runningExperience: double.tryParse(val))),
          ),

          const SizedBox(height: 32),
          Text('러닝 실력 (자체 평가)', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 12),
          _buildLevelSelector(
            current: _userProfile.runningLevel,
            onSelect: (val) => setState(() => _userProfile = _userProfile.copyWith(runningLevel: val)),
          ),

          const SizedBox(height: 48),
          SizedBox(
            width: double.infinity, height: 56,
            child: ElevatedButton(
              onPressed: (_userProfile.runningExperience != null && _userProfile.runningLevel != null) ? _nextPage : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.secondary,
                foregroundColor: Colors.black,
              ),
              child: const Text('다음', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ),
          const SizedBox(height: 12),
          TextButton(
            onPressed: _nextPage,
            child: const Center(child: Text('나중에 입력하기', style: TextStyle(color: Colors.grey))),
          ),
        ],
      ),
    );
  }

  // 3단계: 웨이트 구력 및 레벨
  Widget _buildStep3() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('웨이트 프로필', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          const Text('귀하의 근력 운동 경험을 알려주세요.', style: TextStyle(color: Colors.grey)),
          const SizedBox(height: 32),
          
          Text('웨이트 구력 (년)', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          TextField(
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(hintText: '예: 2', border: OutlineInputBorder(), suffixText: '년'),
            onChanged: (val) => setState(() => _userProfile = _userProfile.copyWith(strengthExperience: double.tryParse(val))),
          ),

          const SizedBox(height: 32),
          Text('웨이트 실력 (자체 평가)', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 12),
          _buildLevelSelector(
            current: _userProfile.strengthLevel,
            onSelect: (val) => setState(() => _userProfile = _userProfile.copyWith(strengthLevel: val)),
          ),

          const SizedBox(height: 48),
          SizedBox(
            width: double.infinity, height: 56,
            child: ElevatedButton(
              onPressed: (_userProfile.strengthExperience != null && _userProfile.strengthLevel != null) ? _nextPage : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.secondary,
                foregroundColor: Colors.black,
              ),
              child: const Text('다음', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ),
          const SizedBox(height: 12),
          TextButton(
            onPressed: _nextPage,
            child: const Center(child: Text('나중에 입력하기', style: TextStyle(color: Colors.grey))),
          ),
        ],
      ),
    );
  }

  Widget _buildLevelSelector({String? current, required Function(String) onSelect}) {
    return Column(
      children: [
        _levelTile('beginner', '초급', '기본기를 익히고 있는 단계', current, onSelect),
        const SizedBox(height: 12),
        _levelTile('intermediate', '중급', '숙련된 자세로 꾸준히 운동 중', current, onSelect),
        const SizedBox(height: 12),
        _levelTile('advanced', '고급', '고강도 훈련 및 정교한 루틴 수행', current, onSelect),
      ],
    );
  }

  Widget _levelTile(String id, String title, String desc, String? current, Function(String) onSelect) {
    final isSelected = current == id;
    return InkWell(
      onTap: () => onSelect(id),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected ? Theme.of(context).colorScheme.secondary.withValues(alpha: 0.1) : Colors.transparent,
          border: Border.all(color: isSelected ? Theme.of(context).colorScheme.secondary : Colors.grey[800]!),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: isSelected ? Theme.of(context).colorScheme.secondary : Colors.white)),
                  Text(desc, style: TextStyle(fontSize: 12, color: Colors.grey[400])),
                ],
              ),
            ),
            if (isSelected) Icon(Icons.check_circle, color: Theme.of(context).colorScheme.secondary),
          ],
        ),
      ),
    );
  }

  // 4단계: 인바디 (선택)
  Widget _buildStep4() {
    return _buildSelectionStep('인바디 정보 입력 (선택)', '정확한 분석을 위해 필요한 정보입니다.', [
      _buildNumericField('골격근량 (kg)', (val) => _userProfile = _userProfile.copyWith(skeletalMuscleMass: double.tryParse(val))),
      _buildNumericField('체지방률 (%)', (val) => _userProfile = _userProfile.copyWith(bodyFatPercentage: double.tryParse(val))),
    ]);
  }

  // 5단계: 러닝 기록 (선택)
  Widget _buildStep5() {
    return _buildSelectionStep('러닝 최고 기록 (선택)', '러닝 퍼포먼스 분석에 사용됩니다.', [
      _buildTimeField('Full (42.195km)', (val) => _userProfile = _userProfile.copyWith(fullMarathonTime: _parseDuration(val))),
      _buildTimeField('Half (21.097km)', (val) => _userProfile = _userProfile.copyWith(halfMarathonTime: _parseDuration(val))),
      _buildTimeField('10K', (val) => _userProfile = _userProfile.copyWith(tenKmTime: _parseDuration(val))),
      _buildTimeField('5K', (val) => _userProfile = _userProfile.copyWith(fiveKmTime: _parseDuration(val))),
    ]);
  }

  // 6단계: 맨몸 운동 (선택)
  Widget _buildStep6() {
    return _buildSelectionStep('맨몸 운동 능력 (선택)', '수행 가능한 최대 횟수를 입력해주세요.', [
      _buildNumericField('턱걸이 (최대)', (val) => _userProfile = _userProfile.copyWith(maxPullUps: int.tryParse(val))),
      _buildNumericField('푸쉬업 (최대)', (val) => _userProfile = _userProfile.copyWith(maxPushUps: int.tryParse(val))),
    ]);
  }

  // 7단계: 3RM (선택)
  Widget _buildStep7() {
    return _buildSelectionStep('3대 운동 3RM (선택)', '3회 반복 가능한 최대 무게를 입력해주세요.', [
      _buildNumericField('스쿼트 (kg)', (val) => _userProfile = _userProfile.copyWith(squat3RM: double.tryParse(val))),
      _buildNumericField('벤치프레스 (kg)', (val) => _userProfile = _userProfile.copyWith(benchPress3RM: double.tryParse(val))),
      _buildNumericField('데드리프트 (kg)', (val) => _userProfile = _userProfile.copyWith(deadlift3RM: double.tryParse(val))),
    ], isLast: true);
  }

  // 공통 선택사항 빌더
  Widget _buildSelectionStep(String title, String desc, List<Widget> fields, {bool isLast = false}) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text(desc, style: const TextStyle(color: Colors.grey)),
          const SizedBox(height: 32),
          ...fields,
          const SizedBox(height: 48),
          SizedBox(
            width: double.infinity, height: 56,
            child: ElevatedButton(
              onPressed: isLast ? _finishSetup : _nextPage,
              style: ElevatedButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.secondary, foregroundColor: Colors.black),
              child: Text(isLast ? '완료' : '다음', style: const TextStyle(fontWeight: FontWeight.bold)),
            ),
          ),
          const SizedBox(height: 12),
          TextButton(
            onPressed: isLast ? _finishSetup : _nextPage,
            child: const Center(child: Text('나중에 입력하기', style: TextStyle(color: Colors.grey))),
          ),
        ],
      ),
    );
  }

  Widget _buildNumericField(String label, Function(String) onChanged) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 8),
          TextField(
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(border: OutlineInputBorder()),
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }

  Widget _buildTimeField(String label, Function(String) onChanged) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 8),
          TextField(
            keyboardType: TextInputType.datetime,
            decoration: const InputDecoration(hintText: 'HH:MM:SS', border: OutlineInputBorder()),
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}