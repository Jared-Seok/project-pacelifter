import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../models/templates/workout_template.dart';
import '../models/templates/template_phase.dart';
import '../models/templates/template_block.dart';
import '../models/exercises/exercise.dart';
import '../models/sessions/exercise_record.dart';
import '../services/template_service.dart';
import '../providers/strength_routine_provider.dart';
import 'strength_tracking_screen.dart';

class StrengthRoutinePreviewScreen extends StatefulWidget {
  final WorkoutTemplate template;

  const StrengthRoutinePreviewScreen({super.key, required this.template});

  @override
  State<StrengthRoutinePreviewScreen> createState() => _StrengthRoutinePreviewScreenState();
}

class _ExerciseVariationEditSheet extends StatefulWidget {
  final Exercise exercise;
  final List<String> initialVariations;
  final Function(List<String>) onSaved;

  const _ExerciseVariationEditSheet({
    required this.exercise,
    required this.initialVariations,
    required this.onSaved,
  });

  @override
  State<_ExerciseVariationEditSheet> createState() => _ExerciseVariationEditSheetState();
}

class _ExerciseVariationEditSheetState extends State<_ExerciseVariationEditSheet> {
  late List<String> _selectedVariations;

  @override
  void initState() {
    super.initState();
    _selectedVariations = List.from(widget.initialVariations);
  }

  @override
  Widget build(BuildContext context) {
    if (widget.exercise.variations.isEmpty) {
      return const Center(child: Text('수정할 수 있는 세부 설정이 없습니다.'));
    }

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

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            '${widget.exercise.nameKo} 세부 설정 수정',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 20),
          Flexible(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ...categorized.entries.map((entry) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 16.0),
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
                                selectedColor: Theme.of(context).colorScheme.primaryContainer,
                              );
                            }).toList(),
                          ),
                        ],
                      ),
                    );
                  }),
                  if (uncategorized.isNotEmpty) ...[
                    const Text('기타', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white70)),
                    const SizedBox(height: 8),
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
                          selectedColor: Theme.of(context).colorScheme.primaryContainer,
                        );
                      }).toList(),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () {
              widget.onSaved(_selectedVariations);
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('수정 완료'),
          ),
        ],
      ),
    );
  }
}

class _StrengthRoutinePreviewScreenState extends State<StrengthRoutinePreviewScreen> {
  final Map<String, List<SetRecord>> _blockSets = {};
  late List<TemplateBlock> _modifiableBlocks;

  @override
  void initState() {
    super.initState();
    // 1. 프로바이더의 현재 상태를 로컬로 복사
    _modifiableBlocks = List.from(widget.template.phases.first.blocks);
    
    // 2. 블록 데이터를 개별 세트 리스트로 변환하여 관리
    for (var block in _modifiableBlocks) {
      _blockSets[block.id] = List.generate(
        block.sets ?? 3,
        (index) => SetRecord(
          setNumber: index + 1,
          repsTarget: block.reps,
          weight: block.weight,
          restSeconds: block.restSeconds,
        ),
      );
    }
  }

  void _onReorder(int oldIndex, int newIndex) {
    setState(() {
      if (oldIndex < newIndex) {
        newIndex -= 1;
      }
      final TemplateBlock item = _modifiableBlocks.removeAt(oldIndex);
      _modifiableBlocks.insert(newIndex, item);
      
      // 프로바이더 상태도 업데이트 (장바구니 순서 유지)
      Provider.of<StrengthRoutineProvider>(context, listen: false).reorderBlocks(oldIndex, newIndex);
    });
  }

  void _addSet(String blockId) {
    setState(() {
      final sets = _blockSets[blockId]!;
      final lastSet = sets.last;
      sets.add(SetRecord(
        setNumber: sets.length + 1,
        repsTarget: lastSet.repsTarget,
        weight: lastSet.weight,
        restSeconds: lastSet.restSeconds,
      ));
    });
  }

  void _removeSet(String blockId, int setIndex) {
    setState(() {
      final sets = _blockSets[blockId]!;
      if (sets.length > 1) {
        sets.removeAt(setIndex);
        _blockSets[blockId] = sets.asMap().entries.map((e) => e.value.copyWith(setNumber: e.key + 1)).toList();
      }
    });
  }

  void _updateSetWeight(String blockId, int setIndex, double weight) {
    setState(() {
      _blockSets[blockId]![setIndex] = _blockSets[blockId]![setIndex].copyWith(weight: (weight * 10).round() / 10.0);
    });
  }

