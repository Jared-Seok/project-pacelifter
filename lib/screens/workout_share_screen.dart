import 'dart:io';
import 'dart:ui' as ui; 
import 'package:flutter/material.dart';
import 'package:health/health.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:screenshot/screenshot.dart';
import 'package:share_plus/share_plus.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:intl/intl.dart';
import '../widgets/grid_painter.dart';
import '../models/sessions/workout_session.dart'; 
import '../utils/workout_ui_utils.dart'; // Centralized UI Utils

/// 운동 공유 화면
class WorkoutShareScreen extends StatefulWidget {
  final HealthDataPoint? workoutData;
  final WorkoutSession? session;
  final List<HealthDataPoint> heartRateData;
  final double avgHeartRate;
  final List<HealthDataPoint> paceData;
  final double avgPace;
  final Duration? movingTime;
  final String? templateName;
  final String? environmentType;

  const WorkoutShareScreen({
    super.key,
    this.workoutData,
    this.session,
    required this.heartRateData,
    required this.avgHeartRate,
    required this.paceData,
    required this.avgPace,
    this.movingTime,
    this.templateName,
    this.environmentType,
  });

  @override
  State<WorkoutShareScreen> createState() => _WorkoutShareScreenState();
}

class _WorkoutShareScreenState extends State<WorkoutShareScreen> {
  final ImagePicker _picker = ImagePicker();
  final ScreenshotController _screenshotController = ScreenshotController();

  File? _selectedImage;
  String _selectedLayout = 'modern_minimal';
  double _imageAspectRatio = 4 / 5; // Default to Instagram Portrait (4:5)
  bool _isProcessing = false;

  // Text/Overlay Positioning
  Offset _contentPosition = const Offset(0.5, 0.8); 
  double _contentScale = 1.0; 
  double _baseScale = 1.0;
  bool _isDragging = false;

  // Metric Visibility State
  final Map<String, bool> _activeMetrics = {
    'distance': true,
    'time': true,
    'pace': true,
    'heartRate': false,
    'calories': false,
  };

  @override
  void initState() {
    super.initState();
    // Set default metrics based on workout type
    _initializeDefaultMetrics();
  }

