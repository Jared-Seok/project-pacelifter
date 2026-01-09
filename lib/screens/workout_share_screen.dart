import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui; // 추가
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

/// 운동 공유 화면
class WorkoutShareScreen extends StatefulWidget {
  final HealthDataPoint workoutData;
  final List<HealthDataPoint> heartRateData;
  final double avgHeartRate;
  final List<HealthDataPoint> paceData;
  final double avgPace;
  final Duration? movingTime;
  final String? templateName;
  final String? environmentType;

  const WorkoutShareScreen({
    super.key,
    required this.workoutData,
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
  String _aspectRatio = 'free'; // 'free', '1:1', '4:3', '16:9'
  double _imageAspectRatio = 1.0; // 실제 이미지 비율 저장
  bool _isProcessing = false;

  // 드래그 가능한 레이아웃 위치 및 크기
  Offset _contentPosition = const Offset(0.5, 0.75); // 중앙 하단
  double _contentScale = 1.0; // 크기 배율 (0.5 ~ 2.0)
  
  // 제스처 기준점 저장용
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
                  // 이미지 선택 섹션
                  _buildImageSection(),
                  const SizedBox(height: 24),

                  // 레이아웃 선택 섹션
                  if (_selectedImage != null) ...[
                    _buildLayoutSelection(),
                    const SizedBox(height: 24),
                  ],

                  // 미리보기 섹션
                  if (_selectedImage != null) ...[
                    _buildPreviewSection(),
                  ],
                ],
              ),
            ),
          ),

          // 하단 버튼
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
            const Text(
              '배경 이미지 선택',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
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

  Widget _buildLayoutSelection() {
    final workout = widget.workoutData.value as WorkoutHealthValue;
    final workoutType = workout.workoutActivityType.name;
    final isRunning = workoutType.toUpperCase().contains('RUNNING');
    final isStrength = _isStrengthWorkout(workoutType);

    // 사용 가능한 레이아웃 목록 생성
    final List<Map<String, dynamic>> availableLayouts = [
      {
        'value': 'minimal',
        'title': '미니멀',
        'type': 'icon', // 타입 구분
        'icon': Icons.view_compact,
      },
      {
        'value': 'detailed',
        'title': '상세',
        'type': 'icon',
        'icon': Icons.view_headline,
      },
      if (isRunning)
        {
          'value': 'running',
          'title': '러닝',
          'type': 'svg', // SVG 타입
          'path': _getWorkoutIconPath(workoutType, environmentType: widget.environmentType),
        },
      if (isStrength)
        {
          'value': 'strength',
          'title': '근력',
          'type': 'svg', // SVG로 변경 (통일성 위해)
          'path': _getWorkoutIconPath(workoutType, environmentType: widget.environmentType),
        },
    ];

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '레이아웃 선택',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            // Row with Expanded children to fill width
            Row(
              children: availableLayouts.asMap().entries.map((entry) {
                final index = entry.key;
                final layout = entry.value;
                final isSelected = _selectedLayout == layout['value'];
                
                return Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(
                      right: index < availableLayouts.length - 1 ? 8.0 : 0,
                    ),
                    child: InkWell(
                      onTap: () {
                        setState(() {
                          _selectedLayout = layout['value'] as String;
                        });
                      },
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: isSelected
                                ? Theme.of(context).colorScheme.primary
                                : Colors.grey.shade300,
                            width: isSelected ? 2 : 1,
                          ),
                          borderRadius: BorderRadius.circular(12),
                          color: isSelected
                              ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.15)
                              : Colors.grey.shade50,
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            if (layout['type'] == 'svg')
                              SvgPicture.asset(
                                layout['path'] as String,
                                width: 28,
                                height: 28,
                                colorFilter: ColorFilter.mode(
                                  isSelected
                                      ? Theme.of(context).colorScheme.primary
                                      : Colors.grey.shade600,
                                  BlendMode.srcIn,
                                ),
                              )
                            else
                              Icon(
                                layout['icon'] as IconData,
                                color: isSelected
                                    ? Theme.of(context).colorScheme.primary
                                    : Colors.grey.shade600,
                                size: 28,
                              ),
                            const SizedBox(height: 8),
                            Text(
                              layout['title'] as String,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: isSelected
                                    ? Theme.of(context).colorScheme.primary
                                    : Colors.grey.shade800,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPreviewSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '미리보기 (텍스트 드래그 가능)',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
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
    final workout = widget.workoutData.value as WorkoutHealthValue;
    final workoutType = workout.workoutActivityType.name;

    if (_selectedImage == null) return const SizedBox.shrink();

    return LayoutBuilder(
      builder: (context, constraints) {
        // 이미지 비율에 따라 높이 계산 (최대 500)
        final maxWidth = constraints.maxWidth;
        double calculatedHeight = maxWidth / _imageAspectRatio;
        
        // 너무 길어지는 경우 대비하여 제한 (옵션)
        if (calculatedHeight > 600) {
          calculatedHeight = 600;
        }

        return ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Container(
            width: maxWidth,
            height: calculatedHeight,
            color: Colors.black,
            child: Stack(
              children: [
                // 배경 이미지 (크롭된 비율에 딱 맞게 채움)
                Positioned.fill(
                  child: Image.file(
                    _selectedImage!,
                    fit: BoxFit.cover, 
                  ),
                ),

                // 그라데이션 오버레이
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.black.withValues(alpha: 0.3),
                          Colors.black.withValues(alpha: 0.7),
                        ],
                      ),
                    ),
                  ),
                ),

                // 3x3 가이드라인
                if (_isDragging)
                  Positioned.fill(
                    child: CustomPaint(
                      painter: GridPainter(),
                    ),
                  ),

                // 로고
                Positioned(
                  top: 20,
                  left: 20,
                  child: SvgPicture.asset(
                    'assets/images/pllogo.svg',
                    width: 32,
                    height: 32,
                    colorFilter: ColorFilter.mode(
                      Theme.of(context).colorScheme.primary,
                      BlendMode.srcIn,
                    ),
                  ),
                ),

                // 드래그 가능한 운동 정보
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
                        // 1. 배율 업데이트 (시작 배율 기준으로 곱함 - 부드러운 확대/축소)
                        _contentScale = (_baseScale * details.scale).clamp(0.5, 2.5);
                        
                        // 2. 위치 업데이트 (이전 프레임 대비 변화량을 현재 위치에 더함 - 1:1 반응)
                        // focalPointDelta는 이전 업데이트 이후의 변화량을 제공하므로 현재 위치에 바로 더하면 손가락을 정확히 따라옵니다.
                        double newDx = _contentPosition.dx + (details.focalPointDelta.dx / maxWidth);
                        double newDy = _contentPosition.dy + (details.focalPointDelta.dy / calculatedHeight);

                        _contentPosition = Offset(
                          newDx.clamp(0.0, 1.0),
                          newDy.clamp(0.0, 1.0),
                        );
                      });
                    },
                    onScaleEnd: (_) {
                      setState(() => _isDragging = false);
                    },
                    child: Stack(
                      children: [
                        Align(
                          alignment: FractionalOffset(_contentPosition.dx, _contentPosition.dy),
                          child: Transform.scale(
                            scale: _contentScale,
                            child: Container(
                              padding: const EdgeInsets.all(12),
                              child: IgnorePointer(
                                child: _buildLayoutContent(workoutType, workout),
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

  Widget _buildLayoutContent(String workoutType, WorkoutHealthValue workout) {
    switch (_selectedLayout) {
      case 'minimal':
        return _buildMinimalLayout(workoutType, workout);
      case 'detailed':
        return _buildDetailedLayout(workoutType, workout);
      case 'running':
        return _buildRunningLayout(workoutType, workout);
      case 'strength':
        return _buildStrengthLayout(workoutType, workout);
      default:
        return _buildMinimalLayout(workoutType, workout);
    }
  }

  Widget _buildMinimalLayout(String workoutType, WorkoutHealthValue workout) {
    final totalDistance = workout.totalDistance;
    final duration = widget.workoutData.dateTo.difference(widget.workoutData.dateFrom);
    final displayTitle = widget.templateName ?? _formatWorkoutType(workoutType);

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // 운동 타입
          Text(
            displayTitle,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 32,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),

          // 핵심 지표
          Wrap(
            spacing: 12,
            runSpacing: 8,
            children: [
              if (totalDistance != null && totalDistance > 0)
                _buildStatBadge(
                  '${(totalDistance / 1000).toStringAsFixed(2)} km',
                  '거리',
                ),
              _buildStatBadge(
                _formatDuration(duration),
                '시간',
              ),
              if (widget.avgPace > 0)
                _buildStatBadge(
                  _formatPace(widget.avgPace),
                  '평균 페이스',
                ),
            ],
          ),
          const SizedBox(height: 8),

          // 날짜
          Text(
            DateFormat('yyyy.MM.dd HH:mm').format(widget.workoutData.dateFrom),
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.8),
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailedLayout(String workoutType, WorkoutHealthValue workout) {
    final totalDistance = workout.totalDistance;
    final totalEnergy = workout.totalEnergyBurned;
    final duration = widget.workoutData.dateTo.difference(widget.workoutData.dateFrom);
    final displayTitle = widget.templateName ?? _formatWorkoutType(workoutType);

    return Padding(
      padding: const EdgeInsets.all(12.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // 운동 타입
          Text(
            displayTitle,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 10),

          // 모든 통계
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (totalDistance != null && totalDistance > 0)
                _buildStatCard(
                  '거리',
                  '${(totalDistance / 1000).toStringAsFixed(2)} km',
                  Icons.straighten,
                ),
              _buildStatCard(
                '시간',
                _formatDuration(duration),
                Icons.timer,
              ),
              if (widget.avgPace > 0)
                _buildStatCard(
                  '페이스',
                  _formatPace(widget.avgPace),
                  Icons.speed,
                ),
              if (widget.avgHeartRate > 0)
                _buildStatCard(
                  '심박수',
                  '${widget.avgHeartRate.toInt()} bpm',
                  Icons.favorite,
                ),
              if (totalEnergy != null && totalEnergy > 0)
                _buildStatCard(
                  '칼로리',
                  '${totalEnergy.toInt()} kcal',
                  Icons.local_fire_department,
                ),
            ],
          ),
          const SizedBox(height: 8),

          // 날짜
          Text(
            DateFormat('yyyy.MM.dd HH:mm').format(widget.workoutData.dateFrom),
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.8),
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRunningLayout(String workoutType, WorkoutHealthValue workout) {
    final totalDistance = workout.totalDistance;
    final duration = widget.workoutData.dateTo.difference(widget.workoutData.dateFrom);
    final displayTitle = widget.templateName ?? 'RUNNING';

    return Padding(
      padding: const EdgeInsets.all(12.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // 러닝 아이콘
          SvgPicture.asset(
            _getWorkoutIconPath(workoutType, environmentType: widget.environmentType),
            width: 32,
            height: 32,
            colorFilter: ColorFilter.mode(
              Theme.of(context).colorScheme.primary,
              BlendMode.srcIn,
            ),
          ),
          const SizedBox(height: 8),

          Text(
            displayTitle,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 10),

          // 러닝 핵심 지표
          if (totalDistance != null && totalDistance > 0) ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  (totalDistance / 1000).toStringAsFixed(2),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(width: 6),
                const Padding(
                  padding: EdgeInsets.only(bottom: 5.0),
                  child: Text(
                    'km',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
          ],

          Wrap(
            spacing: 12,
            runSpacing: 8,
            children: [
              if (widget.avgPace > 0)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '페이스',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.8),
                        fontSize: 10,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _formatPace(widget.avgPace),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '시간',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.8),
                      fontSize: 10,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _formatDuration(duration),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              if (widget.avgHeartRate > 0)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '심박수',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.8),
                        fontSize: 10,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${widget.avgHeartRate.toInt()} bpm',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
            ],
          ),
          const SizedBox(height: 8),

          // 날짜
          Text(
            DateFormat('yyyy.MM.dd HH:mm').format(widget.workoutData.dateFrom),
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.8),
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStrengthLayout(String workoutType, WorkoutHealthValue workout) {
    final totalEnergy = workout.totalEnergyBurned;
    final duration = widget.workoutData.dateTo.difference(widget.workoutData.dateFrom);
    final displayTitle = widget.templateName ?? _formatWorkoutType(workoutType);

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // 근력 아이콘
          SvgPicture.asset(
            _getWorkoutIconPath(workoutType, environmentType: widget.environmentType),
            width: 48,
            height: 48,
            colorFilter: ColorFilter.mode(
              Theme.of(context).colorScheme.primary,
              BlendMode.srcIn,
            ),
          ),
          const SizedBox(height: 12),

          Text(
            displayTitle,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 28,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),

          // 근력 운동 지표
          Wrap(
            spacing: 24,
            runSpacing: 12,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '운동 시간',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.8),
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _formatDuration(duration),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              if (totalEnergy != null && totalEnergy > 0)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '칼로리',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.8),
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${totalEnergy.toInt()} kcal',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
            ],
          ),
          const SizedBox(height: 12),

          // 날짜
          Text(
            DateFormat('yyyy.MM.dd HH:mm').format(widget.workoutData.dateFrom),
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.8),
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatBadge(String value, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.8),
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 14),
          const SizedBox(width: 4),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.8),
                  fontSize: 9,
                ),
              ),
              Text(
                value,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBottomActions() {
    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: ElevatedButton.icon(
              onPressed: _saveImage,
              icon: const Icon(Icons.save_alt),
              label: const Text('저장'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: ElevatedButton.icon(
              onPressed: _shareImage,
              icon: const Icon(Icons.share),
              label: const Text('공유'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.primary,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      // iOS 카메라 접근 시 권한 확인
      if (source == ImageSource.camera && Platform.isIOS) {
        final status = await Permission.camera.status;
        if (status.isDenied || status.isPermanentlyDenied) {
          final result = await Permission.camera.request();
          if (!result.isGranted) {
            if (mounted) {
              _showPermissionDialog('카메라 권한이 필요합니다. 설정에서 권한을 허용해주세요.');
            }
            return;
          }
        }
      }
      
      // iOS 갤러리 접근 시 '전체 접근 권한' 요청 (사용자 요구사항)
      if (source == ImageSource.gallery && Platform.isIOS) {
        // Permission.photos는 iOS에서 전체 라이브러리 접근 권한을 의미함
        var status = await Permission.photos.status;
        
        if (status.isDenied || status.isLimited || status.isPermanentlyDenied) {
          // 권한이 없거나 제한된 경우 요청
          final result = await Permission.photos.request();
          
          if (!result.isGranted && !result.isLimited) {
             // 거부됨
             if (mounted) {
               _showPermissionDialog('사진 라이브러리 전체 접근 권한이 필요합니다.\n설정 > PaceLifter > 사진 > "모든 사진"을 선택해주세요.');
             }
             return;
          }
        }
      }

      // 이미지 선택
      final XFile? image = await _picker.pickImage(
        source: source,
        imageQuality: 100,
      );

      if (image != null) {
        // 즉시 크롭 화면으로 이동 (아이폰 기본 스타일)
        await _cropImage(File(image.path));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('이미지 선택 실패: $e')),
        );
      }
    }
  }

  void _showPermissionDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('권한 필요'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              openAppSettings();
            },
            child: const Text('설정 열기'),
          ),
        ],
      ),
    );
  }

  Future<void> _cropImage(File imageFile) async {
    try {
      final croppedFile = await ImageCropper().cropImage(
        sourcePath: imageFile.path,
        uiSettings: [
          IOSUiSettings(
            title: '이미지 편집',
            cancelButtonTitle: '취소',
            doneButtonTitle: '완료',
            aspectRatioLockEnabled: false,
            resetAspectRatioEnabled: true,
            aspectRatioPickerButtonHidden: false, 
            showCancelConfirmationDialog: true,
            hidesNavigationBar: false, // 네비게이션 바 유지
          ),
          AndroidUiSettings(
            toolbarTitle: '이미지 편집',
            toolbarColor: Theme.of(context).colorScheme.surface,
            toolbarWidgetColor: Theme.of(context).colorScheme.onSurface,
            initAspectRatio: CropAspectRatioPreset.square,
            lockAspectRatio: false,
          ),
        ],
      );

      if (croppedFile != null) {
        // 실제 이미지 크기를 읽어와서 비율 계산
        final data = await File(croppedFile.path).readAsBytes();
        final codec = await ui.instantiateImageCodec(data);
        final frame = await codec.getNextFrame();
        
        if (mounted) {
          setState(() {
            _selectedImage = File(croppedFile.path);
            _imageAspectRatio = frame.image.width / frame.image.height;
            _aspectRatio = 'free'; 
          });
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('이미지 편집 실패: $e')),
        );
      }
    }
  }

  // _showCropOptions 및 _buildCropOption 제거 (크롭 UI에서 통합 처리)

  Future<void> _saveImage() async {
    setState(() {
      _isProcessing = true;
    });

    try {
      final Uint8List? imageBytes = await _screenshotController.capture();

      if (imageBytes != null) {
        await ImageGallerySaver.saveImage(
          imageBytes,
          quality: 100,
          name: 'pacelifter_${DateTime.now().millisecondsSinceEpoch}',
        );

        if (mounted) {
          _showAdModal(); // 저장 완료 후 광고 모달 표시
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('저장 실패: $e')),
        );
      }
    } finally {
      setState(() {
        _isProcessing = false;
      });
    }
  }

  Future<void> _shareImage() async {
    setState(() {
      _isProcessing = true;
    });

    try {
      final Uint8List? imageBytes = await _screenshotController.capture();

      if (imageBytes != null) {
        // 임시 파일로 저장
        final tempDir = Directory.systemTemp;
        final file = await File(
          '${tempDir.path}/pacelifter_share_${DateTime.now().millisecondsSinceEpoch}.png',
        ).create();
        await file.writeAsBytes(imageBytes);

        // 공유
        final box = context.findRenderObject() as RenderBox?;
        
        await Share.shareXFiles(
          [XFile(file.path)],
          text: 'PaceLifter로 기록한 운동 🏃‍♂️💪',
          sharePositionOrigin: box != null 
              ? box.localToGlobal(Offset.zero) & box.size 
              : null,
        );

        if (mounted) {
          _showAdModal(); // 공유 완료 후 광고 모달 표시
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('공유 실패: $e')),
        );
      }
    } finally {
      setState(() {
        _isProcessing = false;
      });
    }
  }

  void _showAdModal() {
    showDialog(
      context: context,
      barrierDismissible: false, // 광고는 강제로 닫아야 함 (선택 사항)
      builder: (context) => AlertDialog(
        title: const Text('공유 완료!'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.check_circle_outline,
              color: Colors.green,
              size: 64,
            ),
            const SizedBox(height: 16),
            const Text(
              '이미지 저장이 완료되었습니다.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            Container(
              width: double.infinity,
              height: 150,
              color: Colors.grey.shade200,
              child: const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.ad_units, size: 48, color: Colors.grey),
                    SizedBox(height: 8),
                    Text('광고 영역', style: TextStyle(color: Colors.grey)),
                  ],
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('닫기'),
          ),
        ],
      ),
    );
  }

  bool _isStrengthWorkout(String type) {
    final upperType = type.toUpperCase();
    return upperType.contains('CORE') ||
        upperType.contains('FUNCTIONAL') ||
        upperType.contains('STRENGTH') ||
        upperType.contains('WEIGHT') ||
        upperType.contains('TRADITIONAL_STRENGTH_TRAINING');
  }

  String _getWorkoutIconPath(String type, {String? environmentType}) {
    final upperType = type.toUpperCase();
    
    // 트레일 환경 체크
    if (environmentType == 'Trail') {
      return 'assets/images/endurance/trail-icon.svg';
    }

    if (upperType.contains('CORE') || upperType.contains('FUNCTIONAL')) {
      return 'assets/images/strength/core-icon.svg';
    } else if (upperType.contains('STRENGTH') ||
        upperType.contains('WEIGHT') ||
        upperType.contains('TRADITIONAL_STRENGTH_TRAINING')) {
      return 'assets/images/strength/lifter-icon.svg';
    } else {
      return 'assets/images/endurance/runner-icon.svg';
    }
  }

  String _formatWorkoutType(String type) {
    final upperType = type.toUpperCase();
    if (type == 'TRADITIONAL_STRENGTH_TRAINING') {
      return 'STRENGTH TRAINING';
    }
    if (type == 'CORE_TRAINING') {
      return 'CORE TRAINING';
    }
    if (upperType.contains('RUNNING')) {
      return 'RUNNING';
    }
    return type
        .replaceAll('WORKOUT_ACTIVITY_TYPE_', '')
        .replaceAll('_', ' ')
        .toLowerCase()
        .split(' ')
        .map(
          (word) =>
              word.isEmpty ? '' : word[0].toUpperCase() + word.substring(1),
        )
        .join(' ');
  }

  String _formatPace(double pace) {
    final minutes = pace.floor();
    final seconds = ((pace - minutes) * 60).round();
    return "$minutes'${seconds.toString().padLeft(2, '0')}\"";
  }

  String _formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);

    if (hours > 0) {
      return '$hours:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    } else if (minutes > 0) {
      return '$minutes:${seconds.toString().padLeft(2, '0')}';
    } else {
      return '0:${seconds.toString().padLeft(2, '0')}';
    }
  }
}
