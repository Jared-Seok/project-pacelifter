import 'package:flutter/material.dart';
import 'package:health/health.dart';
import 'package:pacelifter/models/race.dart';
import 'package:pacelifter/services/health_service.dart';
import 'package:pacelifter/services/auth_service.dart';
import 'package:pacelifter/services/race_service.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:google_fonts/google_fonts.dart';

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
    switch (_selectedPeriod) {
      case TimePeriod.week:
        startDate = now.subtract(const Duration(days: 7));
        break;
      case TimePeriod.month:
        startDate = now.subtract(const Duration(days: 30));
        break;
      case TimePeriod.year:
        startDate = now.subtract(const Duration(days: 365));
        break;
    }
    final filteredData =
        _workoutData.where((data) => data.dateFrom.isAfter(startDate)).toList();
    _totalWorkouts = filteredData.length;
    int strengthCount = 0;
    int enduranceCount = 0;
    for (var data in filteredData) {
      if (data.value is WorkoutHealthValue) {
        final workout = data.value as WorkoutHealthValue;
        final type = workout.workoutActivityType.name.toUpperCase();
        if (type.contains('STRENGTH') ||
            type.contains('WEIGHT') ||
            type.contains('FUNCTIONAL')) {
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
          Text('PaceLifter',
              style: GoogleFonts.anton(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.secondary)),
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
    final List<String> titles = ['최근 운동 요약', '다가오는 레이스'];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                titles[_currentPage],
                style:
                    const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              if (_currentPage == 1) // '다가오는 레이스' 페이지일 때만 + 버튼 표시
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
          height: 220,
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
              if (_currentPage > 0)
                Positioned(
                  left: -4,
                  child: IconButton(
                    icon: const Icon(Icons.arrow_back_ios_new),
                    onPressed: () => _mainPageController.previousPage(
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeInOut,
                    ),
                  ),
                ),
              if (_currentPage < pages.length - 1)
                Positioned(
                  right: -4,
                  child: IconButton(
                    icon: const Icon(Icons.arrow_forward_ios),
                    onPressed: () => _mainPageController.nextPage(
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeInOut,
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(
            pages.length,
            (index) => _buildPageIndicator(index == _currentPage),
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
    return _races.isEmpty
        ? Card(
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
          )
        : PageView(
            controller: PageController(viewportFraction: 0.9),
            children: _races.map((race) => _buildRaceCard(race)).toList(),
          );
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
          Icon(Icons.directions_run,
              size: 40, color: Theme.of(context).colorScheme.primary),
          const SizedBox(height: 8),
          const Text('Endurance',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text('${_endurancePercentage.toStringAsFixed(1)}%',
              style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.primary))
        ])),
        // 원형 차트 (중앙)
        SizedBox(width: 120, height: 120, child: _buildPieChart()),
        // Strength (우측)
        Expanded(
            child:
                Column(children: [
          Icon(Icons.fitness_center,
              size: 40, color: Theme.of(context).colorScheme.primary),
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
      Center(
          child: Text('총 $_totalWorkouts회 운동',
              style: TextStyle(
                  fontSize: 14,
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withOpacity(0.7))))
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
                  final isStrength = _isStrengthWorkout(type);
                  return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: ListTile(
                          leading: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                  color: isStrength
                                      ? Theme.of(context)
                                          .colorScheme
                                          .primary
                                          .withOpacity(0.2)
                                      : Theme.of(context)
                                          .colorScheme
                                          .secondary
                                          .withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(8)),
                              child: Icon(_getWorkoutIcon(type),
                                  color: isStrength
                                      ? Theme.of(context).colorScheme.primary
                                      : Theme.of(context)
                                          .colorScheme
                                          .secondary)),
                          title: Text(type,
                              style:
                                  const TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: Text(
                              DateFormat('yyyy-MM-dd HH:mm').format(data.dateFrom)),
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
                                Text(isStrength ? 'Strength' : 'Endurance',
                                    style: TextStyle(
                                        fontSize: 12,
                                        color: isStrength
                                            ? Theme.of(context)
                                                .colorScheme
                                                .primary
                                            : Theme.of(context)
                                                .colorScheme
                                                .secondary))
                              ])));
                }).toList()),
          const SizedBox(height: 80)
        ]));
  }

  bool _isStrengthWorkout(String type) {
    final upperType = type.toUpperCase();
    return upperType.contains('STRENGTH') ||
        upperType.contains('WEIGHT') ||
        upperType.contains('FUNCTIONAL');
  }

  IconData _getWorkoutIcon(String type) {
    final upperType = type.toUpperCase();
    if (upperType.contains('RUNNING')) return Icons.directions_run;
    if (upperType.contains('WALKING')) return Icons.directions_walk;
    if (upperType.contains('CYCLING')) return Icons.directions_bike;
    if (upperType.contains('SWIMMING')) return Icons.pool;
    if (upperType.contains('HIKING')) return Icons.terrain;
    if (upperType.contains('STRENGTH') || upperType.contains('WEIGHT')) {
      return Icons.fitness_center;
    }
    return Icons.sports;
  }
}