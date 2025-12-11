import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'endurance_template_screen.dart';

/// Endurance 운동 환경 선택 화면 (로드/트레일/트레드밀)
class EnduranceEnvironmentScreen extends StatelessWidget {
  const EnduranceEnvironmentScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        title: const Text('Endurance'),
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
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '운동 환경을 선택하세요',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '운동할 환경에 맞는 템플릿을 선택해주세요',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[600],
                ),
              ),
              const SizedBox(height: 24),
              _buildEnvironmentCard(
                context: context,
                title: '로드',
                subtitle: '실외 로드 및 트랙 러닝',
                iconPath: 'assets/images/runner-icon.svg',
                color: Theme.of(context).colorScheme.secondary,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const EnduranceTemplateScreen(
                        environmentType: '로드',
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 16),
              _buildEnvironmentCard(
                context: context,
                title: '트레일',
                subtitle: '산악 및 오프로드 러닝',
                iconPath: 'assets/images/trail-icon.svg',
                color: Colors.green,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const EnduranceTemplateScreen(
                        environmentType: '트레일',
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 16),
              _buildEnvironmentCard(
                context: context,
                title: '트레드밀',
                subtitle: '실내 러닝머신 운동',
                iconPath: 'assets/images/runner-icon.svg',
                color: Colors.orange,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const EnduranceTemplateScreen(
                        environmentType: '트레드밀',
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
            color: color.withOpacity(0.3),
            width: 2,
          ),
        ),
        child: Row(
          children: [
            // 아이콘
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: SvgPicture.asset(
                iconPath,
                width: 48,
                height: 48,
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
