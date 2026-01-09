import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/cupertino.dart';
import '../models/templates/template_block.dart';

class BlockEditDialog extends StatefulWidget {
  final TemplateBlock block;
  final Function(TemplateBlock) onSave;

  // 정적 변수로 클립보드 역할 (앱이 실행되는 동안 유지)
  static TemplateBlock? _copiedBlock;

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
  
  int _paceMinutes = 0;
  int _paceSeconds = 0;
  bool _isInternalUpdate = false;

  @override
  void initState() {
    super.initState();
    _setsController = TextEditingController(text: widget.block.sets?.toString() ?? '');
    _repsController = TextEditingController(text: widget.block.reps?.toString() ?? '');
    _weightController = TextEditingController(text: widget.block.weight?.toString() ?? '');
    _distanceController = TextEditingController(text: widget.block.targetDistance?.toString() ?? '');
    _durationController = TextEditingController(text: widget.block.targetDuration?.toString() ?? '');
    _restController = TextEditingController(text: widget.block.restSeconds?.toString() ?? '');
    
    if (widget.block.targetPace != null) {
      int totalSeconds = widget.block.targetPace!.toInt();
      _paceMinutes = totalSeconds ~/ 60;
      _paceSeconds = totalSeconds % 60;
    }

    _distanceController.addListener(_onDistanceChanged);
    _durationController.addListener(_onDurationChanged);
  }

  void _onDistanceChanged() {
    if (_isInternalUpdate) return;
    _calculateDuration();
  }

  void _onDurationChanged() {
    if (_isInternalUpdate) return;
    _calculateDistance();
  }

  void _calculateDuration() {
    // Distance changed + Pace exists => Calculate Duration
    double distance = double.tryParse(_distanceController.text) ?? 0;
    double paceSecondsPerKm = (_paceMinutes * 60 + _paceSeconds).toDouble();

    if (distance > 0 && paceSecondsPerKm > 0) {
      int duration = (distance * paceSecondsPerKm / 1000).round();
      _updateController(_durationController, duration.toString());
    }
  }

  void _calculateDistance() {
    // Duration changed + Pace exists => Calculate Distance
    int duration = int.tryParse(_durationController.text) ?? 0;
    double paceSecondsPerKm = (_paceMinutes * 60 + _paceSeconds).toDouble();

    if (duration > 0 && paceSecondsPerKm > 0) {
      int distance = (duration * 1000 / paceSecondsPerKm).round();
      _updateController(_distanceController, distance.toString());
    }
  }

  void _onPaceChanged() {
    // Pace changed
    // Priority: If Distance exists, update Duration.
    // Else if Duration exists, update Distance.
    double distance = double.tryParse(_distanceController.text) ?? 0;
    int duration = int.tryParse(_durationController.text) ?? 0;
    double paceSecondsPerKm = (_paceMinutes * 60 + _paceSeconds).toDouble();

    if (paceSecondsPerKm <= 0) return;

    if (distance > 0) {
      int newDuration = (distance * paceSecondsPerKm / 1000).round();
      _updateController(_durationController, newDuration.toString());
    } else if (duration > 0) {
      int newDistance = (duration * 1000 / paceSecondsPerKm).round();
      _updateController(_distanceController, newDistance.toString());
    }
  }

