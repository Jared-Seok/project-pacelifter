import 'package:flutter/material.dart';
import 'workout_setup_screen.dart';

/// 환경별 세부 훈련 템플릿 선택 화면
class EnduranceTemplateScreen extends StatelessWidget {
  final String environmentType;

  const EnduranceTemplateScreen({
    super.key,
    required this.environmentType,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        title: Text(environmentType),
        backgroundColor: Theme.of(context).colorScheme.surface,
        foregroundColor: Theme.of(context).colorScheme.onSurface,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '훈련 템플릿 선택',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '$environmentType 환경에 맞는 훈련을 선택하세요',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[600],
                ),
              ),
              const SizedBox(height: 24),
              _buildTemplateCard(
                context: context,
                title: '훈련 템플릿 1',
                subtitle: 'LSD (Long Slow Distance)',
                description: '낮은 강도로 장거리 달리기',
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => WorkoutSetupScreen(
                        environmentType: environmentType,
                        templateName: '훈련 템플릿 1',
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 12),
              _buildTemplateCard(
                context: context,
                title: '훈련 템플릿 2',
                subtitle: '인터벌 트레이닝',
                description: '고강도와 저강도 반복',
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => WorkoutSetupScreen(
                        environmentType: environmentType,
                        templateName: '훈련 템플릿 2',
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 12),
              _buildTemplateCard(
                context: context,
                title: '훈련 템플릿 3',
                subtitle: '템포 런',
                description: '중간 강도로 일정 페이스 유지',
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => WorkoutSetupScreen(
                        environmentType: environmentType,
                        templateName: '훈련 템플릿 3',
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTemplateCard({
    required BuildContext context,
    required String title,
    required String subtitle,
    required String description,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: Theme.of(context).colorScheme.outline.withOpacity(0.2),
            width: 1,
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    description,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios,
              color: Theme.of(context).colorScheme.primary,
              size: 16,
            ),
          ],
        ),
      ),
    );
  }
}
