import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pacelifter/models/sessions/workout_session.dart';
import 'package:pacelifter/services/workout_history_service.dart';
import 'package:pacelifter/screens/workout_detail_screen.dart';
import 'package:pacelifter/models/workout_data_wrapper.dart';
import 'package:pacelifter/services/health_service.dart';
import 'package:health/health.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:fl_chart/fl_chart.dart';

class _MonthStats {
  final int enduranceDays;
  final int strengthDays;
  final int hybridDays;
  final int restDays;
  final int totalReferenceDays;

  _MonthStats({
    required this.enduranceDays,
    required this.strengthDays,
    required this.hybridDays,
    required this.restDays,
    required this.totalReferenceDays,
  });
}

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  Map<DateTime, List<WorkoutDataWrapper>> _events = {};
  final WorkoutHistoryService _historyService = WorkoutHistoryService();
  final HealthService _healthService = HealthService();
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadEvents();
  }

  Future<void> _loadEvents() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // 1. Fetch all workout data from HealthKit
      final healthData = await _healthService.fetchWorkoutData();
      
      // 2. Fetch all local sessions
      final sessions = _historyService.getAllSessions();
      
      // 3. Create a map of sessions by healthKitWorkoutId for easy lookup
      final sessionMap = <String, WorkoutSession>{};
      for (var session in sessions) {
        if (session.healthKitWorkoutId != null) {
          sessionMap[session.healthKitWorkoutId!] = session;
        }
      }

      final Map<DateTime, List<WorkoutDataWrapper>> events = {};

      // 4. Process HealthKit data
      for (var data in healthData) {
        final date = DateTime(
          data.dateFrom.year,
          data.dateFrom.month,
          data.dateFrom.day,
        );
        
        if (events[date] == null) {
          events[date] = [];
        }
        
        final linkedSession = sessionMap[data.uuid];
        events[date]!.add(WorkoutDataWrapper(healthData: data, session: linkedSession));
      }

      // 5. Process remaining local sessions (manual entries or those not in HealthKit result)
      final processedSessionIds = healthData.map((d) => sessionMap[d.uuid]?.id).toSet();
      
      for (var session in sessions) {
        if (processedSessionIds.contains(session.id)) continue;
        
        final date = DateTime(
          session.startTime.year,
          session.startTime.month,
          session.startTime.day,
        );
        
        if (events[date] == null) {
          events[date] = [];
        }
        events[date]!.add(WorkoutDataWrapper(session: session));
      }

      if (mounted) {
        setState(() {
          _events = events;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _events = {};
          _isLoading = false;
        });
      }
    }
  }

  _MonthStats _calculateMonthStats() {
    int endurance = 0;
    int strength = 0;
    int hybrid = 0;
    
    final int year = _focusedDay.year;
    final int month = _focusedDay.month;
    final int daysInMonth = DateUtils.getDaysInMonth(year, month);
    
    final now = DateTime.now();
    final bool isCurrentMonth = now.year == year && now.month == month;
    final int totalReferenceDays = isCurrentMonth ? now.day : daysInMonth;

    for (int day = 1; day <= totalReferenceDays; day++) {
      final date = DateTime(year, month, day);
      final events = _getEventsForDay(date);
      final type = _getDayType(events);
      
      if (type == 1) strength++;
      if (type == 2) endurance++;
      if (type == 3) hybrid++;
    }

    final int restDays = totalReferenceDays - (endurance + strength + hybrid);

    return _MonthStats(
      enduranceDays: endurance,
      strengthDays: strength,
      hybridDays: hybrid,
      restDays: restDays,
      totalReferenceDays: totalReferenceDays,
    );
  }

  List<WorkoutDataWrapper> _getEventsForDay(DateTime day) {
    final normalizedDay = DateTime(day.year, day.month, day.day);
    return _events[normalizedDay] ?? [];
  }

  /// Returns 0 for none, 1 for Strength, 2 for Endurance, 3 for Hybrid/Mixed
  int _getDayType(List<WorkoutDataWrapper> wrappers) {
    if (wrappers.isEmpty) return 0;

    bool hasStrength = false;
    bool hasEndurance = false;
    bool hasHybrid = false;

    for (var wrapper in wrappers) {
      String category = 'Unknown';
      if (wrapper.session != null) {
        category = wrapper.session!.category;
      } else if (wrapper.healthData != null) {
        final workout = wrapper.healthData!.value as WorkoutHealthValue;
        category = _getWorkoutCategory(workout.workoutActivityType.name);
      }

      if (category == 'Strength') hasStrength = true;
      if (category == 'Endurance') hasEndurance = true;
      if (category == 'Hybrid') hasHybrid = true;
    }

    if (hasHybrid || (hasStrength && hasEndurance)) {
      return 3;
    } else if (hasStrength) {
      return 1;
    } else if (hasEndurance) {
      return 2;
    }
    return 0;
  }

  String _getWorkoutCategory(String type) {
    final upperType = type.toUpperCase();
    if (upperType.contains('CORE') ||
        upperType.contains('FUNCTIONAL') ||
        upperType.contains('STRENGTH') ||
        upperType.contains('WEIGHT') ||
        upperType.contains('TRADITIONAL_STRENGTH_TRAINING')) {
      return 'Strength';
    } else {
      return 'Endurance';
    }
  }

  Color _getDayColor(int type, ColorScheme colorScheme) {
    switch (type) {
      case 1: // Strength
        return colorScheme.primary;
      case 2: // Endurance
        return colorScheme.secondary;
      case 3: // Hybrid
        return Color.lerp(colorScheme.primary, colorScheme.secondary, 0.5)!;
      default:
        return Colors.transparent;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        title: const Text('캘린더'),
        backgroundColor: Theme.of(context).colorScheme.surface,
        foregroundColor: Theme.of(context).colorScheme.onSurface,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadEvents,
          ),
        ],
      ),
      body: _isLoading 
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              child: Column(
                children: [
                  _buildMonthHeader(),
                  _buildSummarySection(),
                  _buildDaysOfWeekHeader(),
                  _buildCalendarGrid(),
                  if (_selectedDay != null) _buildEventList(),
                  const SizedBox(height: 32), // Bottom padding
                ],
              ),
            ),
    );
  }

  Widget _buildSummarySection() {
    final stats = _calculateMonthStats();
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      padding: const EdgeInsets.all(20.0),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(16.0),
      ),
      child: Row(
        children: [
          // Left: Pie Chart
          SizedBox(
            width: 130,
            height: 130,
            child: PieChart(
              PieChartData(
                startDegreeOffset: 270,
                sectionsSpace: 0,
                centerSpaceRadius: 35,
                sections: [
                  if (stats.enduranceDays > 0)
                    PieChartSectionData(
                      color: colorScheme.secondary,
                      value: stats.enduranceDays.toDouble(),
                      title: '',
                      radius: 20,
                      borderSide: const BorderSide(color: Colors.white, width: 0.75),
                    ),
                  if (stats.strengthDays > 0)
                    PieChartSectionData(
                      color: colorScheme.primary,
                      value: stats.strengthDays.toDouble(),
                      title: '',
                      radius: 20,
                      borderSide: const BorderSide(color: Colors.white, width: 0.75),
                    ),
                  if (stats.hybridDays > 0)
                    PieChartSectionData(
                      color: Color.lerp(colorScheme.primary, colorScheme.secondary, 0.5)!,
                      value: stats.hybridDays.toDouble(),
                      title: '',
                      radius: 20,
                      borderSide: const BorderSide(color: Colors.white, width: 0.75),
                    ),
                  // Rest days (background)
                  PieChartSectionData(
                    color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                    value: stats.restDays.toDouble(),
                    title: '',
                    radius: 20,
                    borderSide: const BorderSide(color: Colors.white, width: 0.75),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 24),
          // Right: Stats
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildStatRow('Endurance', stats.enduranceDays, colorScheme.secondary),
                const SizedBox(height: 6),
                _buildStatRow('Strength', stats.strengthDays, colorScheme.primary),
                const SizedBox(height: 6),
                _buildStatRow('Hybrid', stats.hybridDays, Color.lerp(colorScheme.primary, colorScheme.secondary, 0.5)!),
                const SizedBox(height: 6),
                _buildStatRow('Rest Day', stats.restDays, colorScheme.onSurface.withValues(alpha: 0.5), isRest: true),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatRow(String label, int days, Color color, {bool isRest = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            color: color,
            fontWeight: isRest ? FontWeight.normal : FontWeight.bold,
            fontSize: 15,
          ),
        ),
        Text(
          '$days일',
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.bold,
            fontSize: 15,
          ),
        ),
      ],
    );
  }

  Widget _buildMonthHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left),
            onPressed: () {
              setState(() {
                _focusedDay = DateTime(_focusedDay.year, _focusedDay.month - 1);
                _selectedDay = null; // Clear selection on month change
              });
            },
          ),
          Text(
            DateFormat('yyyy년 MM월').format(_focusedDay),
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right),
            onPressed: () {
              setState(() {
                _focusedDay = DateTime(_focusedDay.year, _focusedDay.month + 1);
                _selectedDay = null;
              });
            },
          ),
        ],
      ),
    );
  }

  Widget _buildDaysOfWeekHeader() {
    final days = ['일', '월', '화', '수', '목', '금', '토'];
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: days
            .map((day) => Expanded(
                  child: Center(
                    child: Text(
                      day,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ))
            .toList(),
      ),
    );
  }

  Widget _buildCalendarGrid() {
    final daysInMonth = DateUtils.getDaysInMonth(_focusedDay.year, _focusedDay.month);
    final firstDayOfMonth = DateTime(_focusedDay.year, _focusedDay.month, 1);
    final weekdayOffset = firstDayOfMonth.weekday % 7; 

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 7,
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
      ),
      itemCount: daysInMonth + weekdayOffset,
      itemBuilder: (context, index) {
        if (index < weekdayOffset) {
          return const SizedBox.shrink();
        }

        final day = index - weekdayOffset + 1;
        final date = DateTime(_focusedDay.year, _focusedDay.month, day);
        final events = _getEventsForDay(date);
        final dayType = _getDayType(events);
        final backgroundColor = _getDayColor(dayType, Theme.of(context).colorScheme);
        final isSelected = _selectedDay != null &&
            date.year == _selectedDay!.year &&
            date.month == _selectedDay!.month &&
            date.day == _selectedDay!.day;
        
        final isToday = date.year == DateTime.now().year &&
            date.month == DateTime.now().month &&
            date.day == DateTime.now().day;

        return GestureDetector(
          onTap: () {
            setState(() {
              if (isSelected) {
                 _selectedDay = null; // Toggle off
              } else {
                 _selectedDay = date;
              }
            });
          },
          child: Container(
            decoration: BoxDecoration(
              color: dayType != 0 ? backgroundColor : null,
              borderRadius: BorderRadius.circular(8),
              border: isSelected
                  ? Border.all(color: Colors.white, width: 2)
                  : (isToday && dayType == 0 ? Border.all(color: Theme.of(context).colorScheme.secondary, width: 1) : null),
            ),
            child: Center(
              child: Text(
                '$day',
                style: TextStyle(
                  color: dayType != 0 ? (dayType == 1 ? Theme.of(context).colorScheme.onPrimary : (dayType == 2 ? Theme.of(context).colorScheme.onSecondary : Colors.black)) : Theme.of(context).colorScheme.onSurface,
                  fontWeight: isToday || isSelected ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildEventList() {
    if (_selectedDay == null) return const SizedBox.shrink();

    final events = _getEventsForDay(_selectedDay!);
    
    if (events.isEmpty) {
        return Container(
          padding: const EdgeInsets.all(16),
          width: double.infinity,
          color: Theme.of(context).colorScheme.surface,
          child: const Center(child: Text("기록된 운동이 없습니다.")),
        );
    }

    return Container(
      color: Theme.of(context).colorScheme.surface,
      child: ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        itemCount: events.length,
        separatorBuilder: (context, index) => const Divider(),
        itemBuilder: (context, index) {
          final wrapper = events[index];
          return _buildEventItem(wrapper);
        },
      ),
    );
  }

  Widget _buildEventItem(WorkoutDataWrapper wrapper) {
    String title = "운동";
    String subtitle = "";
    String category = "Endurance";
    String type = "RUNNING";
    String? environmentType;

    if (wrapper.session != null) {
      title = wrapper.session!.templateName;
      category = wrapper.session!.category;
      type = category == 'Strength' ? 'TRADITIONAL_STRENGTH_TRAINING' : 'RUNNING';
      environmentType = wrapper.session!.environmentType;
      
      if (category == 'Endurance' && wrapper.session!.totalDistance != null) {
        subtitle = "${(wrapper.session!.totalDistance! / 1000).toStringAsFixed(2)}K 러닝";
      } else if (category == 'Strength') {
        subtitle = "근력 트레이닝";
      }
    } else if (wrapper.healthData != null) {
      final workout = wrapper.healthData!.value as WorkoutHealthValue;
      type = workout.workoutActivityType.name;
      category = _getWorkoutCategory(type);
      title = _formatWorkoutType(type);
      
      final distance = workout.totalDistance ?? 0;
      if (distance > 0) {
        subtitle = "${(distance / 1000).toStringAsFixed(2)}K 러닝";
      } else {
        subtitle = category == 'Strength' ? "근력 트레이닝" : "유산소 운동";
      }
    }

    final Color categoryColor = category == 'Strength' 
        ? Theme.of(context).colorScheme.primary 
        : Theme.of(context).colorScheme.secondary;

    final Color backgroundColor;
    final Color iconColor;

    final upperType = type.toUpperCase();
    if (upperType.contains('CORE') || upperType.contains('FUNCTIONAL')) {
      backgroundColor = Theme.of(context).colorScheme.primary.withValues(alpha: 0.2);
      iconColor = Theme.of(context).colorScheme.secondary;
    } else {
      backgroundColor = categoryColor.withValues(alpha: 0.2);
      iconColor = categoryColor;
    }

    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(8),
        ),
        child: _getWorkoutIconWidget(type, iconColor, environmentType: environmentType),
      ),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
      subtitle: Text(subtitle),
      onTap: () {
        _navigateToDetail(wrapper);
      },
      trailing: const Icon(Icons.chevron_right),
    );
  }

  Widget _getWorkoutIconWidget(String type, Color color, {String? environmentType}) {
    final upperType = type.toUpperCase();
    String iconPath;
    double iconSize = 24;

    if (environmentType == 'Trail') {
      return SvgPicture.asset(
        'assets/images/endurance/trail-icon.svg',
        width: iconSize,
        height: iconSize,
        colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
      );
    }

    if (upperType.contains('CORE') || upperType.contains('FUNCTIONAL')) {
      iconPath = 'assets/images/strength/core-icon.svg';
    } else if (upperType.contains('STRENGTH') ||
        upperType.contains('WEIGHT') ||
        upperType.contains('TRADITIONAL_STRENGTH_TRAINING')) {
      iconPath = 'assets/images/strength/lifter-icon.svg';
    } else {
      iconPath = 'assets/images/endurance/runner-icon.svg';
    }

    return SvgPicture.asset(
      iconPath,
      width: iconSize,
      height: iconSize,
      colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
    );
  }

  String _formatWorkoutType(String type) {
    final upperType = type.toUpperCase();
    if (upperType.contains('TRADITIONAL_STRENGTH_TRAINING')) return 'Strength 트레이닝';
    if (upperType.contains('CORE_TRAINING')) return 'Core 트레이닝';
    if (upperType.contains('RUNNING')) return 'Running';
    
    return type.replaceAll('WORKOUT_ACTIVITY_TYPE_', '').replaceAll('_', ' ');
  }

  void _navigateToDetail(WorkoutDataWrapper wrapper) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => WorkoutDetailScreen(
          dataWrapper: wrapper,
        ),
      ),
    );
  }
}
