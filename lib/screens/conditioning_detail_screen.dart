import 'package:flutter/material.dart';
import '../models/scoring/performance_scores.dart';

class ConditioningDetailScreen extends StatelessWidget {
  final PerformanceScores scores;

  const ConditioningDetailScreen({super.key, required this.scores});

  @override
  Widget build(BuildContext context) {
    final secondaryColor = Theme.of(context).colorScheme.secondary;

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        title: const Text('컨디셔닝 세부 분석'),
        backgroundColor: Theme.of(context).colorScheme.surface,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionHeader('훈련 부하 분석 (ACWR)', Icons.analytics),
            const SizedBox(height: 16),
            _buildACWRCard(context, scores.acwr),
            const SizedBox(height: 32),
            
            _buildSectionHeader('생체 지표 분석', Icons.favorite_border),
            const SizedBox(height: 16),
            _buildBioMetricCard(
              context,
              title: '안정 시 심박수 (RHR)',
              value: scores.avgRestingHeartRate != null ? '${scores.avgRestingHeartRate!.toInt()} BPM' : '데이터 없음',
              description: '안정 시 심박수가 낮을수록 심폐 효율과 회복력이 좋음을 의미합니다.',
              icon: Icons.favorite,
              color: Colors.redAccent,
            ),
            const SizedBox(height: 16),
            _buildBioMetricCard(
              context,
              title: '심박 변이도 (HRV)',
              value: scores.avgHRV != null ? '${scores.avgHRV!.toInt()} ms' : '데이터 없음',
              description: 'HRV가 높을수록 자율신경계가 안정적이며 고강도 훈련을 소화할 준비가 되었음을 나타냅니다.',
              icon: Icons.electric_bolt,
              color: Colors.orangeAccent,
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, color: Colors.grey, size: 20),
        const SizedBox(width: 8),
        Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _buildACWRCard(BuildContext context, num acwr) {
    final color = _getACWRColor(context, acwr);
    final String status = _getACWRStatus(acwr);
    final String description = _getACWRDescription(acwr);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Text(
              acwr.toStringAsFixed(2),
              style: TextStyle(fontSize: 48, fontWeight: FontWeight.w900, color: color),
            ),
            Text(
              status,
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color),
            ),
            const SizedBox(height: 24),
            // 범위 시각화 바
            _buildACWRVisualizer(context, acwr),
            const SizedBox(height: 24),
            Text(
              description,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 14, color: Colors.white70, height: 1.5),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildACWRVisualizer(BuildContext context, num acwr) {
    final secondaryColor = Theme.of(context).colorScheme.secondary;
    return Column(
      children: [
        Stack(
          children: [
            Container(
              height: 12,
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.white10,
                borderRadius: BorderRadius.circular(6),
              ),
            ),
            // 최적 범위 표시 (0.8 ~ 1.3)
            Positioned(
              left: (MediaQuery.of(context).size.width - 88) * (0.8 / 2.0),
              child: Container(
                height: 12,
                width: (MediaQuery.of(context).size.width - 88) * (0.5 / 2.0),
                decoration: BoxDecoration(
                  color: secondaryColor.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            // 현재 지점 표시
            Positioned(
              left: (MediaQuery.of(context).size.width - 88) * (acwr.toDouble().clamp(0.0, 2.0) / 2.0),
              child: Container(
                height: 12,
                width: 4,
                decoration: BoxDecoration(
                  color: secondaryColor,
                  borderRadius: BorderRadius.circular(2),
                  boxShadow: [BoxShadow(color: Colors.black, blurRadius: 4)],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('0.0', style: TextStyle(fontSize: 10, color: Colors.grey)),
            Text('Sweet Spot (0.8-1.3)', style: TextStyle(fontSize: 10, color: secondaryColor, fontWeight: FontWeight.bold)),
            const Text('2.0+', style: TextStyle(fontSize: 10, color: Colors.grey)),
          ],
        ),
      ],
    );
  }

  Widget _buildBioMetricCard(BuildContext context, {
    required String title,
    required String value,
    required String description,
    required IconData icon,
    required Color color,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontSize: 14, color: Colors.grey)),
                  const SizedBox(height: 4),
                  Text(value, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Text(description, style: const TextStyle(fontSize: 12, color: Colors.white60, height: 1.4)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _getACWRColor(BuildContext context, num acwr) {
    return Theme.of(context).colorScheme.secondary;
  }

  String _getACWRStatus(num acwr) {
    if (acwr < 0.8) return "훈련량 부족";
    if (acwr <= 1.3) return "최적의 컨디션";
    if (acwr <= 1.5) return "과도한 훈련 부하";
    return "부상 위험 매우 높음";
  }

  String _getACWRDescription(num acwr) {
    if (acwr < 0.8) return "평소보다 훈련량이 적습니다. 신체 능력이 정체될 수 있으니 점진적으로 강도를 높여보세요.";
    if (acwr <= 1.3) return "현재 부상 위험이 낮으면서도 체력이 가장 효율적으로 향상되는 'Sweet Spot'에 있습니다.";
    if (acwr <= 1.5) return "훈련량이 급격히 늘어났습니다. 피로가 쌓이기 쉬우므로 컨디션 모니터링이 필요합니다.";
    return "부상 위험이 매우 높은 상태입니다. 즉시 훈련 강도를 낮추고 충분한 휴식을 취하십시오.";
  }
}
