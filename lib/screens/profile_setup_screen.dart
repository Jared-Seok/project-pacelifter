import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:pacelifter/models/user_profile.dart';
import 'package:pacelifter/services/profile_service.dart';
import 'package:pacelifter/screens/main_navigation.dart';
import 'package:intl/intl.dart';
import 'package:pacelifter/utils/workout_ui_utils.dart'; // 추가

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
  
  final TextEditingController _runningExpController = TextEditingController();
  final TextEditingController _strengthExpController = TextEditingController();

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
    _runningExpController.dispose();
    _strengthExpController.dispose();
    super.dispose();
  }

  void _nextPage() {
    FocusScope.of(context).unfocus();
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
            child: Text(
              '저장',
              style: TextStyle(
                color: Theme.of(context).colorScheme.primary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _finishSetup() async {
    FocusScope.of(context).unfocus();
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

  Color _getCurrentColor() {
    switch (_currentPage) {
      case 1: // 러닝 경험
      case 4: // 러닝 기록
        return WorkoutUIUtils.getWorkoutColor(context, 'Endurance');
      case 2: // 웨이트 경험
      case 3: // 인바디
      case 5: // 맨몸 운동
      case 6: // 3RM
        return WorkoutUIUtils.getWorkoutColor(context, 'Strength');
      default:
        return WorkoutUIUtils.getWorkoutColor(context, 'Hybrid');
    }
  }

  @override
  Widget build(BuildContext context) {
    final activeColor = _getCurrentColor();
    
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
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
                  valueColor: AlwaysStoppedAnimation<Color>(activeColor),
                );
              },
            ),
            Expanded(
              child: PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  _buildStep1(), // 기본 정보
                  _buildStep2(), // 러닝 프로필
                  _buildStep3(), // 웨이트 프로필
                  _buildStep4(), // 인바디
                  _buildStep5(), // 러닝 기록
                  _buildStep6(), // 맨몸 운동
                  _buildStep7(), // 3RM
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 1단계: 기본 정보 (생년월일 추가)
  Widget _buildStep1() {
    final activeColor = _getCurrentColor();
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
            cursorColor: activeColor,
            decoration: InputDecoration(
              hintText: '예: 175', 
              border: const OutlineInputBorder(),
              focusedBorder: OutlineInputBorder(
                borderSide: BorderSide(color: activeColor, width: 2),
              ),
            ),
            onChanged: (val) => setState(() => _userProfile = _userProfile.copyWith(height: double.tryParse(val))),
          ),
          
          const SizedBox(height: 24),
          Text('체중 (kg)', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          TextField(
            keyboardType: TextInputType.number,
            cursorColor: activeColor,
            decoration: InputDecoration(
              hintText: '예: 70', 
              border: const OutlineInputBorder(),
              focusedBorder: OutlineInputBorder(
                borderSide: BorderSide(color: activeColor, width: 2),
              ),
            ),
            onChanged: (val) => setState(() => _userProfile = _userProfile.copyWith(weight: double.tryParse(val))),
          ),

          const SizedBox(height: 48),
          SizedBox(
            width: double.infinity, height: 56,
            child: ElevatedButton(
              onPressed: (_userProfile.gender != null && _userProfile.birthDate != null && _userProfile.height != null && _userProfile.weight != null) ? _nextPage : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: activeColor,
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
    final enduranceColor = Theme.of(context).colorScheme.tertiary;
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
            controller: _runningExpController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            cursorColor: enduranceColor,
            decoration: InputDecoration(
              hintText: '예: 1.5', 
              border: const OutlineInputBorder(), 
              suffixText: '년',
              focusedBorder: OutlineInputBorder(
                borderSide: BorderSide(color: enduranceColor, width: 2),
              ),
            ),
            onChanged: (val) {
              if (val.length > 2) {
                final truncated = val.substring(0, 2);
                _runningExpController.text = truncated;
                _runningExpController.selection = TextSelection.fromPosition(TextPosition(offset: truncated.length));
                FocusScope.of(context).unfocus();
                setState(() => _userProfile = _userProfile.copyWith(runningExperience: double.tryParse(truncated)));
              } else {
                setState(() => _userProfile = _userProfile.copyWith(runningExperience: double.tryParse(val)));
              }
            },
          ),

          const SizedBox(height: 32),
          Text('러닝 실력 (자체 평가)', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 12),
          _buildLevelSelector(
            current: _userProfile.runningLevel,
            onSelect: (val) {
              FocusScope.of(context).unfocus();
              setState(() => _userProfile = _userProfile.copyWith(runningLevel: val));
            },
            activeColor: enduranceColor,
          ),

          const SizedBox(height: 48),
          SizedBox(
            width: double.infinity, height: 56,
            child: ElevatedButton(
              onPressed: (_userProfile.runningExperience != null && _userProfile.runningLevel != null) ? _nextPage : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: enduranceColor,
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
    final activeColor = _getCurrentColor();
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
            controller: _strengthExpController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            cursorColor: activeColor,
            decoration: InputDecoration(
              hintText: '예: 2', 
              border: const OutlineInputBorder(), 
              suffixText: '년',
              focusedBorder: OutlineInputBorder(
                borderSide: BorderSide(color: activeColor, width: 2),
              ),
            ),
            onChanged: (val) {
              if (val.length > 2) {
                final truncated = val.substring(0, 2);
                _strengthExpController.text = truncated;
                _strengthExpController.selection = TextSelection.fromPosition(TextPosition(offset: truncated.length));
                FocusScope.of(context).unfocus();
                setState(() => _userProfile = _userProfile.copyWith(strengthExperience: double.tryParse(truncated)));
              } else {
                setState(() => _userProfile = _userProfile.copyWith(strengthExperience: double.tryParse(val)));
              }
            },
          ),

          const SizedBox(height: 32),
          Text('웨이트 실력 (자체 평가)', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 12),
          _buildLevelSelector(
            current: _userProfile.strengthLevel,
            onSelect: (val) {
              FocusScope.of(context).unfocus();
              setState(() => _userProfile = _userProfile.copyWith(strengthLevel: val));
            },
            activeColor: activeColor,
          ),

          const SizedBox(height: 48),
          SizedBox(
            width: double.infinity, height: 56,
            child: ElevatedButton(
              onPressed: (_userProfile.strengthExperience != null && _userProfile.strengthLevel != null) ? _nextPage : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: activeColor,
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

  Widget _buildLevelSelector({String? current, required Function(String) onSelect, Color? activeColor}) {
    final color = activeColor ?? Theme.of(context).colorScheme.primary;
    return Column(
      children: [
        _levelTile('beginner', '초급', '기본기를 익히고 있는 단계', current, onSelect, color),
        const SizedBox(height: 12),
        _levelTile('intermediate', '중급', '숙련된 자세로 꾸준히 운동 중', current, onSelect, color),
        const SizedBox(height: 12),
        _levelTile('advanced', '고급', '고강도 훈련 및 정교한 루틴 수행', current, onSelect, color),
      ],
    );
  }

  Widget _levelTile(String id, String title, String desc, String? current, Function(String) onSelect, Color activeColor) {
    final isSelected = current == id;
    return InkWell(
      onTap: () => onSelect(id),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected ? activeColor.withValues(alpha: 0.1) : Colors.transparent,
          border: Border.all(color: isSelected ? activeColor : Colors.grey[800]!),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: isSelected ? activeColor : Colors.white)),
                  Text(desc, style: TextStyle(fontSize: 12, color: Colors.grey[400])),
                ],
              ),
            ),
            if (isSelected) Icon(Icons.check_circle, color: activeColor),
          ],
        ),
      ),
    );
  }

  // 4단계: 인바디 (선택)
  Widget _buildStep4() {
    final activeColor = _getCurrentColor();
    return _buildSelectionStep('인바디 정보 입력 (선택)', '정확한 분석을 위해 필요한 정보입니다.', [
      _buildNumericField('골격근량 (kg)', (val) => _userProfile = _userProfile.copyWith(skeletalMuscleMass: double.tryParse(val)), activeColor: activeColor),
      _buildNumericField('체지방률 (%)', (val) => _userProfile = _userProfile.copyWith(bodyFatPercentage: double.tryParse(val)), activeColor: activeColor),
    ], activeColor: activeColor);
  }

  // 5단계: 러닝 기록 (선택)
  Widget _buildStep5() {
    final enduranceColor = Theme.of(context).colorScheme.tertiary;
    return _buildSelectionStep('러닝 최고 기록 (선택)', '러닝 퍼포먼스 분석에 사용됩니다.', [
      _buildTimeDialField(
        'Full (42.195km)',
        _userProfile.fullMarathonTime,
        (duration) => setState(() => _userProfile = _userProfile.copyWith(fullMarathonTime: duration)),
        maxHours: 4,
        minHours: 2,
        activeColor: enduranceColor,
      ),
      _buildTimeDialField(
        'Half (21.097km)',
        _userProfile.halfMarathonTime,
        (duration) => setState(() => _userProfile = _userProfile.copyWith(halfMarathonTime: duration)),
        maxHours: 3,
        activeColor: enduranceColor,
      ),
      _buildTimeDialField(
        '10K',
        _userProfile.tenKmTime,
        (duration) => setState(() => _userProfile = _userProfile.copyWith(tenKmTime: duration)),
        maxHours: 1,
        activeColor: enduranceColor,
      ),
      _buildTimeDialField(
        '5K',
        _userProfile.fiveKmTime,
        (duration) => setState(() => _userProfile = _userProfile.copyWith(fiveKmTime: duration)),
        maxHours: 0, // 0 means no hour dial
        activeColor: enduranceColor,
      ),
    ], activeColor: enduranceColor);
  }

  Widget _buildTimeDialField(String label, Duration? value, Function(Duration) onChanged, {required int maxHours, int minHours = 0, Color? activeColor}) {
    final focusColor = activeColor ?? Theme.of(context).colorScheme.primary;
    final displayValue = value != null 
        ? (maxHours > 0 
            ? "${value.inHours}:${(value.inMinutes % 60).toString().padLeft(2, '0')}:${(value.inSeconds % 60).toString().padLeft(2, '0')}"
            : "${value.inMinutes}:${(value.inSeconds % 60).toString().padLeft(2, '0')}")
        : '기록 선택';

    return Padding(
      padding: const EdgeInsets.only(bottom: 24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 8),
          InkWell(
            onTap: () => _showTimePickerDial(label, value, maxHours, minHours, onChanged),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              decoration: BoxDecoration(
                border: Border.all(color: value != null ? focusColor : Colors.grey[700]!, width: value != null ? 2 : 1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(displayValue, style: TextStyle(
                    color: value != null ? Colors.white : Colors.grey,
                    fontSize: 16,
                    fontWeight: value != null ? FontWeight.bold : FontWeight.normal,
                  )),
                  Icon(Icons.access_time, size: 18, color: value != null ? focusColor : Colors.grey),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showTimePickerDial(String title, Duration? initialValue, int maxHours, int minHours, Function(Duration) onSelected) {
    int h = initialValue?.inHours ?? (maxHours > minHours ? ((maxHours + minHours) ~/ 2) : minHours);
    int m = (initialValue?.inMinutes ?? 0) % 60;
    int s = (initialValue?.inSeconds ?? 0) % 60;

    // Ensure h is within range
    if (h > maxHours && maxHours > 0) h = maxHours;
    if (h < minHours) h = minHours;

    showCupertinoModalPopup(
      context: context,
      builder: (context) => Container(
        height: 300,
        color: const Color(0xFF1C1C1E),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: Colors.white10)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  TextButton(onPressed: () => Navigator.pop(context), child: const Text('취소', style: TextStyle(color: Colors.grey))),
                  Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16, decoration: TextDecoration.none)),
                  TextButton(
                    onPressed: () {
                      onSelected(Duration(hours: h, minutes: m, seconds: s));
                      Navigator.pop(context);
                    },
                    child: Text('확인', style: TextStyle(color: Theme.of(context).colorScheme.tertiary, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (maxHours > 0) ...[
                    _buildPicker(maxHours - minHours + 1, h - minHours, '시간', (val) => h = val + minHours, startValue: minHours),
                  ],
                  _buildPicker(60, m, '분', (val) => m = val),
                  _buildPicker(60, s, '초', (val) => s = val),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPicker(int count, int initialItem, String unit, Function(int) onChanged, {int startValue = 0}) {
    return Expanded(
      child: Stack(
        alignment: Alignment.center,
        children: [
          CupertinoPicker(
            itemExtent: 40,
            scrollController: FixedExtentScrollController(initialItem: initialItem),
            onSelectedItemChanged: onChanged,
            children: List.generate(count, (i) => Center(child: Text('${i + startValue}', style: const TextStyle(color: Colors.white, fontSize: 20)))),
          ),
          Positioned(
            right: 10,
            child: Text(unit, style: const TextStyle(color: Colors.grey, fontSize: 12, decoration: TextDecoration.none)),
          ),
        ],
      ),
    );
  }

  // 6단계: 맨몸 운동 (선택)
  Widget _buildStep6() {
    final activeColor = _getCurrentColor();
    return _buildSelectionStep('맨몸 운동 능력 (선택)', '수행 가능한 최대 횟수를 입력해주세요.', [
      _buildNumericField('턱걸이 (최대)', (val) => _userProfile = _userProfile.copyWith(maxPullUps: int.tryParse(val)), activeColor: activeColor),
      _buildNumericField('푸쉬업 (최대)', (val) => _userProfile = _userProfile.copyWith(maxPushUps: int.tryParse(val)), activeColor: activeColor),
    ], activeColor: activeColor);
  }

  // 7단계: 3RM (선택)
  Widget _buildStep7() {
    final activeColor = _getCurrentColor();
    return _buildSelectionStep('3대 운동 3RM (선택)', '3회 반복 가능한 최대 무게를 입력해주세요.', [
      _buildNumericField('스쿼트 (kg)', (val) => _userProfile = _userProfile.copyWith(squat3RM: double.tryParse(val)), activeColor: activeColor),
      _buildNumericField('벤치프레스 (kg)', (val) => _userProfile = _userProfile.copyWith(benchPress3RM: double.tryParse(val)), activeColor: activeColor),
      _buildNumericField('데드리프트 (kg)', (val) => _userProfile = _userProfile.copyWith(deadlift3RM: double.tryParse(val)), activeColor: activeColor),
    ], isLast: true, activeColor: activeColor);
  }

  // 공통 선택사항 빌더
  Widget _buildSelectionStep(String title, String desc, List<Widget> fields, {bool isLast = false, Color? activeColor}) {
    final color = activeColor ?? Theme.of(context).colorScheme.primary;
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
              style: ElevatedButton.styleFrom(backgroundColor: color, foregroundColor: Colors.black),
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

  Widget _buildNumericField(String label, Function(String) onChanged, {Color? activeColor}) {
    final focusColor = activeColor ?? Theme.of(context).colorScheme.primary;
    return Padding(
      padding: const EdgeInsets.only(bottom: 24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 8),
          TextField(
            keyboardType: TextInputType.number,
            cursorColor: focusColor,
            decoration: InputDecoration(
              border: const OutlineInputBorder(),
              focusedBorder: OutlineInputBorder(
                borderSide: BorderSide(color: focusColor, width: 2),
              ),
            ),
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }

  Widget _buildTimeField(String label, Function(String) onChanged, {Color? activeColor}) {
    final focusColor = activeColor ?? Theme.of(context).colorScheme.primary;
    final controller = TextEditingController();
    
    return Padding(
      padding: const EdgeInsets.only(bottom: 24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 8),
          TextField(
            controller: controller,
            keyboardType: TextInputType.datetime,
            cursorColor: focusColor,
            decoration: InputDecoration(
              hintText: 'HH:MM:SS',
              border: const OutlineInputBorder(),
              focusedBorder: OutlineInputBorder(
                borderSide: BorderSide(color: focusColor, width: 2),
              ),
            ),
            onChanged: (val) {
              // MM:SS validation logic
              final parts = val.split(':');
              bool isValid = true;
              if (parts.length >= 2) {
                final mins = int.tryParse(parts[1]);
                if (mins != null && mins >= 60) isValid = false;
              }
              if (parts.length >= 3) {
                final secs = int.tryParse(parts[2]);
                if (secs != null && secs >= 60) isValid = false;
              }

              if (!isValid) {
                // Remove last character if invalid
                final cleanVal = val.substring(0, val.length - 1);
                controller.text = cleanVal;
                controller.selection = TextSelection.fromPosition(TextPosition(offset: cleanVal.length));
                return;
              }
              onChanged(val);
            },
          ),
        ],
      ),
    );
  }
}