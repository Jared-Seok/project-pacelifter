import 'package:flutter/material.dart';
import 'package:health/health.dart';
import 'package:pacelifter/models/race.dart';
import 'package:pacelifter/services/health_service.dart';
import 'package:pacelifter/services/auth_service.dart';
import 'package:pacelifter/services/race_service.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pacelifter/screens/race_list_screen.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:pacelifter/screens/workout_detail_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

enum TimePeriod { week, month, year }

class _DashboardScreenState extends State<DashboardScreen> {
  final HealthService _healthService = HealthService();
  final AuthService _authService = AuthService();
  final RaceService _raceService = RaceService();
  late PageController _mainPageController;
  List<HealthDataPoint> _workoutData = [];
  List<Race> _races = [];
  bool _isLoading = true;
  TimePeriod _selectedPeriod = TimePeriod.week;
  int _currentPage = 0;

  double _strengthPercentage = 0.0;
  double _endurancePercentage = 0.0;
  int _totalWorkouts = 0;
  String _dateRangeText = '';

  @override
  void initState() {
    super.initState();
    _mainPageController = PageController();
    _initialize();
  }

  @override
  void dispose() {
    _mainPageController.dispose();
    super.dispose();
  }

  Future<void> _initialize() async {
    await _checkFirstLoginAndSync();
    await _loadRaces();
    setState(() {
      _isLoading = false;
    });
  }

  Future<void> _loadRaces() async {
    final races = await _raceService.getRaces();
    if (mounted) {
      // Sort races by date, upcoming first
      races.sort((a, b) => a.raceDate.compareTo(b.raceDate));
      setState(() {
        _races = races;
      });
    }
  }

  Future<void> _checkFirstLoginAndSync() async {
    final isFirstLogin = await _authService.isFirstLogin();
    final isSyncCompleted = await _authService.isHealthSyncCompleted();

    if (isFirstLogin && !isSyncCompleted && mounted) {
      await Future.delayed(const Duration(milliseconds: 500));
      if (mounted) {
        _showHealthSyncDialog();
      }
    } else if (isSyncCompleted) {
      await _loadHealthData();
    }
  }

