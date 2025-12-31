import 'package:flutter/material.dart';
import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:hive/hive.dart';
import 'package:health/health.dart';
import 'package:pacelifter/models/race.dart';
import 'package:pacelifter/models/time_period.dart';
import 'package:pacelifter/services/health_service.dart';
import 'package:pacelifter/services/auth_service.dart';
import 'package:pacelifter/services/race_service.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pacelifter/screens/race_list_screen.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:pacelifter/screens/workout_detail_screen.dart';
import 'package:pacelifter/screens/workout_feed_screen.dart';
import 'package:pacelifter/screens/performance_analysis_screen.dart';
import 'package:pacelifter/services/workout_history_service.dart';
import 'package:pacelifter/models/sessions/workout_session.dart';
import 'package:pacelifter/services/template_service.dart';
import 'package:pacelifter/services/scoring_engine.dart';
import 'package:pacelifter/models/scoring/performance_scores.dart';
import 'package:pacelifter/models/workout_data_wrapper.dart';
import 'package:pacelifter/utils/workout_ui_utils.dart';
import 'package:uuid/uuid.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final HealthService _healthService = HealthService();
  final AuthService _authService = AuthService();
  final RaceService _raceService = RaceService();
  late PageController _mainPageController;
  late PageController _racePageController;
  final ScrollController _scrollController = ScrollController();
  List<WorkoutDataWrapper> _unifiedWorkouts = [];
  List<Race> _races = [];
  bool _isLoading = true;
  TimePeriod _selectedPeriod = TimePeriod.week;
  int _currentPage = 0;
  int _currentRacePage = 0;

  double _strengthPercentage = 0.0;
  double _endurancePercentage = 0.0;
  int _totalWorkouts = 0;
  String _dateRangeText = '';

  // 무한 스크롤 관련 변수
  String _currentVisibleMonth = '';
  final Map<String, GlobalKey> _monthKeyMap = {};
  final Map<String, int> _monthIndexMap = {}; // 각 월의 첫 번째 아이템 인덱스 저장
  
  PerformanceScores? _scores;
  StreamSubscription? _historySubscription;

  @override
  void initState() {
    super.initState();
    _mainPageController = PageController();
    _racePageController = PageController();
    _scrollController.addListener(_onScroll);
    _initialize();
    
    // 로컬 운동 기록 변경 감지 및 자동 새로고침
    _historySubscription = Hive.box<WorkoutSession>('user_workout_history').watch().listen((event) {
      _loadHealthData();
    });
  }

  @override
  void dispose() {
    _mainPageController.dispose();
    _racePageController.dispose();
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _historySubscription?.cancel();
    super.dispose();
  }

  void _onScroll() {
    _updateVisibleMonth();
  }

  void _updateVisibleMonth() {
    if (_unifiedWorkouts.isEmpty) return;

    // 화면 상단(sticky 헤더 바로 아래)에 보이는 첫 번째 운동 데이터의 월을 찾음
    String? newVisibleMonth;

    for (var entry in _monthKeyMap.entries) {
      final key = entry.value;
      final context = key.currentContext;
      if (context != null) {
        final renderBox = context.findRenderObject() as RenderBox?;
        if (renderBox != null) {
          final position = renderBox.localToGlobal(Offset.zero);
          // Sticky 헤더(48px) 바로 아래 영역에 있는 첫 번째 월 찾기
          // 위로 스크롤할 때도 즉시 반응하도록 범위 조정
          if (position.dy <= 100 && position.dy >= -100) {
            newVisibleMonth = entry.key;
            break;
          }
        }
      }
    }

    // 찾지 못했다면 현재 화면에 보이는 첫 번째 데이터의 월 사용
    if (newVisibleMonth == null) {
      for (var data in _unifiedWorkouts) {
        final monthKey = '${data.dateFrom.year}년 ${data.dateFrom.month}월';
        if (_monthKeyMap.containsKey(monthKey)) {
          final key = _monthKeyMap[monthKey];
          final context = key?.currentContext;
          if (context != null) {
            final renderBox = context.findRenderObject() as RenderBox?;
            if (renderBox != null) {
              final position = renderBox.localToGlobal(Offset.zero);
              if (position.dy >= 50 && position.dy <= 300) {
                newVisibleMonth = monthKey;
                break;
              }
            }
          }
        }
      }
    }

    if (newVisibleMonth != null && _currentVisibleMonth != newVisibleMonth) {
      setState(() {
        _currentVisibleMonth = newVisibleMonth!;
      });
    }
  }

  Future<void> _initialize() async {
    try {
      await _checkFirstLoginAndSync();
      await _loadRaces();
      await _loadPerformanceScores();
    } catch (e) {
      debugPrint('❌ Error during dashboard initialization: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _loadRaces() async {
    try {
      final races = await _raceService.getRaces();
      if (mounted) {
        // Sort races by date, upcoming first
        races.sort((a, b) => a.raceDate.compareTo(b.raceDate));
        setState(() {
          _races = races;
        });
      }
    } catch (e) {
      debugPrint('❌ Error loading races: $e');
    }
  }

  Future<void> _loadPerformanceScores() async {
    try {
      final scores = ScoringEngine().getLatestScores();
      if (mounted) {
        setState(() {
          _scores = scores;
        });
      }
      
      final updatedScores = await ScoringEngine().calculateAndSaveScores();
      if (mounted) {
        setState(() {
          _scores = updatedScores;
        });
      }
    } catch (e) {
      debugPrint('❌ Error loading performance scores: $e');
    }
  }

  Future<void> _checkFirstLoginAndSync() async {
    try {
      final isFirstLogin = await _authService.isFirstLogin();
      final isSyncCompleted = await _authService.isHealthSyncCompleted();

      if (isFirstLogin && !isSyncCompleted && mounted) {
        await Future.delayed(const Duration(milliseconds: 500));
        if (mounted) {
          _showHealthSyncDialog();
        }
      } 
      
      // sync 여부와 관계없이 로컬 데이터 및 동기화된 데이터를 로드함
      await _loadHealthData();
    } catch (e) {
      debugPrint('❌ Error checking login/sync: $e');
    }
  }

  void _showHealthSyncDialog() {
    showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
              backgroundColor: const Color(0xFF1C1C1E),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: Row(children: [
                Icon(Icons.health_and_safety,
                    color: Theme.of(context).colorScheme.secondary),
                const SizedBox(width: 12),
                const Text('전체 데이터 동기화'),
              ]),
              content: const Text('PaceLifter가 과거의 모든 운동 기록을 가져와 정밀 퍼포먼스 분석을 시작합니다.\n\n데이터 양에 따라 수십 초가 소요될 수 있습니다.'),
              actions: [
                TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text('나중에', style: TextStyle(color: Colors.grey[400]))),
                ElevatedButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                      _startFullSyncProcess();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).colorScheme.secondary,
                      foregroundColor: Colors.black,
                    ),
                    child: const Text('동기화 시작')),
              ],
            ));
  }

  void _startFullSyncProcess() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => _SyncProgressModal(
        onComplete: () async {
          await _loadHealthData();
          await _loadPerformanceScores();
        },
      ),
    );
  }

  Future<void> _syncHealthData() async {
    _startFullSyncProcess();
  }

  Future<void> _loadHealthData() async {
    try {
      // 1. HealthKit 데이터 가져오기 (최근 90일치 - 일상적 로드는 빠르게)
      final workoutData = await _healthService.fetchWorkoutData(days: 90);
      
      // 2. 로컬 Hive 세션 가져오기
      final sessions = WorkoutHistoryService().getAllSessions();
      final sessionMap = <String, WorkoutSession>{};
      for (var s in sessions) {
        if (s.healthKitWorkoutId != null) {
          sessionMap[s.healthKitWorkoutId!] = s;
        }
      }

      // 3. 통합 리스트 생성
      final List<WorkoutDataWrapper> unified = [];
      final Set<String> linkedSessionIds = {};

      // 3-1. HealthKit 데이터 기반 매핑
      for (var data in workoutData) {
        final session = sessionMap[data.uuid];
        if (session != null) {
          linkedSessionIds.add(session.id);
        }
        unified.add(WorkoutDataWrapper(healthData: data, session: session));
      }

      // 3-2. 연결되지 않은 로컬 세션 추가
      for (var s in sessions) {
        if (!linkedSessionIds.contains(s.id)) {
          unified.add(WorkoutDataWrapper(session: s));
        }
      }

      // 4. 날짜순 정렬 (최신순)
      unified.sort((a, b) => b.dateFrom.compareTo(a.dateFrom));

      if (mounted) {
        setState(() {
          _unifiedWorkouts = unified;
          _calculateStatistics();
          _prepareMonthKeys();
        });
      }
    } catch (e) {
      debugPrint('❌ Error loading health data: $e');
    }
  }

  void _prepareMonthKeys() {
    _monthKeyMap.clear();
    _monthIndexMap.clear();
    if (_unifiedWorkouts.isEmpty) return;

    // 각 월의 첫 번째 데이터(해당 월의 가장 최신 기록)에 대한 Key 및 Index 생성
    for (int i = 0; i < _unifiedWorkouts.length; i++) {
      final data = _unifiedWorkouts[i];
      final date = data.dateFrom;
      final monthKey = '${date.year}년 ${date.month}월';
      
      if (!_monthKeyMap.containsKey(monthKey)) {
        _monthKeyMap[monthKey] = GlobalKey();
        _monthIndexMap[monthKey] = i;
      }
    }

    // 첫 번째 월을 현재 보이는 월로 설정
    if (_monthKeyMap.isNotEmpty) {
      _currentVisibleMonth = _monthKeyMap.keys.first;
    }
  }

  void _showMonthPicker() {
    if (_monthKeyMap.isEmpty) return;

    // 사용 가능한 년도와 월 추출
    final availableYearsMonths = <int, Set<int>>{};
    for (var monthKey in _monthKeyMap.keys) {
      final parts = monthKey.replaceAll('년 ', '-').replaceAll('월', '').split('-');
      final year = int.parse(parts[0]);
      final month = int.parse(parts[1]);

      if (!availableYearsMonths.containsKey(year)) {
        availableYearsMonths[year] = {};
      }
      availableYearsMonths[year]!.add(month);
    }

    final years = availableYearsMonths.keys.toList()..sort((a, b) => b.compareTo(a));

    // 현재 표시 중인 년/월 파싱
    final currentParts = _currentVisibleMonth.replaceAll('년 ', '-').replaceAll('월', '').split('-');
    int selectedYear = int.parse(currentParts[0]);
    int selectedMonth = int.parse(currentParts[1]);

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) {
          final availableMonths = (availableYearsMonths[selectedYear]?.toList() ?? [])
            ..sort((a, b) => b.compareTo(a));

          return Container(
            height: 380,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Column(
              children: [
                Container(
                  margin: const EdgeInsets.only(top: 12),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  '이동할 년/월 선택',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 12),
                // 선택된 년/월 표시
                Text(
                  '$selectedYear년 $selectedMonth월',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.secondary, // Neon Green
                  ),
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: Row(
                    children: [
                      // 년도 피커
                      Expanded(
                        child: Column(
                          children: [
                            Text(
                              '연',
                              style: TextStyle(
                                fontSize: 14,
                                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Expanded(
                              child: CupertinoPicker(
                                scrollController: FixedExtentScrollController(
                                  initialItem: years.indexOf(selectedYear),
                                ),
                                itemExtent: 40,
                                onSelectedItemChanged: (index) {
                                  setModalState(() {
                                    selectedYear = years[index];
                                    // 선택한 년도에 해당하는 월이 없으면 첫 번째 월로 설정
                                    final months = availableYearsMonths[selectedYear]!.toList()
                                      ..sort((a, b) => b.compareTo(a));
                                    if (!months.contains(selectedMonth)) {
                                      selectedMonth = months.first;
                                    }
                                  });
                                },
                                children: years.map((year) {
                                  return Center(
                                    child: Text(
                                      '$year년',
                                      style: TextStyle(
                                        fontSize: 18,
                                        color: Theme.of(context).colorScheme.onSurface,
                                      ),
                                    ),
                                  );
                                }).toList(),
                              ),
                            ),
                          ],
                        ),
                      ),
                      // 월 피커
                      Expanded(
                        child: Column(
                          children: [
                            Text(
                              '월',
                              style: TextStyle(
                                fontSize: 14,
                                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Expanded(
                              child: CupertinoPicker(
                                scrollController: FixedExtentScrollController(
                                  initialItem: availableMonths.indexOf(selectedMonth).clamp(0, availableMonths.length - 1),
                                ),
                                itemExtent: 40,
                                onSelectedItemChanged: (index) {
                                  setModalState(() {
                                    selectedMonth = availableMonths[index];
                                  });
                                },
                                children: availableMonths.map((month) {
                                  return Center(
                                    child: Text(
                                      '$month월',
                                      style: TextStyle(
                                        fontSize: 18,
                                        color: Theme.of(context).colorScheme.onSurface,
                                      ),
                                    ),
                                  );
                                }).toList(),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextButton(
                          onPressed: () => Navigator.pop(context),
                          style: TextButton.styleFrom(
                            foregroundColor: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                          ),
                          child: const Text('취소'),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () {
                            Navigator.pop(context);
                            final targetMonth = '$selectedYear년 $selectedMonth월';
                            _scrollToMonth(targetMonth);
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Theme.of(context).colorScheme.secondary,
                            foregroundColor: Theme.of(context).colorScheme.onSecondary,
                          ),
                          child: const Text('이동'),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _scrollToMonth(String monthKey) {
    final targetIndex = _monthIndexMap[monthKey];
    if (targetIndex == null) return;

    final key = _monthKeyMap[monthKey];
    if (key == null) return;

    // 1단계: 위젯이 현재 메모리에 있는지 확인 (가상화 대응)
    final context = key.currentContext;
    
    if (context == null) {
      // 위젯이 없으므로 대략적인 위치로 강제 점프 (평균 카드 높이 115px + 상단 영역 고려)
      double estimatedOffset = 850 + (targetIndex * 115.0); 
      _scrollController.jumpTo(estimatedOffset.clamp(0, _scrollController.position.maxScrollExtent));
      
      // 점프 후 위젯이 생성될 시간을 위해 약간 지연 후 정밀 스크롤
      Future.delayed(const Duration(milliseconds: 100), () {
        _preciseScroll(monthKey);
      });
    } else {
      _preciseScroll(monthKey);
    }
  }

  void _preciseScroll(String monthKey) {
    final key = _monthKeyMap[monthKey];
    final scrollContext = key?.currentContext;
    
    if (scrollContext != null && mounted) {
      Scrollable.ensureVisible(
        scrollContext,
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOut,
        alignment: 0.0, // 최상단에 배치
      );
    }
  }

  void _scrollToCurrentPeriod() {
    // 현재 선택된 기간의 운동 데이터 필터링
    final now = DateTime.now();
    DateTime startDate;
    DateTime endDate;

    switch (_selectedPeriod) {
      case TimePeriod.week:
        final currentWeekday = now.weekday;
        final daysToMonday = currentWeekday - 1;
        final daysToSunday = 7 - currentWeekday;
        startDate = DateTime(now.year, now.month, now.day)
            .subtract(Duration(days: daysToMonday));
        endDate = DateTime(now.year, now.month, now.day)
            .add(Duration(days: daysToSunday))
            .add(const Duration(hours: 23, minutes: 59, seconds: 59));
        break;
      case TimePeriod.month:
        startDate = DateTime(now.year, now.month, 1);
        endDate = DateTime(now.year, now.month + 1, 0, 23, 59, 59);
        break;
      case TimePeriod.year:
        startDate = DateTime(now.year, 1, 1);
        endDate = DateTime(now.year, 12, 31, 23, 59, 59);
        break;
    }

    final filteredData = _unifiedWorkouts
        .where((data) =>
            data.dateFrom.isAfter(startDate.subtract(const Duration(seconds: 1))) &&
            data.dateFrom.isBefore(endDate.add(const Duration(seconds: 1))))
        .toList();

    // 상세 페이지로 이동
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => WorkoutFeedScreen(
          unifiedWorkouts: filteredData,
          period: _selectedPeriod,
          dateRangeText: _dateRangeText,
        ),
      ),
    );
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

        // 날짜 범위 텍스트 생성: "25/12/8~14" 형식 (월이 바뀌면 "25/12/30~26/1/5" 형식)
        final startDay = startDate.day;
        final endDay = endDate.day;

        // 시작일과 종료일의 연도/월이 다른지 확인
        if (startDate.year != endDate.year || startDate.month != endDate.month) {
          // 연도나 월이 바뀌는 경우: 전체 날짜 표시
          _dateRangeText =
              '${startDate.year.toString().substring(2)}/${startDate.month}/$startDay~'
              '${endDate.year.toString().substring(2)}/${endDate.month}/$endDay';
        } else {
          // 같은 월인 경우: 간단하게 표시
          _dateRangeText = '${startDate.year.toString().substring(2)}/${startDate.month}/$startDay~$endDay';
        }
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

    final filteredData = _unifiedWorkouts
        .where((data) =>
            data.dateFrom.isAfter(startDate.subtract(const Duration(seconds: 1))) &&
            data.dateFrom.isBefore(endDate.add(const Duration(seconds: 1))))
        .toList();

    _totalWorkouts = filteredData.length;
    int strengthCount = 0;
    int enduranceCount = 0;

    for (var wrapper in filteredData) {
      String category = '';
      if (wrapper.session != null) {
        category = wrapper.session!.category;
      } else if (wrapper.healthData != null && wrapper.healthData!.value is WorkoutHealthValue) {
        final workout = wrapper.healthData!.value as WorkoutHealthValue;
        category = WorkoutUIUtils.getWorkoutCategory(workout.workoutActivityType.name);
      }

      if (category == 'Strength') {
        strengthCount++;
      } else if (category == 'Endurance' || category == 'Hybrid') {
        enduranceCount++;
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
                  await _loadPerformanceScores();
                },
                child: CustomScrollView(
                  controller: _scrollController,
                  physics: const AlwaysScrollableScrollPhysics(),
                  slivers: [
                    SliverToBoxAdapter(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildHeader(),
                          const SizedBox(height: 16),
                          _buildPerformanceSection(),
                          const SizedBox(height: 24),
                          _buildSwipableCardsSection(),
                          const SizedBox(height: 24),
                        ],
                      ),
                    ),
                    _buildWorkoutFeedSliver(),
                  ],
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
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.add_circle_outline),
                onPressed: () {
                  Navigator.of(context).pushNamed('/add-workout').then((result) {
                    if (result == true) {
                      // 운동이 추가되면 데이터 새로고침
                      _loadHealthData();
                    }
                  });
                },
                tooltip: '운동 추가',
              ),
              IconButton(
                icon: const Icon(Icons.sync),
                onPressed: _isLoading ? null : _syncHealthData,
                tooltip: '동기화',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPerformanceSection() {
    if (_scores == null) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) => PerformanceAnalysisScreen(scores: _scores!),
              ),
            );
          },
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Text('종합 퍼포먼스', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                        const SizedBox(width: 6),
                        Icon(Icons.chevron_right, size: 20, color: Colors.grey.withValues(alpha: 0.5)),
                      ],
                    ),
                    Text(
                      '최근 업데이트: ${DateFormat('HH:mm').format(_scores!.lastUpdated)}',
                      style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    SizedBox(
                      width: 120,
                      height: 120,
                      child: RadarChart(
                        RadarChartData(
                          dataSets: [
                            RadarDataSet(
                              fillColor: Theme.of(context).colorScheme.secondary.withValues(alpha: 0.2),
                              borderColor: Theme.of(context).colorScheme.secondary,
                              entryRadius: 2,
                              dataEntries: [
                                RadarEntry(value: _scores!.enduranceScore),
                                RadarEntry(value: _scores!.strengthScore),
                                RadarEntry(value: _scores!.conditioningScore),
                              ],
                            ),
                          ],
                          radarShape: RadarShape.polygon,
                          getTitle: (index, angle) {
                            switch (index) {
                              case 0: return const RadarChartTitle(text: '지구력');
                              case 1: return const RadarChartTitle(text: '근력');
                              case 2: return const RadarChartTitle(text: '컨디셔닝');
                              default: return const RadarChartTitle(text: '');
                            }
                          },
                          tickCount: 1,
                          ticksTextStyle: const TextStyle(color: Colors.transparent),
                          gridBorderData: BorderSide(color: Colors.grey.withValues(alpha: 0.2)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 24),
                    Expanded(
                      child: Column(
                        children: [
                          _buildScoreTile('Endurance', _scores!.enduranceScore, Theme.of(context).colorScheme.tertiary),
                          const Divider(height: 12),
                          _buildScoreTile('Strength', _scores!.strengthScore, Theme.of(context).colorScheme.primary),
                          const Divider(height: 12),
                          _buildScoreTile('Conditioning', _scores!.conditioningScore, Theme.of(context).colorScheme.secondary),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildScoreTile(String label, double score, Color color) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
        Row(
          children: [
            Text(
              score.toInt().toString(),
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color),
            ),
            const Text(' 점', style: TextStyle(fontSize: 11, color: Colors.grey)),
          ],
        ),
      ],
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
      child: InkWell(
        onTap: _scrollToCurrentPeriod,
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: _buildStrengthEndurancePage(),
        ),
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

    // 여러 레이스를 상하 스와이프로 전환 가능하도록 PageView 사용
    return SizedBox(
      height: 240, // 카드 높이 + 인디케이터 공간
      child: Stack(
        children: [
          PageView.builder(
            controller: _racePageController,
            scrollDirection: Axis.vertical, // 상하 스크롤로 변경
            onPageChanged: (index) {
              setState(() {
                _currentRacePage = index;
              });
            },
            itemCount: _races.length,
            itemBuilder: (context, index) {
              return _buildRaceCard(_races[index]);
            },
          ),
          // 인디케이터를 오른쪽에 세로로 배치
          if (_races.length > 1)
            Positioned(
              right: 8,
              top: 0,
              bottom: 0,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  _races.length,
                  (index) => Container(
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _currentRacePage == index
                          ? Theme.of(context).colorScheme.secondary
                          : Colors.grey[300],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  void _navigateToRaceTrainingFeed(Race race) {
    final now = DateTime.now();

    // 훈련 기간 동안의 운동 데이터 필터링 (통합 데이터 사용)
    final trainingWorkouts = _unifiedWorkouts.where((wrapper) {
      final date = wrapper.dateFrom;
      return date.isAfter(race.trainingStartDate.subtract(const Duration(seconds: 1))) &&
             date.isBefore(now.add(const Duration(seconds: 1)));
    }).toList();

    // 훈련 기간 텍스트 생성
    final dateRangeText = '${DateFormat('yy.MM.dd').format(race.trainingStartDate)} ~ ${DateFormat('yy.MM.dd').format(now)}';

    // WorkoutFeedScreen으로 이동
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => WorkoutFeedScreen(
          unifiedWorkouts: trainingWorkouts,
          period: TimePeriod.month, // 기본값으로 month 사용
          dateRangeText: dateRangeText,
          raceName: race.name, // 레이스 이름 전달
        ),
      ),
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

    // 훈련 기간 동안의 운동 횟수 계산 (통합 데이터 사용)
    final trainingWorkouts = _unifiedWorkouts.where((wrapper) {
      final date = wrapper.dateFrom;
      return date.isAfter(race.trainingStartDate.subtract(const Duration(seconds: 1))) &&
             date.isBefore(now.add(const Duration(seconds: 1)));
    }).toList();

    int enduranceCount = 0;
    int strengthCount = 0;
    for (final wrapper in trainingWorkouts) {
      String category = 'Unknown';
      if (wrapper.session != null) {
        category = wrapper.session!.category;
      } else if (wrapper.healthData != null) {
        final workout = wrapper.healthData!.value as WorkoutHealthValue;
        category = WorkoutUIUtils.getWorkoutCategory(workout.workoutActivityType.name);
      }
      
      if (category == 'Strength') {
        strengthCount++;
      } else {
        enduranceCount++;
      }
    }

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      child: InkWell(
        onTap: () => _navigateToRaceTrainingFeed(race),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
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
                      color: Theme.of(context).colorScheme.secondary),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
                '훈련 기간: ${DateFormat('yy.MM.dd').format(race.trainingStartDate)} ~ ${DateFormat('yy.MM.dd').format(race.raceDate)}',
                style: const TextStyle(fontSize: 12, color: Colors.grey)),
            const SizedBox(height: 20),
            // 운동 횟수 - 중앙에 크게 배치
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Endurance
                SvgPicture.asset(
                  'assets/images/endurance/runner-icon.svg',
                  width: 36,
                  height: 36,
                  colorFilter: ColorFilter.mode(
                    Theme.of(context).colorScheme.tertiary, // Deep Teal
                    BlendMode.srcIn,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '$enduranceCount회',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.tertiary, // Deep Teal
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Container(
                    width: 2,
                    height: 32,
                    color: Colors.grey[300],
                  ),
                ),
                // Strength
                Text(
                  '$strengthCount회',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
                const SizedBox(width: 8),
                SvgPicture.asset(
                  'assets/images/strength/lifter-icon.svg',
                  width: 36,
                  height: 36,
                  colorFilter: ColorFilter.mode(
                    Theme.of(context).colorScheme.primary,
                    BlendMode.srcIn,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            // 훈련 진행률 - 하단에 배치
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('훈련 진행률: ${(progress * 100).toStringAsFixed(0)}%',
                    style: const TextStyle(fontSize: 13)),
                const SizedBox(height: 8),
                LinearProgressIndicator(
                  value: progress,
                  minHeight: 12,
                  borderRadius: BorderRadius.circular(6),
                  backgroundColor: Colors.white10,
                  valueColor: AlwaysStoppedAnimation<Color>(
                      Theme.of(context).colorScheme.secondary),
                ),
              ],
            ),
            ],
          ),
        ),
      ),
    );
  }

  void _showAddRaceDialog() {
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
                          final navigator = Navigator.of(context);
                          final newRace = Race(
                              name: raceName,
                              raceDate: raceDate!,
                              trainingStartDate: trainingStartDate!);
                          await _raceService.addRace(newRace);
                          await _loadRaces();
                          if (!mounted) return;
                          navigator.pop();
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
                ? Theme.of(context).colorScheme.secondary // Neon Green
                : Colors.grey.withValues(alpha: 0.5),
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
            'assets/images/endurance/runner-icon.svg',
            width: 42,
            height: 42,
            colorFilter: ColorFilter.mode(
              Theme.of(context).colorScheme.tertiary, // Deep Teal
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
                  color: Theme.of(context).colorScheme.tertiary)) // Deep Teal
        ])),
        // 원형 차트 (중앙)
        SizedBox(width: 120, height: 120, child: _buildPieChart()),
        // Strength (우측)
        Expanded(
            child:
                Column(children: [
          SvgPicture.asset(
            'assets/images/strength/lifter-icon.svg',
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
                      .withValues(alpha: 0.7))),
          Text(_dateRangeText,
              style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withValues(alpha: 0.5)))
        ],
      )
    ]);
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
        startDegreeOffset: 270,
        sections: [
          PieChartSectionData(
              value: _strengthPercentage,
              color: Theme.of(context).colorScheme.primary,
              radius: 20,
              showTitle: false),
          PieChartSectionData(
              value: _endurancePercentage,
              color: Theme.of(context).colorScheme.tertiary, // Deep Teal
              radius: 20,
              showTitle: false)
        ]));
  }

  Widget _buildWorkoutFeedSliver() {
    if (_unifiedWorkouts.isEmpty) {
      return SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('운동 피드',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(32.0),
                  child: Center(
                    child: Column(
                      children: [
                        Icon(Icons.info_outline,
                            size: 48,
                            color: Theme.of(context)
                                .colorScheme
                                .onSurface
                                .withValues(alpha: 0.5)),
                        const SizedBox(height: 12),
                        Text('운동 기록이 없습니다',
                            style: TextStyle(
                                fontSize: 16,
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurface
                                    .withValues(alpha: 0.7))),
                        const SizedBox(height: 8),
                        const Text('운동을 시작하거나 헬스 앱과 동기화하여 기록을 가져오세요',
                            style: TextStyle(fontSize: 12),
                            textAlign: TextAlign.center),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 80),
            ],
          ),
        ),
      );
    }

    return SliverMainAxisGroup(
      slivers: [
        // Sticky 헤더
        SliverPersistentHeader(
          pinned: true,
          delegate: _StickyMonthHeaderDelegate(
            currentMonth: _currentVisibleMonth,
            backgroundColor: Theme.of(context).colorScheme.surface,
            onMonthSelectorTap: _showMonthPicker,
            onTitleTap: () {
              _scrollController.animateTo(
                0,
                duration: const Duration(milliseconds: 600),
                curve: Curves.easeInOut,
              );
            },
          ),
        ),
        // 운동 데이터 리스트
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          sliver: SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                return _buildWorkoutItem(index);
              },
              childCount: _unifiedWorkouts.length,
            ),
          ),
        ),
        // 하단 여백
        const SliverToBoxAdapter(
          child: SizedBox(height: 80),
        ),
      ],
    );
  }

  Widget _buildWorkoutItem(int index) {
    final wrapper = _unifiedWorkouts[index];
    final date = wrapper.dateFrom;
    final monthKey = '${date.year}년 ${date.month}월';

    // 해당 월의 첫 번째 항목인지 확인
    final isFirstOfMonth = index == 0 ||
        _unifiedWorkouts[index - 1].dateFrom.month != date.month ||
        _unifiedWorkouts[index - 1].dateFrom.year != date.year;

    // 데이터 추출
    String type = 'UNKNOWN';
    double distance = 0.0;
    String workoutCategory = 'Unknown';
    final session = wrapper.session;
    final healthData = wrapper.healthData;

    if (healthData != null && healthData.value is WorkoutHealthValue) {
      final workout = healthData.value as WorkoutHealthValue;
      type = workout.workoutActivityType.name;
      distance = (workout.totalDistance ?? 0.0).toDouble();
      workoutCategory = WorkoutUIUtils.getWorkoutCategory(type);
    } else if (session != null) {
      workoutCategory = session.category;
      type = session.category == 'Strength' ? 'TRADITIONAL_STRENGTH_TRAINING' : 'OTHER';
    }

    final color = _getCategoryColor(workoutCategory);
    final upperType = type.toUpperCase();

    // 표시 이름 결정
    String displayName;
    if (session != null && session.templateId.isNotEmpty && session.templateId != 'health_kit_import') {
      displayName = session.templateName;
    } else {
      displayName = WorkoutUIUtils.formatWorkoutType(type);
    }

    final Color backgroundColor;
    final Color iconColor;

    if (upperType.contains('CORE') || upperType.contains('FUNCTIONAL')) {
      backgroundColor = Theme.of(context).colorScheme.primary.withValues(alpha: 0.2);
      iconColor = Theme.of(context).colorScheme.primary;
    } else {
      backgroundColor = color.withValues(alpha: 0.2);
      iconColor = color;
    }

    // 세부 운동 아이콘 확인
    bool hasSpecificIcon = false;
    if (session != null && session.templateId != null) {
      final template = TemplateService.getTemplateById(session.templateId!);
      if (template != null && template.phases.isNotEmpty) {
        final firstBlock = template.phases.first.blocks.isNotEmpty ? template.phases.first.blocks.first : null;
        if (firstBlock != null && firstBlock.exerciseId != null) {
          final exercise = TemplateService.getExerciseById(firstBlock.exerciseId!);
          if (exercise?.imagePath != null) hasSpecificIcon = true;
        }
      }
    }

    return Column(
      key: isFirstOfMonth ? _monthKeyMap[monthKey] : null,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (isFirstOfMonth && monthKey != _currentVisibleMonth)
          Container(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
            child: Text(
              monthKey,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.secondary, // Neon Green
              ),
            ),
          ),
        Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: ListTile(
            onTap: () async {
              await Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => WorkoutDetailScreen(
                    dataWrapper: wrapper,
                  ),
                ),
              );
              _loadHealthData(); // 데이터 새로고침
            },
            onLongPress: session != null ? () => _showDeleteWorkoutDialog(wrapper) : null,
            leading: Container(
              padding: hasSpecificIcon ? EdgeInsets.zero : const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: hasSpecificIcon ? Colors.transparent : backgroundColor,
                borderRadius: BorderRadius.circular(8),
              ),
              child: WorkoutUIUtils.getWorkoutIconWidget(
                context: context,
                type: type,
                color: iconColor,
                environmentType: session?.environmentType,
                session: session,
              ),
            ),
            title: Text(displayName,
                style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  DateFormat('yyyy-MM-dd').format(date),
                  style: TextStyle(color: Theme.of(context).colorScheme.secondary.withValues(alpha: 0.8)),
                ),
                if (session != null && session.templateId.isNotEmpty && session.templateId != 'health_kit_import')
                  Padding(
                    padding: const EdgeInsets.only(top: 6.0),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.secondary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(
                          color: Theme.of(context).colorScheme.secondary.withValues(alpha: 0.5),
                          width: 0.5,
                        ),
                      ),
                      child: Text(
                        session.templateName,
                        style: TextStyle(
                          fontSize: 11,
                          color: Theme.of(context).colorScheme.secondary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            trailing: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (distance > 0)
                  Text('${(distance / 1000).toStringAsFixed(2)} km',
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 14)),
                Text(workoutCategory,
                    style: TextStyle(fontSize: 12, color: color)),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Color _getCategoryColor(String category) {
    switch (category) {
      case 'Strength':
        return Theme.of(context).colorScheme.primary; // Orange
      case 'Endurance':
        return Theme.of(context).colorScheme.tertiary; // Deep Teal
      case 'Hybrid':
        return Theme.of(context).colorScheme.secondary; // Neon Green
      default:
        return Theme.of(context).colorScheme.secondary;
    }
  }

  void _showDeleteWorkoutDialog(WorkoutDataWrapper wrapper) {
    final session = wrapper.session;
    if (session == null) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('운동 기록 삭제'),
        content: Text('${session.templateName} 기록을 PaceLifter에서 삭제하시겠습니까?\n\n*이 작업은 PaceLifter 내부 기록만 삭제하며, Apple 건강 앱의 원본 데이터는 유지됩니다.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await WorkoutHistoryService().deleteSession(session.id);
              _loadHealthData(); // 목록 새로고침
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('PaceLifter 기록이 삭제되었습니다.')),
                );
              }
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('삭제'),
          ),
        ],
      ),
    );
  }
}

