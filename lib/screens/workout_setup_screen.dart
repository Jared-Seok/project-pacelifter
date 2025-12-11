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

  // 카운트다운 상태
  bool _isCountingDown = false;
  int _countdown = 3;
  Timer? _countdownTimer;

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
    _countdownTimer?.cancel();
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

    showCupertinoModalPopup(
      context: context,
      builder: (context) => Container(
        height: 300,
        color: CupertinoColors.systemBackground.resolveFrom(context),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                CupertinoButton(
                  child: const Text('취소'),
                  onPressed: () => Navigator.pop(context),
                ),
                CupertinoButton(
                  child: const Text('설정', style: TextStyle(fontWeight: FontWeight.bold)),
                  onPressed: () {
                    final distance = km * 1000.0 + m * 10.0;
                    _workoutService.setGoals(distance: distance);
                    Navigator.pop(context);
                  },
                ),
              ],
            ),
            Expanded(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Expanded(
                    child: CupertinoPicker(
                      itemExtent: 32,
                      scrollController: FixedExtentScrollController(initialItem: km),
                      onSelectedItemChanged: (index) => km = index,
                      children: List.generate(100, (index) => Center(child: Text('$index'))),
                    ),
                  ),
                  const Text('.'),
                  Expanded(
                    child: CupertinoPicker(
                      itemExtent: 32,
                      scrollController: FixedExtentScrollController(initialItem: m),
                      onSelectedItemChanged: (index) => m = index,
                      children: List.generate(100, (index) => Center(child: Text(index.toString().padLeft(2, '0')))),
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.only(right: 20.0),
                    child: Text('km'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showPacePicker() {
    int min = _workoutService.goalPace?.minutes ?? 4;
    int sec = _workoutService.goalPace?.seconds ?? 15;

    showCupertinoModalPopup(
      context: context,
      builder: (context) => Container(
        height: 300,
        color: CupertinoColors.systemBackground.resolveFrom(context),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                CupertinoButton(
                  child: const Text('취소'),
                  onPressed: () => Navigator.pop(context),
                ),
                CupertinoButton(
                  child: const Text('설정', style: TextStyle(fontWeight: FontWeight.bold)),
                  onPressed: () {
                    _workoutService.setGoals(pace: Pace(minutes: min, seconds: sec));
                    Navigator.pop(context);
                  },
                ),
              ],
            ),
            Expanded(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Expanded(
                    child: CupertinoPicker(
                      itemExtent: 32,
                      scrollController: FixedExtentScrollController(initialItem: min),
                      onSelectedItemChanged: (index) => min = index,
                      children: List.generate(20, (index) => Center(child: Text('$index'))),
                    ),
                  ),
                  const Text("'"),
                  Expanded(
                    child: CupertinoPicker(
                      itemExtent: 32,
                      scrollController: FixedExtentScrollController(initialItem: sec),
                      onSelectedItemChanged: (index) => sec = index,
                      children: List.generate(60, (index) => Center(child: Text(index.toString().padLeft(2, '0')))),
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.only(right: 20.0),
                    child: Text('"'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showTimePicker() {
    int h = _workoutService.goalTime?.inHours ?? 0;
    int m = _workoutService.goalTime?.inMinutes.remainder(60) ?? 0;

    showCupertinoModalPopup(
      context: context,
      builder: (context) => Container(
        height: 300,
        color: CupertinoColors.systemBackground.resolveFrom(context),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                CupertinoButton(
                  child: const Text('취소'),
                  onPressed: () => Navigator.pop(context),
                ),
                CupertinoButton(
                  child: const Text('설정', style: TextStyle(fontWeight: FontWeight.bold)),
                  onPressed: () {
                    final duration = Duration(hours: h, minutes: m);
                    _workoutService.setGoals(time: duration);
                    Navigator.pop(context);
                  },
                ),
              ],
            ),
            Expanded(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Expanded(
                    child: CupertinoPicker(
                      itemExtent: 32,
                      scrollController: FixedExtentScrollController(initialItem: h),
                      onSelectedItemChanged: (index) => h = index,
                      children: List.generate(24, (index) => Center(child: Text('$index'))),
                    ),
                  ),
                  const Text('시간'),
                  Expanded(
                    child: CupertinoPicker(
                      itemExtent: 32,
                      scrollController: FixedExtentScrollController(initialItem: m),
                      onSelectedItemChanged: (index) => m = index,
                      children: List.generate(60, (index) => Center(child: Text(index.toString().padLeft(2, '0')))),
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.only(right: 20.0),
                    child: Text('분'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 플레이 버튼 클릭 시 카운트다운 시작
  void _startCountdown() {
    setState(() {
      _isCountingDown = true;
      _countdown = 3;
    });

    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) async {
      if (_countdown > 1) {
        setState(() {
          _countdown--;
        });
      } else {
        timer.cancel();
        // 카운트다운 종료 후 서비스에서 운동 시작
        await _workoutService.startWorkout();

        if (mounted) {
          // 러닝 추적 화면으로 이동
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => const WorkoutTrackingScreen(),
            ),
          );
        }
      }
    });
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
          if (_isCountingDown)
            Container(
              color: Colors.black,
              child: Center(
                child: Text(
                  _countdown.toString(),
                  style: TextStyle(
                    fontFamily: 'Roboto',
                    fontSize: 180,
                    fontWeight: FontWeight.w900,
                    color: Theme.of(context).colorScheme.secondary,
                  ),
                ),
              ),
            ),
        ],
      ),
      floatingActionButton: _currentPosition != null && !_isCountingDown
          ? FloatingActionButton.large(
              onPressed: _startCountdown,
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
    return Container(
      padding: const EdgeInsets.all(20.0),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
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
                  value: workoutService.goalDistance != null ? '${(workoutService.goalDistance! / 1000).toStringAsFixed(2)} km' : '선택',
                  icon: Icons.straighten,
                  onTap: _showDistancePicker,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildGoalButton(
                  label: '페이스',
                  value: workoutService.goalPace != null ? workoutService.goalPace.toString() : '선택',
                  icon: Icons.speed,
                  onTap: _showPacePicker,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildGoalButton(
                  label: '시간',
                  value: workoutService.goalTime != null ? _formatDuration(workoutService.goalTime!) : '선택',
                  icon: Icons.timer,
                  onTap: _showTimePicker,
                ),
              ),
            ],
          ),
          const SizedBox(height: 60), // 플로팅 버튼 공간 확보
        ],
      ),
    );
  }

  Widget _buildGoalButton({
    required String label,
    required String value,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    final hasValue = value != '선택';
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          color: hasValue ? Theme.of(context).colorScheme.secondary.withOpacity(0.1) : Colors.grey.withOpacity(0.1),
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
              ],
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: hasValue ? Theme.of(context).colorScheme.onSurface : Colors.grey),
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
