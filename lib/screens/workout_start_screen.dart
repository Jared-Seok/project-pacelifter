import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'endurance_environment_screen.dart';

/// 운동 시작 화면
///
/// 좌측: Endurance (러닝), 우측: Strength (웨이트)
/// 각 섹션 선택 시 해당 훈련 템플릿 화면으로 전환
class WorkoutStartScreen extends StatefulWidget {
  const WorkoutStartScreen({super.key});

  @override
  State<WorkoutStartScreen> createState() => _WorkoutStartScreenState();
}

enum WorkoutType { none, endurance, strength }

class _WorkoutStartScreenState extends State<WorkoutStartScreen> {
  WorkoutType _selectedType = WorkoutType.none;

  void _selectWorkoutType(WorkoutType type) {
    if (type == WorkoutType.endurance) {
      // Endurance 선택 시 바로 환경 선택 화면으로 이동
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => const EnduranceEnvironmentScreen(),
        ),
      );
    } else {
      // Strength는 기존 방식대로 상태 변경
      setState(() {
        _selectedType = type;
      });
    }
  }

  void _goBack() {
    setState(() {
      _selectedType = WorkoutType.none;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        title: Text(_selectedType == WorkoutType.none
            ? '운동 시작'
            : 'Strength'),
        backgroundColor: Theme.of(context).colorScheme.surface,
        foregroundColor: Theme.of(context).colorScheme.onSurface,
        leading: _selectedType != WorkoutType.none
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: _goBack,
              )
            : null,
      ),
      body: _selectedType == WorkoutType.none
          ? _buildSelectionScreen()
          : _buildStrengthTemplateScreen(),
    );
  }

  /// 초기 선택 화면: 좌측 Endurance, 우측 Strength
  Widget _buildSelectionScreen() {
    return Row(
      children: [
        // 좌측: Endurance 섹션
        Expanded(
          child: GestureDetector(
            onTap: () => _selectWorkoutType(WorkoutType.endurance),
            child: Container(
              color: Colors.transparent,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SvgPicture.asset(
                    'assets/images/runner-icon.svg',
                    width: 120,
                    height: 120,
                    colorFilter: ColorFilter.mode(
                      Theme.of(context).colorScheme.secondary,
                      BlendMode.srcIn,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Endurance',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.secondary,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        // 중앙: 구분 바 (fade-out 효과)
        _buildDividerBar(),
        // 우측: Strength 섹션
        Expanded(
          child: GestureDetector(
            onTap: () => _selectWorkoutType(WorkoutType.strength),
            child: Container(
              color: Colors.transparent,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SvgPicture.asset(
                    'assets/images/lifter-icon.svg',
                    width: 132,
                    height: 132,
                    colorFilter: ColorFilter.mode(
                      Theme.of(context).colorScheme.primary,
                      BlendMode.srcIn,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Strength',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// 중앙 구분 바 위젯 (fade-out 효과 적용, 상하 색상 분리)
  Widget _buildDividerBar() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final screenHeight = MediaQuery.of(context).size.height;
        final appBarHeight = kToolbarHeight + MediaQuery.of(context).padding.top;
        final availableHeight = screenHeight - appBarHeight;
        final barHeight = availableHeight * 0.5; // 화면의 50% 높이

        return SizedBox(
          width: 2,
          height: barHeight,
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  // 상단: secondary color (밝은 카키색)
                  Theme.of(context).colorScheme.secondary.withOpacity(0.0),
                  Theme.of(context).colorScheme.secondary.withOpacity(0.4),
                  Theme.of(context).colorScheme.secondary.withOpacity(0.4),
                  // 중심에서 색상 전환
                  Theme.of(context).colorScheme.primary.withOpacity(0.4),
                  Theme.of(context).colorScheme.primary.withOpacity(0.4),
                  // 하단: primary color
                  Theme.of(context).colorScheme.primary.withOpacity(0.0),
                ],
                stops: const [0.0, 0.2, 0.49, 0.51, 0.8, 1.0],
              ),
            ),
          ),
        );
      },
    );
  }

  /// Strength 템플릿 (웨이트) - 추후 구현
  Widget _buildStrengthTemplateScreen() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SvgPicture.asset(
              'assets/images/lifter-icon.svg',
              width: 100,
              height: 100,
              colorFilter: ColorFilter.mode(
                Theme.of(context).colorScheme.primary,
                BlendMode.srcIn,
              ),
            ),
            const SizedBox(height: 32),
            Text(
              'Strength 템플릿',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              '추후 구현 예정',
              style: TextStyle(
                fontSize: 18,
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '웨이트 트레이닝 템플릿 기능이\n추가될 예정입니다.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
