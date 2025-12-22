import 'package:flutter/material.dart';
import 'package:health/health.dart';
import 'package:intl/intl.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// 수동 운동 추가 화면
class AddWorkoutScreen extends StatefulWidget {
  const AddWorkoutScreen({super.key});

  @override
  State<AddWorkoutScreen> createState() => _AddWorkoutScreenState();
}

class _AddWorkoutScreenState extends State<AddWorkoutScreen> {
  // 운동 타입 선택
  String _selectedCategory = 'Endurance'; // Endurance 또는 Strength

  // 날짜 및 시간
  DateTime _selectedDate = DateTime.now();
  TimeOfDay _startTime = TimeOfDay.now();
  TimeOfDay _endTime = TimeOfDay.now();

  // Endurance 전용 필드
  final TextEditingController _distanceController = TextEditingController();
  final TextEditingController _paceMinController = TextEditingController();
  final TextEditingController _paceSecController = TextEditingController();

  // Strength 전용 필드 (추후 확장)

  // 로딩 상태
  bool _isSaving = false;

  final Health _health = Health();

  @override
  void dispose() {
    _distanceController.dispose();
    _paceMinController.dispose();
    _paceSecController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('운동 추가'),
        backgroundColor: Theme.of(context).colorScheme.surface,
      ),
      body: _isSaving
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildCategorySelector(),
                  const SizedBox(height: 24),
                  _buildDateTimePickers(),
                  const SizedBox(height: 24),
                  if (_selectedCategory == 'Endurance') ...[
                    _buildEnduranceInputs(),
                  ] else ...[
                    _buildStrengthInputs(),
                  ],
                  const SizedBox(height: 32),
                  _buildSaveButton(),
                ],
              ),
            ),
    );
  }

  Widget _buildCategorySelector() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '운동 타입',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildCategoryButton(
                    'Endurance',
                    Icons.directions_run,
                    Theme.of(context).colorScheme.secondary,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildCategoryButton(
                    'Strength',
                    Icons.fitness_center,
                    Theme.of(context).colorScheme.primary,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryButton(String category, IconData icon, Color color) {
    final isSelected = _selectedCategory == category;

    // SVG 아이콘 경로 결정
    final String svgPath = category == 'Endurance'
        ? 'assets/images/endurance/runner-icon.svg'
        : 'assets/images/strength/lifter-icon.svg';

    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedCategory = category;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 20),
        decoration: BoxDecoration(
          color: isSelected ? color.withValues(alpha: 0.2) : Colors.transparent,
          border: Border.all(
            color: isSelected ? color : Colors.grey.withValues(alpha: 0.3),
            width: 2,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            SvgPicture.asset(
              svgPath,
              width: 40,
              height: 40,
              colorFilter: ColorFilter.mode(
                isSelected ? color : Colors.grey,
                BlendMode.srcIn,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              category,
              style: TextStyle(
                fontSize: 16,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                color: isSelected ? color : Colors.grey,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDateTimePickers() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '날짜 및 시간',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            // 날짜 선택
            ListTile(
              leading: const Icon(Icons.calendar_today),
              title: const Text('날짜'),
              subtitle: Text(DateFormat('yyyy년 MM월 dd일').format(_selectedDate)),
              onTap: _selectDate,
            ),
            const Divider(),
            // 시작 시간
            ListTile(
              leading: const Icon(Icons.access_time),
              title: const Text('시작 시간'),
              subtitle: Text(_startTime.format(context)),
              onTap: () => _selectTime(true),
            ),
            const Divider(),
            // 종료 시간
            ListTile(
              leading: const Icon(Icons.access_time_filled),
              title: const Text('종료 시간'),
              subtitle: Text(_endTime.format(context)),
              onTap: () => _selectTime(false),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEnduranceInputs() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '러닝 정보',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            // 거리 입력
            TextField(
              controller: _distanceController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: '거리 (km)',
                hintText: '예: 5.0',
                prefixIcon: Icon(Icons.straighten),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            // 페이스 입력
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _paceMinController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: '페이스 (분)',
                      hintText: '5',
                      prefixIcon: Icon(Icons.speed),
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                const Text(':', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _paceSecController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: '페이스 (초)',
                      hintText: '30',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              '페이스: 1km당 소요 시간 (예: 5분 30초/km)',
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStrengthInputs() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '웨이트 정보',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Center(
              child: Text(
                'Strength 운동 상세 입력은 추후 지원됩니다.\n현재는 시작/종료 시간만 기록됩니다.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSaveButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: _saveWorkout,
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 16),
          backgroundColor: _selectedCategory == 'Endurance'
              ? Theme.of(context).colorScheme.secondary
              : Theme.of(context).colorScheme.primary,
          foregroundColor: Colors.white,
        ),
        child: const Text(
          '저장',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  Future<void> _selectDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  Future<void> _selectTime(bool isStartTime) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: isStartTime ? _startTime : _endTime,
    );
    if (picked != null) {
      setState(() {
        if (isStartTime) {
          _startTime = picked;
        } else {
          _endTime = picked;
        }
      });
    }
  }

  Future<void> _saveWorkout() async {
    // 유효성 검사
    if (_selectedCategory == 'Endurance') {
      if (_distanceController.text.isEmpty) {
        _showError('거리를 입력해주세요.');
        return;
      }
      if (_paceMinController.text.isEmpty || _paceSecController.text.isEmpty) {
        _showError('페이스를 입력해주세요.');
        return;
      }
    }

    // 시작/종료 DateTime 생성
    final startDateTime = DateTime(
      _selectedDate.year,
      _selectedDate.month,
      _selectedDate.day,
      _startTime.hour,
      _startTime.minute,
    );

    final endDateTime = DateTime(
      _selectedDate.year,
      _selectedDate.month,
      _selectedDate.day,
      _endTime.hour,
      _endTime.minute,
    );

    // 종료 시간이 시작 시간보다 이전인지 확인
    if (endDateTime.isBefore(startDateTime) || endDateTime.isAtSameMomentAs(startDateTime)) {
      _showError('종료 시간은 시작 시간보다 이후여야 합니다.');
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      // HealthKit 권한 요청
      final hasPermission = await _health.requestAuthorization([
        HealthDataType.WORKOUT,
        HealthDataType.DISTANCE_WALKING_RUNNING,
        HealthDataType.ACTIVE_ENERGY_BURNED,
      ], permissions: [
        HealthDataAccess.READ_WRITE,
        HealthDataAccess.READ_WRITE,
        HealthDataAccess.READ_WRITE,
      ]);

      if (!hasPermission) {
        throw Exception('HealthKit 권한이 필요합니다.');
      }

      if (_selectedCategory == 'Endurance') {
        await _saveEnduranceWorkout(startDateTime, endDateTime);
      } else {
        await _saveStrengthWorkout(startDateTime, endDateTime);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('운동이 저장되었습니다.')),
        );
        Navigator.of(context).pop(true); // true를 반환하여 새로고침 트리거
      }
    } catch (e) {
      if (mounted) {
        _showError('저장 중 오류가 발생했습니다: $e');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  Future<void> _saveEnduranceWorkout(DateTime start, DateTime end) async {
    final distance = double.parse(_distanceController.text);

    // 페이스로부터 칼로리 계산
    final durationMinutes = end.difference(start).inMinutes;
    final calories = _calculateCalories(distance, durationMinutes);

    // HealthKit에 저장
    final saved = await _health.writeWorkoutData(
      activityType: HealthWorkoutActivityType.RUNNING,
      start: start,
      end: end,
      totalDistance: (distance * 1000).toInt(), // km -> m
      totalEnergyBurned: calories.toInt(),
    );

    if (!saved) {
      throw Exception('HealthKit 저장 실패');
    }

    // 거리 샘플 저장
    await _health.writeHealthData(
      value: distance * 1000,
      type: HealthDataType.DISTANCE_WALKING_RUNNING,
      startTime: start,
      endTime: end,
    );

    // 칼로리 샘플 저장
    await _health.writeHealthData(
      value: calories,
      type: HealthDataType.ACTIVE_ENERGY_BURNED,
      startTime: start,
      endTime: end,
    );
  }

  Future<void> _saveStrengthWorkout(DateTime start, DateTime end) async {
    // Strength 운동 저장
    final saved = await _health.writeWorkoutData(
      activityType: HealthWorkoutActivityType.TRADITIONAL_STRENGTH_TRAINING,
      start: start,
      end: end,
    );

    if (!saved) {
      throw Exception('HealthKit 저장 실패');
    }
  }

  double _calculateCalories(double distanceKm, int durationMinutes) {
    // 간단한 칼로리 계산 (체중 70kg 가정)
    const double weightKg = 70;
    final double hours = durationMinutes / 60;

    if (hours == 0) return 0;

    final double speedKmh = distanceKm / hours;

    // MET 값 계산
    double met;
    if (speedKmh < 6.4) {
      met = 6.0;
    } else if (speedKmh < 8.0) {
      met = 8.3;
    } else if (speedKmh < 9.7) {
      met = 9.8;
    } else if (speedKmh < 11.3) {
      met = 11.0;
    } else if (speedKmh < 12.9) {
      met = 11.8;
    } else {
      met = 12.3;
    }

    return met * weightKg * hours;
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }
}
