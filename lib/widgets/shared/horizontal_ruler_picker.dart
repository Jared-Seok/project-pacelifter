import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:math';

class HorizontalRulerPicker extends StatefulWidget {
  final double minValue;
  final double maxValue;
  final double initialValue;
  final double? value; // 외부에서 제어하기 위한 현재 값
  final ValueChanged<double> onChanged;
  final Color? color;

  const HorizontalRulerPicker({
    super.key,
    this.minValue = 0.0,
    this.maxValue = 50.0,
    this.initialValue = 5.0,
    this.value,
    required this.onChanged,
    this.color,
  });

  @override
  State<HorizontalRulerPicker> createState() => _HorizontalRulerPickerState();
}

class _HorizontalRulerPickerState extends State<HorizontalRulerPicker> {
  late FixedExtentScrollController _controller;
  late double _currentValue;
  bool _isAnimating = false; // 💡 애니메이션 중인지 여부 플래그
  
  static const double _step = 0.1;
  static const double _itemWidth = 12.0;

  @override
  void initState() {
    super.initState();
    _currentValue = widget.value ?? widget.initialValue;
    int initialIndex = ((_currentValue - widget.minValue) / _step).round();
    _controller = FixedExtentScrollController(initialItem: initialIndex);
  }

  @override
  void didUpdateWidget(HorizontalRulerPicker oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 외부에서 값이 명시적으로 변경되었을 때만 이동 (소수점 오차 방지 포함)
    if (widget.value != null && (widget.value! - oldWidget.value!).abs() > 0.01) {
      _animateToValue(widget.value!);
    }
  }

  void _animateToValue(double val) {
    if (!_controller.hasClients) return;
    
    int index = ((val - widget.minValue) / _step).round();
    if (_controller.selectedItem == index) return; // 💡 이미 해당 위치면 무시

    _isAnimating = true;
    _currentValue = val;
    _controller.animateToItem(
      index,
      duration: const Duration(milliseconds: 600),
      curve: Curves.easeOutCubic, // 💡 더 안정적인 곡선으로 변경
    ).then((_) {
      _isAnimating = false;
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final themeColor = widget.color ?? Theme.of(context).colorScheme.tertiary;
    final int totalItems = ((widget.maxValue - widget.minValue) / _step).round() + 1;

    return SizedBox(
      height: 100,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // 1. Background Grid/Ruler
          RotatedBox(
            quarterTurns: -1,
            child: ListWheelScrollView.useDelegate(
              controller: _controller,
              itemExtent: _itemWidth,
              diameterRatio: 3.0,
              physics: const FixedExtentScrollPhysics(),
              onSelectedItemChanged: (index) {
                if (_isAnimating) return; // 💡 외부 제어로 이동 중일 때는 이벤트 무시 (무한 루프 방지)
                
                double newValue = widget.minValue + (index * _step);
                if ((newValue - _currentValue).abs() > 0.05) { // 💡 임계값을 조금 더 줌
                  _currentValue = newValue;
                  widget.onChanged(newValue);
                  HapticFeedback.selectionClick();
                }
              },
              childDelegate: ListWheelChildBuilderDelegate(
                childCount: totalItems,
                builder: (context, index) {
                  double value = widget.minValue + (index * _step);
                  bool isMajor = (value * 10).round() % 10 == 0;
                  bool isHalf = (value * 10).round() % 5 == 0 && !isMajor;

                  return RotatedBox(
                    quarterTurns: 1,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 2,
                          height: isMajor ? 40 : (isHalf ? 25 : 15),
                          decoration: BoxDecoration(
                            color: isMajor 
                                ? themeColor 
                                : themeColor.withOpacity(0.3),
                            borderRadius: BorderRadius.circular(1),
                          ),
                        ),
                        const SizedBox(height: 8),
                        if (isMajor)
                          Text(
                            value.toInt().toString(),
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: themeColor,
                            ),
                          )
                        else
                          const SizedBox(height: 17),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
          
          // 2. Center Indicator (Needle)
          IgnorePointer(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 3,
                  height: 60,
                  decoration: BoxDecoration(
                    color: themeColor,
                    borderRadius: BorderRadius.circular(2),
                    boxShadow: [
                      BoxShadow(
                        color: themeColor.withOpacity(0.5),
                        blurRadius: 8,
                        spreadRadius: 1,
                      )
                    ],
                  ),
                ),
                const SizedBox(height: 30),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
