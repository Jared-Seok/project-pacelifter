import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/templates/template_block.dart';

class BlockEditDialog extends StatefulWidget {
  final TemplateBlock block;
  final Function(TemplateBlock) onSave;

  const BlockEditDialog({
    super.key,
    required this.block,
    required this.onSave,
  });

  @override
  State<BlockEditDialog> createState() => _BlockEditDialogState();
}

class _BlockEditDialogState extends State<BlockEditDialog> {
  late TextEditingController _setsController;
  late TextEditingController _repsController;
  late TextEditingController _weightController;
  late TextEditingController _distanceController;
  late TextEditingController _durationController;
  late TextEditingController _restController;

  @override
  void initState() {
    super.initState();
    _setsController = TextEditingController(text: widget.block.sets?.toString() ?? '');
    _repsController = TextEditingController(text: widget.block.reps?.toString() ?? '');
    _weightController = TextEditingController(text: widget.block.weight?.toString() ?? '');
    _distanceController = TextEditingController(text: widget.block.targetDistance?.toString() ?? '');
    _durationController = TextEditingController(text: widget.block.targetDuration?.toString() ?? '');
    _restController = TextEditingController(text: widget.block.restSeconds?.toString() ?? '');
  }

  @override
  void dispose() {
    _setsController.dispose();
    _repsController.dispose();
    _weightController.dispose();
    _distanceController.dispose();
    _durationController.dispose();
    _restController.dispose();
    super.dispose();
  }

  void _save() {
    final updatedBlock = widget.block.copyWith(
      sets: int.tryParse(_setsController.text),
      reps: int.tryParse(_repsController.text),
      weight: double.tryParse(_weightController.text),
      targetDistance: double.tryParse(_distanceController.text),
      targetDuration: int.tryParse(_durationController.text),
      restSeconds: int.tryParse(_restController.text),
    );
    widget.onSave(updatedBlock);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('${widget.block.name} 설정'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (widget.block.type == 'strength') ...[
              _buildTextField('세트 수', _setsController, isInt: true),
              const SizedBox(height: 12),
              _buildTextField('반복 횟수 (Reps)', _repsController, isInt: true),
              const SizedBox(height: 12),
              _buildTextField('중량 (kg)', _weightController),
              const SizedBox(height: 12),
            ],
            if (widget.block.type == 'endurance') ...[
              _buildTextField('목표 거리 (m)', _distanceController),
              const SizedBox(height: 12),
              _buildTextField('목표 시간 (초)', _durationController, isInt: true),
              const SizedBox(height: 12),
            ],
            if (widget.block.type == 'rest' || widget.block.restSeconds != null) ...[
              _buildTextField('휴식 시간 (초)', _restController, isInt: true),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('취소'),
        ),
        ElevatedButton(
          onPressed: _save,
          child: const Text('저장'),
        ),
      ],
    );
  }

  Widget _buildTextField(String label, TextEditingController controller, {bool isInt = false}) {
    return TextField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),
      keyboardType: TextInputType.numberWithOptions(decimal: !isInt),
      inputFormatters: [
        isInt
            ? FilteringTextInputFormatter.digitsOnly
            : FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d*')),
      ],
    );
  }
}
