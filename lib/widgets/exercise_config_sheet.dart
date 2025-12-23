import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../models/exercises/exercise.dart';
import '../providers/strength_routine_provider.dart';

class ExerciseConfigSheet extends StatefulWidget {
  final Exercise exercise;

  const ExerciseConfigSheet({super.key, required this.exercise});

  @override
  State<ExerciseConfigSheet> createState() => _ExerciseConfigSheetState();
}

class _ExerciseConfigSheetState extends State<ExerciseConfigSheet> {
  final TextEditingController _weightController = TextEditingController(text: '20');
  final TextEditingController _repsController = TextEditingController(text: '10');
  final TextEditingController _setsController = TextEditingController(text: '3');
  final List<String> _selectedVariations = [];

  @override
  void dispose() {
    _weightController.dispose();
    _repsController.dispose();
    _setsController.dispose();
    super.dispose();
  }

  void _addToRoutine() {
    final weight = double.tryParse(_weightController.text) ?? 0;
    final reps = int.tryParse(_repsController.text) ?? 0;
    final sets = int.tryParse(_setsController.text) ?? 0;

    if (weight > 0 && reps > 0 && sets > 0) {
      // 변형 옵션을 이름에 포함하여 전달
      final variationText = _selectedVariations.isNotEmpty 
          ? ' (${_selectedVariations.join(', ')})' 
          : '';
      
      final modifiedExercise = widget.exercise.copyWith(
        name: '${widget.exercise.nameKo}$variationText',
      );

      Provider.of<StrengthRoutineProvider>(context, listen: false).addExercise(
        exercise: modifiedExercise,
        weight: weight,
        reps: reps,
        sets: sets,
      );
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('루틴에 추가되었습니다')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
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
            
            // 세부 설정 (Variations) 칩 섹션
            if (widget.exercise.variations.isNotEmpty) ...[
              const SizedBox(height: 16),
              const Text('세부 설정', style: TextStyle(fontSize: 14, color: Colors.grey)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: widget.exercise.variations.map((variant) {
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
                    labelStyle: TextStyle(
                      color: isSelected 
                          ? Theme.of(context).colorScheme.onPrimaryContainer 
                          : Theme.of(context).colorScheme.onSurface,
                      fontSize: 12,
                    ),
                  );
                }).toList(),
              ),
            ],

            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: _buildInput('무게 (kg)', _weightController),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildInput('횟수 (Reps)', _repsController, isInt: true),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildInput('세트 (Sets)', _setsController, isInt: true),
                ),
              ],
            ),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: _addToRoutine,
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.primary,
                foregroundColor: Theme.of(context).colorScheme.onPrimary,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: const Text('추가하기', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInput(String label, TextEditingController controller, {bool isInt = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          keyboardType: TextInputType.numberWithOptions(decimal: !isInt),
          inputFormatters: [
            isInt
                ? FilteringTextInputFormatter.digitsOnly
                : FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d*')),
          ],
          textAlign: TextAlign.center,
          decoration: InputDecoration(
            contentPadding: const EdgeInsets.symmetric(vertical: 12),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
      ],
    );
  }
}