  void _showHealthSyncDialog() {
    showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
              title: Row(children: [
                Icon(Icons.health_and_safety,
                    color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 12),
                const Text('운동 데이터 동기화'),
              ]),
              content: const SingleChildScrollView(
                  child: Text('PaceLifter와 건강 앱을 연동하여 운동 데이터를 동기화하시겠습니까?')),
              actions: [
                TextButton(
                    onPressed: () async {
                      Navigator.of(context).pop();
                      await _authService.clearFirstLoginFlag();
                      await _authService.setHealthSyncCompleted(false);
                    },
                    child: const Text('나중에')),
                ElevatedButton(
                    onPressed: () async {
                      Navigator.of(context).pop();
                      await _authService.clearFirstLoginFlag();
                      _syncHealthData();
                    },
                    child: const Text('동기화 시작')),
              ],
            ));
  }

  Future<void> _syncHealthData() async {
    setState(() {
      _isLoading = true;
    });
    try {
      final granted = await _healthService.requestAuthorization();
      if (granted) {
        final workoutData = await _healthService.fetchWorkoutData();
        await _authService.setHealthSyncCompleted(true);
        if (mounted) {
          setState(() {
            _workoutData = workoutData;
            _calculateStatistics();
            _isLoading = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text('${workoutData.length}개의 운동 기록을 동기화했습니다!'),
                backgroundColor: Colors.green),
          );
        }
      } else {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _loadHealthData() async {
    setState(() {
      _isLoading = true;
    });
    final workoutData = await _healthService.fetchWorkoutData();
    if (mounted) {
      setState(() {
        _workoutData = workoutData;
        _calculateStatistics();
        _isLoading = false;
      });
    }
  }

  void _calculateStatistics() {
    final now = DateTime.now();
    DateTime startDate;
    DateTime endDate;

    switch (_selectedPeriod) {
      case TimePeriod.week:
        // 월요일부터 일요일까지
        // DateTime.weekday: 1 = Monday, 7 = Sunday
        final currentWeekday = now.weekday;
        final daysToMonday = currentWeekday - 1; // 월요일까지의 일수
        final daysToSunday = 7 - currentWeekday; // 일요일까지의 일수

        startDate = DateTime(now.year, now.month, now.day)
            .subtract(Duration(days: daysToMonday));
        endDate = DateTime(now.year, now.month, now.day)
            .add(Duration(days: daysToSunday))
            .add(const Duration(hours: 23, minutes: 59, seconds: 59));

        // 날짜 범위 텍스트 생성: "25/12/8 ~ 14" 형식
        final startDay = startDate.day;
        final endDay = endDate.day;
        _dateRangeText = '${now.year.toString().substring(2)}/${now.month}/$startDay ~ $endDay';
        break;

      case TimePeriod.month:
        // 해당 월의 1일부터 마지막 날까지
        startDate = DateTime(now.year, now.month, 1);
        endDate = DateTime(now.year, now.month + 1, 0, 23, 59, 59);

        // 날짜 범위 텍스트 생성: "25/12" 형식
        _dateRangeText = '${now.year.toString().substring(2)}/${now.month}';
        break;

      case TimePeriod.year:
        // 해당 연도의 1월 1일부터 12월 31일까지
        startDate = DateTime(now.year, 1, 1);
        endDate = DateTime(now.year, 12, 31, 23, 59, 59);

        // 날짜 범위 텍스트 생성: "2025" 형식
        _dateRangeText = '${now.year}';
        break;
    }

    final filteredData = _workoutData
        .where((data) =>
            data.dateFrom.isAfter(startDate.subtract(const Duration(seconds: 1))) &&
            data.dateFrom.isBefore(endDate.add(const Duration(seconds: 1))))
        .toList();

    _totalWorkouts = filteredData.length;
    int strengthCount = 0;
    int enduranceCount = 0;

    for (var data in filteredData) {
      if (data.value is WorkoutHealthValue) {
        final workout = data.value as WorkoutHealthValue;
        final type = workout.workoutActivityType.name;
        if (_isStrengthWorkout(type)) {
          strengthCount++;
        } else {
          enduranceCount++;
        }
      }
    }

    final total = strengthCount + enduranceCount;
    if (total > 0) {
      _strengthPercentage = (strengthCount / total) * 100;
      _endurancePercentage = (enduranceCount / total) * 100;
    } else {
      _strengthPercentage = 50.0;
      _endurancePercentage = 50.0;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : RefreshIndicator(
                onRefresh: () async {
                  await _loadHealthData();
                  await _loadRaces();
                },
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildHeader(),
                      const SizedBox(height: 16),
                      _buildSwipableCardsSection(),
                      const SizedBox(height: 24),
                      _buildWorkoutFeed(),
                    ],
                  ),
                ),
              ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              SvgPicture.asset(
                'assets/images/pllogo.svg',
                width: 40,
                height: 40,
                colorFilter: ColorFilter.mode(
                  Theme.of(context).colorScheme.secondary,
                  BlendMode.srcIn,
                ),
              ),
              const SizedBox(width: 8),
              Text('PaceLifter',
                  style: GoogleFonts.anton(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.secondary)),
            ],
          ),
          IconButton(
              icon: const Icon(Icons.sync),
              onPressed: _isLoading ? null : _syncHealthData,
              tooltip: '동기화'),
        ],
      ),
    );
  }

  Widget _buildSwipableCardsSection() {
    final List<Widget> pages = [
      _buildWorkoutSummaryPage(),
      _buildRacesPage(),
    ];
    final List<String> titles = ['최근 운동 요약', '준비중인 레이스'];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: Text(
                  titles[_currentPage],
                  style:
                      const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
              if (_currentPage == 1) // '준비중인 레이스' 페이지일 때만 + 버튼 표시
                IconButton(
                  icon: const Icon(Icons.add_circle_outline),
                  onPressed: _showAddRaceDialog,
                  tooltip: '레이스 추가',
                ),
              if (_currentPage == 0) // '운동 요약' 페이지일 때만 기간 선택 버튼 표시
                _buildPeriodSelector(),
            ],
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 230,
          child: Stack(
            alignment: Alignment.center,
            children: [
              PageView(
                controller: _mainPageController,
                onPageChanged: (index) {
                  setState(() {
                    _currentPage = index;
                  });
                },
                children: pages,
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        // 페이지 인디케이터 및 더보기 버튼
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ...List.generate(
              pages.length,
              (index) => _buildPageIndicator(index == _currentPage),
            ),
          ],
        ),
        if (_currentPage == 1 && _races.length > 1)
          Center(
            child: TextButton(
              onPressed: () {
                Navigator.of(context).push(MaterialPageRoute(
                  builder: (context) => RaceListScreen(races: _races),
                ));
              },
              child: const Text('모든 레이스 보기'),
            ),
          ),
      ],
    );
  }

  Widget _buildWorkoutSummaryPage() {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: _buildStrengthEndurancePage(),
      ),
    );
  }

  Widget _buildRacesPage() {
    if (_races.isEmpty) {
      return Card(
        margin: const EdgeInsets.symmetric(horizontal: 16.0),
        child: InkWell(
          onTap: _showAddRaceDialog,
          child: const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.flag_outlined, size: 48, color: Colors.grey),
                SizedBox(height: 12),
                Text('등록된 레이스가 없습니다.'),
                Text('새로운 목표를 추가해보세요!'),
              ],
            ),
          ),
        ),
      );
    }
    // 가장 가까운 레이스 하나만 보여줌
    return _buildRaceCard(_races.first);
  }

  Widget _buildRaceCard(Race race) {
    final now = DateTime.now();
    final dDay = race.raceDate.difference(now).inDays + 1;
    final totalTrainingDays =
        race.raceDate.difference(race.trainingStartDate).inDays;
    final trainingDaysPassed = now.difference(race.trainingStartDate).inDays;
    final progress = totalTrainingDays > 0
        ? (trainingDaysPassed / totalTrainingDays).clamp(0.0, 1.0)
        : 0.0;
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(race.name,
                    style: const TextStyle(
                        fontSize: 20, fontWeight: FontWeight.bold)),
                Text(
                  'D-${dDay > 0 ? dDay : 'Day'}',
                  style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.primary),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
                '훈련 기간: ${DateFormat('yy.MM.dd').format(race.trainingStartDate)} ~ ${DateFormat('yy.MM.dd').format(race.raceDate)}',
                style: const TextStyle(fontSize: 12, color: Colors.grey)),
            const Spacer(),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('훈련 진행률: ${(progress * 100).toStringAsFixed(0)}%'),
                const SizedBox(height: 4),
                LinearProgressIndicator(
                  value: progress,
                  minHeight: 12,
                  borderRadius: BorderRadius.circular(6),
                  backgroundColor: Colors.grey[200],
                  valueColor: AlwaysStoppedAnimation<Color>(
                      Theme.of(context).colorScheme.primary),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showAddRaceDialog() {
    // ... (rest of the file is unchanged)
    final formKey = GlobalKey<FormState>();
    String raceName = '';
    DateTime? raceDate;
    DateTime? trainingStartDate;
    showDialog(
        context: context,
        builder: (context) {
          return StatefulBuilder(builder: (context, setDialogState) {
            return AlertDialog(
                title: const Text('새로운 레이스 추가'),
                content: Form(
                    key: formKey,
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      TextFormField(
                          decoration:
                              const InputDecoration(labelText: '레이스 이름'),
                          validator: (value) => value == null || value.isEmpty
                              ? '레이스 이름을 입력해주세요.'
                              : null,
                          onSaved: (value) => raceName = value!),
                      const SizedBox(height: 16),
                      Row(children: [
                        Expanded(
                            child: Text(raceDate == null
                                ? '레이스 날짜 선택'
                                : DateFormat('yyyy.MM.dd').format(raceDate!))),
                        IconButton(
                            icon: const Icon(Icons.calendar_today),
                            onPressed: () async {
                              final pickedDate = await showDatePicker(
                                  context: context,
                                  initialDate: DateTime.now(),
                                  firstDate: DateTime.now(),
                                  lastDate: DateTime.now()
                                      .add(const Duration(days: 365 * 5)));
                              if (pickedDate != null) {
                                setDialogState(() {
                                  raceDate = pickedDate;
                                });
                              }
                            })
                      ]),
                      const SizedBox(height: 16),
                      Row(children: [
                        Expanded(
                            child: Text(trainingStartDate == null
                                ? '훈련 시작일 선택'
                                : DateFormat('yyyy.MM.dd')
                                    .format(trainingStartDate!))),
                        IconButton(
                            icon: const Icon(Icons.calendar_today),
                            onPressed: () async {
                              final pickedDate = await showDatePicker(
                                  context: context,
                                  initialDate: DateTime.now(),
                                  firstDate: DateTime.now()
                                      .subtract(const Duration(days: 365)),
                                  lastDate: DateTime.now()
                                      .add(const Duration(days: 365)));
                              if (pickedDate != null) {
                                setDialogState(() {
                                  trainingStartDate = pickedDate;
                                });
                              }
                            })
                      ])
                    ])),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('취소')),
                  ElevatedButton(
                      onPressed: () async {
                        if (formKey.currentState!.validate() &&
                            raceDate != null &&
                            trainingStartDate != null) {
                          formKey.currentState!.save();
                          final newRace = Race(
                              name: raceName,
                              raceDate: raceDate!,
                              trainingStartDate: trainingStartDate!);
                          await _raceService.addRace(newRace);
                          await _loadRaces();
                          if (mounted) Navigator.of(context).pop();
                        }
                      },
                      child: const Text('저장'))
                ]);
          });
        });
  }

  Widget _buildPageIndicator(bool isActive) {
    return AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        margin: const EdgeInsets.symmetric(horizontal: 4.0),
        height: 8.0,
        width: isActive ? 24.0 : 8.0,
        decoration: BoxDecoration(
            color: isActive
                ? Theme.of(context).colorScheme.primary
                : Colors.grey.withOpacity(0.5),
            borderRadius: const BorderRadius.all(Radius.circular(12))));
  }

  Widget _buildStrengthEndurancePage() {
    return Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Row(children: [
        // Endurance (좌측)
        Expanded(
            child:
                Column(children: [
          SvgPicture.asset(
            'assets/images/runner-icon.svg',
            width: 42,
            height: 42,
            colorFilter: ColorFilter.mode(
              Theme.of(context).colorScheme.secondary,
              BlendMode.srcIn,
            ),
          ),
          const SizedBox(height: 8),
          const Text('Endurance',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text('${_endurancePercentage.toStringAsFixed(1)}%',
              style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.secondary))
        ])),
        // 원형 차트 (중앙)
        SizedBox(width: 120, height: 120, child: _buildPieChart()),
        // Strength (우측)
        Expanded(
            child:
                Column(children: [
          SvgPicture.asset(
            'assets/images/lifter-icon.svg',
            width: 46,
            height: 46,
            colorFilter: ColorFilter.mode(
              Theme.of(context).colorScheme.primary,
              BlendMode.srcIn,
            ),
          ),
          const SizedBox(height: 8),
          const Text('Strength',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text('${_strengthPercentage.toStringAsFixed(1)}%',
              style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.primary))
        ]))
      ]),
      const SizedBox(height: 16),
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text('총 $_totalWorkouts회 운동',
              style: TextStyle(
                  fontSize: 14,
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withOpacity(0.7))),
          Text(_dateRangeText,
              style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withOpacity(0.5)))
        ],
      )
    ]);
  }
  
  Widget _buildPlaceholderPage(String title, String content) {
    return Center(
        child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
          Text(title,
              style:
                  const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text(content, style: const TextStyle(fontSize: 14, color: Colors.grey))
        ]));
  }

  Widget _buildPeriodSelector() {
    return SegmentedButton<TimePeriod>(
        segments: const [
          ButtonSegment(
              value: TimePeriod.week,
              label: Text('주', style: TextStyle(fontSize: 12))),
          ButtonSegment(
              value: TimePeriod.month,
              label: Text('월', style: TextStyle(fontSize: 12))),
          ButtonSegment(
              value: TimePeriod.year,
              label: Text('연', style: TextStyle(fontSize: 12)))
        ],
        selected: {_selectedPeriod},
        onSelectionChanged: (Set<TimePeriod> newSelection) {
          setState(() {
            _selectedPeriod = newSelection.first;
            _calculateStatistics();
          });
        },
        style: ButtonStyle(
            visualDensity: VisualDensity.compact,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap));
  }

  Widget _buildPieChart() {
    return PieChart(PieChartData(
        sectionsSpace: 2,
        centerSpaceRadius: 35,
        sections: [
          PieChartSectionData(
              value: _strengthPercentage,
              color: Theme.of(context).colorScheme.primary,
              radius: 20,
              showTitle: false),
          PieChartSectionData(
              value: _endurancePercentage,
              color: Theme.of(context).colorScheme.secondary,
              radius: 20,
              showTitle: false)
        ]));
  }

  Widget _buildWorkoutFeed() {
    final recentWorkouts = _workoutData.take(20).toList();
    return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('운동 피드',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          recentWorkouts.isEmpty
              ? Card(
                  child: Padding(
                      padding: const EdgeInsets.all(32.0),
                      child: Center(
                          child: Column(children: [
                        Icon(Icons.info_outline,
                            size: 48,
                            color: Theme.of(context)
                                .colorScheme
                                .onSurface
                                .withOpacity(0.5)),
                        const SizedBox(height: 12),
                        Text('운동 기록이 없습니다',
                            style: TextStyle(
                                fontSize: 16,
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurface
                                    .withOpacity(0.7))),
                        const SizedBox(height: 8),
                        const Text('헬스 앱과 동기화하여 운동 기록을 가져오세요',
                            style: TextStyle(fontSize: 12),
                            textAlign: TextAlign.center)
                      ]))))
              : Column(
                  children: recentWorkouts.map((data) {
                  final workout = data.value as WorkoutHealthValue;
                  final distance = workout.totalDistance ?? 0.0;
                  final type = workout.workoutActivityType.name;
                  final workoutCategory = _getWorkoutCategory(type);
                  final color = _getCategoryColor(workoutCategory);

                  final String displayName;
                  if (type == 'TRADITIONAL_STRENGTH_TRAINING') {
                    displayName = 'STRENGTH TRAINING';
                  } else if (type == 'CORE_TRAINING') {
                    displayName = 'CORE TRAINING';
                  } else {
                    displayName = type;
                  }

                  final Color backgroundColor;
                  final Color iconColor;

                  if (workoutCategory == 'Strength(Core)') {
                    backgroundColor = Theme.of(context).colorScheme.primary;
                    iconColor = Theme.of(context).colorScheme.secondary;
                  } else {
                    backgroundColor = color.withOpacity(0.2);
                    iconColor = color;
                  }

                  return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: ListTile(
                          onTap: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (context) => WorkoutDetailScreen(workoutData: data),
                              ),
                            );
                          },
                          leading: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                  color: backgroundColor,
                                  borderRadius: BorderRadius.circular(8)),
                              child: _getWorkoutIconWidget(type, iconColor)),
                          title: Text(displayName,
                              style:
                                  const TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: Text(
                              DateFormat('yyyy-MM-dd').format(data.dateFrom)),
                          trailing: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                if (distance > 0)
                                  Text(
                                      '${(distance / 1000).toStringAsFixed(2)} km',
                                      style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 14)),
                                Text(workoutCategory,
                                    style: TextStyle(
                                        fontSize: 12,
                                        color: color))
                              ])));
                }).toList()),
          const SizedBox(height: 80)
        ]));
  }

  bool _isStrengthWorkout(String type) {
    final upperType = type.toUpperCase();
    return upperType.contains('STRENGTH') ||
        upperType.contains('WEIGHT') ||
        upperType.contains('FUNCTIONAL') ||
        upperType.contains('CORE') ||
        upperType.contains('TRADITIONAL_STRENGTH_TRAINING');
  }

  String _getWorkoutCategory(String type) {
    final upperType = type.toUpperCase();
    if (upperType.contains('CORE') || upperType.contains('FUNCTIONAL')) {
      return 'Strength(Core)';
    } else if (upperType.contains('STRENGTH') ||
        upperType.contains('WEIGHT') ||
        upperType.contains('TRADITIONAL_STRENGTH_TRAINING')) {
      return 'Strength';
    } else {
      return 'Endurance';
    }
  }

  Color _getCategoryColor(String category) {
    switch (category) {
      case 'Strength':
        return Theme.of(context).colorScheme.primary;
      case 'Endurance':
        return Theme.of(context).colorScheme.secondary;
      case 'Strength(Core)':
        return Theme.of(context).colorScheme.primary;
      default:
        return Theme.of(context).colorScheme.secondary;
    }
  }

  Widget _getWorkoutIconWidget(String type, Color color) {
    final upperType = type.toUpperCase();
    String iconPath;
    double iconSize = 24;

    if (upperType.contains('CORE') || upperType.contains('FUNCTIONAL')) {
      iconPath = 'assets/images/core-icon.svg';
      iconSize = 24;
    } else if (upperType.contains('STRENGTH') ||
        upperType.contains('WEIGHT') ||
        upperType.contains('TRADITIONAL_STRENGTH_TRAINING')) {
      iconPath = 'assets/images/lifter-icon.svg';
    } else {
      iconPath = 'assets/images/runner-icon.svg';
    }

    return SvgPicture.asset(
      iconPath,
      width: iconSize,
      height: iconSize,
      colorFilter: ColorFilter.mode(
        color,
        BlendMode.srcIn,
      ),
    );
  }
}