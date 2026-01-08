import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'endurance_template_screen.dart';
import 'workout_setup_screen.dart';
import '../services/template_service.dart';

/// Endurance 운동 환경 선택 화면 (로드/실내/트레일)
class EnduranceEnvironmentScreen extends StatelessWidget {
  const EnduranceEnvironmentScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        title: const Text('지구력 훈련 (Endurance)'),
        backgroundColor: Theme.of(context).colorScheme.surface,
        foregroundColor: Theme.of(context).colorScheme.onSurface,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                '운동 환경',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '어디서 달리실 건가요?',
                style: TextStyle(
                  fontSize: 14,
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                ),
              ),
              const SizedBox(height: 24),
              // 1. 로드 (Road) -> Outdoor
              _buildEnvironmentCard(
                context: context,
                title: '로드 러닝',
                subtitle: '도로 및 야외에서의 일반적인 러닝',
                iconPath: 'assets/images/endurance/runner-icon.svg',
                color: Theme.of(context).colorScheme.tertiary, // Deep Teal
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const EnduranceTemplateScreen(
                        environmentType: 'Outdoor',
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 16),
              // 2. 실내 (Indoor) -> Indoor
              _buildEnvironmentCard(
                context: context,
                title: '실내 러닝',
                subtitle: '트레드밀 및 실내 트랙 (Treadmill)',
                iconPath: 'assets/images/endurance/runner-icon.svg',
                color: Theme.of(context).colorScheme.tertiary, // Deep Teal
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const EnduranceTemplateScreen(
                        environmentType: 'Indoor',
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 16),
              // 3. 트레일 (Trail) -> Trail (최하단 배치 및 즉시 설정 화면 진입)
              _buildEnvironmentCard(
                context: context,
                title: '트레일 러닝',
                subtitle: '산악 및 비포장 도로 (산악 달리기)',
                iconPath: 'assets/images/endurance/trail-icon.svg',
                color: Theme.of(context).colorScheme.tertiary, // Deep Teal
                onTap: () {
                  // 트레일은 템플릿이 1개이므로 즉시 설정 화면으로 이동
                  final template = TemplateService.getTemplateById('endurance_trail_basic');
                  if (template != null) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => WorkoutSetupScreen(
                          template: template,
                        ),
                      ),
                    );
                  } else {
                    // 템플릿 로드 실패 시 기본 화면으로 폴백 (안전 장치)
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const EnduranceTemplateScreen(
                          environmentType: 'Trail',
                        ),
                      ),
                    );
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEnvironmentCard({
    required BuildContext context,
    required String title,
    required String subtitle,
    required String iconPath,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: color.withValues(alpha: 0.3),
            width: 2,
          ),
        ),
        child: Row(
          children: [
            // 아이콘
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: SvgPicture.asset(
                iconPath,
                width: 32,
                height: 32,
                colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
              ),
            ),
            const SizedBox(width: 20),
            // 텍스트 정보
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
            // 화살표 아이콘
            Icon(
              Icons.arrow_forward_ios,
              color: color,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}
