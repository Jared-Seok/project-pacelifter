import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:uuid/uuid.dart';
import '../models/templates/template_block.dart';
import '../utils/workout_ui_utils.dart'; // For color utilities if needed

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
  late double _workDistance;
  late int _workDuration;
  int _workPaceMinutes = 0;
  int _workPaceSeconds = 0;

  // Rest Settings
  late int _restDuration;
  // Rest Distance removed from UI, but kept in state if needed or defaulted to 0
  double _restDistance = 0;

  // Sets
  late int _sets;

  bool _isInternalUpdate = false;

  @override
  void initState() {
    super.initState();
    // 기본값 400m 설정 (기존 값이 0일 경우)
    _workDistance = widget.workBlock.targetDistance ?? 400;
    if (_workDistance == 0) _workDistance = 400;
    
    _workDuration = widget.workBlock.targetDuration ?? 0;
    
    if (widget.workBlock.targetPace != null && widget.workBlock.targetPace! > 0) {
      int totalSeconds = widget.workBlock.targetPace!.toInt();
      _workPaceMinutes = totalSeconds ~/ 60;
      _workPaceSeconds = totalSeconds % 60;
    } else {
      // 기본 페이스 4분 30초 설정 (현실적인 인터벌 훈련 기준)
      _workPaceMinutes = 4;
      _workPaceSeconds = 30;
      
      // 거리는 있고 시간이 없는 경우, 4:30 페이스(270초/km) 기준으로 시간 자동 계산
      if (_workDistance > 0) {
        _workDuration = (_workDistance * 270 / 1000).round();
      }
    }

    _restDuration = widget.restBlock?.targetDuration ?? 60; // 휴식 기본 60초
    if (_restDuration == 0) _restDuration = 60;
    
    _sets = widget.currentSets;
  }

  void _onWorkChanged(String source) {
    if (_isInternalUpdate) return;
    
    double paceSecondsPerKm = (_workPaceMinutes * 60 + _workPaceSeconds).toDouble();

    // 페이스가 0이면 계산 불가
    if (paceSecondsPerKm <= 0) return;

    _isInternalUpdate = true;
    setState(() {
      if (source == 'distance' && _workDistance > 0) {
        // 거리 변경 -> 시간 자동 계산 (내부적으로만 저장)
        _workDuration = (_workDistance * paceSecondsPerKm / 1000).round();
      } else if (source == 'pace') {
        // 페이스 변경 -> 거리가 있으면 시간 업데이트
         if (_workDistance > 0) {
          _workDuration = (_workDistance * paceSecondsPerKm / 1000).round();
        } 
      }
    });
    _isInternalUpdate = false;
  }

  void _save() {
    final List<TemplateBlock> newBlocks = [];
    final uuid = const Uuid();

    double? workPace;
    if (_workPaceMinutes > 0 || _workPaceSeconds > 0) {
      workPace = (_workPaceMinutes * 60 + _workPaceSeconds).toDouble();
    }

    for (int i = 1; i <= _sets; i++) {
      // Work Block
      newBlocks.add(widget.workBlock.copyWith(
        id: uuid.v4(),
        name: 'Interval Rep $i',
        targetDistance: _workDistance > 0 ? _workDistance : null,
        targetDuration: _workDuration > 0 ? _workDuration : null,
        targetPace: workPace,
      ));

      // Rest Block
      // Rest는 이제 시간(Duration)만 설정
      if (_restDuration > 0) {
        final baseRestBlock = widget.restBlock ?? TemplateBlock(
          id: '', 
          name: 'Recovery $i',
          type: 'rest',
          order: 0,
        );

        newBlocks.add(baseRestBlock.copyWith(
          id: uuid.v4(),
          name: 'Recovery $i',
          targetDuration: _restDuration > 0 ? _restDuration : null,
          targetDistance: null, // 거리 제거
        ));
      }
    }

    Navigator.of(context).pop();
    widget.onSave(newBlocks);
  }

  String _calculateSpeed(int minutes, int seconds) {
    if (minutes == 0 && seconds == 0) return '0.0';
    double totalHours = (minutes * 60 + seconds) / 3600;
    if (totalHours == 0) return '0.0';
    double speed = 1 / totalHours;
    return speed.toStringAsFixed(1);
  }

  @override
  Widget build(BuildContext context) {
    // Bottom Sheet Height Calculation
    final double height = MediaQuery.of(context).size.height * 0.85; // 높이 85%로 확장

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
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSetsControl(),
                  const SizedBox(height: 32),
                  _buildSectionTitle('RUN / WORK', Icons.directions_run),
                  const SizedBox(height: 12),
                  _buildWorkCard(),
                  const SizedBox(height: 32),
                  _buildSectionTitle('RECOVER / REST', Icons.battery_charging_full),
                  const SizedBox(height: 12),
                  _buildRestCard(),
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
              const Text(
                '인터벌 설정',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const Spacer(),
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

  Widget _buildSectionTitle(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 18, color: Colors.grey),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(
            fontSize: 14, 
            fontWeight: FontWeight.bold, 
            color: Colors.grey,
            letterSpacing: 1.2,
          ),
        ),
      ],
    );
  }

  Widget _buildSetsControl() {
    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(24),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildCircleButton(Icons.remove, () {
              if (_sets > 1) setState(() => _sets--);
            }),
            Container(
              constraints: const BoxConstraints(minWidth: 100),
              child: Column(
                children: [
                  Text(
                    '$_sets',
                    style: const TextStyle(
                      fontSize: 42, 
                      fontWeight: FontWeight.w900, 
                      height: 1.0,
                    ),
                  ),
                  const Text('SETS', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey)),
                ],
              ),
            ),
            _buildCircleButton(Icons.add, () => setState(() => _sets++)),
          ],
        ),
      ),
    );
  }

  Widget _buildCircleButton(IconData icon, VoidCallback onTap) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: Colors.grey.withValues(alpha: 0.3), width: 2),
          ),
          child: Icon(icon, size: 28),
        ),
      ),
    );
  }

  Widget _buildWorkCard() {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          _buildValueTile(
            '목표 거리', 
            '${_workDistance.toInt()}', 
            'm', 
            isActive: true,
            isFullWidth: true, // 전체 너비 사용
                        onTap: () => _showNumberPicker(
                          '거리 설정', 
                          'm', 
                          _workDistance.toInt(), 
                          3000, 
                          step: 100,
                          (val) => _onWorkChanged('distance'), 
                          (val) { setState(() => _workDistance = val.toDouble()); },
                        ),          ),
          const Divider(height: 1),
          _buildPaceTile(),
        ],
      ),
    );
  }

  Widget _buildRestCard() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.withValues(alpha: 0.3)),
      ),
      child: _buildValueTile(
        '휴식 시간', 
        _formatDuration(_restDuration), 
        '', 
        isFullWidth: true, // 전체 너비 사용
        onTap: () => _showTimePicker(
          '휴식 시간', 
          _restDuration, 
          (val) {},
          (val) { setState(() => _restDuration = val); },
        ),
      ),
    );
  }

  Widget _buildValueTile(String label, String value, String unit, {bool isActive = false, bool isFullWidth = false, required VoidCallback onTap}) {
    final color = isActive ? Theme.of(context).colorScheme.primary : Theme.of(context).colorScheme.onSurface;
    
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: isFullWidth ? double.infinity : null,
        padding: const EdgeInsets.symmetric(vertical: 20),
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

  Widget _buildPaceTile() {
    return InkWell(
      onTap: _showPacePicker,
      borderRadius: const BorderRadius.vertical(bottom: Radius.circular(20)),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  '목표 페이스', 
                  style: TextStyle(
                    fontSize: 12, 
                    color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.7), 
                    fontWeight: FontWeight.bold
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    '${_calculateSpeed(_workPaceMinutes, _workPaceSeconds)} km/h',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              "$_workPaceMinutes' ${_workPaceSeconds.toString().padLeft(2, '0')}",
              style: TextStyle(
                fontSize: 24, 
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            Text(
              '/km', 
              style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.5)),
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
            child: const Text('설정 적용', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
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

  // ---

  // --- Pickers ---

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
    // 0m를 허용하지 않으므로, 100m부터 시작하도록 인덱스 조정 (index 0 -> 1*step)
    int initialIndex = (initialValue ~/ step) - 1;
    if (initialIndex < 0) initialIndex = 0;
    
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
                  currentValue = (index + 1) * step; // 0 index -> 100m (if step 100)
                  onChanged(currentValue);
                },
                children: List<Widget>.generate(maxValue ~/ step, (int index) {
                  return Center(
                    child: Text(
                      '${(index + 1) * step} $unit', 
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
    // 인터벌 페이스 제한: 2분 ~ 4분 (최대 4분 59초)
    const int minPaceMinute = 2;
    const int maxPaceMinute = 4;
    int initialPaceIndex = _workPaceMinutes - minPaceMinute;
    if (initialPaceIndex < 0) initialPaceIndex = 0;
    if (initialPaceIndex > (maxPaceMinute - minPaceMinute)) initialPaceIndex = maxPaceMinute - minPaceMinute;

    showCupertinoModalPopup(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) {
          return Container(
            height: 300,
            color: const Color(0xFF1C1C1E),
            child: Column(
              children: [
                _buildPickerHeader(
                  '${_calculateSpeed(_workPaceMinutes, _workPaceSeconds)} km/h', // 헤더에 시속 표시
                  () {
                    Navigator.pop(context);
                    _onWorkChanged('pace');
                  }
                ),
                Expanded(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Expanded(
                        child: CupertinoPicker(
                          itemExtent: 32,
                          scrollController: FixedExtentScrollController(initialItem: initialPaceIndex),
                          onSelectedItemChanged: (int index) {
                            // setState for Dialog (Parent)
                            this.setState(() {
                              _workPaceMinutes = index + minPaceMinute;
                            });
                            // setModalState for Header Update (Self)
                            setModalState(() {});
                            
                            _onWorkChanged('pace'); 
                          },
                          children: List<Widget>.generate(maxPaceMinute - minPaceMinute + 1, (int index) {
                            return Center(child: Text('${index + minPaceMinute}', style: const TextStyle(color: Colors.white, fontSize: 20)));
                          }),
                        ),
                      ),
                      const Text("분", style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                      Expanded(
                        child: CupertinoPicker(
                          itemExtent: 32,
                          scrollController: FixedExtentScrollController(initialItem: _workPaceSeconds),
                          onSelectedItemChanged: (int selectedItem) {
                            this.setState(() {
                              _workPaceSeconds = selectedItem;
                            });
                            setModalState(() {});
                            _onWorkChanged('pace');
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
          );
        }
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
