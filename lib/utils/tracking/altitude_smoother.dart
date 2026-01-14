import 'dart:math';

/// 고도 데이터 스무딩 및 누적 상승 고도 계산기
class AltitudeSmoother {
  final double _threshold; // 누적을 위한 최소 변화 임계값 (m)
  final double _alpha;    // EMA 스무딩 팩터
  
  double? _lastSmoothedAltitude;
  double _totalGain = 0.0;
  double _pendingGain = 0.0; // 임계값을 넘기 전까지 대기 중인 상승분

  /// [threshold]: 보통 GPS 전용은 3.0m, 기압계 병행 시 1.0m 추천
  /// [smoothingWindow]: 스무딩할 데이터 포인트 개수 (기본 5개)
  AltitudeSmoother({double threshold = 3.0, int smoothingWindow = 5})
      : _threshold = threshold,
        _alpha = 2 / (smoothingWindow + 1);

  /// 새로운 고도 데이터 처리 및 누적 상승 고도 반환
  double process(double rawAltitude) {
    if (_lastSmoothedAltitude == null) {
      _lastSmoothedAltitude = rawAltitude;
      return 0.0;
    }

    // 1. EMA 스무딩
    double smoothed = (rawAltitude * _alpha) + (_lastSmoothedAltitude! * (1 - _alpha));
    
    // 2. 변화량 계산
    double diff = smoothed - _lastSmoothedAltitude!;
    
    if (diff > 0) {
      // 상승 중
      _pendingGain += diff;
      
      // 누적된 상승분이 임계값을 넘었을 때만 실제 Gain에 반영 (Hysteresis)
      if (_pendingGain >= _threshold) {
        _totalGain += _pendingGain;
        _pendingGain = 0.0;
      }
    } else {
      // 하강 중이거나 정지 시 대기 중인 상승분 초기화 (노이즈 방지)
      // 단, 아주 미세한 하강은 노이즈일 수 있으므로 pendingGain을 즉시 버리지 않고 감쇄할 수도 있으나
      // 여기서는 보수적으로 초기화하여 뻥튀기를 원천 차단함
      if (diff.abs() > 0.5) {
        _pendingGain = 0.0;
      }
    }

    _lastSmoothedAltitude = smoothed;
    return _totalGain;
  }

  double get totalGain => _totalGain;
  double? get currentAltitude => _lastSmoothedAltitude;

  void reset() {
    _lastSmoothedAltitude = null;
    _totalGain = 0.0;
    _pendingGain = 0.0;
  }
}
