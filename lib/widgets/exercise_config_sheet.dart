import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/exercises/exercise.dart';
import '../providers/strength_routine_provider.dart';
import '../services/profile_service.dart';
import '../utils/strength_standards.dart';
import '../utils/workout_ui_utils.dart';

class ExerciseConfigSheet extends StatefulWidget {
  final Exercise exercise;

  const ExerciseConfigSheet({super.key, required this.exercise});

  @override
  State<ExerciseConfigSheet> createState() => _ExerciseConfigSheetState();
}

class _ExerciseConfigSheetState extends State<ExerciseConfigSheet> {
  final List<String> _selectedVariations = [];
  double _defaultWeight = 0;
  bool _isLoading = true;
  String? _userGender;

  @override
  void initState() {
    super.initState();
    _loadDefaultValues();
  }

  Future<void> _loadDefaultValues() async {
    final profile = await ProfileService().getProfile();
    _userGender = profile?.gender;
    // 성별에 따른 기본 초기 무게 계산
    _defaultWeight = StrengthStandards.getInitialWeight(widget.exercise, _userGender);
    
    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _addToRoutine() {
    // 세부 설정 기반 무게 재계산 (중량 추가 시나리오 등 대응)
    final isWeighted = _selectedVariations.any((v) => v.contains('중량') || v.toLowerCase().contains('weighted'));
    
    double finalWeight = _defaultWeight;
    
    // 만약 맨몸운동인데 '중량'이 선택되었다면 기본값(예: 5kg) 부여하거나 0 유지
    // 대부분의 경우 StrengthStandards에서 이미 적절한 값을 주거나 0을 줌.
    if (widget.exercise.equipment == 'bodyweight' && isWeighted && finalWeight == 0) {
      finalWeight = 5.0; // 최소 중량 제안
    }

    // 변형 옵션을 이름에 포함하여 전달
    final variationText = _selectedVariations.isNotEmpty 
        ? ' (${_selectedVariations.map((v) => v.contains(': ') ? v.split(': ')[1] : v).join(', ')})' 
        : '';
    
    final modifiedExercise = widget.exercise.copyWith(
      name: '${widget.exercise.nameKo}$variationText',
    );

    // 초기값은 3세트 10회로 고정하여 장바구니에 담기 (최종 점검에서 수정 유도)
    Provider.of<StrengthRoutineProvider>(context, listen: false).addExercise(
      exercise: modifiedExercise,
      weight: finalWeight,
      reps: 10,
      sets: 3,
      selectedVariations: _selectedVariations,
    );

    Navigator.pop(context);
    WorkoutUIUtils.showTopNotification(context, '${widget.exercise.nameKo}가 루틴에 추가되었습니다.');
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              widget.exercise.nameKo.isNotEmpty ? widget.exercise.nameKo : widget.exercise.name,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              '세부 설정을 선택해주세요',
              style: TextStyle(fontSize: 14, color: Colors.grey[400]),
            ),
            
            // 세부 설정 (Variations) 칩 섹션
            if (widget.exercise.variations.isNotEmpty) ...[
              const SizedBox(height: 20),
              Builder(
                builder: (context) {
                  final Map<String, List<String>> categorized = {};
                  final List<String> uncategorized = [];

                  for (var variant in widget.exercise.variations) {
                    if (variant.contains(': ')) {
                      final parts = variant.split(': ');
                      final category = parts[0];
                      categorized.putIfAbsent(category, () => []).add(variant);
                    } else {
                      uncategorized.add(variant);
                    }
                  }

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ...categorized.entries.map((entry) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(entry.key, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white70)),
                              const SizedBox(height: 8),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: entry.value.map((fullVariant) {
                                  final isSelected = _selectedVariations.contains(fullVariant);
                                  final displayLabel = fullVariant.split(': ')[1];
                                  return FilterChip(
                                    label: Text(displayLabel),
                                    selected: isSelected,
                                    onSelected: (selected) {
                                      setState(() {
                                        final categoryPrefix = fullVariant.split(': ')[0] + ': ';
                                        _selectedVariations.removeWhere((v) => v.startsWith(categoryPrefix));
                                        if (selected) {
                                          _selectedVariations.add(fullVariant);
                                        }
                                      });
                                    },
                                    selectedColor: Theme.of(context).colorScheme.primary.withValues(alpha: 0.2),
                                    side: BorderSide(
                                      color: isSelected 
                                          ? Theme.of(context).colorScheme.primary 
                                          : Colors.grey.shade700,
                                    ),
                                    labelStyle: TextStyle(
                                      color: isSelected 
                                          ? Theme.of(context).colorScheme.primary
                                          : Theme.of(context).colorScheme.onSurface,
                                      fontSize: 12,
                                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                    ),
                                  );
                                }).toList(),
                              ),
                            ],
                          ),
                        );
                      }),
                      if (uncategorized.isNotEmpty)
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: uncategorized.map((variant) {
                            final isSelected = _selectedVariations.contains(variant);
                            return FilterChip(
                              label: Text(variant),
                              selected: isSelected,
                              onSelected: (selected) {
                                setState(() {
                                  if (selected) {
                                    _selectedVariations.add(variant);
                                  } else {
                                    _selectedVariations.remove(variant);
                                  }
                                });
                              },
                              selectedColor: Theme.of(context).colorScheme.primary.withValues(alpha: 0.2),
                              side: BorderSide(
                                color: isSelected 
                                    ? Theme.of(context).colorScheme.primary 
                                    : Colors.grey.shade700,
                              ),
                              labelStyle: TextStyle(
                                color: isSelected 
                                    ? Theme.of(context).colorScheme.primary
                                    : Theme.of(context).colorScheme.onSurface,
                                fontSize: 12,
                                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                              ),
                            );
                          }).toList(),
                        ),
                    ],
                  );
                },
              ),
            ] else 
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 40),
                child: Center(child: Text('기본 설정으로 추가됩니다.', style: TextStyle(color: Colors.grey))),
              ),

            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: _isLoading ? null : _addToRoutine,
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.primary,
                foregroundColor: Theme.of(context).colorScheme.onPrimary,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: _isLoading 
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Text('루틴에 추가', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }
}