import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../models/scoring/performance_scores.dart';
import '../services/scoring_engine.dart';
import 'conditioning_detail_screen.dart';

class PerformanceAnalysisScreen extends StatelessWidget {
  final PerformanceScores scores;

  const PerformanceAnalysisScreen({super.key, required this.scores});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: CustomScrollView(
        slivers: [
          // 1. 애니메이션 헤더
          _buildSliverAppBar(context),
          
          // 2. 상세 리포트 내용
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildCoachingSummary(context),
                  const SizedBox(height: 24),
                  _buildConditioningAnalysis(context),
                  const SizedBox(height: 16),
                  _buildCategoryAnalysis(
                    context, 
                    title: '지구력 분석 (Endurance)',
                    color: Theme.of(context).colorScheme.tertiary,
                    score: scores.enduranceScore,
                    metricLabel: '최근 7일 누적 거리',
                    metricValue: '${scores.totalDistanceKm.toStringAsFixed(1)} km',
                    freqValue: scores.enduranceWeeklyFreq,
                    baselineFreq: scores.enduranceBaselineFreq,
                    description: '지구력 점수는 베이스라인 대비 훈련 빈도와 총 거리를 기준으로 산출됩니다.',
                  ),
                  const SizedBox(height: 16),
                  _buildCategoryAnalysis(
                    context, 
                    title: '근력 분석 (Strength)',
                    color: Theme.of(context).colorScheme.primary,
                    score: scores.strengthScore,
                    metricLabel: '최근 7일 누적 볼륨',
                    metricValue: '${scores.totalVolumeTon.toStringAsFixed(2)} t',
                    freqValue: scores.strengthWeeklyFreq,
                    baselineFreq: scores.strengthBaselineFreq,
                    description: '근력 점수는 수행한 운동의 총 중량(Volume)과 규칙성을 분석합니다.',
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSliverAppBar(BuildContext context) {
    return SliverAppBar(
      expandedHeight: 320,
      pinned: true,
      stretch: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      flexibleSpace: FlexibleSpaceBar(
        title: Text('종합 퍼포먼스 분석', 
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurface,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
        background: Stack(
          fit: StackFit.expand,
          children: [
            // 배경 그라데이션
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Theme.of(context).colorScheme.secondary.withValues(alpha: 0.15),
                    Theme.of(context).colorScheme.surface,
                  ],
                ),
              ),
            ),
            // 대형 레이더 차트
            Center(
              child: Padding(
                padding: const EdgeInsets.only(top: 40.0),
                child: SizedBox(
                  width: 200,
                  height: 200,
                  child: RadarChart(
                    RadarChartData(
                      dataSets: [
                        RadarDataSet(
                          fillColor: Theme.of(context).colorScheme.secondary.withValues(alpha: 0.2),
                          borderColor: Theme.of(context).colorScheme.secondary,
                          entryRadius: 3,
                          dataEntries: [
                            RadarEntry(value: scores.enduranceScore),
                            RadarEntry(value: scores.strengthScore),
                            RadarEntry(value: scores.conditioningScore),
                          ],
                        ),
                      ],
                      radarShape: RadarShape.polygon,
                      getTitle: (index, angle) {
                        switch (index) {
                          case 0: return const RadarChartTitle(text: '지구력');
                          case 1: return const RadarChartTitle(text: '근력');
                          case 2: return const RadarChartTitle(text: '컨디셔닝');
                          default: return const RadarChartTitle(text: '');
                        }
                      },
                      tickCount: 1,
                      ticksTextStyle: const TextStyle(color: Colors.transparent),
                      gridBorderData: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCoachingSummary(BuildContext context) {
    String advice = "";
    if (scores.enduranceScore < scores.strengthScore - 15) {
      advice = "근력에 비해 지구력 훈련이 부족합니다. 이번 주는 페이스를 낮춘 Zone 2 러닝을 1회 더 추가해보는 건 어떨까요?";
    } else if (scores.strengthScore < scores.enduranceScore - 15) {
      advice = "지구력은 훌륭하지만 근력 보강이 필요합니다. 전신 복합 다관절 운동(스쿼트, 데드리프트) 위주로 세션을 구성해 보세요.";
    } else if (scores.conditioningScore < 60) {
      advice = "현재 컨디셔닝 수치가 낮습니다. 무리한 고강도 훈련보다는 충분한 수면과 가벼운 회복 운동에 집중할 때입니다.";
    } else {
      advice = "모든 지표가 균형 있게 발달하고 있습니다. 현재의 루틴을 유지하며 점진적 과부하를 적용해 보세요!";
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.secondary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Theme.of(context).colorScheme.secondary.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              SvgPicture.asset(
                'assets/images/pllogo.svg',
                width: 20,
                height: 20,
                colorFilter: ColorFilter.mode(Theme.of(context).colorScheme.secondary, BlendMode.srcIn),
              ),
              const SizedBox(width: 8),
              const Text('PaceLifter 코칭', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 12),
          Text(advice, style: const TextStyle(fontSize: 14, height: 1.5, color: Colors.white70)),
        ],
      ),
    );
  }

  Widget _buildCategoryAnalysis(
    BuildContext context, {
    required String title,
    required Color color,
    required double score,
    required String metricLabel,
    required String metricValue,
    required double freqValue,
    required double baselineFreq,
    required String description,
  }) {
    final double ratio = baselineFreq > 0 ? freqValue / baselineFreq : 1.0;
    
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(title, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color)),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(color: color.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(12)),
                  child: Text('${score.toInt()}점', style: TextStyle(color: color, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
            const Divider(height: 32),
            _buildMetricRow(metricLabel, metricValue, color),
            const SizedBox(height: 16),
            _buildFrequencyComparison(context, freqValue, baselineFreq, color),
            const SizedBox(height: 20),
            Text(description, style: const TextStyle(fontSize: 12, color: Colors.grey)),
          ],
        ),
      ),
    );
  }

  Widget _buildConditioningAnalysis(BuildContext context) {
    final color = Theme.of(context).colorScheme.secondary;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('컨디셔닝 분석 (Conditioning)', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color)),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(color: color.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(12)),
                  child: Text('${scores.conditioningScore.toInt()}점', style: TextStyle(color: color, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
            const Divider(height: 32),
            _buildMetricRow('부하 비율 (ACWR)', scores.acwr.toStringAsFixed(2), color),
            const SizedBox(height: 12),
            _buildMetricRow('평균 안정 시 심박수', scores.avgRestingHeartRate != null ? '${scores.avgRestingHeartRate!.toInt()} BPM' : '데이터 없음', Colors.grey),
            const SizedBox(height: 12),
            _buildMetricRow('평균 HRV (심박 변이도)', scores.avgHRV != null ? '${scores.avgHRV!.toInt()} ms' : '데이터 없음', Colors.grey),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (context) => ConditioningDetailScreen(scores: scores)),
                  );
                },
                style: TextButton.styleFrom(
                  backgroundColor: color.withValues(alpha: 0.1),
                  foregroundColor: color,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text('자세히 보기', style: TextStyle(fontWeight: FontWeight.bold)),
                    SizedBox(width: 4),
                    Icon(Icons.chevron_right, size: 18),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricRow(String label, String value, Color valueColor) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(fontSize: 14, color: Colors.white70)),
        Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: valueColor)),
      ],
    );
  }

  Widget _buildFrequencyComparison(BuildContext context, double current, double baseline, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('주당 훈련 빈도 비교', style: TextStyle(fontSize: 13, color: Colors.white60)),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: Column(
                children: [
                  Text('${current.toInt()}회', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  const Text('최근 7일', style: TextStyle(fontSize: 11, color: Colors.grey)),
                ],
              ),
            ),
            const Icon(Icons.compare_arrows, color: Colors.grey),
            Expanded(
              child: Column(
                children: [
                  Text('${baseline.toStringAsFixed(1)}회', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  const Text('평소(베이스라인)', style: TextStyle(fontSize: 11, color: Colors.grey)),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  Color _getACWRColor(BuildContext context, double acwr) {
    return Theme.of(context).colorScheme.secondary;
  }

  String _getFormulaName(String formula) {
    switch (formula) {
      case 'tanaka': return 'Tanaka';
      case 'gellish': return 'Gellish';
      case 'gulati': return 'Gulati';
      default: return 'Fox';
    }
  }
}
