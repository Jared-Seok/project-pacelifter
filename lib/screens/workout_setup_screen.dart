import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'dart:async';
import 'package:provider/provider.dart';
import '../services/workout_tracking_service.dart';
import '../models/templates/workout_template.dart';
import '../models/templates/template_block.dart';
import 'workout_tracking_screen.dart';
import '../widgets/block_edit_dialog.dart';

/// 운동 시작 전 세팅 및 커스터마이징 화면
class WorkoutSetupScreen extends StatefulWidget {
  final WorkoutTemplate template;

  const WorkoutSetupScreen({
    super.key,
    required this.template,
  });

  @override
  State<WorkoutSetupScreen> createState() => _WorkoutSetupScreenState();
}

class _WorkoutSetupScreenState extends State<WorkoutSetupScreen> {
  // 위치 관련 상태
  Position? _currentPosition;
  bool _isLoadingLocation = true;
  String? _locationError;
  GoogleMapController? _mapController;
  
  // 템플릿 상태 (딥 카피)
  late WorkoutTemplate _editableTemplate;
  
  late WorkoutTrackingService _workoutService;

  @override
  void initState() {
    super.initState();
    
    // 템플릿 딥 카피 생성 (toJson -> fromJson)
    // 이렇게 하면 원본 Hive 객체를 건드리지 않고 이 화면에서만 수정 가능
    _editableTemplate = WorkoutTemplate.fromJson(widget.template.toJson());

    // 맵이 필요한 환경인지 확인 (Outdoor, Track)
    if (_shouldShowMap()) {
      _getCurrentLocation();
    } else {
      _isLoadingLocation = false;
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _workoutService = Provider.of<WorkoutTrackingService>(context, listen: false);
    // 화면에 들어올 때마다 서비스의 목표 초기화 (템플릿 기반으로 자동 설정 가능하나 일단 초기화)
    _workoutService.setGoals(distance: null, time: null, pace: null);
  }

  @override
  void dispose() {
    _mapController?.dispose();
    super.dispose();
  }

  bool _shouldShowMap() {
    final env = widget.template.environmentType;
    return env == 'Outdoor' || env == 'Track';
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

  // 플레이 버튼 클릭 시 운동 시작
  void _startWorkout() async {
    // 서비스에서 운동 시작
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        title: Text(widget.template.name),
        backgroundColor: Theme.of(context).colorScheme.surface,
        foregroundColor: Theme.of(context).colorScheme.onSurface,
      ),
      body: Column(
        children: [
          // 1. 상단 섹션 (맵 또는 템플릿 정보) - 크기 축소 (flex 2)
          Expanded(
            flex: 2,
            child: _shouldShowMap() ? _buildMapSection() : _buildTemplateInfoSection(),
          ),
          
          // 2. 하단 섹션 (커스터마이징 및 목표 설정) - 공간 확대 (flex 5)
          Expanded(
            flex: 5,
            child: Container(
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
              child: DefaultTabController(
                length: 2,
                child: Column(
                  children: [
                    const TabBar(
                      tabs: [
                        Tab(text: '세부 조정'),
                        Tab(text: '전체 목표'),
                      ],
                    ),
                    Expanded(
                      child: TabBarView(
                        children: [
                          _buildCustomizationTab(),
                          _buildGlobalGoalTab(),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
          child: _shouldShowMap() && _currentPosition == null && _locationError == null
              ? const SizedBox(
                  height: 60,
                  child: Center(child: CircularProgressIndicator()),
                )
              : SizedBox(
                  height: 60,
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _startWorkout,
                    style: FilledButton.styleFrom(
                      backgroundColor: Theme.of(context).colorScheme.secondary,
                      foregroundColor: Theme.of(context).colorScheme.onSecondary,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      elevation: 4,
                    ),
                    icon: const Icon(Icons.play_arrow, size: 28),
                    label: const Text(
                      '운동 시작',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ),
                ),
        ),
      ),
    );
  }

  // 맵 위젯
  Widget _buildMapSection() {
    if (_isLoadingLocation) {
      return Container(
        color: Colors.grey[900],
        child: const Center(child: CircularProgressIndicator()),
      );
    }
    if (_locationError != null) {
      return Container(
        color: Colors.grey[900],
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Text(
              _locationError!, 
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white70),
            ),
          ),
        ),
      );
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

  // 맵이 없을 때 보여줄 템플릿 정보 섹션
  Widget _buildTemplateInfoSection() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
        border: Border(
          bottom: BorderSide(
            color: Theme.of(context).colorScheme.outlineVariant,
            width: 1,
          ),
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _buildCategoryIcon(
            _editableTemplate.category,
            size: 48, // 크기 살짝 축소
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(height: 12),
          Text(
            _editableTemplate.description,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.8),
            ),
          ),
          const SizedBox(height: 12),
          // 칩 형태로 태그 표시
          Wrap(
            spacing: 8,
            children: [
              _buildSmallChip(_editableTemplate.category),
              if (_editableTemplate.subCategory != null)
                _buildSmallChip(_editableTemplate.subCategory!),
              if (_editableTemplate.environmentType != null)
                _buildSmallChip(_editableTemplate.environmentType!),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSmallChip(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.secondary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Theme.of(context).colorScheme.secondary.withValues(alpha: 0.3),
        ),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          color: Theme.of(context).colorScheme.secondary,
        ),
      ),
    );
  }

  Widget _buildCategoryIcon(String category, {double size = 24, Color? color}) {
    final effectiveColor = color ?? Theme.of(context).colorScheme.primary;
    switch (category) {
      case 'Endurance':
        return SvgPicture.asset(
          'assets/images/endurance/runner-icon.svg',
          width: size,
          height: size,
          colorFilter: ColorFilter.mode(effectiveColor, BlendMode.srcIn),
        );
      case 'Strength':
        return SvgPicture.asset(
          'assets/images/strength/lifter-icon.svg',
          width: size,
          height: size,
          colorFilter: ColorFilter.mode(effectiveColor, BlendMode.srcIn),
        );
      case 'Hybrid':
        return Icon(Icons.layers, size: size, color: effectiveColor);
      default:
        return Icon(Icons.fitness_center, size: size, color: effectiveColor);
    }
  }

  // 탭 1: 세부 조정 (Phases & Blocks)
  Widget _buildCustomizationTab() {
    return ListView.builder(
      padding: const EdgeInsets.all(16), // Padding 축소 (하단 가림 없음)
      itemCount: _editableTemplate.phases.length,
      itemBuilder: (context, phaseIndex) {
        final phase = _editableTemplate.phases[phaseIndex];
        return Card(
          margin: const EdgeInsets.only(bottom: 16),
          child: ExpansionTile(
            title: Text(
              phase.name,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Text('${phase.blocks.length} blocks'),
            initiallyExpanded: true,
            children: phase.blocks.asMap().entries.map((entry) {
              final blockIndex = entry.key;
              final block = entry.value;
              return _buildBlockItem(block, phaseIndex, blockIndex);
            }).toList(),
          ),
        );
      },
    );
  }

  Widget _buildBlockItem(TemplateBlock block, int phaseIndex, int blockIndex) {
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: Theme.of(context).colorScheme.secondary.withValues(alpha: 0.2),
        child: _buildBlockIcon(
          block.type,
          size: 16,
          color: Theme.of(context).colorScheme.secondary,
        ),
      ),
      title: Text(block.name),
      subtitle: Text(_getBlockSummary(block)),
      trailing: IconButton(
        icon: const Icon(Icons.edit, size: 20),
        onPressed: () => _showEditBlockDialog(block, phaseIndex, blockIndex),
      ),
    );
  }

  Widget _buildBlockIcon(String type, {double size = 24, Color? color}) {
    final effectiveColor = color ?? Theme.of(context).colorScheme.secondary;
    if (type == 'strength') {
      return SvgPicture.asset(
        'assets/images/strength/lifter-icon.svg',
        width: size,
        height: size,
        colorFilter: ColorFilter.mode(effectiveColor, BlendMode.srcIn),
      );
    }
    if (type == 'endurance') {
      return SvgPicture.asset(
        'assets/images/endurance/runner-icon.svg',
        width: size,
        height: size,
        colorFilter: ColorFilter.mode(effectiveColor, BlendMode.srcIn),
      );
    }
    if (type == 'rest') return Icon(Icons.timer, size: size, color: effectiveColor);
    return Icon(Icons.circle, size: size, color: effectiveColor);
  }

  String _getBlockSummary(TemplateBlock block) {
    if (block.type == 'strength') {
      return '${block.sets} sets x ${block.reps} reps @ ${block.weight ?? 0}kg';
    } else if (block.type == 'endurance') {
      if (block.targetDistance != null) return '${block.targetDistance}m';
      if (block.targetDuration != null) return '${block.targetDuration}s';
      return 'Free Run';
    } else {
      return '${block.targetDuration ?? 0}s Rest';
    }
  }

  void _showEditBlockDialog(TemplateBlock block, int phaseIndex, int blockIndex) {
    showDialog(
      context: context,
      builder: (context) => BlockEditDialog(
        block: block,
        onSave: (updatedBlock) {
          setState(() {
            // 해당 블록만 업데이트
            // 리스트는 레퍼런스 타입이므로 새 리스트로 교체하여 불변성 유지 권장
            final updatedBlocks = List<TemplateBlock>.from(_editableTemplate.phases[phaseIndex].blocks);
            updatedBlocks[blockIndex] = updatedBlock;
            
            // 페이즈 업데이트
            final updatedPhase = _editableTemplate.phases[phaseIndex].copyWith(blocks: updatedBlocks);
            _editableTemplate.phases[phaseIndex] = updatedPhase;
          });
        },
      ),
    );
  }

  // 탭 2: 전체 목표 (기존 로직 유지)
  Widget _buildGlobalGoalTab() {
    return Consumer<WorkoutTrackingService>(
      builder: (context, workoutService, child) {
        final calculatedValues = _calculateMissingGoal(workoutService);
        return SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              const Text('전체 운동 목표 설정', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 20),
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
            ],
          ),
        );
      },
    );
  }

  // 기존 목표 설정 관련 메서드들 (동일하게 유지)
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
            height: screenHeight * 0.5,
            color: CupertinoColors.systemBackground.resolveFrom(context),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      CupertinoButton(child: const Text('취소'), onPressed: () => Navigator.pop(context)),
                      CupertinoButton(
                        child: Icon(useKeyboard ? Icons.dialpad : Icons.keyboard),
                        onPressed: () => setModalState(() => useKeyboard = !useKeyboard),
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
                          Navigator.pop(context);
                        },
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: useKeyboard
                      ? SingleChildScrollView(child: _buildKeyboardInput(kmController, mController, 'km'))
                      : _buildPickerInput(km, m, 'km', (index) => km = index, (index) => m = index),
                ),
              ],
            ),
          );
        },
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

              height: screenHeight * 0.5,

              color: CupertinoColors.systemBackground.resolveFrom(context),

              child: Column(

                children: [

                  Container(

                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),

                    child: Row(

                      mainAxisAlignment: MainAxisAlignment.spaceBetween,

                      children: [

                        CupertinoButton(child: const Text('취소'), onPressed: () => Navigator.pop(context)),

                        CupertinoButton(

                          child: Icon(useKeyboard ? Icons.dialpad : Icons.keyboard),

                          onPressed: () => setModalState(() => useKeyboard = !useKeyboard),

                        ),

                        CupertinoButton(

                          child: const Text('설정', style: TextStyle(fontWeight: FontWeight.bold)),

                          onPressed: () {

                            if (useKeyboard) {

                              min = int.tryParse(minController.text) ?? 0;

                              sec = int.tryParse(secController.text) ?? 0;

                            }

                            _workoutService.setGoals(pace: Pace(minutes: min, seconds: sec));

                            Navigator.pop(context);

                          },

                        ),

                      ],

                    ),

                  ),

                  Expanded(

                    child: useKeyboard

                        ? SingleChildScrollView(child: _buildKeyboardInput(minController, secController, 'pace'))

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

              height: screenHeight * 0.5,

              color: CupertinoColors.systemBackground.resolveFrom(context),

              child: Column(

                children: [

                  Container(

                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),

                    child: Row(

                      mainAxisAlignment: MainAxisAlignment.spaceBetween,

                      children: [

                        CupertinoButton(child: const Text('취소'), onPressed: () => Navigator.pop(context)),

                        CupertinoButton(

                          child: Icon(useKeyboard ? Icons.dialpad : Icons.keyboard),

                          onPressed: () => setModalState(() => useKeyboard = !useKeyboard),

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

                            Navigator.pop(context);

                          },

                        ),

                      ],

                    ),

                  ),

                  Expanded(

                    child: useKeyboard

                        ? SingleChildScrollView(child: _buildKeyboardInput(hController, mController, 'time'))

                        : _buildPickerInputTime(h, m, (index) => h = index, (index) => m = index),

                  ),

                ],

              ),

            );

          },

        ),

      );

    }

  

    Widget _buildPickerInputTime(int hours, int minutes, Function(int) onChangedH, Function(int) onChangedM) {

      final secondaryColor = Theme.of(context).colorScheme.secondary;

      return Row(

        mainAxisAlignment: MainAxisAlignment.center,

        children: [

          Expanded(child: CupertinoPicker(itemExtent: 40, onSelectedItemChanged: onChangedH, scrollController: FixedExtentScrollController(initialItem: hours), children: List.generate(24, (index) => Center(child: Text('$index', style: const TextStyle(fontSize: 20)))))),

          Padding(padding: const EdgeInsets.symmetric(horizontal: 8), child: Text('시간', style: TextStyle(fontSize: 20, color: secondaryColor, fontWeight: FontWeight.bold))),

          Expanded(child: CupertinoPicker(itemExtent: 40, onSelectedItemChanged: onChangedM, scrollController: FixedExtentScrollController(initialItem: minutes), children: List.generate(60, (index) => Center(child: Text(index.toString().padLeft(2, '0'), style: const TextStyle(fontSize: 20)))))),

          Padding(padding: const EdgeInsets.only(right: 20.0), child: Text('분', style: TextStyle(fontSize: 20, color: secondaryColor, fontWeight: FontWeight.bold))),

        ],

      );

    }

  

    Widget _buildPickerInput(int value1, int value2, String unit, Function(int) onChanged1, Function(int) onChanged2) {

      final secondaryColor = Theme.of(context).colorScheme.secondary;

      return Row(

        mainAxisAlignment: MainAxisAlignment.center,

        children: [

          Expanded(child: CupertinoPicker(itemExtent: 40, onSelectedItemChanged: onChanged1, scrollController: FixedExtentScrollController(initialItem: value1), children: List.generate(100, (index) => Center(child: Text('$index', style: const TextStyle(fontSize: 20)))))),

          Text(unit == 'km' ? '.' : "'", style: TextStyle(fontSize: 20, color: secondaryColor, fontWeight: FontWeight.bold)),

          Expanded(child: CupertinoPicker(itemExtent: 40, onSelectedItemChanged: onChanged2, scrollController: FixedExtentScrollController(initialItem: value2), children: List.generate(unit == 'km' ? 100 : 60, (index) => Center(child: Text(index.toString().padLeft(2, '0'), style: const TextStyle(fontSize: 20)))))),

          Padding(padding: const EdgeInsets.only(right: 20.0), child: Text(unit == 'km' ? 'km' : '"', style: TextStyle(fontSize: 20, color: secondaryColor, fontWeight: FontWeight.bold))),

        ],

      );

    }

  

    Widget _buildKeyboardInput(TextEditingController c1, TextEditingController c2, String unit) {

      final secondaryColor = Theme.of(context).colorScheme.secondary;

      String separator = unit == 'km' ? '.' : (unit == 'pace' ? "'" : '');

      String suffix1 = unit == 'time' ? '시간' : '';

      String suffix2 = unit == 'km' ? 'km' : (unit == 'pace' ? '"' : '분');

      

      return Padding(

        padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 20),

        child: Row(

          children: [

            Expanded(child: CupertinoTextField(controller: c1, textAlign: TextAlign.center, keyboardType: TextInputType.number, style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold))),

            if (separator.isNotEmpty) Text(separator, style: TextStyle(fontSize: 32, color: secondaryColor, fontWeight: FontWeight.bold)),

            if (suffix1.isNotEmpty) Text(suffix1, style: TextStyle(fontSize: 20, color: secondaryColor, fontWeight: FontWeight.bold)),

            const SizedBox(width: 8), 

            Expanded(child: CupertinoTextField(controller: c2, textAlign: TextAlign.center, keyboardType: TextInputType.number, style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold))),

            Text(suffix2, style: TextStyle(fontSize: 20, color: secondaryColor, fontWeight: FontWeight.bold)),

          ],

        ),

      );

    }

  

    Map<String, dynamic> _calculateMissingGoal(WorkoutTrackingService service) {

      final hasDistance = service.goalDistance != null;

      final hasPace = service.goalPace != null;

      final hasTime = service.goalTime != null;

      String? distanceValue, paceValue, timeValue;

      bool distanceCalculated = false, paceCalculated = false, timeCalculated = false;

  

      if (hasDistance && hasPace && !hasTime) {

        final distanceKm = service.goalDistance! / 1000;

        final paceMin = service.goalPace!.minutes + service.goalPace!.seconds / 60;

        final timeMin = (distanceKm * paceMin).round();

        timeValue = _formatDuration(Duration(minutes: timeMin));

        timeCalculated = true;

        distanceValue = '${distanceKm.toStringAsFixed(2)} km';

        paceValue = service.goalPace.toString();

      } else if (hasDistance && hasTime && !hasPace) {

        final distanceKm = service.goalDistance! / 1000;

        final totalMinutes = service.goalTime!.inMinutes;

        final paceMinutes = (totalMinutes / distanceKm);

        final paceMin = paceMinutes.floor();

        final paceSec = ((paceMinutes - paceMin) * 60).round();

        paceValue = '$paceMin:${paceSec.toString().padLeft(2, '0')}';

        paceCalculated = true;

        distanceValue = '${distanceKm.toStringAsFixed(2)} km';

        timeValue = _formatDuration(service.goalTime!);

      } else if (hasPace && hasTime && !hasDistance) {

        final paceMinutes = service.goalPace!.minutes + (service.goalPace!.seconds / 60);

        final totalMinutes = service.goalTime!.inMinutes;

        final calculatedDistanceKm = totalMinutes / paceMinutes;

        distanceValue = '${calculatedDistanceKm.toStringAsFixed(2)} km';

        distanceCalculated = true;

        paceValue = service.goalPace.toString();

        timeValue = _formatDuration(service.goalTime!);

      } else {

        distanceValue = hasDistance ? '${(service.goalDistance! / 1000).toStringAsFixed(2)} km' : '선택';

        paceValue = hasPace ? service.goalPace.toString() : '선택';

        timeValue = hasTime ? _formatDuration(service.goalTime!) : '선택';

      }

      return {

        'distance': distanceValue, 'pace': paceValue, 'time': timeValue,

        'distanceCalculated': distanceCalculated, 'paceCalculated': paceCalculated, 'timeCalculated': timeCalculated

      };

    }

  

    Widget _buildGoalButton({required String label, required String value, required IconData icon, required VoidCallback onTap, bool isCalculated = false}) {

      final hasValue = value != '선택';

      return InkWell(

        onTap: onTap,

        borderRadius: BorderRadius.circular(8),

        child: Container(

          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),

          decoration: BoxDecoration(

            color: hasValue ? Theme.of(context).colorScheme.secondary.withValues(alpha: 0.1) : Colors.grey.withValues(alpha: 0.1),

            borderRadius: BorderRadius.circular(8),

            border: Border.all(color: hasValue ? Theme.of(context).colorScheme.secondary : Colors.grey, width: hasValue ? 2 : 1),

          ),

          child: Column(

            children: [

              Row(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(icon, size: 16, color: hasValue ? Theme.of(context).colorScheme.secondary : Colors.grey), const SizedBox(width: 4), Text(label, style: TextStyle(fontSize: 12, color: hasValue ? Theme.of(context).colorScheme.secondary : Colors.grey)), if (isCalculated) Icon(Icons.auto_awesome, size: 12, color: Theme.of(context).colorScheme.primary)]),

              const SizedBox(height: 8),

              Text(value, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: hasValue ? Theme.of(context).colorScheme.onSurface : Colors.grey, fontStyle: isCalculated ? FontStyle.italic : FontStyle.normal), textAlign: TextAlign.center),

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

  

    

  