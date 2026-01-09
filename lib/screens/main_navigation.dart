import 'package:flutter/material.dart';
import 'package:pacelifter/screens/dashboard_screen.dart';
import 'package:pacelifter/screens/workout_start_screen.dart';
import 'package:pacelifter/screens/athlete_screen.dart';
import 'package:pacelifter/screens/settings_screen.dart';
import 'package:pacelifter/screens/calendar_screen.dart';

/// 메인 네비게이션 화면 (중앙 강조 리디자인 버전)
class MainNavigation extends StatefulWidget {
  const MainNavigation({super.key});

  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation> {
  int _currentIndex = 0;

  final List<Widget> _screens = [
    const DashboardScreen(),
    const CalendarScreen(),
    const WorkoutStartScreen(),
    const AthleteScreen(),
    const SettingsScreen(),
  ];

  // Brand Color (Hybrid & UI Core)
  Color get brandColor => Theme.of(context).colorScheme.primary;

  void _onTabTapped(int index) {
    setState(() {
      _currentIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: _buildCustomBottomBar(),
    );
  }

  Widget _buildCustomBottomBar() {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(
          top: BorderSide(
            color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.1),
            width: 0.5,
          ),
        ),
      ),
      child: SafeArea(
        child: Container(
          height: 64,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildNavItem(0, Icons.dashboard, '대시보드'),
              _buildNavItem(1, Icons.calendar_month, '캘린더'),
              _buildCenterNavItem(2, Icons.play_circle_filled, '운동 시작'),
              _buildNavItem(3, Icons.person_outline, '애슬릿'),
              _buildNavItem(4, Icons.settings_outlined, '설정'),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(int index, IconData icon, String label) {
    final bool isSelected = _currentIndex == index;
    final Color activeColor = brandColor;
    final Color inactiveColor = Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5);

    return Expanded(
      child: InkWell(
        onTap: () => _onTabTapped(index),
        splashColor: Colors.transparent,
        highlightColor: Colors.transparent,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              color: isSelected ? activeColor : inactiveColor,
              size: 24,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                color: isSelected ? activeColor : inactiveColor,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCenterNavItem(int index, IconData icon, String label) {
    final bool isSelected = _currentIndex == index;
    
    return Expanded(
      child: InkWell(
        onTap: () => _onTabTapped(index),
        splashColor: Colors.transparent,
        highlightColor: Colors.transparent,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: brandColor.withValues(alpha: 0.15),
                shape: BoxShape.circle,
                boxShadow: isSelected ? [
                  BoxShadow(
                    color: brandColor.withValues(alpha: 0.3),
                    blurRadius: 10,
                    spreadRadius: 1,
                  )
                ] : null,
              ),
              child: Icon(
                icon,
                color: brandColor,
                size: 28,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                color: brandColor,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}