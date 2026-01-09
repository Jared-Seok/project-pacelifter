import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/cupertino.dart';
import 'package:uuid/uuid.dart';
import '../models/templates/template_block.dart';

class IntervalSetEditDialog extends StatefulWidget {
  final TemplateBlock workBlock;
  final TemplateBlock? restBlock;
  final int currentSets;
  final Function(List<TemplateBlock>) onSave;

  const IntervalSetEditDialog({
    super.key,
    required this.workBlock,
    this.restBlock,
    required this.currentSets,
    required this.onSave,
  });

  @override
  State<IntervalSetEditDialog> createState() => _IntervalSetEditDialogState();
}

class _IntervalSetEditDialogState extends State<IntervalSetEditDialog> {
  // Work Settings
  late TextEditingController _workDistanceController;
  late TextEditingController _workDurationController;
  int _workPaceMinutes = 0;
  int _workPaceSeconds = 0;

  // Rest Settings
  late TextEditingController _restDurationController;
  late TextEditingController _restDistanceController;

  // Sets
  late TextEditingController _setsController;

  bool _isInternalUpdate = false;

  @override
  void initState() {
    super.initState();
    _workDistanceController = TextEditingController(text: widget.workBlock.targetDistance?.toString() ?? '');
    _workDurationController = TextEditingController(text: widget.workBlock.targetDuration?.toString() ?? '');
    
    if (widget.workBlock.targetPace != null) {
      int totalSeconds = widget.workBlock.targetPace!.toInt();
      _workPaceMinutes = totalSeconds ~/ 60;
      _workPaceSeconds = totalSeconds % 60;
    }

    _restDurationController = TextEditingController(text: widget.restBlock?.targetDuration?.toString() ?? '');
    _restDistanceController = TextEditingController(text: widget.restBlock?.targetDistance?.toString() ?? '');
    
    _setsController = TextEditingController(text: widget.currentSets.toString());

    _workDistanceController.addListener(() => _onWorkChanged('distance'));
    _workDurationController.addListener(() => _onWorkChanged('duration'));
  }

  void _onWorkChanged(String source) {
    if (_isInternalUpdate) return;
    
    double distance = double.tryParse(_workDistanceController.text) ?? 0;
    int duration = int.tryParse(_workDurationController.text) ?? 0;
    double paceSecondsPerKm = (_workPaceMinutes * 60 + _workPaceSeconds).toDouble();

    if (paceSecondsPerKm <= 0) return;

    _isInternalUpdate = true;
    if (source == 'distance' && distance > 0) {
      int newDuration = (distance * paceSecondsPerKm / 1000).round();
      _workDurationController.text = newDuration.toString();
    } else if (source == 'duration' && duration > 0) {
      int newDistance = (duration * 1000 / paceSecondsPerKm).round();
      _workDistanceController.text = newDistance.toString();
    } else if (source == 'pace') {
       if (distance > 0) {
        int newDuration = (distance * paceSecondsPerKm / 1000).round();
        _workDurationController.text = newDuration.toString();
      } else if (duration > 0) {
        int newDistance = (duration * 1000 / paceSecondsPerKm).round();
        _workDistanceController.text = newDistance.toString();
      }
    }
    _isInternalUpdate = false;
  }

  @override
  void dispose() {
    _workDistanceController.dispose();
    _workDurationController.dispose();
    _restDurationController.dispose();
    _restDistanceController.dispose();
    _setsController.dispose();
    super.dispose();
  }

  void _save() {
    final sets = int.tryParse(_setsController.text) ?? 1;
    final List<TemplateBlock> newBlocks = [];
    final uuid = const Uuid();

    double? workPace;
    if (_workPaceMinutes > 0 || _workPaceSeconds > 0) {
      workPace = (_workPaceMinutes * 60 + _workPaceSeconds).toDouble();
    }

    for (int i = 1; i <= sets; i++) {
      // Work Block
      newBlocks.add(widget.workBlock.copyWith(
        id: uuid.v4(), // 새 ID 생성
        name: 'Interval Rep $i',
        targetDistance: double.tryParse(_workDistanceController.text),
        targetDuration: int.tryParse(_workDurationController.text),
        targetPace: workPace,
      ));

      // Rest Block
      if (_restDurationController.text.isNotEmpty || _restDistanceController.text.isNotEmpty) {
        // 기존 Rest 블록이 있으면 복사, 없으면 새로 생성 (type: rest or endurance recovery)
        // 보통 Rest는 'rest' 타입이거나 저강도 'endurance'
        final restType = widget.restBlock?.type ?? 'rest'; 
        
        // 만약 기존 Rest 블록이 없다면 기본 템플릿 생성
        final baseRestBlock = widget.restBlock ?? TemplateBlock(
          id: '', 
          name: 'Recovery $i', 
          type: 'rest', 
          order: 0,
        );

        newBlocks.add(baseRestBlock.copyWith(
          id: uuid.v4(),
          name: 'Recovery $i',
          targetDuration: int.tryParse(_restDurationController.text),
          targetDistance: double.tryParse(_restDistanceController.text),
        ));
      }
    }

    Navigator.of(context).pop();
    widget.onSave(newBlocks);
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
                        scrollController: FixedExtentScrollController(initialItem: _workPaceMinutes),
                        onSelectedItemChanged: (int selectedItem) {
                          setState(() {
                            _workPaceMinutes = selectedItem;
                          });
                          _onWorkChanged('pace');
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
                        scrollController: FixedExtentScrollController(initialItem: _workPaceSeconds),
                        onSelectedItemChanged: (int selectedItem) {
                          setState(() {
                            _workPaceSeconds = selectedItem;
                          });
                          _onWorkChanged('pace');
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
                  "$_workPaceMinutes' ${_workPaceSeconds.toString().padLeft(2, '0')}\"",
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
      title: const Text('인터벌 세트 설정'),
      backgroundColor: Theme.of(context).colorScheme.surface,
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('운동 (Work)', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
            const SizedBox(height: 8),
            _buildPaceSelector(),
            const SizedBox(height: 12),
            _buildTextField('목표 거리 (m)', _workDistanceController),
            const SizedBox(height: 12),
            _buildTextField('목표 시간 (초)', _workDurationController, isInt: true),
            
            const Divider(height: 32),
            
            const Text('휴식 (Rest)', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
            const SizedBox(height: 8),
            _buildTextField('휴식 시간 (초)', _restDurationController, isInt: true),
            const SizedBox(height: 12),
            _buildTextField('휴식 거리 (m, 조깅 시)', _restDistanceController),

            const Divider(height: 32),

            const Text('반복 (Sets)', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
            const SizedBox(height: 8),
            _buildTextField('반복 횟수', _setsController, isInt: true),
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
          child: const Text('적용'),
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
            : FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d*')),
      ],
    );
  }
}