  void _initializeDefaultMetrics() {
    String category = 'Endurance';
    if (widget.session != null) {
      category = widget.session!.category;
    } else if (widget.workoutData != null) {
       final val = widget.workoutData!.value as WorkoutHealthValue;
       category = WorkoutUIUtils.getWorkoutCategory(val.workoutActivityType.name);
    }

    if (category == 'Strength') {
      _activeMetrics['distance'] = false;
      _activeMetrics['pace'] = false;
      _activeMetrics['heartRate'] = true;
      _activeMetrics['calories'] = true;
    } else {
      // Endurance default
      _activeMetrics['distance'] = true;
      _activeMetrics['pace'] = true;
      _activeMetrics['heartRate'] = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        title: const Text('운동 공유'),
        backgroundColor: Theme.of(context).colorScheme.surface,
        foregroundColor: Theme.of(context).colorScheme.onSurface,
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildPreviewSection(),
                  const SizedBox(height: 24),
                  _buildImageSection(),
                  const SizedBox(height: 24),
                  _buildLayoutSelection(),
                  const SizedBox(height: 24),
                  _buildDataOptionSection(),
                ],
              ),
            ),
          ),
          if (!_isProcessing)
            _buildBottomActions(),
        ],
      ),
    );
  }

  Widget _buildImageSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('배경', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildActionButton(
                icon: Icons.camera_alt,
                label: '카메라',
                onPressed: () => _pickImage(ImageSource.camera),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildActionButton(
                icon: Icons.photo_library,
                label: '갤러리',
                onPressed: () => _pickImage(ImageSource.gallery),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildActionButton(
                icon: Icons.palette,
                label: '기본 배경',
                onPressed: () => setState(() => _selectedImage = null),
                isOutlined: true,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildActionButton({
    required IconData icon, 
    required String label, 
    required VoidCallback onPressed, 
    bool isOutlined = false
  }) {
    if (isOutlined) {
      return OutlinedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, size: 20),
        label: Text(label),
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 12),
          side: BorderSide(color: Theme.of(context).colorScheme.primary),
        ),
      );
    }
    return ElevatedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 20),
      label: Text(label),
      style: ElevatedButton.styleFrom(
        backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
        foregroundColor: Theme.of(context).colorScheme.onSurface,
        elevation: 0,
        padding: const EdgeInsets.symmetric(vertical: 12),
      ),
    );
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final XFile? image = await _picker.pickImage(source: source);
      if (image == null) return;

      final croppedFile = await ImageCropper().cropImage(
        sourcePath: image.path,
        uiSettings: [
          AndroidUiSettings(
            toolbarTitle: '이미지 편집',
            toolbarColor: Colors.black,
            toolbarWidgetColor: Colors.white,
            initAspectRatio: CropAspectRatioPreset.ratio4x3,
            lockAspectRatio: false,
          ),
          IOSUiSettings(
            title: '이미지 편집',
            aspectRatioLockEnabled: false,
            resetAspectRatioEnabled: false,
            doneButtonTitle: '완료',
            cancelButtonTitle: '취소',
            hidesNavigationBar: true, // Fix for UI cutoff issues
          ),
        ],
      );

      if (croppedFile != null) {
        final file = File(croppedFile.path);
        final decodedImage = await decodeImageFromList(await file.readAsBytes());
        setState(() {
          _selectedImage = file;
          _imageAspectRatio = decodedImage.width / decodedImage.height;
          // Reset position for new image
          _contentPosition = const Offset(0.5, 0.8);
          _contentScale = 1.0;
        });
      }
    } catch (e) {
      debugPrint('❌ Image Pick Error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('이미지 선택 오류: $e')));
      }
    }
  }

  Widget _buildLayoutSelection() {
    final layouts = [
      {'id': 'modern_minimal', 'name': '모던', 'icon': Icons.crop_portrait},
      {'id': 'sticker', 'name': '스티커', 'icon': Icons.layers},
      {'id': 'magazine', 'name': '매거진', 'icon': Icons.newspaper},
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('템플릿', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        SizedBox(
          height: 90,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: layouts.length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (context, index) {
              final layout = layouts[index];
              final isSelected = _selectedLayout == layout['id'];
              return GestureDetector(
                onTap: () => setState(() => _selectedLayout = layout['id'] as String),
                child: Container(
                  width: 70,
                  decoration: BoxDecoration(
                    color: isSelected 
                      ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.2) 
                      : Theme.of(context).colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(12),
                    border: isSelected 
                      ? Border.all(color: Theme.of(context).colorScheme.primary, width: 2) 
                      : null,
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        layout['icon'] as IconData, 
                        color: isSelected ? Theme.of(context).colorScheme.primary : Colors.white60
                      ),
                      const SizedBox(height: 8),
                      Text(
                        layout['name'] as String,
                        style: TextStyle(
                          fontSize: 12,
                          color: isSelected ? Theme.of(context).colorScheme.primary : Colors.white60,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildDataOptionSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('표시할 데이터', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _buildFilterChip('거리', 'distance'),
            _buildFilterChip('시간', 'time'),
            _buildFilterChip('페이스', 'pace'),
            _buildFilterChip('심박수', 'heartRate'),
            _buildFilterChip('칼로리', 'calories'),
          ],
        ),
      ],
    );
  }

  Widget _buildFilterChip(String label, String key) {
    return FilterChip(
      label: Text(label),
      selected: _activeMetrics[key]!,
      onSelected: (bool value) {
        setState(() {
          _activeMetrics[key] = value;
        });
      },
      selectedColor: Theme.of(context).colorScheme.primaryContainer,
      labelStyle: TextStyle(
        color: _activeMetrics[key]! 
          ? Theme.of(context).colorScheme.onPrimaryContainer 
          : Theme.of(context).colorScheme.onSurface,
        fontWeight: _activeMetrics[key]! ? FontWeight.bold : FontWeight.normal,
      ),
      checkmarkColor: Theme.of(context).colorScheme.onPrimaryContainer,
    );
  }

  Widget _buildPreviewSection() {
    return Center(
      child: Container(
        decoration: BoxDecoration(
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.3),
              blurRadius: 20,
              offset: const Offset(0, 10),
            )
          ]
        ),
        child: Screenshot(
          controller: _screenshotController,
          child: _buildWorkoutOverlay(),
        ),
      ),
    );
  }

  Widget _buildWorkoutOverlay() {
    // 1. Data Extraction
    String workoutType = 'RUNNING';
    String category = 'Endurance';
    double? totalDistance;
    double? totalEnergy;
    // 💡 정밀한 활동 시간(movingTime)을 우선적으로 사용하도록 수정
    Duration duration = widget.movingTime ?? Duration.zero;
    DateTime startTime = DateTime.now();
    double avgPace = widget.avgPace;
    double avgHeartRate = widget.avgHeartRate;

    if (widget.workoutData != null) {
      final val = widget.workoutData!.value as WorkoutHealthValue;
      workoutType = val.workoutActivityType.name;
      totalDistance = val.totalDistance?.toDouble();
      totalEnergy = val.totalEnergyBurned?.toDouble();
      // 활동 시간이 없을 경우에만 원본 데이터 기반 계산
      if (duration == Duration.zero) {
        duration = widget.workoutData!.dateTo.difference(widget.workoutData!.dateFrom);
      }
      startTime = widget.workoutData!.dateFrom;
    } else if (widget.session != null) {
      workoutType = widget.session!.category == 'Strength' ? 'STRENGTH_TRAINING' : 'RUNNING';
      category = widget.session!.category;
      totalDistance = widget.session!.totalDistance;
      totalEnergy = widget.session!.calories;
      // 활동 시간이 없을 경우에만 세션 데이터 기반 계산
      if (duration == Duration.zero) {
        duration = Duration(seconds: widget.session!.activeDuration);
      }
      startTime = widget.session!.startTime;
    }

    // Determine color based on centralized logic
    final themeColor = WorkoutUIUtils.getWorkoutColor(context, category);
    final displayTitle = widget.templateName ?? WorkoutUIUtils.formatWorkoutType(workoutType);

    // 💡 2. Pace Fallback Calculation Logic (Detail Screen(EnduranceDashboard)과 로직 동기화)
    if (avgPace <= 0 && totalDistance != null && totalDistance > 0 && duration.inSeconds > 0) {
      final double distanceKm = totalDistance / 1000.0;
      final double durationMin = duration.inSeconds / 60.0;
      if (distanceKm > 0) {
        avgPace = durationMin / distanceKm;
      }
    }

    // 3. Aspect Ratio Handling
    return LayoutBuilder(
      builder: (context, constraints) {
        // We want a fixed width for the screenshot, but responsive for preview
        // Let's assume a standard width of 350 for preview scaling
        double renderWidth = constraints.maxWidth;
        // Limit max width for better UX on tablets
        if (renderWidth > 400) renderWidth = 400;
        
        double renderHeight = renderWidth / _imageAspectRatio;
        
        // Safety cap for extremely tall images
        if (renderHeight > 600) {
          renderHeight = 600;
          // _imageAspectRatio logic might need adjustment if we force crop, but for now we let it fill
        }

        return ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Container(
            width: renderWidth,
            height: renderHeight,
            color: const Color(0xFF1A1A1A), // Dark background for no image
            child: Stack(
              children: [
                // Layer 1: Background Image or Gradient
                Positioned.fill(
                  child: _selectedImage != null
                      ? Image.file(_selectedImage!, fit: BoxFit.cover)
                      : Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                const Color(0xFF2C2C2C),
                                const Color(0xFF000000),
                              ],
                            ),
                          ),
                          child: Center(
                            child: Icon(Icons.fitness_center, size: 80, color: Colors.white.withValues(alpha: 0.05)),
                          ),
                        ),
                ),

                // Layer 2: Standard Darkening for readability
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.black.withValues(alpha: 0.1),
                          Colors.black.withValues(alpha: 0.6),
                        ],
                      ),
                    ),
                  ),
                ),

                // Layer 3: Draggable Content Area
                Positioned.fill(
                  child: GestureDetector(
                    behavior: HitTestBehavior.translucent,
                    onScaleStart: (details) {
                      setState(() {
                        _isDragging = true;
                        _baseScale = _contentScale;
                        // _basePosition = _contentPosition; // Removed unused field assignment
                      });
                    },
                    onScaleUpdate: (details) {
                      setState(() {
                        _contentScale = (_baseScale * details.scale).clamp(0.5, 3.0);
                        double newDx = _contentPosition.dx + (details.focalPointDelta.dx / renderWidth);
                        double newDy = _contentPosition.dy + (details.focalPointDelta.dy / renderHeight);
                        _contentPosition = Offset(newDx.clamp(0.0, 1.0), newDy.clamp(0.0, 1.0));
                      });
                    },
                    onScaleEnd: (_) => setState(() => _isDragging = false),
                    child: Stack(
                      children: [
                        if (_isDragging) Positioned.fill(child: CustomPaint(painter: GridPainter())),
                        Align(
                          alignment: FractionalOffset(_contentPosition.dx, _contentPosition.dy),
                          child: Transform.scale(
                            scale: _contentScale,
                            child: Container(
                              constraints: BoxConstraints(maxWidth: renderWidth * 0.9),
                              child: _buildLayoutContent(
                                _selectedLayout,
                                displayTitle,
                                themeColor,
                                duration,
                                totalDistance,
                                totalEnergy,
                                avgPace,
                                avgHeartRate,
                                startTime,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                // Fixed Logo Position (Top Left usually looks good, or can be part of draggable)
                Positioned(
                  top: 20, left: 20,
                  child: SvgPicture.asset(
                    'assets/images/pllogo.svg', width: 24, height: 24,
                    colorFilter: const ColorFilter.mode(Colors.white, BlendMode.srcIn),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // --- Specific Layout Builders ---

  Widget _buildLayoutContent(String layoutId, String title, Color color, Duration duration, double? dist, double? cal, double pace, double heartRate, DateTime date) {
    switch (layoutId) {
      case 'modern_minimal':
        return _buildModernLayout(title, color, duration, dist, cal, pace, heartRate, date);
      case 'sticker':
        return _buildStickerLayout(title, color, duration, dist, cal, pace, heartRate, date);
      case 'magazine':
        return _buildMagazineLayout(title, color, duration, dist, cal, pace, heartRate, date);
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildModernLayout(String title, Color color, Duration duration, double? dist, double? cal, double pace, double heartRate, DateTime date) {
    List<Widget> stats = [];
    
    // Dynamically build stat row
    if (_activeMetrics['distance'] == true && dist != null && dist > 0) {
      stats.add(_buildModernStat((dist / 1000).toStringAsFixed(2), 'KM', color));
    }
    if (_activeMetrics['time'] == true) {
      stats.add(_buildModernStat(_formatDuration(duration), 'TIME', color));
    }
    // Fixed: Show Pace if active (even if 0 to show selection, or ensure it's not hidden)
    if (_activeMetrics['pace'] == true) {
      stats.add(_buildModernStat(_formatPace(pace), 'PACE', color));
    }
    if (_activeMetrics['heartRate'] == true && heartRate > 0) {
      stats.add(_buildModernStat(heartRate.toInt().toString(), 'BPM', color));
    }
    if (_activeMetrics['calories'] == true && cal != null && cal > 0) {
      stats.add(_buildModernStat(cal.toInt().toString(), 'CAL', color));
    }

    // Insert Dividers
    List<Widget> displayStats = [];
    for (int i = 0; i < stats.length; i++) {
      displayStats.add(stats[i]);
      if (i < stats.length - 1) {
        displayStats.add(
          Container(width: 1, height: 30, color: Colors.white24, margin: const EdgeInsets.symmetric(horizontal: 20)),
        );
      }
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
         Text(DateFormat('MMMM d').format(date).toUpperCase(), 
          style: const TextStyle(color: Colors.white70, fontSize: 12, letterSpacing: 4, fontWeight: FontWeight.bold)),
         const SizedBox(height: 8),
         Text(title.toUpperCase(), 
          style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w900, letterSpacing: 1, height: 1.0)),
         const SizedBox(height: 20),
         // Intelligent Scaling: Wrap in FittedBox with limited width
         SizedBox(
           width: double.infinity, 
           child: FittedBox(
             fit: BoxFit.scaleDown,
             child: Row(
               mainAxisSize: MainAxisSize.min,
               mainAxisAlignment: MainAxisAlignment.center,
               children: displayStats,
             ),
           ),
         )
      ],
    );
  }

  Widget _buildStickerLayout(String title, Color color, Duration duration, double? dist, double? cal, double pace, double heartRate, DateTime date) {
    List<Widget> stats = [];

    // Dynamically build sticker row
    if (_activeMetrics['time'] == true) {
      stats.add(Text(_formatDuration(duration), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)));
    }
    if (_activeMetrics['distance'] == true && dist != null && dist > 0) {
      stats.add(Text('${(dist / 1000).toStringAsFixed(1)} km', style: const TextStyle(color: Colors.white, fontSize: 16)));
    }
    if (_activeMetrics['pace'] == true) {
      stats.add(Text(_formatPace(pace), style: const TextStyle(color: Colors.white, fontSize: 16)));
    }
    if (_activeMetrics['heartRate'] == true && heartRate > 0) {
      stats.add(Text('${heartRate.toInt()} bpm', style: const TextStyle(color: Colors.white, fontSize: 16)));
    }
    if (_activeMetrics['calories'] == true && cal != null && cal > 0) {
      stats.add(Text('${cal.toInt()} kcal', style: const TextStyle(color: Colors.white, fontSize: 16)));
    }

     // Insert Dots
    List<Widget> displayStats = [];
    if (stats.isNotEmpty) {
       displayStats.add(
         SvgPicture.asset('assets/images/pllogo.svg', width: 20, colorFilter: ColorFilter.mode(color, BlendMode.srcIn)),
       );
       displayStats.add(const SizedBox(width: 12));
    }

    for (int i = 0; i < stats.length; i++) {
      displayStats.add(stats[i]);
      if (i < stats.length - 1) {
        displayStats.add(const SizedBox(width: 8));
        displayStats.add(const Text('•', style: TextStyle(color: Colors.white54)));
        displayStats.add(const SizedBox(width: 8));
      }
    }

    // Intelligent Scaling: FittedBox ensures it scales down instead of overflowing
    return ClipRRect(
      borderRadius: BorderRadius.circular(30),
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 5, sigmaY: 5),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.6),
            borderRadius: BorderRadius.circular(30),
            border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 300), // Limit max width to force scaling
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: displayStats,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMagazineLayout(String title, Color color, Duration duration, double? dist, double? cal, double pace, double heartRate, DateTime date) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          color: color,
          child: Text(title.toUpperCase(), style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 12)),
        ),
        const SizedBox(height: 8),
        // Intelligent Title Scaling
        FittedBox(
          fit: BoxFit.scaleDown,
          child: _activeMetrics['distance'] == true && dist != null && dist > 0
            ? Text(
                '${(dist / 1000).toStringAsFixed(2)} KM',
                style: const TextStyle(color: Colors.white, fontSize: 56, fontWeight: FontWeight.w900, height: 0.9, letterSpacing: -2),
              )
            : _activeMetrics['time'] == true
              ? Text(
                 _formatDuration(duration),
                style: const TextStyle(color: Colors.white, fontSize: 56, fontWeight: FontWeight.w900, height: 0.9, letterSpacing: -2),
              )
              : const Text(
                'WORKOUT',
                style: TextStyle(color: Colors.white, fontSize: 56, fontWeight: FontWeight.w900, height: 0.9, letterSpacing: -2),
              ),
        ),
        const SizedBox(height: 8),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Row(
            children: [
              if (_activeMetrics['time'] == true && (_activeMetrics['distance'] == true || dist == null || dist == 0)) 
                _buildMagazineStat('TIME', _formatDuration(duration)),
              if (_activeMetrics['time'] == true && (_activeMetrics['distance'] == true || dist == null || dist == 0))
                const SizedBox(width: 20),
              if (_activeMetrics['pace'] == true) ...[
                 _buildMagazineStat('PACE', _formatPace(pace)),
                 const SizedBox(width: 20),
              ],
              if (_activeMetrics['calories'] == true && cal != null && cal > 0) ...[
                _buildMagazineStat('CAL', cal.toInt().toString()),
                const SizedBox(width: 20),
              ],
              if (_activeMetrics['heartRate'] == true && heartRate > 0)
                _buildMagazineStat('HR', heartRate.toInt().toString()),
            ],
          ),
        )
      ],
    );
  }


  Widget _buildModernStat(String val, String label, Color color) {
    return Column(
      children: [
        Text(val, style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
        Text(label, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _buildMagazineStat(String label, String val) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Colors.white54, fontSize: 10, fontWeight: FontWeight.bold)),
        Text(val, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
      ],
    );
  }

  // --- Bottom Actions & Utils ---

  Widget _buildBottomActions() {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                onPressed: _shareImage,
                icon: const Icon(Icons.share, size: 20),
                label: const Text('공유하기'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _shareImage() async {
    setState(() => _isProcessing = true);
    try {
      final image = await _screenshotController.capture(pixelRatio: 3.0);
      if (image != null) {
        final tempDir = await Directory.systemTemp.createTemp();
        final file = await File('${tempDir.path}/pacelifter_share.png').create();
        await file.writeAsBytes(image);
        
        await Share.shareXFiles(
          [XFile(file.path)], 
          text: 'PaceLifter로 기록한 오늘의 운동! #PaceLifter'
        );
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('공유 실패: $e')));
    } finally { setState(() => _isProcessing = false); }
  }

  String _formatDuration(Duration d) {
    String h = d.inHours.toString().padLeft(2, '0');
    String m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    String s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return d.inHours > 0 ? '$h:$m:$s' : '$m:$s';
  }

  String _formatPace(double paceMinKm) {
    // 💡 EnduranceDashboard의 포맷팅 로직과 동일하게 통일
    if (paceMinKm <= 0 || paceMinKm.isInfinite || paceMinKm.isNaN) return "--'--\"";
    int totalSeconds = (paceMinKm * 60).round();
    int minutes = totalSeconds ~/ 60;
    int seconds = totalSeconds % 60;
    if (minutes >= 60) return "--'--\"";
    return "${minutes.toString().padLeft(2, '0')}'${seconds.toString().padLeft(2, '0')}\"";
  }
}