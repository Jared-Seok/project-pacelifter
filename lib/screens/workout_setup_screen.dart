import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'dart:async';
import 'package:provider/provider.dart';
import '../services/workout_tracking_service.dart';
import 'workout_tracking_screen.dart';

/// 운동 시작 전 세팅 화면 (지도 + 목표 설정)
class WorkoutSetupScreen extends StatefulWidget {
  final String environmentType;
  final String templateName;

  const WorkoutSetupScreen({
    super.key,
    required this.environmentType,
    required this.templateName,
  });

  @override
  State<WorkoutSetupScreen> createState() => _WorkoutSetupScreenState();
}

class _WorkoutSetupScreenState extends State<WorkoutSetupScreen> {
  Position? _currentPosition;
  bool _isLoadingLocation = true;
  String? _locationError;
  GoogleMapController? _mapController;

  late WorkoutTrackingService _workoutService;

  @override
  void initState() {
    super.initState();
    _getCurrentLocation();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _workoutService = Provider.of<WorkoutTrackingService>(context, listen: false);
    // 화면에 들어올 때마다 이전 목표를 초기화
    _workoutService.setGoals(distance: null, time: null, pace: null);
  }

  @override
  void dispose() {
    _mapController?.dispose();
    super.dispose();
  }

  Future<void> _getCurrentLocation() async {
    setState(() {
      _isLoadingLocation = true;
      _locationError = null;
    });

    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          setState(() {
            _locationError = '위치 권한이 거부되었습니다.';
            _isLoadingLocation = false;
          });
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        setState(() {
          _locationError = '위치 권한이 영구적으로 거부되었습니다.\n설정에서 권한을 허용해주세요.';
          _isLoadingLocation = false;
        });
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );

      setState(() {
        _currentPosition = position;
        _isLoadingLocation = false;
      });

