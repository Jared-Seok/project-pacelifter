import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui; 
import 'package:flutter/material.dart';
import 'package:health/health.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:screenshot/screenshot.dart';
import 'package:share_plus/share_plus.dart';
import 'package:image_gallery_saver/image_gallery_saver.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:intl/intl.dart';
import 'package:permission_handler/permission_handler.dart';
import '../widgets/grid_painter.dart';
import '../models/sessions/workout_session.dart'; 

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
  String _selectedLayout = 'minimal';
  String _aspectRatio = 'free'; 
  double _imageAspectRatio = 1.0; 
  bool _isProcessing = false;

  Offset _contentPosition = const Offset(0.5, 0.75); 
  double _contentScale = 1.0; 
  Offset _basePosition = const Offset(0.5, 0.75);
  double _baseScale = 1.0;
  bool _isDragging = false;

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
                  _buildImageSection(),
                  const SizedBox(height: 24),
                  if (_selectedImage != null) ...[
                    _buildLayoutSelection(),
                    const SizedBox(height: 24),
                  ],
                  if (_selectedImage != null) ...[
                    _buildPreviewSection(),
                  ],
                ],
              ),
            ),
          ),
          if (_selectedImage != null && !_isProcessing)
            _buildBottomActions(),
        ],
      ),
    );
  }

  Widget _buildImageSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('배경 이미지 선택', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _pickImage(ImageSource.camera),
                    icon: const Icon(Icons.camera_alt),
                    label: const Text('사진 촬영'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).colorScheme.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _pickImage(ImageSource.gallery),
                    icon: const Icon(Icons.photo_library),
                    label: const Text('갤러리'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).colorScheme.primary,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
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
            initAspectRatio: CropAspectRatioPreset.original,
            lockAspectRatio: false,
          ),
          IOSUiSettings(title: '이미지 편집'),
        ],
      );

      if (croppedFile != null) {
        final file = File(croppedFile.path);
        final decodedImage = await decodeImageFromList(await file.readAsBytes());
        setState(() {
          _selectedImage = file;
          _imageAspectRatio = decodedImage.width / decodedImage.height;
        });
      }
    } catch (e) {
      debugPrint('❌ Image Pick Error: $e');
    }
  }

  Widget _buildLayoutSelection() {
    final layouts = [
      {'id': 'minimal', 'name': '심플', 'icon': Icons.remove},
      {'id': 'detailed', 'name': '상세', 'icon': Icons.list},
      {'id': 'running', 'name': '러닝 전용', 'icon': Icons.directions_run},
      {'id': 'strength', 'name': '근력 전용', 'icon': Icons.fitness_center},
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('레이아웃 선택', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        SizedBox(
          height: 50,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: layouts.length,
            itemBuilder: (context, index) {
              final layout = layouts[index];
              final isSelected = _selectedLayout == layout['id'];
              return Padding(
                padding: const EdgeInsets.only(right: 8.0),
                child: ChoiceChip(
                  label: Text(layout['name'] as String),
                  selected: isSelected,
                  onSelected: (val) {
                    if (val) setState(() => _selectedLayout = layout['id'] as String);
                  },
                  selectedColor: Theme.of(context).colorScheme.primary,
                  backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                  labelStyle: TextStyle(
                    color: isSelected ? Colors.black : Theme.of(context).colorScheme.onSurface,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildPreviewSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('미리보기 (텍스트 드래그 가능)', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            Screenshot(
              controller: _screenshotController,
              child: _buildWorkoutOverlay(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWorkoutOverlay() {
    if (_selectedImage == null) return const SizedBox.shrink();

    // 데이터 추출 (HealthKit 또는 로컬 세션)
    String workoutType = 'RUNNING';
    double? totalDistance;
    double? totalEnergy;
    Duration duration = Duration.zero;
    DateTime startTime = DateTime.now();

    if (widget.workoutData != null) {
      final val = widget.workoutData!.value as WorkoutHealthValue;
      workoutType = val.workoutActivityType.name;
      totalDistance = val.totalDistance?.toDouble();
      totalEnergy = val.totalEnergyBurned?.toDouble();
      duration = widget.workoutData!.dateTo.difference(widget.workoutData!.dateFrom);
      startTime = widget.workoutData!.dateFrom;
    } else if (widget.session != null) {
      workoutType = widget.session!.category == 'Strength' ? 'STRENGTH_TRAINING' : 'RUNNING';
      totalDistance = widget.session!.totalDistance;
      totalEnergy = widget.session!.calories;
      duration = Duration(seconds: widget.session!.activeDuration);
      startTime = widget.session!.startTime;
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final maxWidth = constraints.maxWidth;
        double calculatedHeight = maxWidth / _imageAspectRatio;
        if (calculatedHeight > 600) calculatedHeight = 600;

        return ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Container(
            width: maxWidth,
            height: calculatedHeight,
            color: Colors.black,
            child: Stack(
              children: [
                Positioned.fill(child: Image.file(_selectedImage!, fit: BoxFit.cover)),
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Colors.black.withValues(alpha: 0.3), Colors.black.withValues(alpha: 0.7)],
                      ),
                    ),
                  ),
                ),
                if (_isDragging) Positioned.fill(child: CustomPaint(painter: GridPainter())),
                Positioned(
                  top: 20, left: 20,
                  child: SvgPicture.asset(
                    'assets/images/pllogo.svg', width: 32, height: 32,
                    colorFilter: ColorFilter.mode(Theme.of(context).colorScheme.primary, BlendMode.srcIn),
                  ),
                ),
                Positioned.fill(
                  child: GestureDetector(
                    behavior: HitTestBehavior.translucent,
                    onScaleStart: (details) {
                      setState(() {
                        _isDragging = true;
                        _baseScale = _contentScale;
                        _basePosition = _contentPosition;
                      });
                    },
                    onScaleUpdate: (details) {
                      setState(() {
                        _contentScale = (_baseScale * details.scale).clamp(0.5, 2.5);
                        double newDx = _contentPosition.dx + (details.focalPointDelta.dx / maxWidth);
                        double newDy = _contentPosition.dy + (details.focalPointDelta.dy / calculatedHeight);
                        _contentPosition = Offset(newDx.clamp(0.0, 1.0), newDy.clamp(0.0, 1.0));
                      });
                    },
                    onScaleEnd: (_) => setState(() => _isDragging = false),
                    child: Stack(
                      children: [
                        Align(
                          alignment: FractionalOffset(_contentPosition.dx, _contentPosition.dy),
                          child: Transform.scale(
                            scale: _contentScale,
                            child: Container(
                              padding: const EdgeInsets.all(12),
                              child: IgnorePointer(
                                child: _buildLayoutContent(workoutType, totalDistance, totalEnergy, duration, startTime),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildLayoutContent(String type, double? distance, double? energy, Duration duration, DateTime start) {
    switch (_selectedLayout) {
      case 'minimal': return _buildMinimalLayout(type, distance, duration, start);
      case 'detailed': return _buildDetailedLayout(type, distance, energy, duration, start);
      case 'running': return _buildRunningLayout(type, distance, duration, start);
      case 'strength': return _buildStrengthLayout(type, energy, duration, start);
      default: return _buildMinimalLayout(type, distance, duration, start);
    }
  }

  Widget _buildMinimalLayout(String type, double? distance, Duration duration, DateTime start) {
    final displayTitle = widget.templateName ?? _formatWorkoutType(type);
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(displayTitle, style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          Wrap(
            spacing: 12, runSpacing: 8,
            children: [
              if (distance != null && distance > 0) _buildStatBadge('${(distance / 1000).toStringAsFixed(2)} km', '거리'),
              _buildStatBadge(_formatDuration(duration), '시간'),
              if (widget.avgPace > 0) _buildStatBadge(_formatPace(widget.avgPace), '평균 페이스'),
            ],
          ),
          const SizedBox(height: 8),
          Text(DateFormat('yyyy.MM.dd HH:mm').format(start), style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 14)),
        ],
      ),
    );
  }

  Widget _buildDetailedLayout(String type, double? distance, double? energy, Duration duration, DateTime start) {
    final displayTitle = widget.templateName ?? _formatWorkoutType(type);
    return Padding(
      padding: const EdgeInsets.all(12.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(displayTitle, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          GridView.count(
            crossAxisCount: 2, shrinkWrap: true, childAspectRatio: 2.5, crossAxisSpacing: 10, mainAxisSpacing: 10,
            children: [
              if (distance != null && distance > 0) _buildSmallStat('${(distance / 1000).toStringAsFixed(2)} km', '거리'),
              _buildSmallStat(_formatDuration(duration), '시간'),
              if (widget.avgHeartRate > 0) _buildSmallStat('${widget.avgHeartRate.toInt()} bpm', '평균 심박'),
              if (energy != null && energy > 0) _buildSmallStat('${energy.toInt()} kcal', '칼로리'),
            ],
          ),
          const SizedBox(height: 8),
          Text(DateFormat('yyyy.MM.dd HH:mm').format(start), style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 12)),
        ],
      ),
    );
  }

  Widget _buildRunningLayout(String type, double? distance, Duration duration, DateTime start) {
    final displayTitle = widget.templateName ?? '러닝 리포트';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.4), borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.white.withValues(alpha: 0.2))),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(displayTitle, style: TextStyle(color: Theme.of(context).colorScheme.primary, fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 2)),
          const SizedBox(height: 12),
          if (distance != null && distance > 0) ...[
            Text((distance / 1000).toStringAsFixed(2), style: const TextStyle(color: Colors.white, fontSize: 64, fontWeight: FontWeight.w900, height: 1)),
            const Text('KILOMETERS', style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 4)),
          ],
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildStatItem(_formatDuration(duration), 'TIME'),
              _buildStatItem(_formatPace(widget.avgPace), 'PACE'),
              if (widget.avgHeartRate > 0) _buildStatItem('${widget.avgHeartRate.toInt()}', 'BPM'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStrengthLayout(String type, double? energy, Duration duration, DateTime start) {
    final displayTitle = widget.templateName ?? '웨이트 트레이닝';
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(border: Border(left: BorderSide(color: Theme.of(context).colorScheme.secondary, width: 4))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min,
        children: [
          Text(displayTitle, style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          Row(
            children: [
              _buildStatBadge(_formatDuration(duration), '운동 시간'),
              const SizedBox(width: 12),
              if (energy != null && energy > 0) _buildStatBadge('${energy.toInt()} kcal', '소모 칼로리'),
            ],
          ),
          const SizedBox(height: 12),
          if (widget.avgHeartRate > 0) Text('평균 심박수: ${widget.avgHeartRate.toInt()} bpm', style: const TextStyle(color: Colors.white70, fontSize: 14)),
        ],
      ),
    );
  }

  Widget _buildStatBadge(String value, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(8)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(color: Colors.white70, fontSize: 10, fontWeight: FontWeight.bold)),
          Text(value, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildSmallStat(String value, String label) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Colors.white60, fontSize: 10)),
        Text(value, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _buildStatItem(String value, String label) {
    return Column(
      children: [
        Text(value, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
        Text(label, style: const TextStyle(color: Colors.white60, fontSize: 10, letterSpacing: 1)),
      ],
    );
  }

  Widget _buildBottomActions() {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _saveToGallery,
                icon: const Icon(Icons.download),
                label: const Text('갤러리 저장'),
                style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16), side: BorderSide(color: Theme.of(context).colorScheme.primary)),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: _shareImage,
                icon: const Icon(Icons.share),
                label: const Text('공유하기'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _saveToGallery() async {
    setState(() => _isProcessing = true);
    try {
      final image = await _screenshotController.capture();
      if (image != null) {
        final result = await ImageGallerySaver.saveImage(image);
        if (result['isSuccess'] && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('갤러리에 저장되었습니다.')));
        }
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('저장 실패: $e')));
    } finally { setState(() => _isProcessing = false); }
  }

  Future<void> _shareImage() async {
    setState(() => _isProcessing = true);
    try {
      final image = await _screenshotController.capture();
      if (image != null) {
        final tempDir = await Directory.systemTemp.createTemp();
        final file = await File('${tempDir.path}/workout_share.png').create();
        await file.writeAsBytes(image);
        await Share.shareXFiles([XFile(file.path)], text: 'PaceLifter로 기록한 오늘의 운동!');
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

  String _formatPace(double pace) {
    int m = pace.floor();
    int s = ((pace - m) * 60).round();
    return "$m'${s.toString().padLeft(2, '0')}\"";
  }

  String _formatWorkoutType(String type) {
    return type.replaceAll('WORKOUT_ACTIVITY_TYPE_', '').replaceAll('_', ' ');
  }
}