// Sticky 헤더 델리게이트
class _StickyMonthHeaderDelegate extends SliverPersistentHeaderDelegate {
  final String currentMonth;
  final Color backgroundColor;
  final VoidCallback onMonthSelectorTap;
  final VoidCallback onTitleTap; // 추가: 타이틀 터치 시 콜백

  _StickyMonthHeaderDelegate({
    required this.currentMonth,
    required this.backgroundColor,
    required this.onMonthSelectorTap,
    required this.onTitleTap,
  });

  @override
  Widget build(
      BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      color: backgroundColor,
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          GestureDetector(
            onTap: onTitleTap,
            child: const Text(
              '운동 피드',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Text(
                currentMonth,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.secondary, // Neon Green
                ),
              ),
              const SizedBox(width: 8),
              InkWell(
                onTap: onMonthSelectorTap,
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.secondary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(
                    Icons.calendar_month,
                    size: 20,
                    color: Theme.of(context).colorScheme.secondary, // Neon Green
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  double get maxExtent => 82.0;

  @override
  double get minExtent => 82.0;

  @override
  bool shouldRebuild(covariant _StickyMonthHeaderDelegate oldDelegate) {
    return currentMonth != oldDelegate.currentMonth;
  }
}

class _SyncProgressModal extends StatefulWidget {
  final VoidCallback onComplete;

  const _SyncProgressModal({required this.onComplete});

  @override
  State<_SyncProgressModal> createState() => _SyncProgressModalState();
}

class _SyncProgressModalState extends State<_SyncProgressModal> {
  String _status = 'fetching'; // fetching, analyzing, completed
  int _foundCount = 0;
  double _progress = 0.0;

  @override
  void initState() {
    super.initState();
    _runSync();
  }

  Future<void> _runSync() async {
    final healthService = HealthService();
    final historyService = WorkoutHistoryService();
    final scoringEngine = ScoringEngine();

    try {
      // Step 1: Fetching (10 years)
      setState(() => _status = 'fetching');
      final allWorkouts = await healthService.fetchWorkoutData(days: 3650);
      
      if (!mounted) return;
      setState(() {
        _foundCount = allWorkouts.length;
        _status = 'analyzing';
      });

      // Step 2: Saving & Analyzing
      // Save to local cache to ensure persistence
      int savedCount = 0;
      for (var data in allWorkouts) {
        final existing = historyService.getSessionByHealthKitId(data.uuid);
        if (existing == null) {
          final workoutData = data.value is WorkoutHealthValue ? data.value as WorkoutHealthValue : null;
          final workoutTypeName = workoutData?.workoutActivityType.name ?? 'Other';
          final formattedName = WorkoutUIUtils.formatWorkoutType(workoutTypeName);
          
          final session = WorkoutSession(
            id: const Uuid().v4(),
            templateId: '', // 기본 임포트는 템플릿 지정 없음
            category: WorkoutUIUtils.getWorkoutCategory(workoutTypeName),
            templateName: formattedName,
            startTime: data.dateFrom,
            endTime: data.dateTo,
            activeDuration: data.dateTo.difference(data.dateFrom).inSeconds,
            totalDuration: data.dateTo.difference(data.dateFrom).inSeconds,
            totalDistance: (workoutData?.totalDistance ?? 0).toDouble(),
            calories: (workoutData?.totalEnergyBurned ?? 0).toDouble(),
            healthKitWorkoutId: data.uuid,
            exerciseRecords: [],
          );
          await historyService.saveSession(session);
          savedCount++;
        }
        
        // Update progress UI slowly
        if (savedCount % 10 == 0 || savedCount == allWorkouts.length) {
          setState(() {
            _progress = (allWorkouts.indexOf(data) + 1) / allWorkouts.length;
          });
        }
      }

      // Step 3: Global Athletic Analysis
      await scoringEngine.calculateAndSaveScores();

      if (!mounted) return;
      setState(() {
        _status = 'completed';
      });
      
      widget.onComplete();
    } catch (e) {
      debugPrint('❌ Sync Process Error: $e');
      if (mounted) Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFF1C1C1E),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_status == 'fetching') ...[
              const CircularProgressIndicator(),
              const SizedBox(height: 24),
              const Text('과거 데이터 동기화 중...', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
              const SizedBox(height: 12),
              Text('과거 10년의 모든 운동 기록을\n안전하게 가져오고 있습니다.', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey[400])),
            ] else if (_status == 'analyzing') ...[
              SizedBox(
                width: 80, height: 80,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    CircularProgressIndicator(value: _progress, strokeWidth: 6),
                    Text('${(_progress * 100).toInt()}%', style: const TextStyle(fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              const Text('애슬릿 분석 진행 중', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
              const SizedBox(height: 12),
              Text('총 $_foundCount개의 기록을 기반으로\n종합 퍼포먼스를 산출하고 있습니다.', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey[400])),
            ] else ...[
              const Icon(Icons.check_circle_outline, color: Color(0xFFD4E157), size: 64),
              const SizedBox(height: 24),
              const Text('동기화 및 분석 완료!', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
              const SizedBox(height: 12),
              Text('이제 모든 과거 기록이 대시보드와\n캘린더에 완벽하게 반영되었습니다.', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey[400])),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFD4E157),
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('시작하기', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}