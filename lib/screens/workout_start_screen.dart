import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'endurance_environment_screen.dart';
import 'strength_template_screen.dart';
import 'hybrid_template_screen.dart';

/// 운동 시작 화면 (Bento Grid Layout)
///
/// 상단: Endurance (1) : Strength (1) 비율로 배치
/// 하단: Hybrid 배치
class WorkoutStartScreen extends StatefulWidget {
  const WorkoutStartScreen({super.key});

  @override
  State<WorkoutStartScreen> createState() => _WorkoutStartScreenState();
}

enum WorkoutType { none, endurance, strength, hybrid }

class _WorkoutStartScreenState extends State<WorkoutStartScreen> {
  void _selectWorkoutType(WorkoutType type) {
    if (type == WorkoutType.endurance) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => const EnduranceEnvironmentScreen(),
        ),
      );
    } else if (type == WorkoutType.strength) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => const StrengthTemplateScreen(),
        ),
      );
    } else if (type == WorkoutType.hybrid) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => const HybridTemplateScreen(),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        title: const Text('운동 시작'),
        backgroundColor: Theme.of(context).colorScheme.surface,
        foregroundColor: Theme.of(context).colorScheme.onSurface,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // 상단 Row: Endurance (1) : Strength (1)
            Expanded(
              flex: 3,
              child: Row(
                children: [
                  Expanded(
                    child: _buildBentoCard(
                      type: WorkoutType.endurance,
                      title: 'Endurance',
                      subtitle: '러닝 & 지구력',
                      iconPath: 'assets/images/endurance/runner-icon.svg',
                      color: Theme.of(context).colorScheme.secondary,
                      backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildBentoCard(
                      type: WorkoutType.strength,
                      title: 'Strength',
                      subtitle: '웨이트 & 근력',
                      iconPath: 'assets/images/strength/lifter-icon.svg',
                      color: Theme.of(context).colorScheme.primary,
                      backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            // 하단: Hybrid
            Expanded(
              flex: 2,
              child: _buildBentoCard(
                type: WorkoutType.hybrid,
                title: 'Hybrid',
                subtitle: 'Endurance + Strength 복합 훈련',
                iconPath: 'assets/images/pllogo.svg',
                color: Color.lerp(Theme.of(context).colorScheme.primary, Theme.of(context).colorScheme.secondary, 0.5)!,
                backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                iconSize: 56,
                isHorizontal: true, // 가로형 레이아웃
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBentoCard({
    required WorkoutType type,
    required String title,
    required String subtitle,
    required String iconPath,
    required Color color,
    required Color backgroundColor,
    double iconSize = 64,
    bool isHorizontal = false,
  }) {
    return GestureDetector(
      onTap: () => _selectWorkoutType(type),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(24), // 둥근 모서리 강화
          border: Border.all(
            color: color.withValues(alpha: 0.1),
            width: 1,
          ),
        ),
        child: isHorizontal
            ? Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _buildIcon(iconPath, color, iconSize),
                  const SizedBox(width: 24),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: color,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          subtitle,
                          style: TextStyle(
                            fontSize: 16,
                            color: Theme.of(context)
                                .colorScheme
                                .onSurface
                                .withValues(alpha: 0.7),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    Icons.arrow_forward_ios,
                    color: color.withValues(alpha: 0.5),
                  ),
                ],
              )
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _buildIcon(iconPath, color, iconSize),
                  const SizedBox(height: 24),
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    subtitle,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withValues(alpha: 0.7),
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildIcon(String iconPath, Color color, double size) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        shape: BoxShape.circle,
      ),
      child: SvgPicture.asset(
        iconPath,
        width: size,
        height: size,
        colorFilter: ColorFilter.mode(
          color,
          BlendMode.srcIn,
        ),
      ),
    );
  }
}