      _mapController?.animateCamera(
        CameraUpdate.newLatLng(
          LatLng(position.latitude, position.longitude),
        ),
      );
    } catch (e) {
      setState(() {
        _locationError = '위치를 가져오는데 실패했습니다: $e';
        _isLoadingLocation = false;
      });
    }
  }

  void _showDistancePicker() {
    int km = _workoutService.goalDistance != null ? (_workoutService.goalDistance! / 1000).floor() : 0;
    int m = _workoutService.goalDistance != null ? ((_workoutService.goalDistance! % 1000) / 10).round() : 0;
    bool useKeyboard = false;
    final kmController = TextEditingController(text: km.toString());
    final mController = TextEditingController(text: m.toString().padLeft(2, '0'));

    showCupertinoModalPopup(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) {
          final screenHeight = MediaQuery.of(context).size.height;
          return Container(
            height: screenHeight * 0.5, // 화면 절반 높이
            color: CupertinoColors.systemBackground.resolveFrom(context),
            child: Column(
              children: [
                // 헤더
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      CupertinoButton(
                        child: const Text('취소'),
                        onPressed: () {
                          kmController.dispose();
                          mController.dispose();
                          Navigator.pop(context);
                        },
                      ),
                      CupertinoButton(
                        padding: EdgeInsets.zero,
                        onPressed: () {
                          setModalState(() {
                            useKeyboard = !useKeyboard;
                          });
                        },
                        child: Icon(
                          useKeyboard ? Icons.dialpad : Icons.keyboard,
                          color: Theme.of(context).colorScheme.secondary,
                        ),
                      ),
                      CupertinoButton(
                        child: const Text('설정', style: TextStyle(fontWeight: FontWeight.bold)),
                        onPressed: () {
                          if (useKeyboard) {
                            km = int.tryParse(kmController.text) ?? 0;
                            m = int.tryParse(mController.text) ?? 0;
                          }
                          final distance = km * 1000.0 + m * 10.0;
                          _workoutService.setGoals(distance: distance);
                          kmController.dispose();
                          mController.dispose();
                          Navigator.pop(context);
                        },
                      ),
                    ],
                  ),
                ),
                // 입력 영역
                Expanded(
                  child: useKeyboard
                      ? SingleChildScrollView(
                          child: _buildKeyboardInput(kmController, mController, 'km'),
                        )
                      : _buildPickerInput(km, m, 'km', (index) => km = index, (index) => m = index),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  // 다이얼 입력 위젯
  Widget _buildPickerInput(int value1, int value2, String unit, Function(int) onChanged1, Function(int) onChanged2) {
    final secondaryColor = Theme.of(context).colorScheme.secondary;

    return Stack(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Expanded(
              child: CupertinoPicker(
                itemExtent: 40,
                scrollController: FixedExtentScrollController(initialItem: value1),
                onSelectedItemChanged: onChanged1,
                selectionOverlay: Container(), // 빨간색 선 제거
                children: List.generate(100, (index) => Center(child: Text('$index', style: const TextStyle(fontSize: 20)))),
              ),
            ),
            Text(
              unit == 'km' ? '.' : "'",
              style: TextStyle(fontSize: 20, color: secondaryColor, fontWeight: FontWeight.bold),
            ),
            Expanded(
              child: CupertinoPicker(
                itemExtent: 40,
                scrollController: FixedExtentScrollController(initialItem: value2),
                onSelectedItemChanged: onChanged2,
                selectionOverlay: Container(), // 빨간색 선 제거
                children: List.generate(unit == 'km' ? 100 : 60, (index) => Center(child: Text(index.toString().padLeft(2, '0'), style: const TextStyle(fontSize: 20)))),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(right: 20.0),
              child: Text(
                unit == 'km' ? 'km' : '"',
                style: TextStyle(fontSize: 20, color: secondaryColor, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // 키보드 입력 위젯
  Widget _buildKeyboardInput(TextEditingController controller1, TextEditingController controller2, String unit) {
    final secondaryColor = Theme.of(context).colorScheme.secondary;
    String separator, suffix1, suffix2;

    if (unit == 'km') {
      separator = '.';
      suffix1 = '';
      suffix2 = 'km';
    } else if (unit == 'pace') {
      separator = "'";
      suffix1 = '';
      suffix2 = '"';
    } else { // time
      separator = '';
      suffix1 = '시간';
      suffix2 = '분';
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Expanded(
            child: CupertinoTextField(
              controller: controller1,
              textAlign: TextAlign.center,
              keyboardType: TextInputType.number,
              style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
              decoration: BoxDecoration(
                border: Border.all(color: CupertinoColors.systemGrey),
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
          if (separator.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Text(separator, style: TextStyle(fontSize: 32, color: secondaryColor, fontWeight: FontWeight.bold)),
            ),
          if (suffix1.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(left: 8, right: 12),
              child: Text(suffix1, style: TextStyle(fontSize: 20, color: secondaryColor, fontWeight: FontWeight.bold)),
            ),
          Expanded(
            child: CupertinoTextField(
              controller: controller2,
              textAlign: TextAlign.center,
              keyboardType: TextInputType.number,
              style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
              decoration: BoxDecoration(
                border: Border.all(color: CupertinoColors.systemGrey),
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(left: 8),
            child: Text(suffix2, style: TextStyle(fontSize: 20, color: secondaryColor, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _showPacePicker() {
    int min = _workoutService.goalPace?.minutes ?? 4;
    int sec = _workoutService.goalPace?.seconds ?? 15;
    bool useKeyboard = false;
    final minController = TextEditingController(text: min.toString());
    final secController = TextEditingController(text: sec.toString().padLeft(2, '0'));

    showCupertinoModalPopup(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) {
          final screenHeight = MediaQuery.of(context).size.height;
          return Container(
            height: screenHeight * 0.5, // 화면 절반 높이
            color: CupertinoColors.systemBackground.resolveFrom(context),
            child: Column(
              children: [
                // 헤더
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      CupertinoButton(
                        child: const Text('취소'),
                        onPressed: () {
                          minController.dispose();
                          secController.dispose();
                          Navigator.pop(context);
                        },
                      ),
                      CupertinoButton(
                        padding: EdgeInsets.zero,
                        onPressed: () {
                          setModalState(() {
                            useKeyboard = !useKeyboard;
                          });
                        },
                        child: Icon(
                          useKeyboard ? Icons.dialpad : Icons.keyboard,
                          color: Theme.of(context).colorScheme.secondary,
                        ),
                      ),
                      CupertinoButton(
                        child: const Text('설정', style: TextStyle(fontWeight: FontWeight.bold)),
                        onPressed: () {
                          if (useKeyboard) {
                            min = int.tryParse(minController.text) ?? 0;
                            sec = int.tryParse(secController.text) ?? 0;
                          }
                          _workoutService.setGoals(pace: Pace(minutes: min, seconds: sec));
                          minController.dispose();
                          secController.dispose();
                          Navigator.pop(context);
                        },
                      ),
                    ],
                  ),
                ),
                // 입력 영역
                Expanded(
                  child: useKeyboard
                      ? SingleChildScrollView(
                          child: _buildKeyboardInput(minController, secController, 'pace'),
                        )
                      : _buildPickerInput(min, sec, 'pace', (index) => min = index, (index) => sec = index),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _showTimePicker() {
    int h = _workoutService.goalTime?.inHours ?? 0;
    int m = _workoutService.goalTime?.inMinutes.remainder(60) ?? 0;
    bool useKeyboard = false;
    final hController = TextEditingController(text: h.toString());
    final mController = TextEditingController(text: m.toString().padLeft(2, '0'));

    showCupertinoModalPopup(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) {
          final screenHeight = MediaQuery.of(context).size.height;
          return Container(
            height: screenHeight * 0.5, // 화면 절반 높이
            color: CupertinoColors.systemBackground.resolveFrom(context),
            child: Column(
              children: [
                // 헤더
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      CupertinoButton(
                        child: const Text('취소'),
                        onPressed: () {
                          hController.dispose();
                          mController.dispose();
                          Navigator.pop(context);
                        },
                      ),
                      CupertinoButton(
                        padding: EdgeInsets.zero,
                        onPressed: () {
                          setModalState(() {
                            useKeyboard = !useKeyboard;
                          });
                        },
                        child: Icon(
                          useKeyboard ? Icons.dialpad : Icons.keyboard,
                          color: Theme.of(context).colorScheme.secondary,
                        ),
                      ),
                      CupertinoButton(
                        child: const Text('설정', style: TextStyle(fontWeight: FontWeight.bold)),
                        onPressed: () {
                          if (useKeyboard) {
                            h = int.tryParse(hController.text) ?? 0;
                            m = int.tryParse(mController.text) ?? 0;
                          }
                          final duration = Duration(hours: h, minutes: m);
                          _workoutService.setGoals(time: duration);
                          hController.dispose();
                          mController.dispose();
                          Navigator.pop(context);
                        },
                      ),
                    ],
                  ),
                ),
                // 입력 영역
                Expanded(
                  child: useKeyboard
                      ? SingleChildScrollView(
                          child: _buildKeyboardInput(hController, mController, 'time'),
                        )
                      : _buildPickerInputTime(h, m, (index) => h = index, (index) => m = index),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  // 시간 전용 다이얼 입력 위젯
  Widget _buildPickerInputTime(int hours, int minutes, Function(int) onChangedH, Function(int) onChangedM) {
    final secondaryColor = Theme.of(context).colorScheme.secondary;

    return Stack(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Expanded(
              child: CupertinoPicker(
                itemExtent: 40,
                scrollController: FixedExtentScrollController(initialItem: hours),
                onSelectedItemChanged: onChangedH,
                selectionOverlay: Container(), // 빨간색 선 제거
                children: List.generate(24, (index) => Center(child: Text('$index', style: const TextStyle(fontSize: 20)))),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Text('시간', style: TextStyle(fontSize: 20, color: secondaryColor, fontWeight: FontWeight.bold)),
            ),
            Expanded(
              child: CupertinoPicker(
                itemExtent: 40,
                scrollController: FixedExtentScrollController(initialItem: minutes),
                onSelectedItemChanged: onChangedM,
                selectionOverlay: Container(), // 빨간색 선 제거
                children: List.generate(60, (index) => Center(child: Text(index.toString().padLeft(2, '0'), style: const TextStyle(fontSize: 20)))),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(right: 20.0),
              child: Text('분', style: TextStyle(fontSize: 20, color: secondaryColor, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ],
    );
  }

  // 플레이 버튼 클릭 시 운동 시작 및 추적 화면으로 이동
  void _startWorkout() async {
    // 서비스에서 운동 시작 (카운트다운은 WorkoutTrackingScreen에서 처리)
    await _workoutService.startWorkout();

    if (mounted) {
      // 러닝 추적 화면으로 이동 (카운트다운 포함)
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => const WorkoutTrackingScreen(),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        title: Text(widget.templateName),
        backgroundColor: Theme.of(context).colorScheme.surface,
        foregroundColor: Theme.of(context).colorScheme.onSurface,
      ),
      body: Stack(
        children: [
          Column(
            children: [
              Expanded(
                flex: 3,
                child: Stack(
                  children: [
                    _buildMapSection(),
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      child: Container(
                        height: 50,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.transparent,
                              Theme.of(context).colorScheme.surface,
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                flex: 2,
                child: Consumer<WorkoutTrackingService>(
                  builder: (context, workoutService, child) {
                    return _buildGoalSection(workoutService);
                  },
                ),
              ),
            ],
          ),
        ],
      ),
      floatingActionButton: _currentPosition != null
          ? FloatingActionButton.large(
              onPressed: _startWorkout,
              backgroundColor: Theme.of(context).colorScheme.secondary,
              child: Icon(
                Icons.play_arrow,
                size: 48,
                color: Theme.of(context).colorScheme.onSecondary,
              ),
            )
          : null,
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }

  Widget _buildMapSection() {
    if (_isLoadingLocation) {
      return Container(
        color: Colors.grey[300],
        child: const Center(child: CircularProgressIndicator()),
      );
    }
    if (_locationError != null) {
      return Center(child: Text(_locationError!));
    }
    if (_currentPosition == null) {
      return const Center(child: Text('위치 정보를 가져올 수 없습니다.'));
    }
    return GoogleMap(
      initialCameraPosition: CameraPosition(
        target: LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
        zoom: 16,
      ),
      onMapCreated: (controller) => _mapController = controller,
      myLocationEnabled: true,
      myLocationButtonEnabled: true,
      zoomControlsEnabled: false,
    );
  }

  Widget _buildGoalSection(WorkoutTrackingService workoutService) {
    // 자동 계산된 목표 값들
    final calculatedValues = _calculateMissingGoal(workoutService);

    return Container(
      padding: const EdgeInsets.all(20.0),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.terrain, size: 20, color: Theme.of(context).colorScheme.secondary),
              const SizedBox(width: 8),
              Text(
                widget.environmentType,
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.secondary),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Text('목표 설정', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildGoalButton(
                  label: '거리',
                  value: calculatedValues['distance'] ?? '선택',
                  icon: Icons.straighten,
                  onTap: _showDistancePicker,
                  isCalculated: calculatedValues['distanceCalculated'] == true,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildGoalButton(
                  label: '페이스',
                  value: calculatedValues['pace'] ?? '선택',
                  icon: Icons.speed,
                  onTap: _showPacePicker,
                  isCalculated: calculatedValues['paceCalculated'] == true,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildGoalButton(
                  label: '시간',
                  value: calculatedValues['time'] ?? '선택',
                  icon: Icons.timer,
                  onTap: _showTimePicker,
                  isCalculated: calculatedValues['timeCalculated'] == true,
                ),
              ),
            ],
          ),
          const SizedBox(height: 60), // 플로팅 버튼 공간 확보
        ],
      ),
    );
  }

  // 자동 계산 로직: 2개 목표 설정 시 나머지 1개 자동 계산
  Map<String, dynamic> _calculateMissingGoal(WorkoutTrackingService service) {
    final hasDistance = service.goalDistance != null;
    final hasPace = service.goalPace != null;
    final hasTime = service.goalTime != null;

    String? distanceValue;
    String? paceValue;
    String? timeValue;
    bool distanceCalculated = false;
    bool paceCalculated = false;
    bool timeCalculated = false;

    // 거리 + 페이스 설정 → 시간 자동 계산
    if (hasDistance && hasPace && !hasTime) {
      distanceValue = '${(service.goalDistance! / 1000).toStringAsFixed(2)} km';
      paceValue = service.goalPace.toString();

      final distanceKm = service.goalDistance! / 1000;
      final paceMinutes = service.goalPace!.minutes + (service.goalPace!.seconds / 60);
      final totalMinutes = (distanceKm * paceMinutes).round();
      final calculatedTime = Duration(minutes: totalMinutes);

      timeValue = _formatDuration(calculatedTime);
      timeCalculated = true;
    }
    // 거리 + 시간 설정 → 페이스 자동 계산
    else if (hasDistance && hasTime && !hasPace) {
      distanceValue = '${(service.goalDistance! / 1000).toStringAsFixed(2)} km';
      timeValue = _formatDuration(service.goalTime!);

      final distanceKm = service.goalDistance! / 1000;
      final totalMinutes = service.goalTime!.inMinutes;
      final paceMinutes = (totalMinutes / distanceKm);
      final paceMin = paceMinutes.floor();
      final paceSec = ((paceMinutes - paceMin) * 60).round();

      paceValue = '$paceMin:${paceSec.toString().padLeft(2, '0')}';
      paceCalculated = true;
    }
    // 페이스 + 시간 설정 → 거리 자동 계산
    else if (hasPace && hasTime && !hasDistance) {
      paceValue = service.goalPace.toString();
      timeValue = _formatDuration(service.goalTime!);

      final paceMinutes = service.goalPace!.minutes + (service.goalPace!.seconds / 60);
      final totalMinutes = service.goalTime!.inMinutes;
      final calculatedDistanceKm = totalMinutes / paceMinutes;

      distanceValue = '${calculatedDistanceKm.toStringAsFixed(2)} km';
      distanceCalculated = true;
    }
    // 일반적인 경우 (계산 없이 직접 설정된 값 표시)
    else {
      distanceValue = hasDistance ? '${(service.goalDistance! / 1000).toStringAsFixed(2)} km' : '선택';
      paceValue = hasPace ? service.goalPace.toString() : '선택';
      timeValue = hasTime ? _formatDuration(service.goalTime!) : '선택';
    }

    return {
      'distance': distanceValue,
      'pace': paceValue,
      'time': timeValue,
      'distanceCalculated': distanceCalculated,
      'paceCalculated': paceCalculated,
      'timeCalculated': timeCalculated,
    };
  }

  Widget _buildGoalButton({
    required String label,
    required String value,
    required IconData icon,
    required VoidCallback onTap,
    bool isCalculated = false, // 자동 계산된 값인지 여부
  }) {
    final hasValue = value != '선택';
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          color: hasValue ? Theme.of(context).colorScheme.secondary.withValues(alpha: 0.1) : Colors.grey.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: hasValue ? Theme.of(context).colorScheme.secondary : Colors.grey,
            width: hasValue ? 2 : 1,
          ),
        ),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 16, color: hasValue ? Theme.of(context).colorScheme.secondary : Colors.grey),
                const SizedBox(width: 4),
                Text(label, style: TextStyle(fontSize: 12, color: hasValue ? Theme.of(context).colorScheme.secondary : Colors.grey)),
                if (isCalculated) ...[
                  const SizedBox(width: 4),
                  Icon(
                    Icons.auto_awesome,
                    size: 12,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ],
              ],
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: hasValue ? Theme.of(context).colorScheme.onSurface : Colors.grey,
                fontStyle: isCalculated ? FontStyle.italic : FontStyle.normal,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, "0");
    String twoDigitMinutes = twoDigits(duration.inMinutes.remainder(60));
    String twoDigitSeconds = twoDigits(duration.inSeconds.remainder(60));
    return "${twoDigits(duration.inHours)}:$twoDigitMinutes:$twoDigitSeconds";
  }
}