  void _updateController(TextEditingController controller, String value) {
    if (controller.text != value) {
      _isInternalUpdate = true;
      controller.text = value;
      _isInternalUpdate = false;
    }
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

  void _copyBlock() {
    double? targetPace;
    if (_paceMinutes > 0 || _paceSeconds > 0) {
      targetPace = (_paceMinutes * 60 + _paceSeconds).toDouble();
    }

    BlockEditDialog._copiedBlock = widget.block.copyWith(
      sets: int.tryParse(_setsController.text),
      reps: int.tryParse(_repsController.text),
      weight: double.tryParse(_weightController.text),
      targetDistance: double.tryParse(_distanceController.text),
      targetDuration: int.tryParse(_durationController.text),
      restSeconds: int.tryParse(_restController.text),
      targetPace: targetPace,
    );

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('설정이 복사되었습니다'), duration: Duration(seconds: 1)),
    );
    setState(() {});
  }

  void _pasteBlock() {
    final source = BlockEditDialog._copiedBlock;
    if (source == null) return;

    if (source.type != widget.block.type) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('다른 타입의 블록 설정은 붙여넣을 수 없습니다')),
      );
      return;
    }

    setState(() {
      _isInternalUpdate = true; // Prevent triggering listeners during paste
      _setsController.text = source.sets?.toString() ?? '';
      _repsController.text = source.reps?.toString() ?? '';
      _weightController.text = source.weight?.toString() ?? '';
      _distanceController.text = source.targetDistance?.toString() ?? '';
      _durationController.text = source.targetDuration?.toString() ?? '';
      _restController.text = source.restSeconds?.toString() ?? '';
      _isInternalUpdate = false;

      if (source.targetPace != null) {
        int totalSeconds = source.targetPace!.toInt();
        _paceMinutes = totalSeconds ~/ 60;
        _paceSeconds = totalSeconds % 60;
      } else {
        _paceMinutes = 0;
        _paceSeconds = 0;
      }
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('설정이 붙여넣기 되었습니다'), duration: Duration(seconds: 1)),
    );
  }

  void _save() {
    double? targetPace;
    if (_paceMinutes > 0 || _paceSeconds > 0) {
      targetPace = (_paceMinutes * 60 + _paceSeconds).toDouble();
    }

    final updatedBlock = widget.block.copyWith(
      sets: int.tryParse(_setsController.text),
      reps: int.tryParse(_repsController.text),
      weight: double.tryParse(_weightController.text),
      targetDistance: double.tryParse(_distanceController.text),
      targetDuration: int.tryParse(_durationController.text),
      restSeconds: int.tryParse(_restController.text),
      targetPace: targetPace,
    );
    widget.onSave(updatedBlock);
    Navigator.of(context).pop();
  }

  void _showPacePicker() {
    showCupertinoModalPopup(
      context: context,
      builder: (context) => Container(
        height: 320,
        padding: const EdgeInsets.only(top: 6.0),
        color: const Color(0xFF1C1C1E),
        child: SafeArea(
          top: false,
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  CupertinoButton(
                    child: const Text('취소', style: TextStyle(color: Colors.grey)),
                    onPressed: () => Navigator.pop(context),
                  ),
                  const Text('목표 페이스 설정', 
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 18,
                      decoration: TextDecoration.none,
                      color: Colors.white,
                    )
                  ),
                  CupertinoButton(
                    child: Text('확인', style: TextStyle(color: Theme.of(context).colorScheme.primary)),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              Expanded(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Expanded(
                      child: CupertinoPicker(
                        magnification: 1.22,
                        squeeze: 1.2,
                        useMagnifier: true,
                        itemExtent: 32,
                        scrollController: FixedExtentScrollController(initialItem: _paceMinutes),
                        onSelectedItemChanged: (int selectedItem) {
                          setState(() {
                            _paceMinutes = selectedItem;
                          });
                          _onPaceChanged();
                        },
                        children: List<Widget>.generate(30, (int index) {
                          return Center(child: Text('$index', style: const TextStyle(color: Colors.white, fontSize: 20)));
                        }),
                      ),
                    ),
                    const DefaultTextStyle(
                      style: TextStyle(fontSize: 18, color: Colors.white, fontWeight: FontWeight.bold),
                      child: Text("분"),
                    ),
                    Expanded(
                      child: CupertinoPicker(
                        magnification: 1.22,
                        squeeze: 1.2,
                        useMagnifier: true,
                        itemExtent: 32,
                        scrollController: FixedExtentScrollController(initialItem: _paceSeconds),
                        onSelectedItemChanged: (int selectedItem) {
                          setState(() {
                            _paceSeconds = selectedItem;
                          });
                          _onPaceChanged();
                        },
                        children: List<Widget>.generate(60, (int index) {
                          return Center(child: Text(index.toString().padLeft(2, '0'), style: const TextStyle(color: Colors.white, fontSize: 20)));
                        }),
                      ),
                    ),
                    const DefaultTextStyle(
                      style: TextStyle(fontSize: 18, color: Colors.white, fontWeight: FontWeight.bold),
                      child: Text("초"),
                    ),
                    const SizedBox(width: 20),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPaceSelector() {
    return GestureDetector(
      onTap: _showPacePicker,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade700),
          borderRadius: BorderRadius.circular(8),
          color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('목표 페이스', style: TextStyle(fontSize: 16)),
            Row(
              children: [
                Text(
                  "$_paceMinutes' ${_paceSeconds.toString().padLeft(2, '0')}\"",
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
                const SizedBox(width: 8),
                const Icon(Icons.keyboard_arrow_down, size: 20),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      titlePadding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
      title: Row(
        children: [
          Expanded(child: Text('${widget.block.name} 설정')),
          IconButton(
            icon: const Icon(Icons.copy, size: 20),
            onPressed: _copyBlock,
            tooltip: '설정 복사',
          ),
          IconButton(
            icon: const Icon(Icons.paste, size: 20),
            onPressed: BlockEditDialog._copiedBlock != null ? _pasteBlock : null,
            tooltip: '설정 붙여넣기',
            color: BlockEditDialog._copiedBlock != null 
                ? Theme.of(context).colorScheme.primary 
                : Colors.grey,
          ),
        ],
      ),
      backgroundColor: Theme.of(context).colorScheme.surface,
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 16),
            if (widget.block.type == 'strength') ...[
              _buildTextField('세트 수', _setsController, isInt: true),
              const SizedBox(height: 12),
              _buildTextField('반복 횟수 (Reps)', _repsController, isInt: true),
              const SizedBox(height: 12),
              _buildTextField('중량 (kg)', _weightController),
              const SizedBox(height: 12),
            ],
            if (widget.block.type == 'endurance') ...[
              _buildPaceSelector(),
              const SizedBox(height: 16),
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
          child: Text('취소', style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6))),
        ),
        ElevatedButton(
          onPressed: _save,
          style: ElevatedButton.styleFrom(
            backgroundColor: Theme.of(context).colorScheme.primary,
            foregroundColor: Theme.of(context).colorScheme.onSecondary,
          ),
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
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        labelStyle: TextStyle(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7)),
      ),
      keyboardType: TextInputType.numberWithOptions(decimal: !isInt),
      inputFormatters: [
        isInt
            ? FilteringTextInputFormatter.digitsOnly
            : FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d*'))
      ],
    );
  }
}