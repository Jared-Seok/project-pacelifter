import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'dart:async';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../services/workout_tracking_service.dart';
import '../services/template_service.dart';
import '../models/templates/workout_template.dart';
import '../models/templates/template_block.dart';
import '../models/templates/custom_phase_preset.dart';
import 'workout_tracking_screen.dart';
import 'strength_tracking_screen.dart'; // Correctly placed import
import '../widgets/block_edit_dialog.dart';
import '../widgets/interval_set_edit_dialog.dart';

class _DisplayItem {
  final bool isGroup;
  final List<TemplateBlock> blocks;
  final int startIndex;
  final int count;

  _DisplayItem({
    required this.isGroup,
    required this.blocks,
    required this.startIndex,
    this.count = 1,
  });
}

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
    // Reset goals after the frame is built to avoid setState during build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _workoutService.setGoals(distance: null, time: null, pace: null);
    });
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

  String _getCleanName(String name) {
    return name
        .replaceAll('Outdoor ', '')
        .replaceAll('Indoor ', '')
        .replaceAll('Trail ', '')
        .replaceAll('Track ', '');
  }

  String _getCleanPhaseName(String name) {
    if (name == 'Warm-up') return '웜업 조깅';
    if (name == 'Cool-down') return '쿨다운 조깅';
    return name;
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

  void _startWorkout() async {
    if (widget.template.category == 'Strength') {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => StrengthTrackingScreen(template: widget.template),
        ),
      );
    } else {
      await _workoutService.startWorkout();
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => const WorkoutTrackingScreen(),
          ),
        );
      }
    }
  }

  Future<void> _showSavePresetDialog(int phaseIndex) async {
    final phase = _editableTemplate.phases[phaseIndex];
    final nameController = TextEditingController(text: phase.name);
    
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('현재 구성을 프리셋으로 저장'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('현재 단계의 블록 구성을 저장하여 나중에 다시 불러올 수 있습니다.'),
            const SizedBox(height: 16),
            TextField(
              controller: nameController,
              decoration: const InputDecoration(
                labelText: '프리셋 이름',
                hintText: '예: 인터벌 400m x 10',
                border: OutlineInputBorder(),
              ),
              autofocus: true,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('취소'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (nameController.text.trim().isEmpty) return;
              
              final preset = CustomPhasePreset(
                id: const Uuid().v4(),
                name: nameController.text.trim(),
                category: _editableTemplate.category, // Endurance, Strength etc.
                blocks: List<TemplateBlock>.from(phase.blocks), // Deep copy needed? generic copy
                createdAt: DateTime.now(),
              );

              await TemplateService.saveCustomPhasePreset(preset);
              
              if (mounted) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('프리셋이 저장되었습니다.')),
                );
              }
            },
            child: const Text('저장'),
          ),
        ],
      ),
    );
  }

  Future<void> _showLoadPresetDialog(int phaseIndex) async {
    final presets = await TemplateService.getCustomPhasePresetsByCategory(_editableTemplate.category);
    
    if (!mounted) return;

    if (presets.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('저장된 프리셋이 없습니다.')),
      );
      return;
    }

    await showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              child: Text(
                '프리셋 불러오기',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
            ),
            Expanded(
              child: ListView.builder(
                itemCount: presets.length,
                itemBuilder: (context, index) {
                  final preset = presets[index];
                  return ListTile(
                    leading: const Icon(Icons.bookmarks_outlined),
                    title: Text(preset.name),
                    subtitle: Text('${preset.blocks.length}개 블록 | ${_formatDate(preset.createdAt)}'),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete_outline, color: Colors.grey),
                      onPressed: () async {
                        await TemplateService.deleteCustomPhasePreset(preset.id);
                        Navigator.pop(context); // Close to refresh (simple way)
                        _showLoadPresetDialog(phaseIndex); // Re-open
                      },
                    ),
                    onTap: () {
                      _loadPreset(phaseIndex, preset);
                      Navigator.pop(context);
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _loadPreset(int phaseIndex, CustomPhasePreset preset) {
    setState(() {
      // Create new block instances with new IDs to avoid conflicts
      final newBlocks = preset.blocks.map((b) => b.copyWith(id: const Uuid().v4())).toList();
      
      final updatedPhase = _editableTemplate.phases[phaseIndex].copyWith(blocks: newBlocks);
      _editableTemplate.phases[phaseIndex] = updatedPhase;
    });
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${preset.name} 프리셋을 적용했습니다.')),
    );
  }

  Future<void> _showLoadCustomTemplateDialog() async {
    final allTemplates = TemplateService.getAllTemplates();
    final customTemplates = allTemplates.where((t) => 
      t.isCustom && 
      t.category == widget.template.category &&
      (t.subCategory == widget.template.subCategory || widget.template.subCategory == null)
    ).toList();

    if (!mounted) return;

    if (customTemplates.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('불러올 수 있는 커스텀 템플릿이 없습니다.')),
      );
      return;
    }

    await showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              child: Text(
                '나만의 템플릿 불러오기',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
            ),
            Expanded(
              child: ListView.builder(
                itemCount: customTemplates.length,
                itemBuilder: (context, index) {
                  final template = customTemplates[index];
                  return ListTile(
                    leading: const Icon(Icons.refresh),
                    title: Text(template.name),
                    subtitle: Text(_formatDate(template.createdAt ?? DateTime.now())),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete_outline, color: Colors.grey),
                      onPressed: () async {
                        await TemplateService.deleteTemplate(template.id);
                        Navigator.pop(context);
                        _showLoadCustomTemplateDialog();
                      },
                    ),
                    onTap: () {
                      Navigator.pop(context); // Close sheet
                      // Replace current screen with selected template
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(
                          builder: (context) => WorkoutSetupScreen(
                            template: template,
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.year}.${date.month}.${date.day}';
  }

  Future<void> _saveAsCustomTemplate() async {
    final nameController = TextEditingController(text: '${_getCleanName(_editableTemplate.name)} (Custom)');
    
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('커스텀 템플릿 저장'),
        content: TextField(
          controller: nameController,
          decoration: const InputDecoration(
            labelText: '템플릿 이름',
            hintText: '나만의 템플릿 이름을 입력하세요',
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('취소'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (nameController.text.trim().isEmpty) return;
              
              final newTemplate = _editableTemplate.copyWith(
                id: const Uuid().v4(),
                name: nameController.text.trim(),
                isCustom: true,
                createdAt: DateTime.now(),
                modifiedAt: DateTime.now(),
              );

              await TemplateService.saveCustomTemplate(newTemplate);
              
              if (mounted) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('커스텀 템플릿이 저장되었습니다.')),
                );
              }
            },
            child: const Text('저장'),
          ),
        ],
      ),
    );
  }

  bool get _isBasicRun => widget.template.subCategory == 'Basic Run';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        title: Text(_getCleanName(widget.template.name)),
        backgroundColor: Theme.of(context).colorScheme.surface,
        foregroundColor: Theme.of(context).colorScheme.onSurface,
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            tooltip: '템플릿 옵션',
            onSelected: (value) {
              if (value == 'load') {
                _showLoadCustomTemplateDialog();
              } else if (value == 'save') {
                _saveAsCustomTemplate();
              }
            },
            itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
              const PopupMenuItem<String>(
                value: 'load',
                child: Row(
                  children: [
                    Icon(Icons.folder_open, size: 20),
                    SizedBox(width: 8),
                    Text('나만의 템플릿 불러오기'),
                  ],
                ),
              ),
              const PopupMenuItem<String>(
                value: 'save',
                child: Row(
                  children: [
                    Icon(Icons.save_alt, size: 20),
                    SizedBox(width: 8),
                    Text('전체 템플릿 저장'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            flex: 2,
            child: _shouldShowMap() ? _buildMapSection() : _buildTemplateInfoSection(),
          ),
          Expanded(
            flex: 5,
            child: _isBasicRun ? _buildBasicRunUI() : _buildStandardUI(),
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

  Widget _buildStandardUI() {
    return Container(
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
    );
  }

  Widget _buildBasicRunUI() {
    return Consumer<WorkoutTrackingService>(
      builder: (context, workoutService, child) {
        final calculatedValues = _calculateMissingGoal(workoutService);
        return Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            boxShadow: [
               BoxShadow(
                color: Colors.black.withValues(alpha: 0.2),
                blurRadius: 20,
                offset: const Offset(0, -5),
              ),
            ],
          ),
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '목표 설정',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '원하는 목표를 설정하고 바로 시작하세요',
                style: TextStyle(
                  fontSize: 14,
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                ),
              ),
              const SizedBox(height: 32),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildBigGoalCard(
                      label: '목표 거리',
                      value: calculatedValues['distance'] ?? '설정 안함',
                      icon: Icons.straighten,
                      onTap: _showDistancePicker,
                      isActive: workoutService.goalDistance != null || calculatedValues['distanceCalculated'] == true,
                      isCalculated: calculatedValues['distanceCalculated'] == true,
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: _buildBigGoalCard(
                            label: '목표 페이스',
                            value: calculatedValues['pace'] ?? '설정 안함',
                            icon: Icons.speed,
                            onTap: _showPacePicker,
                            isActive: workoutService.goalPace != null || calculatedValues['paceCalculated'] == true,
                            isCalculated: calculatedValues['paceCalculated'] == true,
                            isSmall: true,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: _buildBigGoalCard(
                            label: '목표 시간',
                            value: calculatedValues['time'] ?? '설정 안함',
                            icon: Icons.timer,
                            onTap: _showTimePicker,
                            isActive: workoutService.goalTime != null || calculatedValues['timeCalculated'] == true,
                            isCalculated: calculatedValues['timeCalculated'] == true,
                            isSmall: true,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildBigGoalCard({
    required String label,
    required String value,
    required IconData icon,
    required VoidCallback onTap,
    required bool isActive,
    bool isCalculated = false,
    bool isSmall = false,
  }) {
    final themeColor = Theme.of(context).colorScheme.secondary;
    
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: isActive 
              ? themeColor.withValues(alpha: 0.15) 
              : Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isActive ? themeColor : Colors.transparent,
            width: 2,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  icon,
                  color: isActive ? themeColor : Colors.grey,
                  size: isSmall ? 20 : 24,
                ),
                const SizedBox(width: 8),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: isSmall ? 14 : 16,
                    color: isActive ? themeColor : Colors.grey,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (isCalculated) ...[
                  const SizedBox(width: 4),
                  Icon(Icons.auto_awesome, size: 12, color: Theme.of(context).colorScheme.primary),
                ],
              ],
            ),
            const SizedBox(height: 12),
            Text(
              value,
              style: TextStyle(
                fontSize: isSmall ? 24 : 32,
                fontWeight: FontWeight.bold,
                color: isActive ? Theme.of(context).colorScheme.onSurface : Colors.grey,
                fontStyle: isCalculated ? FontStyle.italic : FontStyle.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }

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
            size: 48,
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
          Wrap(
            spacing: 8,
            children: [
              _buildSmallChip(_getCleanName(_editableTemplate.category)),
              if (_editableTemplate.subCategory != null)
                _buildSmallChip(_getCleanName(_editableTemplate.subCategory!)),
              if (_editableTemplate.environmentType != null)
                _buildSmallChip(_getCleanName(_editableTemplate.environmentType!)),
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

  // --- Grouping Logic ---

  Widget _buildCustomizationTab() {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 140),
      itemCount: _editableTemplate.phases.length,
      itemBuilder: (context, phaseIndex) {
        final phase = _editableTemplate.phases[phaseIndex];
        final phaseDisplayName = _getCleanPhaseName(phase.name);
        final displayItems = _groupBlocks(phase.blocks, phaseDisplayName);

        // 웜업/쿨다운은 "세트" 텍스트 대신 "항목" 또는 숨김
        String subtitleText = '';
        if (phase.name == 'Main Set') {
          int totalSets = 0;
          for (var item in displayItems) {
            totalSets += item.count;
          }
          subtitleText = '$totalSets 세트';
        } else {
          subtitleText = '${phase.blocks.length}개 항목';
        }

        return Card(
          margin: const EdgeInsets.only(bottom: 16),
          child: ExpansionTile(
            leading: SvgPicture.asset(
              'assets/images/endurance/runner-icon.svg',
              width: 24,
              height: 24,
              colorFilter: ColorFilter.mode(
                Theme.of(context).colorScheme.primary,
                BlendMode.srcIn,
              ),
            ),
            title: Row(
              children: [
                Expanded(
                  child: Text(
                    phaseDisplayName,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_horiz),
                  tooltip: '프리셋 옵션',
                  onSelected: (value) {
                    if (value == 'load') {
                      _showLoadPresetDialog(phaseIndex);
                    } else if (value == 'save') {
                      _showSavePresetDialog(phaseIndex);
                    }
                  },
                  itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
                    const PopupMenuItem<String>(
                      value: 'load',
                      child: Row(
                        children: [
                          Icon(Icons.file_download_outlined, size: 20),
                          SizedBox(width: 8),
                          Text('프리셋 불러오기'),
                        ],
                      ),
                    ),
                    const PopupMenuItem<String>(
                      value: 'save',
                      child: Row(
                        children: [
                          Icon(Icons.save_alt, size: 20),
                          SizedBox(width: 8),
                          Text('현재 구성 저장'),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
            subtitle: Text(subtitleText),
            initiallyExpanded: true,
            children: displayItems.map((item) {
              if (item.isGroup) {
                return _buildGroupItem(item, phaseIndex);
              } else {
                return _buildBlockItem(item.blocks.first, phaseIndex, item.startIndex);
              }
            }).toList(),
          ),
        );
      },
    );
  }

  List<_DisplayItem> _groupBlocks(List<TemplateBlock> blocks, String phaseDisplayName) {
    // 웜업 및 쿨다운은 그룹화하지 않음 (사용자 요청: Set 텍스트 필요 없음)
    if (phaseDisplayName.contains('웜업') || phaseDisplayName.contains('쿨다운')) {
      return blocks.asMap().entries.map((e) => _DisplayItem(
        isGroup: false,
        blocks: [e.value],
        startIndex: e.key,
      )).toList();
    }

    List<_DisplayItem> items = [];
    int i = 0;
    while (i < blocks.length) {
      // 1. Try Work + Rest Pattern
      if (i + 1 < blocks.length) {
        final b1 = blocks[i];
        final b2 = blocks[i + 1];
        
        // Pair detection (Work followed by Rest/Recovery)
        bool isWorkRestPair = (b1.type == 'endurance' || b1.type == 'strength') && 
                              (b2.type == 'rest' || (b2.type == 'endurance' && (b2.name.toLowerCase().contains('recovery') || b2.intensityZone != b1.intensityZone)));

        if (isWorkRestPair) {
          int count = 1;
          int j = i + 2;
          while (j + 1 < blocks.length) {
            if (_isSameBlock(blocks[j], b1) && _isSameBlock(blocks[j + 1], b2)) {
              count++;
              j += 2;
            } else {
              break;
            }
          }

          // Even for 1 set, if it's a pair, we group it for unified editing
          if (count >= 1) {
            items.add(_DisplayItem(
              isGroup: true,
              blocks: [b1, b2],
              startIndex: i,
              count: count,
            ));
            i += count * 2;
            continue;
          }
        }
      }

      // 2. Try Single Repeating Block
      final b1 = blocks[i];
      int count = 1;
      int j = i + 1;
      while (j < blocks.length) {
        if (_isSameBlock(blocks[j], b1)) {
          count++;
          j++;
        } else {
          break;
        }
      }

      if (count >= 1 && (b1.type == 'endurance' || b1.type == 'strength')) {
        items.add(_DisplayItem(
          isGroup: true,
          blocks: [b1],
          startIndex: i,
          count: count,
        ));
        i += count;
        continue;
      }

      items.add(_DisplayItem(
        isGroup: false,
        blocks: [b1],
        startIndex: i,
      ));
      i++;
    }
    return items;
  }

  bool _isSameBlock(TemplateBlock a, TemplateBlock b) {
    return a.type == b.type &&
           a.targetDistance == b.targetDistance &&
           a.targetDuration == b.targetDuration &&
           a.targetPace == b.targetPace &&
           a.intensityZone == b.intensityZone &&
           a.sets == b.sets &&
           a.reps == b.reps &&
           a.weight == b.weight;
  }

  Widget _buildGroupItem(_DisplayItem item, int phaseIndex) {
    final workBlock = item.blocks[0];
    final restBlock = item.blocks.length > 1 ? item.blocks[1] : null;

    return Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        leading: CircleAvatar(
          backgroundColor: Theme.of(context).colorScheme.primary.withValues(alpha: 0.2),
          child: Icon(Icons.repeat, color: Theme.of(context).colorScheme.primary, size: 20),
        ),
        title: Text('${item.count} 세트: ${_getCleanName(workBlock.name).replaceAll(RegExp(r' \d+$'), '')}'),
        subtitle: Text(
          '${_getBlockSummary(workBlock)}' + 
          (restBlock != null ? ' + ${_getBlockSummary(restBlock)}' : '')
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.edit, size: 20),
              onPressed: () => _showEditGroupDialog(item, phaseIndex),
              tooltip: '전체 세트 수정',
            ),
            const Icon(Icons.keyboard_arrow_down),
          ],
        ),
        children: List.generate(item.count * item.blocks.length, (i) {
          final actualIndex = item.startIndex + i;
          final block = _editableTemplate.phases[phaseIndex].blocks[actualIndex];
          return Padding(
            padding: const EdgeInsets.only(left: 16.0),
            child: _buildBlockItem(block, phaseIndex, actualIndex),
          );
        }),
      ),
    );
  }

  void _showEditGroupDialog(_DisplayItem item, int phaseIndex) {
    showDialog(
      context: context,
      builder: (context) => IntervalSetEditDialog(
        workBlock: item.blocks[0],
        restBlock: item.blocks.length > 1 ? item.blocks[1] : null,
        currentSets: item.count,
        onSave: (newBlocks) async {
          setState(() {
            final currentBlocks = List<TemplateBlock>.from(_editableTemplate.phases[phaseIndex].blocks);
            int unitLength = item.blocks.length;
            int removeCount = item.count * unitLength;
            currentBlocks.removeRange(item.startIndex, item.startIndex + removeCount);
            currentBlocks.insertAll(item.startIndex, newBlocks);
            final updatedPhase = _editableTemplate.phases[phaseIndex].copyWith(blocks: currentBlocks);
            _editableTemplate.phases[phaseIndex] = updatedPhase;
          });

          await showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('템플릿 저장'),
              content: const Text('변경된 설정을 나만의 템플릿으로 저장하시겠습니까?\n저장하면 다음에도 이 설정을 불러올 수 있습니다.'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('아니오'),
                ),
                FilledButton(
                  onPressed: () {
                    Navigator.pop(context);
                    _saveAsCustomTemplate();
                  },
                  child: const Text('예, 저장합니다'),
                ),
              ],
            ),
          );
        },
      ),
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
      title: Text(_getCleanName(block.name)),
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
      List<String> parts = [];
      if (block.targetDistance != null) parts.add('${block.targetDistance!.toInt()}m');
      
      if (block.targetPace != null) {
        int totalSeconds = block.targetPace!.toInt();
        int minutes = totalSeconds ~/ 60;
        int seconds = totalSeconds % 60;
        parts.add("$minutes'${seconds.toString().padLeft(2, '0')}");
      }
      
      if (block.targetDuration != null) parts.add('${block.targetDuration}s');
      
      if (parts.isEmpty) return 'Free Run';
      return parts.join(' | ');
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
            final updatedBlocks = List<TemplateBlock>.from(_editableTemplate.phases[phaseIndex].blocks);
            updatedBlocks[blockIndex] = updatedBlock;
            final updatedPhase = _editableTemplate.phases[phaseIndex].copyWith(blocks: updatedBlocks);
            _editableTemplate.phases[phaseIndex] = updatedPhase;
          });
        },
      ),
    );
  }

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
