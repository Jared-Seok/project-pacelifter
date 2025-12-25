import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pacelifter/models/sessions/workout_session.dart';
import 'package:pacelifter/services/workout_history_service.dart';
import 'package:pacelifter/screens/workout_detail_screen.dart';
import 'package:pacelifter/models/workout_data_wrapper.dart';

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  Map<DateTime, List<WorkoutSession>> _events = {};
  final WorkoutHistoryService _historyService = WorkoutHistoryService();

  @override
  void initState() {
    super.initState();
    _loadEvents();
  }

  void _loadEvents() {
    final sessions = _historyService.getAllSessions();
    final Map<DateTime, List<WorkoutSession>> events = {};

    for (var session in sessions) {
      final date = DateTime(
        session.startTime.year,
        session.startTime.month,
        session.startTime.day,
      );
      if (events[date] == null) {
        events[date] = [];
      }
      events[date]!.add(session);
    }

    setState(() {
      _events = events;
    });
  }

  List<WorkoutSession> _getEventsForDay(DateTime day) {
    final normalizedDay = DateTime(day.year, day.month, day.day);
    return _events[normalizedDay] ?? [];
  }

  /// Returns 0 for none, 1 for Strength, 2 for Endurance, 3 for Hybrid/Mixed
  int _getDayType(List<WorkoutSession> sessions) {
    if (sessions.isEmpty) return 0;

    bool hasStrength = false;
    bool hasEndurance = false;
    bool hasHybrid = false;

    for (var session in sessions) {
      if (session.category == 'Strength') hasStrength = true;
      if (session.category == 'Endurance') hasEndurance = true;
      if (session.category == 'Hybrid') hasHybrid = true;
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

  Color _getDayColor(int type, ColorScheme colorScheme) {
    switch (type) {
      case 1: // Strength
        return colorScheme.primary;
      case 2: // Endurance
        return colorScheme.secondary;
      case 3: // Hybrid
        // Intermediate value
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
        title: const Text('Calendar'),
        backgroundColor: Theme.of(context).colorScheme.surface,
        foregroundColor: Theme.of(context).colorScheme.onSurface,
        elevation: 0,
      ),
      body: Column(
        children: [
          _buildMonthHeader(),
          _buildDaysOfWeekHeader(),
          _buildCalendarGrid(),
          const SizedBox(height: 16),
          if (_selectedDay != null) _buildEventList(),
        ],
      ),
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
            DateFormat('MMMM yyyy').format(_focusedDay),
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
    final days = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];
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
    final weekdayOffset = firstDayOfMonth.weekday % 7; // Sunday is 7 in DateTime but usually 0 index in grid

    return Expanded(
      child: GridView.builder(
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

          // Determine text color based on background
          Color textColor = Theme.of(context).colorScheme.onSurface;
          if (dayType != 0) {
             if (dayType == 1) textColor = Theme.of(context).colorScheme.onPrimary;
             if (dayType == 2) textColor = Theme.of(context).colorScheme.onSecondary;
             if (dayType == 3) textColor = Colors.black; 
          }

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
                    color: textColor,
                    fontWeight: isToday || isSelected ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
              ),
            ),
          );
        },
      ),
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
          child: const Center(child: Text("No workouts recorded for this day.")),
        );
    }

    return Expanded( // Use Expanded to allow scrolling if many events
      child: Container(
        color: Theme.of(context).colorScheme.surface,
        child: ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: events.length,
          separatorBuilder: (context, index) => const Divider(),
          itemBuilder: (context, index) {
            final session = events[index];
            return _buildEventItem(session);
          },
        ),
      ),
    );
  }

  Widget _buildEventItem(WorkoutSession session) {
    String title = session.templateName;
    String subtitle = "";

    if (session.category == 'Endurance' && session.totalDistance != null) {
      subtitle = "${(session.totalDistance! / 1000).toStringAsFixed(2)}K Run";
    } else if (session.category == 'Strength') {
      subtitle = "Strength Training";
    } else {
      subtitle = session.category;
    }

    Color iconColor;
    if (session.category == 'Strength') {
      iconColor = Theme.of(context).colorScheme.primary;
    } else if (session.category == 'Endurance') {
      iconColor = Theme.of(context).colorScheme.secondary;
    } else {
      iconColor = Color.lerp(Theme.of(context).colorScheme.primary, Theme.of(context).colorScheme.secondary, 0.5)!;
    }

    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: iconColor.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(
          session.category == 'Endurance' ? Icons.directions_run : Icons.fitness_center,
          color: iconColor,
        ),
      ),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
      subtitle: Text(subtitle),
      onTap: () {
        _navigateToDetail(session);
      },
      trailing: const Icon(Icons.chevron_right),
    );
  }

  void _navigateToDetail(WorkoutSession session) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => WorkoutDetailScreen(
          dataWrapper: WorkoutDataWrapper(session: session),
        ),
      ),
    );
  }
}