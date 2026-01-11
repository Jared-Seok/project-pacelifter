import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/exercises/exercise.dart';
import '../providers/strength_routine_provider.dart';
import '../services/profile_service.dart';
import '../utils/strength_standards.dart';
import '../utils/workout_ui_utils.dart';

class ExerciseConfigSheet extends StatefulWidget {
  final Exercise exercise;
  
  // 편집/보강 모드를 위한 추가 파라미터
  final int? initialSets;
  final int? initialReps;
  final double? initialWeight;
  final List<String>? initialVariations;
  final Function(int sets, int reps, double weight, List<String> variations)? onConfirm;

  const ExerciseConfigSheet({
    super.key, 
    required this.exercise,
    this.initialSets,
    this.initialReps,
    this.initialWeight,
    this.initialVariations,
    this.onConfirm,
  });

  @override
  State<ExerciseConfigSheet> createState() => _ExerciseConfigSheetState();
}

class _ExerciseConfigSheetState extends State<ExerciseConfigSheet> {
  final List<String> _selectedVariations = [];
  late int _sets;
  late int _reps;
  late double _weight;
  
  bool _isLoading = true;
  String? _userGender;

  @override
  void initState() {
    super.initState();
    // 초기값 설정
    _sets = widget.initialSets ?? 3;
    _reps = widget.initialReps ?? 10;
    _weight = widget.initialWeight ?? 0.0;
    if (widget.initialVariations != null) {
      _selectedVariations.addAll(widget.initialVariations!);
    }
    
    _loadDefaultValues();
  }

  Future<void> _loadDefaultValues() async {
    if (widget.initialWeight == null) {
      final profile = await ProfileService().getProfile();
      _userGender = profile?.gender;
      _weight = StrengthStandards.getInitialWeight(widget.exercise, _userGender);
    }
    
    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _handleConfirm() {
    // 변형 옵션을 이름에 포함하여 전달
    final variationText = _selectedVariations.isNotEmpty 
        ? ' (${_selectedVariations.map((v) => v.contains(': ') ? v.split(': ')[1] : v).join(', ')})' 
        : '';
    
    final modifiedExercise = widget.exercise.copyWith(
      name: '${widget.exercise.nameKo}$variationText',
    );

    if (widget.onConfirm != null) {
      // 보강/편집 모드 콜백 실행
      widget.onConfirm!(_sets, _reps, _weight, _selectedVariations);
    } else {
      // 일반 루틴 추가 모드
      Provider.of<StrengthRoutineProvider>(context, listen: false).addExercise(
        exercise: modifiedExercise,
        weight: _weight,
        reps: _reps,
        sets: _sets,
        selectedVariations: _selectedVariations,
      );
      Navigator.pop(context);
      WorkoutUIUtils.showTopNotification(context, '${widget.exercise.nameKo}가 루틴에 추가되었습니다.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildHeader(),
            const SizedBox(height: 24),
            
            // 1. 세트/횟수/무게 조절 섹션
            _buildCounterSection(),
            const SizedBox(height: 24),
            
            // 2. 세부 설정 (Variations)
            if (widget.exercise.variations.isNotEmpty) ...[
              const Divider(),
              const SizedBox(height: 16),
              _buildVariationsSection(),
            ],

            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: _isLoading ? null : _handleConfirm,
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.secondary,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: _isLoading 
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : Text(widget.onConfirm != null ? '변경사항 저장' : '루틴에 추가', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.exercise.nameKo.isNotEmpty ? widget.exercise.nameKo : widget.exercise.name,
          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4),
        Text(
          '운동의 강도와 볼륨을 설정하세요',
          style: TextStyle(fontSize: 13, color: Colors.grey[400]),
        ),
      ],
    );
  }

  Widget _buildCounterSection() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        _buildCounterItem('세트', _sets, (v) => setState(() => _sets = (v as int).clamp(1, 20))),
        _buildCounterItem('횟수', _reps, (v) => setState(() => _reps = (v as int).clamp(1, 100))),
        _buildCounterItem('무게(kg)', _weight, (v) => setState(() => _weight = (v as double).clamp(0, 500)), isDouble: true),
      ],
    );
  }

  Widget _buildCounterItem(String label, dynamic value, Function(dynamic) onChanged, {bool isDouble = false}) {
    return Column(
      children: [
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.remove, size: 18),
                onPressed: () => onChanged(isDouble ? (value - 2.5) : (value - 1)),
              ),
              Text(
                isDouble ? value.toStringAsFixed(1).replaceAll(RegExp(r'\.0$'), '') : value.toString(),
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              IconButton(
                icon: const Icon(Icons.add, size: 18),
                onPressed: () => onChanged(isDouble ? (value + 2.5) : (value + 1)),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildVariationsSection() {
    // ... 기존 Variations 칩 렌더링 로직 유지
    final Map<String, List<String>> categorized = {};
    final List<String> uncategorized = [];

    for (var variant in widget.exercise.variations) {
      if (variant.contains(': ')) {
        final parts = variant.split(': ');
        categorized.putIfAbsent(parts[0], () => []).add(variant);
      } else {
        uncategorized.add(variant);
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ...categorized.entries.map((entry) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(entry.key, style: const TextStyle(fontSize: 12, color: Colors.white70)),
            const SizedBox(height: 8),
            Wrap(spacing: 8, children: entry.value.map((v) => _buildChip(v)).toList()),
            const SizedBox(height: 12),
          ],
        )),
      ],
    );
  }

  Widget _buildChip(String fullVariant) {
    final isSelected = _selectedVariations.contains(fullVariant);
    final displayLabel = fullVariant.contains(': ') ? fullVariant.split(': ')[1] : fullVariant;
    return ChoiceChip(
      label: Text(displayLabel, style: TextStyle(fontSize: 11, color: isSelected ? Colors.black : Colors.white)),
      selected: isSelected,
      onSelected: (selected) {
        setState(() {
          final prefix = fullVariant.contains(': ') ? '${fullVariant.split(': ')[0]}: ' : '';
          if (prefix.isNotEmpty) _selectedVariations.removeWhere((v) => v.startsWith(prefix));
          if (selected) _selectedVariations.add(fullVariant);
          else if (prefix.isEmpty) _selectedVariations.remove(fullVariant);
        });
      },
      selectedColor: Theme.of(context).colorScheme.secondary,
    );
  }
}
