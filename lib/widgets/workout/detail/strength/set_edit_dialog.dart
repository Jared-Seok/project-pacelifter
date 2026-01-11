import 'package:flutter/material.dart';
import '../../../../models/sessions/exercise_record.dart';

/// 고품질 근력 운동 정밀 편집 다이얼로그
/// - 버튼 조절 및 직접 입력 동시 지원
/// - 테마 색상(Strength) 일원화 적용
class SetEditDialog extends StatefulWidget {
  final ExerciseRecord record;
  final Color themeColor;
  final Function(List<SetRecord>) onSave;

  const SetEditDialog({
    super.key, 
    required this.record, 
    required this.themeColor,
    required this.onSave
  });

  @override
  State<SetEditDialog> createState() => _SetEditDialogState();
}

class _SetEditDialogState extends State<SetEditDialog> {
  late List<SetRecord> _tempSets;

  @override
  void initState() {
    super.initState();
    _tempSets = widget.record.sets.map((s) => SetRecord(
      setNumber: s.setNumber,
      weight: s.weight,
      repsTarget: s.repsTarget,
      repsCompleted: s.repsCompleted,
    )).toList();
  }

  void _addSet() {
    setState(() {
      final lastSet = _tempSets.isNotEmpty ? _tempSets.last : SetRecord(setNumber: 0, weight: 0, repsTarget: 10);
      _tempSets.add(SetRecord(
        setNumber: _tempSets.length + 1,
        weight: lastSet.weight,
        repsTarget: lastSet.repsTarget,
        repsCompleted: lastSet.repsCompleted,
      ));
    });
  }

  void _removeSet(int index) {
    if (_tempSets.length <= 1) return;
    setState(() {
      _tempSets.removeAt(index);
      for (int i = 0; i < _tempSets.length; i++) {
        _tempSets[i] = _updateSet(_tempSets[i], setNumber: i + 1);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Container(
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.8),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildHeader(),
            const SizedBox(height: 20),
            Expanded(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: _tempSets.length,
                itemBuilder: (context, index) => _buildSetRow(index, _tempSets[index]),
              ),
            ),
            const SizedBox(height: 16),
            _buildActionButtons(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(widget.record.exerciseName, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Text('세트별 정밀 수정', style: TextStyle(fontSize: 12, color: Colors.grey[400])),
            ],
          ),
        ),
        IconButton(
          onPressed: _addSet,
          icon: Icon(Icons.add_circle_outline, color: widget.themeColor),
          tooltip: '세트 추가',
        ),
      ],
    );
  }

  Widget _buildSetRow(int index, SetRecord set) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white10),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 14,
            backgroundColor: widget.themeColor.withValues(alpha: 0.2),
            child: Text('${index + 1}', style: TextStyle(color: widget.themeColor, fontSize: 12, fontWeight: FontWeight.bold)),
          ),
          const SizedBox(width: 16),
          // 무게 조절
          Expanded(child: _buildValueAdjuster('kg', set.weight ?? 0, (v) => _tempSets[index] = _updateSet(set, weight: v), step: 2.5)),
          const SizedBox(width: 12),
          // 횟수 조절
          Expanded(child: _buildValueAdjuster('회', (set.repsCompleted ?? 10).toDouble(), (v) => _tempSets[index] = _updateSet(set, reps: v.toInt()), step: 1)),
          const SizedBox(width: 8),
          IconButton(
            icon: const Icon(Icons.remove_circle_outline, color: Colors.redAccent, size: 20),
            onPressed: () => _removeSet(index),
          ),
        ],
      ),
    );
  }

  Widget _buildValueAdjuster(String label, double value, Function(double) onChanged, {double step = 1.0}) {
    final controller = TextEditingController(text: value.toStringAsFixed(1).replaceAll(RegExp(r'\.0$'), ''));
    
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _miniButton(Icons.remove, () => onChanged((value - step).clamp(0, 999))),
            Expanded(
              child: TextField(
                controller: controller,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                decoration: InputDecoration(
                  isDense: true,
                  contentPadding: EdgeInsets.zero,
                  border: InputBorder.none,
                  suffixText: label,
                  suffixStyle: const TextStyle(fontSize: 10, color: Colors.grey),
                ),
                onSubmitted: (v) {
                  final double? val = double.tryParse(v);
                  if (val != null) onChanged(val);
                },
              ),
            ),
            _miniButton(Icons.add, () => onChanged((value + step).clamp(0, 999))),
          ],
        ),
      ],
    );
  }

  Widget _miniButton(IconData icon, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.all(4),
        child: Icon(icon, size: 16, color: widget.themeColor),
      ),
    );
  }

  Widget _buildActionButtons() {
    return Row(
      children: [
        Expanded(
          child: TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('취소', style: TextStyle(color: Colors.grey)),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: ElevatedButton(
            onPressed: () {
              widget.onSave(_tempSets);
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: widget.themeColor,
              foregroundColor: Colors.black,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('저장하기', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ),
      ],
    );
  }

  SetRecord _updateSet(SetRecord old, {int? setNumber, double? weight, int? reps}) {
    return SetRecord(
      setNumber: setNumber ?? old.setNumber,
      weight: weight ?? old.weight,
      repsTarget: reps ?? old.repsTarget,
      repsCompleted: reps ?? old.repsCompleted,
    );
  }
}