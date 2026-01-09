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
    // 3탭 구조: 인사이트, 신체 정보, 수행 능력
    _tabController = TabController(length: 3, vsync: this);
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
    setState(() { _username = username; });
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
                    expandedHeight: 300,
                    floating: false,
                    pinned: true,
                    backgroundColor: Theme.of(context).colorScheme.surface,
                    flexibleSpace: FlexibleSpaceBar(
                      background: _buildHeaderBackground(),
                    ),
                    bottom: TabBar(
                      controller: _tabController,
                      indicatorColor: Theme.of(context).colorScheme.primary,
                      labelColor: Theme.of(context).colorScheme.primary,
                      unselectedLabelColor: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                      tabs: const [
                        Tab(text: '인사이트'),
                        Tab(text: '신체 정보'),
                        Tab(text: '수행 능력'),
                      ],
                    ),
                  ),
                ];
              },
              body: TabBarView(
                controller: _tabController,
                children: [
                  _buildInsightTab(),      // 1. 인사이트
                  _buildPersonalInfoTab(), // 2. 신체 정보
                  _buildPerformanceTab(),  // 3. 수행 능력
                ],
              ),
            ),
    );
  }

  Widget _buildHeaderBackground() {
    return Container(
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
        padding: const EdgeInsets.only(bottom: 40.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(height: 20),
            CircleAvatar(
              radius: 40,
              backgroundColor: Theme.of(context).colorScheme.primary,
              child: const Icon(Icons.person, size: 40, color: Colors.black),
            ),
            const SizedBox(height: 16),
            Text(_username ?? '애슬릿', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            Text('Hybrid Athlete Pipeline', style: TextStyle(fontSize: 13, color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.w600, letterSpacing: 1.5)),
          ],
        ),
      ),
    );
  }

  // ==================== Tab 1: 인사이트 ====================
  Widget _buildInsightTab() {
    if (_userProfile?.birthDate == null) {
      return _buildEmptyInsight();
    }

    final mhr = _userProfile!.maxHeartRate;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildInsightCard(
            title: '예상 최대 심박수 (MHR)',
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text('$mhr', style: const TextStyle(fontSize: 48, fontWeight: FontWeight.w900)),
                    const SizedBox(width: 8),
                    const Text('BPM', style: TextStyle(fontSize: 16, color: Colors.grey, fontWeight: FontWeight.bold)),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  '현재 나이와 ${_getFormulaName(_userProfile!.preferredMhrFormula ?? "fox")} 공식을 기반으로 한 분석 결과입니다.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
                const SizedBox(height: 16),
                OutlinedButton.icon(
                  onPressed: _showMhrFormulaPicker,
                  icon: const Icon(Icons.settings_suggest, size: 16),
                  label: const Text('분석 공식 변경'),
                  style: OutlinedButton.styleFrom(visualDensity: VisualDensity.compact),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _buildHeartRateZonesSection(),
          const SizedBox(height: 16),
          if (_userProfile?.bodyFatPercentage != null)
            _buildInsightCard(
              title: '신체 구성 분석',
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildMiniInsightItem('체지방률', '${_userProfile!.bodyFatPercentage}%', '기록 기준'),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildEmptyInsight() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.analytics_outlined, size: 64, color: Colors.grey[800]),
          const SizedBox(height: 16),
          const Text('분석을 위한 정보가 부족합니다.', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
          TextButton(onPressed: () => _tabController.animateTo(1), child: const Text('신체 정보 입력하러 가기')),
        ],
      ),
    );
  }

  // ==================== Tab 2: 신체 정보 ====================
  Widget _buildPersonalInfoTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildEditableSection(
            title: '신체 기초 데이터',
            icon: Icons.accessibility_new,
            items: [
              _buildEditableItem(label: '성별', value: _userProfile?.gender == 'male' ? '남성' : (_userProfile?.gender == 'female' ? '여성' : '미설정'), onTap: () => _editGender()),
              _buildEditableItem(label: '생년월일', value: _userProfile?.birthDate != null ? DateFormat('yyyy - MM - dd').format(_userProfile!.birthDate!) : '미설정', onTap: () => _editBirthDate()),
              _buildEditableItem(label: '키 / 체중', value: '${_userProfile?.height?.toStringAsFixed(1) ?? "--"}cm / ${_userProfile?.weight?.toStringAsFixed(1) ?? "--"}kg', onTap: () => _editHeightWeight()),
            ],
          ),
          const SizedBox(height: 16),
          _buildEditableSection(
            title: '경력 및 숙련도',
            icon: Icons.history_edu,
            items: [
              _buildEditableItem(label: '러닝', value: '${_userProfile?.runningExperience?.toStringAsFixed(1) ?? "--"}년 / ${_formatLevel(_userProfile?.runningLevel)}', onTap: () => _editExperienceAndLevel('running')),
              _buildEditableItem(label: '웨이트', value: '${_userProfile?.strengthExperience?.toStringAsFixed(1) ?? "--"}년 / ${_formatLevel(_userProfile?.strengthLevel)}', onTap: () => _editExperienceAndLevel('strength')),
            ],
          ),
          const SizedBox(height: 16),
          _buildEditableSection(
            title: '인바디 세부 정보',
            svgIcon: 'assets/images/pllogo.svg',
            items: [
              _buildEditableItem(label: '골격근량', value: _userProfile?.skeletalMuscleMass != null ? '${_userProfile!.skeletalMuscleMass!.toStringAsFixed(1)} kg' : '미설정', onTap: () => _editSkeletalMuscleMass()),
              _buildEditableItem(label: '체지방률', value: _userProfile?.bodyFatPercentage != null ? '${_userProfile!.bodyFatPercentage!.toStringAsFixed(1)} %' : '미설정', onTap: () => _editBodyFatPercentage()),
            ],
          ),
        ],
      ),
    );
  }

  // ==================== Tab 3: 수행 능력 ====================
  Widget _buildPerformanceTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildEditableSection(
            title: '러닝 개인 최고 기록',
            svgIcon: 'assets/images/endurance/runner-icon.svg',
            items: [
              _buildEditableItem(label: 'Full Marathon', value: _formatDuration(_userProfile?.fullMarathonTime), onTap: () => _editRunningRecord('fullMarathon')),
              _buildEditableItem(label: 'Half Marathon', value: _formatDuration(_userProfile?.halfMarathonTime), onTap: () => _editRunningRecord('halfMarathon')),
              _buildEditableItem(label: '10K', value: _formatDuration(_userProfile?.tenKmTime), onTap: () => _editRunningRecord('10K')),
              _buildEditableItem(label: '5K', value: _formatDuration(_userProfile?.fiveKmTime), onTap: () => _editRunningRecord('5K')),
            ],
          ),
          const SizedBox(height: 16),
          _buildEditableSection(
            title: '근력 3RM 기록',
            svgIcon: 'assets/images/strength/lifter-icon.svg',
            items: [
              _buildEditableItem(label: '스쿼트', value: _userProfile?.squat3RM != null ? '${_userProfile!.squat3RM!.toStringAsFixed(1)} kg' : '미설정', onTap: () => _edit3RM('squat')),
              _buildEditableItem(label: '벤치프레스', value: _userProfile?.benchPress3RM != null ? '${_userProfile!.benchPress3RM!.toStringAsFixed(1)} kg' : '미설정', onTap: () => _edit3RM('benchPress')),
              _buildEditableItem(label: '데드리프트', value: _userProfile?.deadlift3RM != null ? '${_userProfile!.deadlift3RM!.toStringAsFixed(1)} kg' : '미설정', onTap: () => _edit3RM('deadlift')),
            ],
          ),
          const SizedBox(height: 16),
          _buildEditableSection(
            title: '맨몸 운동 수행력',
            svgIcon: 'assets/images/strength/pullup-icon.svg',
            items: [
              _buildEditableItem(label: '턱걸이 (최대)', value: _userProfile?.maxPullUps != null ? '${_userProfile!.maxPullUps} 회' : '미설정', onTap: () => _editBodyweightExercise('pullUps')),
              _buildEditableItem(label: '푸쉬업 (최대)', value: _userProfile?.maxPushUps != null ? '${_userProfile!.maxPushUps} 회' : '미설정', onTap: () => _editBodyweightExercise('pushUps')),
            ],
          ),
        ],
      ),
    );
  }

  // ==================== UI Helpers ====================

  Widget _buildInsightCard({required String title, required Widget child}) {
    return Card(
      elevation: 0,
      color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: const BorderSide(color: Colors.white10)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.grey)),
          const SizedBox(height: 16),
          child,
        ]),
      ),
    );
  }

  Widget _buildMiniInsightItem(String label, String value, String subValue) {
    return Column(children: [
      Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
      const SizedBox(height: 4),
      Text(value, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
      Text(subValue, style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.w600)),
    ]);
  }

  Widget _buildHeartRateZonesSection() {
    final zones = _userProfile!.hrZones;
    return _buildInsightCard(
      title: '심박수 훈련 가이드 (Zones)',
      child: Column(children: zones.entries.map((entry) => _buildZoneBar(entry.key, entry.value['min']!, entry.value['max']!)).toList()),
    );
  }

  Widget _buildZoneBar(int zone, int min, int max) {
    final colors = [Colors.blue, Colors.green, Colors.yellow, Colors.orange, Colors.red];
    final labels = ['Warm-up', 'Fat Burn', 'Aerobic', 'Threshold', 'VO2 Max'];
    final color = colors[zone - 1];
    return Padding(
      padding: const EdgeInsets.only(bottom: 14.0),
      child: Column(children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text('Zone $zone: ${labels[zone - 1]}', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: color)),
          Text('$min - $max BPM', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, fontFamily: 'monospace')),
        ]),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: (max / (_userProfile?.maxHeartRate ?? 200)).clamp(0.0, 1.0),
            backgroundColor: color.withValues(alpha: 0.1),
            valueColor: AlwaysStoppedAnimation<Color>(color),
            minHeight: 6,
          ),
        ),
      ]),
    );
  }

  Widget _buildEditableSection({required String title, IconData? icon, String? svgIcon, required List<Widget> items}) {
    return Card(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Row(children: [
            if (svgIcon != null) SvgPicture.asset(svgIcon, width: 18, height: 18, colorFilter: ColorFilter.mode(Theme.of(context).colorScheme.primary, BlendMode.srcIn))
            else if (icon != null) Icon(icon, size: 18, color: Theme.of(context).colorScheme.primary),
            const SizedBox(width: 8),
            Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
          ]),
        ),
        const Divider(height: 1),
        ...items,
      ]),
    );
  }

  Widget _buildEditableItem({required String label, required String value, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text(label, style: const TextStyle(fontSize: 14)),
          Row(children: [
            Text(value, style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.primary)),
            const Icon(Icons.chevron_right, color: Colors.grey, size: 18),
          ]),
        ]),
      ),
    );
  }

  // ==================== Formatting & Logic ====================
  String _formatDuration(Duration? d) {
    if (d == null) return '미설정';
    return "${d.inHours.toString().padLeft(2, '0')}:${d.inMinutes.remainder(60).toString().padLeft(2, '0')}:${d.inSeconds.remainder(60).toString().padLeft(2, '0')}";
  }

  String _formatLevel(String? l) {
    if (l == 'beginner') return '초급';
    if (l == 'intermediate') return '중급';
    if (l == 'advanced') return '고급';
    return '미설정';
  }

  String _getFormulaName(String f) {
    if (f == 'tanaka') return 'Tanaka';
    if (f == 'gellish') return 'Gellish';
    if (f == 'gulati') return 'Gulati';
    return 'Fox';
  }

  // ==================== Editing Methods ====================
  void _showMhrFormulaPicker() {
    showCupertinoModalPopup(
      context: context,
      builder: (context) => CupertinoActionSheet(
        title: const Text('MHR 계산 공식 선택'),
        actions: [
          _formulaAction('fox', 'Fox (220 - 나이)', '표준'),
          _formulaAction('tanaka', 'Tanaka (208 - 0.7x나이)', '고급/운동선수'),
          _formulaAction('gellish', 'Gellish (207 - 0.7x나이)', '정밀'),
          if (_userProfile?.gender == 'female') _formulaAction('gulati', 'Gulati (206 - 0.88x나이)', '여성 최적화'),
        ],
        cancelButton: CupertinoActionSheetAction(child: const Text('취소'), onPressed: () => Navigator.pop(context)),
      ),
    );
  }

  Widget _formulaAction(String id, String title, String desc) {
    return CupertinoActionSheetAction(
      onPressed: () { _saveProfile(_userProfile?.copyWith(preferredMhrFormula: id)); Navigator.pop(context); },
      child: Text('$title ($desc)'),
    );
  }

  void _editGender() {
    showCupertinoModalPopup(
      context: context,
      builder: (context) => CupertinoActionSheet(
        title: const Text('성별 선택'),
        actions: [
          CupertinoActionSheetAction(child: const Text('남성'), onPressed: () { _saveProfile(_userProfile?.copyWith(gender: 'male')); Navigator.pop(context); }),
          CupertinoActionSheetAction(child: const Text('여성'), onPressed: () { _saveProfile(_userProfile?.copyWith(gender: 'female')); Navigator.pop(context); }),
        ],
        cancelButton: CupertinoActionSheetAction(child: const Text('취소'), onPressed: () => Navigator.pop(context)),
      ),
    );
  }

  void _editBirthDate() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('생년월일 선택'),
        content: SizedBox(
          height: 200, width: double.maxFinite,
          child: Localizations.override(
            context: context, locale: const Locale('ko', 'KR'),
            child: CupertinoDatePicker(
              mode: CupertinoDatePickerMode.date,
              initialDateTime: _userProfile?.birthDate ?? DateTime(1995, 1, 1),
              minimumYear: 1950, maximumDate: DateTime.now(),
              onDateTimeChanged: (DateTime newDate) { _saveProfile(_userProfile?.copyWith(birthDate: newDate)); },
            ),
          ),
        ),
        actions: [ TextButton(onPressed: () => Navigator.pop(context), child: const Text('저장')) ],
      ),
    );
  }

  void _editHeightWeight() {
    final h = TextEditingController(text: _userProfile?.height?.toStringAsFixed(1) ?? '');
    final w = TextEditingController(text: _userProfile?.weight?.toStringAsFixed(1) ?? '');
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('신체 치수 입력'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: h, decoration: const InputDecoration(labelText: '키 (cm)'), keyboardType: TextInputType.number),
          TextField(controller: w, decoration: const InputDecoration(labelText: '체중 (kg)'), keyboardType: TextInputType.number),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('취소')),
          TextButton(onPressed: () { _saveProfile(_userProfile?.copyWith(height: double.tryParse(h.text), weight: double.tryParse(w.text))); Navigator.pop(context); }, child: const Text('저장'))
        ],
      ),
    );
  }

  void _editExperienceAndLevel(String type) {
    final exp = TextEditingController(text: (type == 'running' ? _userProfile?.runningExperience : _userProfile?.strengthExperience)?.toStringAsFixed(1) ?? '');
    String lv = (type == 'running' ? _userProfile?.runningLevel : _userProfile?.strengthLevel) ?? 'beginner';
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(builder: (context, setM) => AlertDialog(
        title: Text(type == 'running' ? '러닝 프로필' : '웨이트 프로필'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: exp, decoration: const InputDecoration(labelText: '구력 (년)'), keyboardType: TextInputType.number),
          const SizedBox(height: 16),
          DropdownButton<String>(isExpanded: true, value: lv, items: const [DropdownMenuItem(value: 'beginner', child: Text('초급')), DropdownMenuItem(value: 'intermediate', child: Text('중급')), DropdownMenuItem(value: 'advanced', child: Text('고급'))], onChanged: (v) => setM(() => lv = v!)),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('취소')),
          TextButton(onPressed: () {
            if (type == 'running') {
              _saveProfile(_userProfile?.copyWith(runningExperience: double.tryParse(exp.text), runningLevel: lv));
            } else {
              _saveProfile(_userProfile?.copyWith(strengthExperience: double.tryParse(exp.text), strengthLevel: lv));
            }
            Navigator.pop(context);
          }, child: const Text('저장'))
        ],
      )),
    );
  }

  void _editSkeletalMuscleMass() {
    final c = TextEditingController(text: _userProfile?.skeletalMuscleMass?.toStringAsFixed(1) ?? '');
    _showNumericInputDialog(title: '골격근량 (kg)', hint: 'kg', controller: c, onSave: (v) => _saveProfile(_userProfile?.copyWith(skeletalMuscleMass: double.tryParse(v))));
  }

  void _editBodyFatPercentage() {
    final c = TextEditingController(text: _userProfile?.bodyFatPercentage?.toStringAsFixed(1) ?? '');
    _showNumericInputDialog(title: '체지방률 (%)', hint: '%', controller: c, onSave: (v) => _saveProfile(_userProfile?.copyWith(bodyFatPercentage: double.tryParse(v))));
  }

  void _editRunningRecord(String type) {
    Duration? cur;
    if (type == 'fullMarathon') {
      cur = _userProfile?.fullMarathonTime;
    } else if (type == 'halfMarathon') cur = _userProfile?.halfMarathonTime;
    else if (type == '10K') cur = _userProfile?.tenKmTime;
    else cur = _userProfile?.fiveKmTime;
    _showTimeInputDialog(title: '최고 기록 입력', currentTime: cur, onSave: (d) {
      UserProfile? up;
      if (type == 'fullMarathon') {
        up = _userProfile?.copyWith(fullMarathonTime: d);
      } else if (type == 'halfMarathon') up = _userProfile?.copyWith(halfMarathonTime: d);
      else if (type == '10K') up = _userProfile?.copyWith(tenKmTime: d);
      else up = _userProfile?.copyWith(fiveKmTime: d);
      if (up != null) _saveProfile(up);
    });
  }

  void _editBodyweightExercise(String type) {
    final c = TextEditingController(text: (type == 'pullUps' ? _userProfile?.maxPullUps : _userProfile?.maxPushUps)?.toString() ?? '');
    _showNumericInputDialog(title: '최대 횟수 입력', hint: '회', controller: c, isInteger: true, onSave: (v) {
      if (type == 'pullUps') {
        _saveProfile(_userProfile?.copyWith(maxPullUps: int.tryParse(v)));
      } else {
        _saveProfile(_userProfile?.copyWith(maxPushUps: int.tryParse(v)));
      }
    });
  }

  void _edit3RM(String type) {
    final c = TextEditingController(text: (type == 'squat' ? _userProfile?.squat3RM : type == 'benchPress' ? _userProfile?.benchPress3RM : _userProfile?.deadlift3RM)?.toStringAsFixed(1) ?? '');
    _showNumericInputDialog(title: '3RM 중량 입력', hint: 'kg', controller: c, onSave: (v) {
      final w = double.tryParse(v);
      if (type == 'squat') {
        _saveProfile(_userProfile?.copyWith(squat3RM: w));
      } else if (type == 'benchPress') _saveProfile(_userProfile?.copyWith(benchPress3RM: w));
      else _saveProfile(_userProfile?.copyWith(deadlift3RM: w));
    });
  }

  void _showNumericInputDialog({required String title, required String hint, required TextEditingController controller, required Function(String) onSave, bool isInteger = false}) {
    showDialog(context: context, builder: (context) => AlertDialog(title: Text(title), content: TextField(controller: controller, decoration: InputDecoration(hintText: hint), keyboardType: TextInputType.numberWithOptions(decimal: !isInteger), autofocus: true), actions: [ TextButton(onPressed: () => Navigator.pop(context), child: const Text('취소')), TextButton(onPressed: () { onSave(controller.text); Navigator.pop(context); }, child: const Text('저장')) ]));
  }

  void _showTimeInputDialog({required String title, Duration? currentTime, required Function(Duration) onSave}) {
    int h = currentTime?.inHours ?? 0, m = currentTime?.inMinutes.remainder(60) ?? 0, s = currentTime?.inSeconds.remainder(60) ?? 0;
    showDialog(context: context, builder: (context) => AlertDialog(title: Text(title), content: SizedBox(height: 200, child: Row(children: [
      Expanded(child: CupertinoPicker(itemExtent: 40, scrollController: FixedExtentScrollController(initialItem: h), onSelectedItemChanged: (v) => h = v, children: List.generate(24, (i) => Center(child: Text('$i'))))), const Text(':'),
      Expanded(child: CupertinoPicker(itemExtent: 40, scrollController: FixedExtentScrollController(initialItem: m), onSelectedItemChanged: (v) => m = v, children: List.generate(60, (i) => Center(child: Text(i.toString().padLeft(2, '0')))))), const Text(':'),
      Expanded(child: CupertinoPicker(itemExtent: 40, scrollController: FixedExtentScrollController(initialItem: s), onSelectedItemChanged: (v) => s = v, children: List.generate(60, (i) => Center(child: Text(i.toString().padLeft(2, '0')))))),
    ])), actions: [ TextButton(onPressed: () => Navigator.pop(context), child: const Text('취소')), TextButton(onPressed: () { onSave(Duration(hours: h, minutes: m, seconds: s)); Navigator.pop(context); }, child: const Text('저장')) ]));
  }

  Future<void> _saveProfile(UserProfile? profile) async {
    if (profile == null) return;
    await _profileService.saveProfile(profile);
    setState(() { _userProfile = profile; });
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('저장되었습니다'), duration: Duration(seconds: 1)));
  }
}
