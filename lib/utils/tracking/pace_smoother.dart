/// 지수 이동 평균(EMA) 기반 페이스 스무더
///
/// 단순 이동 평균(SMA)보다 최근 데이터에 더 높은 가중치를 두어,
/// 인터벌 러닝 등 속도 변화가 잦은 상황에서 반응성을 높이면서도 노이즈를 억제합니다.
class PaceSmoother {
  // 스무딩 팩터 (Alpha)
  // 0 < alpha <= 1
  // alpha가 클수록: 최근 데이터 반영 비중 큼 (반응성 빠름, 노이즈 큼) -> 인터벌용 (약 0.3~0.5)
  // alpha가 작을수록: 과거 데이터 반영 비중 큼 (부드러움, 딜레이 큼) -> LSD용 (약 0.1~0.2)
  double _alpha;
  
  double? _currentSmoothedSpeedMs; // 현재 스무딩된 속도 (m/s)

  /// 생성자
  /// [windowSizeSeconds]: 대략적인 윈도우 크기 (초 단위)
  /// alpha = 2 / (N + 1) 공식을 사용하여 변환
  PaceSmoother({int windowSizeSeconds = 10}) 
      : _alpha = 2 / (windowSizeSeconds + 1);

  /// 스무딩 윈도우 크기 변경 (실시간 모드 변경용)
  void setWindowSize(int windowSizeSeconds) {
    _alpha = 2 / (windowSizeSeconds + 1);
  }

  /// 속도 데이터 추가 및 스무딩된 값 반환
  /// [rawSpeedMs]: 현재 측정된 순간 속도 (m/s)
  double add(double rawSpeedMs) {
    // 유효성 검사 (너무 터무니없는 값 제외, 예: 우사인 볼트 12.4m/s)
    if (rawSpeedMs < 0) rawSpeedMs = 0;
    if (rawSpeedMs > 15) rawSpeedMs = 15; // 상한선 설정

    if (_currentSmoothedSpeedMs == null) {
      _currentSmoothedSpeedMs = rawSpeedMs;
    } else {
      // EMA 공식: EMA_today = (Value_today * alpha) + (EMA_yesterday * (1-alpha))
      _currentSmoothedSpeedMs = 
          (rawSpeedMs * _alpha) + (_currentSmoothedSpeedMs! * (1 - _alpha));
    }

    return _currentSmoothedSpeedMs!;
  }

  /// 현재 스무딩된 속도 반환 (m/s)
  double get currentSpeedMs => _currentSmoothedSpeedMs ?? 0.0;

  /// 초기화
  void reset() {
    _currentSmoothedSpeedMs = null;
  }
}
