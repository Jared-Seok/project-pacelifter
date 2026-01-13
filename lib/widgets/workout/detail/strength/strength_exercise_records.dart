import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../../../models/sessions/workout_session.dart';
import '../../../../models/sessions/exercise_record.dart';
import '../../../../services/template_service.dart';

/// 근력 운동 종목 및 세트 상세 기록 리스트 위젯 (아이콘 고도화 및 편집 기능 포함)
class StrengthExerciseRecords extends StatelessWidget {
  final WorkoutSession session;
  final Color themeColor;
  final Function(ExerciseRecord) onEditRecord;
  final VoidCallback onAddExercise; // 추가 콜백

  const StrengthExerciseRecords({
    super.key,
    required this.session,
    required this.themeColor,
    required this.onEditRecord,
    required this.onAddExercise,
  });

  @override
  Widget build(BuildContext context) {
    final records = session.exerciseRecords;
    if (records == null) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),
        ...records.map((record) => _buildRecordCard(context, record)),
        
        // ➕ 리스트 마지막에 종목 추가 버튼 배치
        _buildAddMoreButton(context),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildAddMoreButton(BuildContext context) {
    return InkWell(
      onTap: onAddExercise,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          border: Border.all(color: themeColor.withValues(alpha: 0.3)),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.add_circle_outline, color: themeColor, size: 20),
            const SizedBox(width: 8),
            Text('다른 운동 추가하기', style: TextStyle(color: themeColor, fontWeight: FontWeight.bold, fontSize: 14)),
          ],
        ),
      ),
    );
  }

  Widget _buildRecordCard(BuildContext context, ExerciseRecord record) {
    // 💡 동적 아이콘 매핑: 라이브러리에서 운동 정보를 찾아 커스텀 아이콘 확인
    final exercise = TemplateService.getExerciseById(record.exerciseId);
    final String iconPath = exercise?.imagePath ?? 'assets/images/strength/lifter-icon.svg';

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ExpansionTile(
        initiallyExpanded: false, // 요약 바닥글과 통합되었으므로 기본은 닫힘 권장
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: themeColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: SvgPicture.asset(
            iconPath,
            width: 24,
            height: 24,
            fit: BoxFit.contain,
            colorFilter: ColorFilter.mode(themeColor, BlendMode.srcIn),
          ),
        ),
        title: Text(
          record.exerciseName, 
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)
        ),
        subtitle: Text(
          '${record.sets.length} 세트 | 총 ${record.totalVolume >= 1000 ? "${(record.totalVolume / 1000).toStringAsFixed(2)} t" : "${record.totalVolume.toStringAsFixed(0)} kg"}',
          style: const TextStyle(fontSize: 12, color: Colors.grey),
        ),
        trailing: IconButton(
          icon: const Icon(Icons.edit_note, size: 22),
          color: themeColor.withValues(alpha: 0.7),
          onPressed: () => onEditRecord(record), // 편집 모드 진입
        ),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Column(
              children: [
                const Divider(),
                _buildTableHeader(),
                const SizedBox(height: 8),
                ...record.sets.asMap().entries.map((entry) => _buildSetRow(entry.key, entry.value)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTableHeader() {
    return const Row(
      children: [
        SizedBox(width: 40, child: Text('SET', style: TextStyle(fontSize: 11, color: Colors.grey))),
        Expanded(child: Text('무게', textAlign: TextAlign.center, style: TextStyle(fontSize: 11, color: Colors.grey))),
        Expanded(child: Text('횟수', textAlign: TextAlign.center, style: TextStyle(fontSize: 11, color: Colors.grey))),
      ],
    );
  }

  Widget _buildSetRow(int index, SetRecord set) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        children: [
          SizedBox(
            width: 40,
            child: Text('${index + 1}', textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.bold)),
          ),
          Expanded(
            child: Text(
              '${set.weight?.toStringAsFixed(1).replaceAll(RegExp(r'\.0$'), '') ?? 0} kg',
              textAlign: TextAlign.center,
            ),
          ),
          Expanded(
            child: Text(
              '${set.repsCompleted ?? set.repsTarget ?? 0} 회',
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }
}
