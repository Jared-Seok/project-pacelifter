import 'package:flutter/material.dart';

/// 근력 운동 정보가 없을 때 보강을 유도하는 카드 위젯
class StrengthEnrichmentCard extends StatelessWidget {
  final Color themeColor;
  final VoidCallback onActionTap;

  const StrengthEnrichmentCard({
    super.key,
    required this.themeColor,
    required this.onActionTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: themeColor.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: themeColor.withValues(alpha: 0.2)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Icon(Icons.lightbulb_outline, color: themeColor, size: 20),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  '수행한 운동 종목을 기록해 보세요',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            '종목 정보를 추가하면 정밀한 퍼포먼스 분석과 근력 점수 산출이 가능해집니다.',
            style: TextStyle(fontSize: 12, color: Colors.grey),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: onActionTap,
              icon: const Icon(Icons.add_task),
              label: const Text('운동 종목 추가하기'),
              style: ElevatedButton.styleFrom(
                backgroundColor: themeColor,
                foregroundColor: Colors.black,
                elevation: 0,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