  void _updateSetReps(String blockId, int setIndex, int reps) {
    setState(() {
      _blockSets[blockId]![setIndex] = _blockSets[blockId]![setIndex].copyWith(repsTarget: reps);
    });
  }

  Future<void> _saveCurrentRoutine() async {
    final nameController = TextEditingController();
    final bool? shouldSave = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('루틴 저장'),
        content: TextField(
          controller: nameController,
          decoration: const InputDecoration(labelText: '루틴 이름', hintText: '예: 오늘 가슴 운동'),
          autofocus: true,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('취소')),
          ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('저장')),
        ],
      ),
    );

    if (shouldSave == true && nameController.text.trim().isNotEmpty) {
      final updatedBlocks = _modifiableBlocks.asMap().entries.map((e) {
        final block = e.value;
        final sets = _blockSets[block.id]!;
        return block.copyWith(
          sets: sets.length,
          weight: sets.first.weight,
          reps: sets.first.repsTarget,
        );
      }).toList();

      final newTemplate = widget.template.copyWith(
        id: const Uuid().v4(),
        name: nameController.text.trim(),
        isCustom: true,
        createdAt: DateTime.now(),
        phases: [widget.template.phases.first.copyWith(blocks: updatedBlocks)],
      );

      await TemplateService.saveCustomTemplate(newTemplate);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('내 루틴에 저장되었습니다.')));
      }
    }
  }

  Future<void> _handleStartWorkout() async {
    final bool? saveBeforeStart = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('운동 시작'),
        content: const Text('현재 구성을 나만의 루틴으로 저장하고 시작할까요?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('아니오')),
          ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('예, 저장합니다')),
        ],
      ),
    );

    if (saveBeforeStart == true) {
      await _saveCurrentRoutine();
    }

    if (mounted) {
      final updatedTemplate = widget.template.copyWith(
        phases: [widget.template.phases.first.copyWith(blocks: _modifiableBlocks)],
      );
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => StrengthTrackingScreen(
          template: updatedTemplate,
          manualPlan: _blockSets,
        )),
      );
    }
  }

  void _showVariationEditSheet(int index, TemplateBlock block) {
    final exercise = block.exerciseId != null ? TemplateService.getExerciseById(block.exerciseId!) : null;
    if (exercise == null) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _ExerciseVariationEditSheet(
        exercise: exercise,
        initialVariations: block.selectedVariations ?? [],
        onSaved: (newVariations) {
          final variationText = newVariations.isNotEmpty 
              ? ' (${newVariations.map((v) => v.contains(': ') ? v.split(': ')[1] : v).join(', ')})' 
              : '';
          setState(() {
            _modifiableBlocks[index] = block.copyWith(
              selectedVariations: newVariations,
              name: '${exercise.nameKo}$variationText',
            );
          });
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    int totalExercises = _modifiableBlocks.length;
    int totalSets = _blockSets.values.fold(0, (sum, sets) => sum + sets.length);
    double totalVolume = _blockSets.values.fold(0.0, (sum, sets) {
      return sum + sets.fold(0.0, (sSum, s) => sSum + ((s.weight ?? 0) * (s.repsTarget ?? 0)));
    });

    return Scaffold(
      appBar: AppBar(
        title: const Text('루틴 최종 점검'),
        actions: [
          TextButton.icon(
            onPressed: _saveCurrentRoutine,
            icon: const Icon(Icons.save_alt, size: 20),
            label: const Text('루틴 저장'),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ReorderableListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _modifiableBlocks.length,
              onReorder: _onReorder,
              itemBuilder: (context, index) {
                final block = _modifiableBlocks[index];
                return Container(
                  key: ValueKey(block.id),
                  child: _buildExerciseEditor(block, index),
                );
              },
            ),
          ),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.2), blurRadius: 10, offset: const Offset(0, -5))],
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: SafeArea(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildSummaryItem('운동', '$totalExercises'),
                      _buildSummaryItem('세트', '$totalSets'),
                      _buildSummaryItem(
                        '예상 볼륨', 
                        totalVolume >= 1000 
                          ? '${(totalVolume / 1000).toStringAsFixed(2)} t' 
                          : '${totalVolume.toStringAsFixed(0)} kg'
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      onPressed: totalExercises > 0 ? _handleStartWorkout : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Theme.of(context).colorScheme.primary,
                        foregroundColor: Theme.of(context).colorScheme.onPrimary,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        elevation: 4,
                      ),
                      child: const Text('운동 시작하기', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryItem(String label, String value) {
    return Column(
      children: [
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
        const SizedBox(height: 4),
        Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _buildExerciseEditor(TemplateBlock block, int blockIndex) {
    final exercise = block.exerciseId != null ? TemplateService.getExerciseById(block.exerciseId!) : null;
    final sets = _blockSets[block.id]!;

    return Card(
      margin: const EdgeInsets.only(bottom: 20),
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 8, 8),
            child: Row(
              children: [
                // 드래그 핸들 추가
                ReorderableDragStartListener(
                  index: blockIndex,
                  child: const Padding(
                    padding: EdgeInsets.only(right: 8.0),
                    child: Icon(Icons.drag_indicator, color: Colors.grey),
                  ),
                ),
                Container(
                  width: 40, height: 44,
                  decoration: BoxDecoration(color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
                  padding: const EdgeInsets.all(6),
                  child: SvgPicture.asset(exercise?.imagePath ?? 'assets/images/strength/lifter-icon.svg', colorFilter: ColorFilter.mode(Theme.of(context).colorScheme.primary, BlendMode.srcIn)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: InkWell(
                    onTap: () => _showVariationEditSheet(blockIndex, block),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(exercise?.nameKo ?? block.name.split(' (')[0], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                            const SizedBox(width: 4),
                            const Icon(Icons.edit, size: 14, color: Colors.grey),
                          ],
                        ),
                        Text(
                          (block.selectedVariations?.isNotEmpty == true)
                              ? block.selectedVariations!.map((v) => v.contains(': ') ? v.split(': ')[1] : v).join(', ')
                              : (block.name.contains(' (') ? block.name.substring(block.name.indexOf(' (') + 2, block.name.length - 1) : '기본 설정'),
                          style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.primary),
                        ),
                      ],
                    ),
                  ),
                ),
                IconButton(icon: const Icon(Icons.remove_circle_outline, color: Colors.redAccent, size: 22), onPressed: () => setState(() => _modifiableBlocks.removeAt(blockIndex))),
              ],
            ),
          ),
          const Divider(),
          ...sets.asMap().entries.map((entry) => _buildSetEditRow(block.id, entry.key, entry.value)),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextButton.icon(onPressed: () => _addSet(block.id), icon: const Icon(Icons.add, size: 18), label: const Text('세트 추가'), style: TextButton.styleFrom(minimumSize: const Size(double.infinity, 44))),
          ),
        ],
      ),
    );
  }

  Widget _buildSetEditRow(String blockId, int index, SetRecord set) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Row(
        children: [
          SizedBox(width: 30, child: Text('${index + 1}', textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.grey))),
          Expanded(child: _buildValueAdjuster(value: set.weight ?? 0, onChanged: (val) => _updateSetWeight(blockId, index, val), step: 2.5, isDecimal: true, suffix: ' kg')),
          const SizedBox(width: 8),
          Expanded(child: _buildValueAdjuster(value: (set.repsTarget ?? 0).toDouble(), onChanged: (val) => _updateSetReps(blockId, index, val.toInt()), step: 1, isDecimal: false, suffix: ' 회')),
          SizedBox(width: 40, child: IconButton(icon: const Icon(Icons.close, size: 18, color: Colors.grey), onPressed: () => _removeSet(blockId, index))),
        ],
      ),
    );
  }

  Widget _buildValueAdjuster({required double value, required Function(double) onChanged, required double step, bool isDecimal = false, String suffix = ''}) {
    return Container(
      decoration: BoxDecoration(color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.3), borderRadius: BorderRadius.circular(12)),
      child: Row(
        children: [
          _buildMiniStepBtn(Icons.remove, () => onChanged(value - step)),
          Expanded(child: Text('${isDecimal ? value.toStringAsFixed(1).replaceAll(RegExp(r'\.0$'), '') : value.toInt()}$suffix', textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14))),
          _buildMiniStepBtn(Icons.add, () => onChanged(value + step)),
        ],
      ),
    );
  }

  Widget _buildMiniStepBtn(IconData icon, VoidCallback onTap) {
    return InkWell(onTap: onTap, borderRadius: BorderRadius.circular(8), child: Padding(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8), child: Icon(icon, size: 14, color: Theme.of(context).colorScheme.primary)));
  }
}
