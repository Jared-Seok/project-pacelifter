import 'package:flutter/material.dart';
import 'package:health/health.dart';
import 'package:pacelifter/services/health_service.dart';
import 'package:pacelifter/services/auth_service.dart';
import 'package:pacelifter/screens/health_import_screen.dart';
import 'package:pacelifter/screens/login_screen.dart';
import 'package:intl/intl.dart';

/// 대시보드 화면
///
/// 앱의 메인 화면으로, 운동 통계와 최근 활동을 표시합니다.
class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final HealthService _healthService = HealthService();
  final AuthService _authService = AuthService();
  List<HealthDataPoint> _workoutData = [];
  bool _isLoading = false;
  String? _username;

  // 통계 데이터
  int _totalWorkouts = 0;
  double _totalDistance = 0.0;
  Duration _totalDuration = Duration.zero;

  @override
  void initState() {
    super.initState();
    _checkFirstLoginAndSync();
    _loadUserData();
  }

  /// 첫 로그인 확인 및 동기화 팝업 표시
  Future<void> _checkFirstLoginAndSync() async {
    final isFirstLogin = await _authService.isFirstLogin();
    final isSyncCompleted = await _authService.isHealthSyncCompleted();

    if (isFirstLogin && !isSyncCompleted && mounted) {
      // 첫 로그인이고 동기화가 완료되지 않은 경우 팝업 표시
      await Future.delayed(const Duration(milliseconds: 500));
      if (mounted) {
        _showHealthSyncDialog();
      }
    } else if (isSyncCompleted) {
      // 이미 동기화가 완료된 경우 데이터 로드
      _loadHealthData();
    }
  }

  /// 사용자 데이터 로드
  Future<void> _loadUserData() async {
    final username = await _authService.getUsername();
    setState(() {
      _username = username;
    });
  }

  /// 헬스 데이터 동기화 다이얼로그 표시
  void _showHealthSyncDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(
              Icons.health_and_safety,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(width: 12),
            const Text('운동 데이터 동기화'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'PaceLifter와 건강 앱을 연동하여\n운동 데이터를 동기화하시겠습니까?',
              style: TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.check_circle_outline,
                        size: 20,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      const SizedBox(width: 8),
                      const Text('운동 기록 자동 분석'),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(
                        Icons.check_circle_outline,
                        size: 20,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      const SizedBox(width: 8),
                      const Text('페이스 및 거리 추적'),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(
                        Icons.check_circle_outline,
                        size: 20,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      const SizedBox(width: 8),
                      const Text('개인화된 훈련 인사이트'),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Text(
              '※ 나중에 설정에서 변경할 수 있습니다.',
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () async {
              Navigator.of(context).pop();
              await _authService.clearFirstLoginFlag();
              await _authService.setHealthSyncCompleted(false);
            },
            child: const Text('나중에'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.of(context).pop();
              await _authService.clearFirstLoginFlag();
              _syncHealthData();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.secondary,
              foregroundColor: Theme.of(context).colorScheme.onSecondary,
            ),
            child: const Text('동기화 시작'),
          ),
        ],
      ),
    );
  }

  /// 헬스 데이터 동기화
  Future<void> _syncHealthData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final granted = await _healthService.requestAuthorization();
      if (granted) {
        final workoutData = await _healthService.fetchWorkoutData();
        await _authService.setHealthSyncCompleted(true);

        setState(() {
          _workoutData = workoutData;
          _calculateStatistics();
          _isLoading = false;
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${workoutData.length}개의 운동 기록을 동기화했습니다!'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        setState(() {
          _isLoading = false;
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('건강 데이터 접근 권한이 필요합니다'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('동기화 실패: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// 헬스 데이터 로드
  Future<void> _loadHealthData() async {
    setState(() {
      _isLoading = true;
    });

    final workoutData = await _healthService.fetchWorkoutData();

    setState(() {
      _workoutData = workoutData;
      _calculateStatistics();
      _isLoading = false;
    });
  }

  /// 통계 계산
  void _calculateStatistics() {
    _totalWorkouts = _workoutData.length;
    _totalDistance = 0.0;
    _totalDuration = Duration.zero;

    for (var data in _workoutData) {
      if (data.value is WorkoutHealthValue) {
        final workout = data.value as WorkoutHealthValue;
        _totalDistance += workout.totalDistance ?? 0.0;
        _totalDuration += workout.totalEnergyBurned != null
            ? Duration(
                seconds: (data.dateFrom.difference(data.dateTo).inSeconds).abs())
            : Duration.zero;
      }
    }
  }

  /// 로그아웃
  Future<void> _handleLogout() async {
    await _authService.logout();
    if (mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => const LoginScreen()),
        (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        title: const Text('PaceLifter'),
        backgroundColor: Theme.of(context).colorScheme.surface,
        foregroundColor: Theme.of(context).colorScheme.onSurface,
        actions: [
          IconButton(
            icon: const Icon(Icons.sync),
            onPressed: _isLoading ? null : _syncHealthData,
            tooltip: '데이터 동기화',
          ),
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'logout') {
                _handleLogout();
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'logout',
                child: Row(
                  children: [
                    Icon(Icons.logout),
                    SizedBox(width: 8),
                    Text('로그아웃'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: _isLoading
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(height: 16),
                  const Text('운동 데이터를 동기화하는 중...'),
                ],
              ),
            )
          : RefreshIndicator(
              onRefresh: _loadHealthData,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 환영 메시지
                    Text(
                      '안녕하세요, ${_username ?? '사용자'}님!',
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '오늘도 훌륭한 러닝을 준비하세요',
                      style: TextStyle(
                        fontSize: 14,
                        color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // 통계 카드
                    _buildStatisticsCard(),
                    const SizedBox(height: 24),

                    // 최근 운동 섹션
                    _buildRecentWorkoutsSection(),
                    const SizedBox(height: 24),

                    // 빠른 액션 버튼
                    _buildQuickActions(),
                  ],
                ),
              ),
            ),
    );
  }

  /// 통계 카드 위젯
  Widget _buildStatisticsCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '전체 통계',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildStatItem(
                    Icons.directions_run,
                    '운동 횟수',
                    '$_totalWorkouts회',
                  ),
                ),
                Expanded(
                  child: _buildStatItem(
                    Icons.straighten,
                    '총 거리',
                    '${(_totalDistance / 1000).toStringAsFixed(1)}km',
                  ),
                ),
                Expanded(
                  child: _buildStatItem(
                    Icons.timer,
                    '총 시간',
                    '${_totalDuration.inHours}시간',
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// 통계 항목 위젯
  Widget _buildStatItem(IconData icon, String label, String value) {
    return Column(
      children: [
        Icon(
          icon,
          color: Theme.of(context).colorScheme.primary,
          size: 32,
        ),
        const SizedBox(height: 8),
        Text(
          value,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
          ),
        ),
      ],
    );
  }

  /// 최근 운동 섹션
  Widget _buildRecentWorkoutsSection() {
    final recentWorkouts = _workoutData.take(5).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              '최근 운동',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            TextButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const HealthImportScreen(),
                  ),
                );
              },
              child: const Text('전체보기'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        recentWorkouts.isEmpty
            ? Card(
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Center(
                    child: Column(
                      children: [
                        Icon(
                          Icons.info_outline,
                          size: 48,
                          color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          '운동 기록이 없습니다',
                          style: TextStyle(
                            fontSize: 16,
                            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          '헬스 앱과 동기화하여 운동 기록을 가져오세요',
                          style: TextStyle(fontSize: 12),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ),
              )
            : Column(
                children: recentWorkouts.map((data) {
                  final workout = data.value as WorkoutHealthValue;
                  final distance = workout.totalDistance ?? 0.0;
                  final type = workout.workoutActivityType.name;

                  return Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      leading: Icon(
                        _getWorkoutIcon(type),
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      title: Text(type),
                      subtitle: Text(
                        DateFormat('yyyy-MM-dd HH:mm').format(data.dateFrom),
                      ),
                      trailing: Text(
                        '${(distance / 1000).toStringAsFixed(2)} km',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  );
                }).toList(),
              ),
      ],
    );
  }

  /// 빠른 액션 버튼
  Widget _buildQuickActions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '빠른 액션',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('GPS 러닝 기능은 개발 중입니다')),
                  );
                },
                icon: const Icon(Icons.play_arrow),
                label: const Text('러닝 시작'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.secondary,
                  foregroundColor: Theme.of(context).colorScheme.onSecondary,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const HealthImportScreen(),
                    ),
                  );
                },
                icon: const Icon(Icons.analytics),
                label: const Text('분석'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  /// 운동 유형에 따른 아이콘 반환
  IconData _getWorkoutIcon(String type) {
    switch (type.toUpperCase()) {
      case 'RUNNING':
        return Icons.directions_run;
      case 'WALKING':
        return Icons.directions_walk;
      case 'CYCLING':
        return Icons.directions_bike;
      case 'SWIMMING':
        return Icons.pool;
      case 'HIKING':
        return Icons.terrain;
      default:
        return Icons.fitness_center;
    }
  }
}
