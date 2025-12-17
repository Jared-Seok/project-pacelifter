import 'dart:io';
import 'dart:typed_data';
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

/// 운동 공유 화면
class WorkoutShareScreen extends StatefulWidget {
  final HealthDataPoint workoutData;
  final List<HealthDataPoint> heartRateData;
  final double avgHeartRate;
  final List<HealthDataPoint> paceData;
  final double avgPace;
  final Duration? movingTime;

  const WorkoutShareScreen({
    super.key,
    required this.workoutData,
    required this.heartRateData,
    required this.avgHeartRate,
    required this.paceData,
    required this.avgPace,
    this.movingTime,
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
  bool _isProcessing = false;

  // 드래그 가능한 레이아웃 위치 및 크기
  Offset _contentPosition = const Offset(0.5, 0.75); // 중앙 하단
  double _contentScale = 1.0; // 크기 배율 (0.5 ~ 2.0)
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
                      backgroundColor: Theme.of(context).colorScheme.secondary,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ],
            ),
            if (_selectedImage != null) ...[
              const SizedBox(height: 16),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.file(
                  _selectedImage!,
                  height: 200,
                  width: double.infinity,
                  fit: BoxFit.cover,
                ),
              ),
            ],
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
        'description': '핵심 지표',
        'icon': Icons.view_compact,
      },
      {
        'value': 'detailed',
        'title': '상세',
        'description': '전체 통계',
        'icon': Icons.view_headline,
      },
      if (isRunning)
        {
          'value': 'running',
          'title': '러닝',
          'description': '러닝 전용',
          'icon': Icons.directions_run,
        },
      if (isStrength)
        {
          'value': 'strength',
          'title': '근력',
          'description': '근력 전용',
          'icon': Icons.fitness_center,
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
            // 가로 스크롤 레이아웃 옵션
            SizedBox(
              height: 90,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: availableLayouts.length,
                separatorBuilder: (context, index) => const SizedBox(width: 12),
                itemBuilder: (context, index) {
                  final layout = availableLayouts[index];
                  final isSelected = _selectedLayout == layout['value'];

                  return InkWell(
                    onTap: () {
                      setState(() {
                        _selectedLayout = layout['value'] as String;
                      });
                    },
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      width: 100,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: isSelected
                              ? Theme.of(context).colorScheme.secondary
                              : Colors.grey.shade300,
                          width: isSelected ? 2 : 1,
                        ),
                        borderRadius: BorderRadius.circular(12),
                        color: isSelected
                            ? Theme.of(context).colorScheme.secondary.withValues(alpha: 0.15)
                            : Colors.grey.shade50,
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            layout['icon'] as IconData,
                            color: isSelected
                                ? Theme.of(context).colorScheme.secondary
                                : Colors.grey.shade600,
                            size: 32,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            layout['title'] as String,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: isSelected
                                  ? Theme.of(context).colorScheme.secondary
                                  : Colors.grey.shade800,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            layout['description'] as String,
                            style: TextStyle(
                              fontSize: 10,
                              color: Colors.grey.shade600,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
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
              '미리보기',
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

    return SizedBox(
      height: 500,
      width: double.infinity,
      child: Stack(
        children: [
          // 배경 이미지
          if (_selectedImage != null)
            Positioned.fill(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.file(
                  _selectedImage!,
                  fit: BoxFit.cover,
                ),
              ),
            ),

          // 그라데이션 오버레이
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
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

          // 로고 (좌측 상단 고정)
          Positioned(
            top: 24,
            left: 24,
            child: SvgPicture.asset(
              'assets/images/pllogo.svg',
              width: 40,
              height: 40,
              colorFilter: ColorFilter.mode(
                Theme.of(context).colorScheme.secondary,
                BlendMode.srcIn,
              ),
            ),
          ),

          // 드래그 및 스케일 가능한 운동 정보
          Positioned(
            left: _contentPosition.dx * 500,
            top: _contentPosition.dy * 500,
            child: GestureDetector(
              onScaleStart: (details) {
                setState(() {
                  _isDragging = true;
                });
              },
              onScaleUpdate: (details) {
                setState(() {
                  // 스케일 업데이트 (0.5 ~ 2.0 범위로 제한)
                  _contentScale = (_contentScale * details.scale).clamp(0.5, 2.0);

                  // 위치 업데이트 (드래그)
                  double newDx = (_contentPosition.dx * 500 + details.focalPointDelta.dx) / 500;
                  double newDy = (_contentPosition.dy * 500 + details.focalPointDelta.dy) / 500;

                  // 경계 제한
                  newDx = newDx.clamp(0.0, 0.9);
                  newDy = newDy.clamp(0.1, 0.9);

                  _contentPosition = Offset(newDx, newDy);
                });
              },
              onScaleEnd: (_) {
                setState(() {
                  _isDragging = false;
                });
              },
              child: Transform.scale(
                scale: _contentScale,
                child: Container(
                  decoration: BoxDecoration(
                    color: _isDragging
                        ? Colors.white.withValues(alpha: 0.1)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(8),
                    border: _isDragging
                        ? Border.all(color: Colors.white.withValues(alpha: 0.5), width: 2)
                        : null,
                  ),
                  child: _buildLayoutContent(workoutType, workout),
                ),
              ),
            ),
          ),
        ],
      ),
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

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // 운동 타입
          Text(
            _formatWorkoutType(workoutType),
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

    return Padding(
      padding: const EdgeInsets.all(12.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // 운동 타입
          Text(
            _formatWorkoutType(workoutType),
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

    return Padding(
      padding: const EdgeInsets.all(12.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // 러닝 아이콘
          SvgPicture.asset(
            'assets/images/runner-icon.svg',
            width: 32,
            height: 32,
            colorFilter: ColorFilter.mode(
              Theme.of(context).colorScheme.secondary,
              BlendMode.srcIn,
            ),
          ),
          const SizedBox(height: 8),

          const Text(
            'RUNNING',
            style: TextStyle(
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

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // 근력 아이콘
          SvgPicture.asset(
            _getWorkoutIconPath(workoutType),
            width: 48,
            height: 48,
            colorFilter: ColorFilter.mode(
              Theme.of(context).colorScheme.primary,
              BlendMode.srcIn,
            ),
          ),
          const SizedBox(height: 12),

          Text(
            _formatWorkoutType(workoutType),
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
                backgroundColor: Theme.of(context).colorScheme.secondary,
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
      // iOS에서는 갤러리 접근 시 명시적으로 권한 요청
      if (source == ImageSource.gallery && Platform.isIOS) {
        final status = await Permission.photos.status;

        // 권한이 거부되었거나 제한된 경우 권한 요청
        if (status.isDenied || status.isPermanentlyDenied || status.isLimited) {
          final result = await Permission.photos.request();

          // 권한이 부여되지 않았거나 제한된 경우
          if (!result.isGranted || result.isLimited) {
            if (mounted) {
              // 기존 SnackBar 제거
              ScaffoldMessenger.of(context).clearSnackBars();

              final message = result.isLimited
                  ? '전체 사진 라이브러리 접근을 위해 설정에서 "모든 사진" 접근을 허용해주세요.'
                  : '사진 라이브러리 권한이 필요합니다. 설정에서 권한을 허용해주세요.';

              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(message),
                  action: SnackBarAction(
                    label: '설정',
                    onPressed: () => openAppSettings(),
                  ),
                  duration: const Duration(seconds: 4),
                ),
              );
            }

            // 제한된 권한이라도 선택한 사진은 접근 가능하므로 계속 진행
            if (!result.isLimited) {
              return;
            }
          }
        }
      }

      // 이미지 선택
      final XFile? image = await _picker.pickImage(
        source: source,
        imageQuality: 100,
      );

      if (image != null) {
        // 크롭 옵션 표시
        await _showCropOptions(File(image.path));
      }
    } catch (e) {
      // 권한 거부 또는 기타 오류 처리
      if (mounted) {
        // 기존 SnackBar 제거
        ScaffoldMessenger.of(context).clearSnackBars();

        final errorMessage = e.toString().toLowerCase();

        // 권한 관련 오류인지 확인
        if (errorMessage.contains('permission') ||
            errorMessage.contains('denied') ||
            errorMessage.contains('authorization')) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                source == ImageSource.camera
                    ? '카메라 권한이 거부되었습니다. 설정에서 권한을 허용해주세요.'
                    : '사진 라이브러리 권한이 거부되었습니다. 설정에서 권한을 허용해주세요.',
              ),
              action: SnackBarAction(
                label: '설정',
                onPressed: () => openAppSettings(),
              ),
              duration: const Duration(seconds: 4),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('이미지 선택 실패: $e'),
              duration: const Duration(seconds: 3),
            ),
          );
        }
      }
    }
  }

  Future<void> _showCropOptions(File imageFile) async {
    final selectedRatio = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('이미지 비율 선택'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildCropOption(context, '자유 비율', 'free'),
            _buildCropOption(context, '정사각형 (1:1)', '1:1'),
            _buildCropOption(context, '가로형 (4:3)', '4:3'),
            _buildCropOption(context, '와이드 (16:9)', '16:9'),
          ],
        ),
      ),
    );

    if (selectedRatio != null) {
      setState(() {
        _aspectRatio = selectedRatio;
      });

      if (selectedRatio == 'free') {
        // 자유 비율은 크롭 없이 사용
        setState(() {
          _selectedImage = imageFile;
        });
      } else {
        // 선택한 비율로 크롭
        await _cropImage(imageFile, selectedRatio);
      }
    }
  }

  Widget _buildCropOption(BuildContext context, String title, String value) {
    return ListTile(
      title: Text(title),
      onTap: () => Navigator.pop(context, value),
    );
  }

  Future<void> _cropImage(File imageFile, String ratio) async {
    try {
      CropAspectRatio? aspectRatio;

      switch (ratio) {
        case '1:1':
          aspectRatio = const CropAspectRatio(ratioX: 1, ratioY: 1);
          break;
        case '4:3':
          aspectRatio = const CropAspectRatio(ratioX: 4, ratioY: 3);
          break;
        case '16:9':
          aspectRatio = const CropAspectRatio(ratioX: 16, ratioY: 9);
          break;
      }

      final croppedFile = await ImageCropper().cropImage(
        sourcePath: imageFile.path,
        aspectRatio: aspectRatio,
        uiSettings: [
          IOSUiSettings(
            title: '이미지 자르기',
            cancelButtonTitle: '취소',
            doneButtonTitle: '완료',
            aspectRatioLockEnabled: aspectRatio != null,
          ),
        ],
      );

      if (croppedFile != null) {
        setState(() {
          _selectedImage = File(croppedFile.path);
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('이미지 자르기 실패: $e')),
        );
      }
    }
  }

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
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('이미지가 저장되었습니다')),
          );
        }

        // TODO: 광고 표시 (나중에 추가)
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
        await Share.shareXFiles(
          [XFile(file.path)],
          text: 'PaceLifter로 기록한 운동 🏃‍♂️💪',
        );

        // TODO: 광고 표시 (나중에 추가)
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

  bool _isStrengthWorkout(String type) {
    final upperType = type.toUpperCase();
    return upperType.contains('CORE') ||
        upperType.contains('FUNCTIONAL') ||
        upperType.contains('STRENGTH') ||
        upperType.contains('WEIGHT') ||
        upperType.contains('TRADITIONAL_STRENGTH_TRAINING');
  }

  String _getWorkoutIconPath(String type) {
    final upperType = type.toUpperCase();
    if (upperType.contains('CORE') || upperType.contains('FUNCTIONAL')) {
      return 'assets/images/core-icon.svg';
    } else if (upperType.contains('STRENGTH') ||
        upperType.contains('WEIGHT') ||
        upperType.contains('TRADITIONAL_STRENGTH_TRAINING')) {
      return 'assets/images/lifter-icon.svg';
    } else {
      return 'assets/images/runner-icon.svg';
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
