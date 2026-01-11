import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// 운동 종료 직후 축하 메시지와 점수를 보여주는 레이어
class WorkoutResultOverlay extends StatelessWidget {
  final Color themeColor;
  final VoidCallback onShareTap;

  const WorkoutResultOverlay({
    super.key,
    required this.themeColor,
    required this.onShareTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [themeColor, themeColor.withValues(alpha: 0.7)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: themeColor.withValues(alpha: 0.3),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          const Icon(Icons.stars_rounded, color: Colors.black, size: 48),
          const SizedBox(height: 12),
          Text(
            '운동 완료!',
            style: GoogleFonts.anton(fontSize: 28, color: Colors.black, letterSpacing: 1.5),
          ),
          const SizedBox(height: 8),
          const Text(
            '오늘도 한계를 넘으셨군요.\n분석 결과가 곧 퍼포먼스에 반영됩니다.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.black87, fontWeight: FontWeight.w500, fontSize: 14),
          ),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: onShareTap,
            icon: const Icon(Icons.ios_share_rounded, size: 18),
            label: const Text('기록 공유하기'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.black,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ],
      ),
    );
  }
}
