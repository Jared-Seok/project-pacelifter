import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../../models/sessions/workout_session.dart';
import '../../../../models/sessions/exercise_record.dart';
import '../../../../providers/workout_detail_provider.dart';
import '../strength/strength_exercise_records.dart';

/// 운동 카테고리에 최적화된 핵심 지표 그리드 위젯 (UI 통합 및 최적화 버전)
class WorkoutMetricsGrid extends StatefulWidget {
  final WorkoutDetailProvider provider;
  final String category;
  final Color themeColor;
  final Function(ExerciseRecord)? onEditRecord;
  final VoidCallback onAddExercise;

  const WorkoutMetricsGrid({
    super.key,
    required this.provider,
    required this.category,
    required this.themeColor,
    this.onEditRecord,
    required this.onAddExercise,
  });

  @override
  State<WorkoutMetricsGrid> createState() => _WorkoutMetricsGridState();
}

class _WorkoutMetricsGridState extends State<WorkoutMetricsGrid> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    final wrapper = widget.provider.dataWrapper;
    final session = widget.provider.session;
    final hasRecords = session != null && session.exerciseRecords != null && session.exerciseRecords!.isNotEmpty;

    return Card(
      child: Column(
        children: [
          // 1. 상단 액션/요약 패널
          if (widget.category == 'Strength' || widget.category == 'Hybrid')
            _buildStrengthActionPanel(context, session, hasRecords)
          else
            _buildDefaultHeader(),

          // 2. 확장 상세 기록
          if ((widget.category == 'Strength' || widget.category == 'Hybrid') && _isExpanded && hasRecords)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: StrengthExerciseRecords(
                session: session!,
                themeColor: widget.themeColor,
                onEditRecord: (record) => widget.onEditRecord?.call(record),
                onAddExercise: widget.onAddExercise, // 추가 버튼 콜백 연결
              ),
            ),

          const Divider(height: 1),

          // 3. 공통 지표 섹션
          _buildCommonMetrics(wrapper),
        ],
      ),
    );
  }

  Widget _buildStrengthActionPanel(BuildContext context, WorkoutSession? session, bool hasRecords) {
    if (!hasRecords) {
      // 🟢 시나리오 B: 기록이 없는 경우
      return InkWell(
        onTap: widget.onAddExercise,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [widget.themeColor.withValues(alpha: 0.15), widget.themeColor.withValues(alpha: 0.05)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
          ),
          child: Column(
            children: [
              Icon(Icons.post_add_rounded, size: 40, color: widget.themeColor),
              const SizedBox(height: 12),
              const Text('운동 정보가 부족합니다', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Text('여기를 눌러 수행하신 종목을 기록하세요', style: TextStyle(fontSize: 12, color: widget.themeColor.withValues(alpha: 0.8))),
            ],
          ),
        ),
      );
    }

    // 🟠 시나리오 A: 이미 기록이 있는 경우 (통합형)
    return InkWell(
      onTap: () => setState(() => _isExpanded = !_isExpanded),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 24, 16, 16),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(child: _buildStrengthSummary(context, session!)),
                Icon(
                  _isExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                  color: widget.themeColor,
                ),
              ],
            ),
            const SizedBox(height: 16),
            // 통합된 안내 문구 및 추가 버튼 역할
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  _isExpanded ? '상세 기록 닫기' : '상세 기록 보기 및 종목 추가',
                  style: TextStyle(fontSize: 12, color: widget.themeColor, fontWeight: FontWeight.w600),
                ),
                if (!_isExpanded) ...[
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: () {
                      // 종목 추가 실행
                      widget.onAddExercise();
                    },
                    child: Icon(Icons.add_circle_outline, size: 16, color: widget.themeColor),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDefaultHeader() {
    return const Padding(
      padding: EdgeInsets.all(16.0),
      child: Text('운동 데이터', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
    );
  }

  Widget _buildCommonMetrics(dynamic wrapper) {
    final dateFrom = wrapper.dateFrom;
    final dateTo = wrapper.dateTo;
    final dateStr = DateFormat('yyyy년 MM월 dd일').format(dateFrom);
    final timeRangeStr = '${DateFormat('HH:mm').format(dateFrom)} ~ ${DateFormat('HH:mm').format(dateTo)}';

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          _buildMetricItem(Icons.play_circle_outline, '운동 시간', _formatDuration(widget.provider.activeDuration ?? dateTo.difference(dateFrom))),
          const Divider(height: 24),
          _buildMetricItem(Icons.access_time, '날짜 및 시간', '$dateStr\n$timeRangeStr'),
          const Divider(height: 24),
          _buildMetricItem(Icons.local_fire_department, '소모 칼로리', '${wrapper.calories.toStringAsFixed(0)} kcal'),
          if (widget.provider.avgHeartRate > 0) ...[
            const Divider(height: 24),
            _buildMetricItem(Icons.favorite, '평균 심박수', '${widget.provider.avgHeartRate.toStringAsFixed(1)} BPM'),
          ],
          // 유산소 지표(페이스, 케이던스, 고도)는 EnduranceDashboard에서 담당하므로 여기서는 제거
        ],
      ),
    );
  }

  Widget _buildStrengthSummary(BuildContext context, WorkoutSession session) {
    final vol = session.totalVolume ?? 0;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: [
        _buildSummaryStat(context, '총 볼륨', vol >= 1000 ? '${(vol / 1000).toStringAsFixed(2)}t' : '${vol.toInt()}kg'),
        _buildSummaryStat(context, '총 세트', '${session.totalSets ?? 0}'),
        _buildSummaryStat(context, '총 횟수', '${session.totalReps ?? 0}'),
      ],
    );
  }

  Widget _buildSummaryStat(BuildContext context, String label, String value) {
    return Column(
      children: [
        Text(label, style: TextStyle(fontSize: 11, color: Colors.grey[500], fontWeight: FontWeight.w500)),
        const SizedBox(height: 6),
        Text(value, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: widget.themeColor, letterSpacing: -0.5)),
      ],
    );
  }

  Widget _buildMetricItem(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 22, color: Colors.grey[600]),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
              const SizedBox(height: 2),
              Text(value, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500)),
            ],
          ),
        ),
      ],
    );
  }

  String _formatDuration(Duration d) {
    final hours = d.inHours;
    final minutes = d.inMinutes.remainder(60);
    final seconds = d.inSeconds.remainder(60);
    if (hours > 0) return '$hours시간 $minutes분 $seconds초';
    return '$minutes분 $seconds초';
  }

  String _formatPace(double pace) {
    final minutes = pace.floor();
    final seconds = ((pace - minutes) * 60).round();
    return "$minutes'${seconds.toString().padLeft(2, '0')}\"/km";
  }
}