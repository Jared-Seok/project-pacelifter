import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../services/template_service.dart';
import '../models/templates/workout_template.dart';
import 'workout_setup_screen.dart';

/// 환경별 세부 훈련 템플릿 선택 화면
class EnduranceTemplateScreen extends StatefulWidget {
  final String environmentType;

  const EnduranceTemplateScreen({
    super.key,
    required this.environmentType,
  });

  @override
  State<EnduranceTemplateScreen> createState() =>
      _EnduranceTemplateScreenState();
}

class _EnduranceTemplateScreenState extends State<EnduranceTemplateScreen> {
  List<WorkoutTemplate> _templates = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadTemplates();
  }

  Future<void> _loadTemplates() async {
    try {
      final templates = TemplateService.getEnduranceTemplatesByEnvironment(
        widget.environmentType,
      );

      // 표준 템플릿만 표시 (커스텀 템플릿 제외)
      final standardTemplates = templates.where((t) => !t.isCustom).toList();

      if (mounted) {
        setState(() {
          _templates = standardTemplates;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('템플릿 로드 실패: $e')),
        );
      }
    }
  }

  String _getCleanName(String name) {
    return name
        .replaceAll('Outdoor ', '')
        .replaceAll('Indoor ', '')
        .replaceAll('Trail ', '')
        .replaceAll('Track ', '');
  }

  @override
  Widget build(BuildContext context) {
    // 환경에 따른 아이콘 및 색상 설정
    final String iconPath = widget.environmentType == 'Trail' 
        ? 'assets/images/endurance/trail-icon.svg' 
        : 'assets/images/endurance/runner-icon.svg';
    
    final Color themeColor = Theme.of(context).colorScheme.tertiary; // Deep Teal for all Endurance templates

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        title: Text(widget.environmentType == 'Outdoor' ? '로드 러닝' : 
                   (widget.environmentType == 'Indoor' ? '실내 러닝' : '트레일 러닝')),
        backgroundColor: Theme.of(context).colorScheme.surface,
        foregroundColor: Theme.of(context).colorScheme.onSurface,
      ),
      body: _isLoading
          ? Center(
              child: CircularProgressIndicator(
                color: themeColor,
              ),
            )
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        SvgPicture.asset(
                          iconPath,
                          width: 32,
                          height: 32,
                          colorFilter: ColorFilter.mode(
                            themeColor,
                            BlendMode.srcIn,
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Text(
                            '훈련 템플릿 선택',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${widget.environmentType} 환경에 맞는 훈련을 선택하세요',
                      style: TextStyle(
                        fontSize: 14,
                        color: Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withValues(alpha: 0.6),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Expanded(
                      child: _templates.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.inbox_outlined,
                                    size: 64,
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurface
                                        .withValues(alpha: 0.3),
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    '사용 가능한 템플릿이 없습니다',
                                    style: TextStyle(
                                      fontSize: 16,
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onSurface
                                          .withValues(alpha: 0.6),
                                    ),
                                  ),
                                ],
                              ),
                            )
                          : ListView.builder(
                              itemCount: _templates.length,
                              itemBuilder: (context, index) {
                                final template = _templates[index];
                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 12),
                                  child: _buildTemplateCard(
                                    context: context,
                                    template: template,
                                    iconPath: iconPath,
                                    themeColor: themeColor,
                                  ),
                                );
                              },
                            ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildTemplateCard({
    required BuildContext context,
    required WorkoutTemplate template,
    required String iconPath,
    required Color themeColor,
  }) {
    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => WorkoutSetupScreen(
              template: template,
            ),
          ),
        );
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: themeColor.withValues(alpha: 0.3),
            width: 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: themeColor.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: SvgPicture.asset(
                iconPath,
                width: 24,
                height: 24,
                colorFilter: ColorFilter.mode(
                  themeColor,
                  BlendMode.srcIn,
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _getCleanName(template.name),
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  if (template.subCategory != null)
                    Text(
                      template.subCategory!,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: themeColor,
                      ),
                    ),
                  const SizedBox(height: 4),
                  Text(
                    template.description,
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withValues(alpha: 0.6),
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Icon(
              Icons.arrow_forward_ios,
              color: themeColor,
              size: 16,
            ),
          ],
        ),
      ),
    );
  }
}
