import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:math';

class HorizontalRulerPicker extends StatefulWidget {
  final double minValue;
  final double maxValue;
  final double initialValue;
  final double? value; // 외부에서 제어하기 위한 현재 값
  final double step; // 💡 스텝 값 파라미터 추가
  final ValueChanged<double> onChanged;
  final Color? color;

  const HorizontalRulerPicker({
    super.key,
    this.minValue = 0.0,
    this.maxValue = 50.0,
    this.initialValue = 5.0,
    this.value,
    this.step = 0.1, // 기본값 0.1
    required this.onChanged,
    this.color,
  });

  @override
  State<HorizontalRulerPicker> createState() => _HorizontalRulerPickerState();
}

class _HorizontalRulerPickerState extends State<HorizontalRulerPicker> {
  late FixedExtentScrollController _controller;
  late double _currentValue;
  bool _isAnimating = false;
  
  static const double _itemWidth = 12.0;

  @override
  void initState() {
    super.initState();
    _currentValue = widget.value ?? widget.initialValue;
    int initialIndex = ((_currentValue - widget.minValue) / widget.step).round();
    _controller = FixedExtentScrollController(initialItem: initialIndex);
  }

  @override
  void didUpdateWidget(HorizontalRulerPicker oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 외부에서 값이 명시적으로 변경되었을 때만 이동 (소수점 오차 방지 포함)
    if (widget.value != null && (widget.value! - oldWidget.value!).abs() > (widget.step / 2)) {
      _animateToValue(widget.value!);
    }
  }

  void _animateToValue(double val) {
    if (!_controller.hasClients) return;
    
    int index = ((val - widget.minValue) / widget.step).round();
    if (_controller.selectedItem == index) return;

    _isAnimating = true;
    _currentValue = val;
    _controller.animateToItem(
      index,
      duration: const Duration(milliseconds: 600),
      curve: Curves.easeOutCubic,
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
    final int totalItems = ((widget.maxValue - widget.minValue) / widget.step).round() + 1;

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
                if (_isAnimating) return;
                
                double newValue = widget.minValue + (index * widget.step);
                if ((newValue - _currentValue).abs() > (widget.step / 2)) {
                  _currentValue = newValue;
                  widget.onChanged(newValue);
                  HapticFeedback.selectionClick();
                }
              },
              childDelegate: ListWheelChildBuilderDelegate(
                childCount: totalItems,
                builder: (context, index) {
                  double value = widget.minValue + (index * widget.step);
                  // 스텝에 따라 메이저 눈금 표시 로직 유동적으로 변경
                  bool isMajor;
                  bool isHalf;
                  
                  if (widget.step >= 1.0) {
                     // 1단위 이상일 때 (예: 시간 분 단위)
                     isMajor = value % 10 == 0;
                     isHalf = value % 5 == 0 && !isMajor;
                  } else {
                     // 0.1 단위일 때 (거리)
                     isMajor = (value * 10).round() % 10 == 0;
                     isHalf = (value * 10).round() % 5 == 0 && !isMajor;
                  }

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
                          // 💡 숫자가 12px 너비를 넘어 가로로 정상 표시되도록 OverflowBox 적용
                          SizedBox(
                            width: 12,
                            child: OverflowBox(
                              maxWidth: 50, // 충분한 가로 공간 확보
                              child: Text(
                                value.toInt().toString(),
                                softWrap: false, // 줄바꿈 방지
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: themeColor,
                                ),
                              ),
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
