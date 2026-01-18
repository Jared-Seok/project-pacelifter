import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import '../models/templates/template_block.dart';
import '../utils/workout_ui_utils.dart'; // For color utilities if needed

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
  // Common
  late String _name;
  
  // Strength
  int _sets = 1;
  int _reps = 10;
  double _weight = 0;

  // Endurance
  double _distance = 0;
  int _duration = 0;
  int _paceMinutes = 0;
  int _paceSeconds = 0;
  
  // Rest
  int _restSeconds = 0;

  @override
  void initState() {
    super.initState();
    _name = widget.block.name;
    _sets = widget.block.sets ?? 1;
    _reps = widget.block.reps ?? 10;
    _weight = widget.block.weight ?? 0;
    
    _distance = widget.block.targetDistance ?? 0;
    _duration = widget.block.targetDuration ?? 0;
    _restSeconds = widget.block.restSeconds ?? 0;
    
    // For pure Rest blocks, targetDuration is the rest time
    if (widget.block.type == 'rest') {
      _duration = widget.block.targetDuration ?? 0;
    }

    if (widget.block.targetPace != null) {
      int totalSeconds = widget.block.targetPace!.toInt();
      _paceMinutes = totalSeconds ~/ 60;
      _paceSeconds = totalSeconds % 60;
    }
  }

  void _save() {
    double? targetPace;
    if (_paceMinutes > 0 || _paceSeconds > 0) {
      targetPace = (_paceMinutes * 60 + _paceSeconds).toDouble();
    }

    TemplateBlock updatedBlock = widget.block.copyWith(
      sets: _sets,
      reps: _reps,
      weight: _weight,
      targetDistance: _distance > 0 ? _distance : null,
      targetDuration: _duration > 0 ? _duration : null,
      restSeconds: _restSeconds > 0 ? _restSeconds : null,
      targetPace: targetPace,
    );
    
    // Special handling for Rest type
    if (widget.block.type == 'rest') {
      updatedBlock = updatedBlock.copyWith(
        targetDuration: _duration > 0 ? _duration : null,
        targetDistance: null, // Rest blocks usually don't have distance
      );
    }

    widget.onSave(updatedBlock);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final double height = MediaQuery.of(context).size.height * 0.65;

    return Container(
      height: height,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
      ),
      child: Column(
        children: [
          _buildHeader(),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
              child: Column(
                children: [
                  const SizedBox(height: 16),
                  if (widget.block.type == 'strength') _buildStrengthUI(),
                  if (widget.block.type == 'endurance') _buildEnduranceUI(),
                  if (widget.block.type == 'rest') _buildRestUI(),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
          _buildBottomBar(),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      children: [
        const SizedBox(height: 12),
        Container(
          width: 40,
          height: 5,
          decoration: BoxDecoration(
            color: Colors.grey.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(10),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 10),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  '${_name} 설정',
                  style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
        ),
        const Divider(),
      ],
    );
  }

  Widget _buildStrengthUI() {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _buildValueTile(
                '세트', 
                '$_sets', 
                'sets', 
                isActive: true,
                onTap: () => _showNumberPicker('세트 수', '', _sets, 20, (v) {}, (v) => setState(() => _sets = v)),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildValueTile(
                '횟수', 
                '$_reps', 
                'reps', 
                isActive: true,
                onTap: () => _showNumberPicker('반복 횟수', '', _reps, 100, (v) {}, (v) => setState(() => _reps = v)),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _buildValueTile(
          '중량', 
          '${_weight.toInt()}', 
          'kg', 
          isFullWidth: true,
          onTap: () => _showNumberPicker('중량 설정', 'kg', _weight.toInt(), 300, (v) {}, (v) => setState(() => _weight = v.toDouble()), step: 5),
        ),
      ],
    );
  }

  Widget _buildEnduranceUI() {
    final bool isDistanceSet = _distance > 0;
    final bool isDurationSet = _duration > 0;

    return Column(
      children: [
        // Toggle Logic for Easy Jog / Cool Down: usually distinct choice
        // But allowing both is flexible. We'll use the Card style.
        
        _buildValueTile(
          '목표 거리', 
          '${_distance.toInt()}', 
          'm', 
          isActive: isDistanceSet,
          isFullWidth: true,
          onTap: () => _showNumberPicker(
            '목표 거리', 
            'm', 
            _distance.toInt(), 
            20000, 
            step: 50,
            (v) {}, 
            (v) => setState(() {
               _distance = v.toDouble();
               // Optional: Auto-clear duration if user sets distance, to enforce "one or the other" 
               // for Warmup/CoolDown, but let's keep it flexible or maybe just clear it to avoid confusion.
               if (v > 0) _duration = 0; 
            }),
          ),
        ),
        const SizedBox(height: 12),
        _buildValueTile(
          '목표 시간',
          _formatDuration(_duration),
          '', 
          isActive: isDurationSet,
          isFullWidth: true,
          onTap: () => _showTimePicker(
            '목표 시간', 
            _duration, 
            (v) {}, 
            (v) => setState(() {
              _duration = v;
              if (v > 0) _distance = 0; // Enforce single objective preference
            }),
          ),
        ),
        const SizedBox(height: 24),
        
        // Pace Section (Optional)
        // Collapsible or just a smaller tile
        InkWell(
          onTap: _showPacePicker,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('목표 페이스 (선택)', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
                Text(
                  (_paceMinutes > 0 || _paceSeconds > 0) 
                      ? "$_paceMinutes' ${_paceSeconds.toString().padLeft(2, '0')}\"" 
                      : '설정 안함',
                  style: TextStyle(
                    fontSize: 16, 
                    fontWeight: FontWeight.bold,
                    color: (_paceMinutes > 0 || _paceSeconds > 0) 
                        ? Theme.of(context).colorScheme.primary 
                        : Colors.grey,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRestUI() {
    return Column(
      children: [
        const Icon(Icons.timer_outlined, size: 48, color: Colors.grey),
        const SizedBox(height: 16),
        _buildValueTile(
          '휴식 시간', 
          _formatDuration(_duration), 
          '', 
          isActive: true,
          isFullWidth: true,
          onTap: () => _showTimePicker(
            '휴식 시간', 
            _duration, 
            (v) {}, 
            (v) => setState(() => _duration = v),
          ),
        ),
      ],
    );
  }

  Widget _buildValueTile(String label, String value, String unit, {bool isActive = false, bool isFullWidth = false, required VoidCallback onTap}) {
    final color = isActive ? Theme.of(context).colorScheme.primary : Theme.of(context).colorScheme.onSurface;
    final bgColor = isActive 
        ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.1) 
        : Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.3);
    final borderColor = isActive 
        ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.3) 
        : Colors.transparent;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        width: isFullWidth ? double.infinity : null,
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: borderColor),
        ),
        child: Column(
          children: [
            Text(label, style: TextStyle(fontSize: 12, color: color.withValues(alpha: 0.7), fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  value, 
                  style: TextStyle(
                    fontSize: 28, 
                    fontWeight: FontWeight.w600, 
                    color: color,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
                if (unit.isNotEmpty) ...[
                  const SizedBox(width: 2),
                  Text(unit, style: TextStyle(fontSize: 14, color: color.withValues(alpha: 0.7), fontWeight: FontWeight.w500)),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomBar() {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: SizedBox(
          width: double.infinity,
          height: 56,
          child: FilledButton(
            onPressed: _save,
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.primary,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
            child: const Text('설정 저장', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          ),
        ),
      ),
    );
  }

  String _formatDuration(int seconds) {
    if (seconds == 0) return '0';
    if (seconds >= 60) {
      int min = seconds ~/ 60;
      int sec = seconds % 60;
      return '$min:${sec.toString().padLeft(2, '0')}';
    }
    return '$seconds';
  }

  // --- Pickers (Reused Logic) ---

  void _showNumberPicker(
    String title, 
    String unit, 
    int initialValue, 
    int maxValue, 
    Function(int) onComplete,
    Function(int) onChanged, 
    {int step = 1}
  ) {
    int currentValue = initialValue;
    int initialIndex = initialValue ~/ step;
    
    showCupertinoModalPopup(
      context: context,
      builder: (context) => Container(
        height: 300,
        color: const Color(0xFF1C1C1E),
        child: Column(
          children: [
            _buildPickerHeader(title, () {
              Navigator.pop(context);
              onComplete(currentValue);
            }),
            Expanded(
              child: CupertinoPicker(
                magnification: 1.22,
                squeeze: 1.2,
                useMagnifier: true,
                itemExtent: 32,
                scrollController: FixedExtentScrollController(initialItem: initialIndex),
                onSelectedItemChanged: (int index) {
                  currentValue = index * step;
                  onChanged(currentValue);
                },
                children: List<Widget>.generate((maxValue ~/ step) + 1, (int index) {
                  return Center(
                    child: Text(
                      '${index * step} $unit', 
                      style: const TextStyle(color: Colors.white, fontSize: 20)
                    ),
                  );
                }),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showTimePicker(
    String title, 
    int initialSeconds, 
    Function(int) onComplete,
    Function(int) onChanged,
  ) {
    int min = initialSeconds ~/ 60;
    int sec = initialSeconds % 60;

    showCupertinoModalPopup(
      context: context,
      builder: (context) => Container(
        height: 300,
        color: const Color(0xFF1C1C1E),
        child: Column(
          children: [
            _buildPickerHeader(title, () {
               Navigator.pop(context);
               onComplete(min * 60 + sec);
            }),
            Expanded(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Expanded(
                    child: CupertinoPicker(
                      itemExtent: 32,
                      scrollController: FixedExtentScrollController(initialItem: min),
                      onSelectedItemChanged: (int index) {
                        min = index;
                        onChanged(min * 60 + sec);
                      },
                      children: List<Widget>.generate(120, (int index) {
                        return Center(child: Text('$index', style: const TextStyle(color: Colors.white, fontSize: 20)));
                      }),
                    ),
                  ),
                  const Text('분', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                  Expanded(
                    child: CupertinoPicker(
                      itemExtent: 32,
                      scrollController: FixedExtentScrollController(initialItem: sec),
                      onSelectedItemChanged: (int index) {
                        sec = index;
                        onChanged(min * 60 + sec);
                      },
                      children: List<Widget>.generate(60, (int index) {
                        return Center(child: Text(index.toString().padLeft(2, '0'), style: const TextStyle(color: Colors.white, fontSize: 20)));
                      }),
                    ),
                  ),
                  const Text('초', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showPacePicker() {
    showCupertinoModalPopup(
      context: context,
      builder: (context) => Container(
        height: 300,
        color: const Color(0xFF1C1C1E),
        child: Column(
          children: [
            _buildPickerHeader('목표 페이스', () {
              Navigator.pop(context);
            }),
            Expanded(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Expanded(
                    child: CupertinoPicker(
                      itemExtent: 32,
                      scrollController: FixedExtentScrollController(initialItem: _paceMinutes),
                      onSelectedItemChanged: (int selectedItem) {
                        setState(() {
                          _paceMinutes = selectedItem;
                        });
                      },
                      children: List<Widget>.generate(30, (int index) {
                        return Center(child: Text('$index', style: const TextStyle(color: Colors.white, fontSize: 20)));
                      }),
                    ),
                  ),
                  const Text("분", style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                  Expanded(
                    child: CupertinoPicker(
                      itemExtent: 32,
                      scrollController: FixedExtentScrollController(initialItem: _paceSeconds),
                      onSelectedItemChanged: (int selectedItem) {
                        setState(() {
                          _paceSeconds = selectedItem;
                        });
                      },
                      children: List<Widget>.generate(60, (int index) {
                        return Center(child: Text(index.toString().padLeft(2, '0'), style: const TextStyle(color: Colors.white, fontSize: 20)));
                      }),
                    ),
                  ),
                  const Text("초", style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPickerHeader(String title, VoidCallback onConfirm) {
    return Container(
      height: 56,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: const Color(0xFF1C1C1E),
        border: Border(bottom: BorderSide(color: Colors.white.withValues(alpha: 0.1))),
      ),
      child: Stack(
        children: [
          Center(
            child: Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 17,
                fontWeight: FontWeight.w600,
                letterSpacing: -0.4,
              ),
            ),
          ),
          Align(
            alignment: Alignment.centerRight,
            child: CupertinoButton(
              padding: EdgeInsets.zero,
              minSize: 0,
              onPressed: onConfirm,
              child: Text(
                '완료',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.primary,
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
