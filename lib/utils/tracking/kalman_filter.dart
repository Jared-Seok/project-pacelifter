import 'dart:math';

/// GPS 좌표 스무딩을 위한 칼만 필터
///
/// 단순 1차원 칼만 필터를 위도(Lat)와 경도(Lng)에 각각 적용하여
/// GPS 튐 현상(Drift)을 제거하고 경로를 부드럽게 만듭니다.
class KalmanFilter {
  // 필터 파라미터 (튜닝 필요 가능성 있음)
  
  /// Process Noise Covariance (Q)
  /// 시스템의 불확실성 (사람이 움직이는 불규칙성)
  /// 값이 클수록: 측정값(GPS)을 더 신뢰 (반응성 증가, 노이즈 증가)
  /// 값이 작을수록: 예측값(이전 위치)을 더 신뢰 (부드러움 증가, 딜레이 증가)
  /// 러닝의 경우 3~5 m/s 정도의 불확실성을 가짐
  final double _Q_metres_per_second;

  // 추정 상태 (Lat, Lng)
  double? _lat;
  double? _lng;
  
  // 오차 공분산 (P) - 초기값은 불확실하므로 높게 설정할 수도 있으나, 첫 측정 시 초기화됨
  double _variance = 0; 

  // 마지막 업데이트 시간
  int? _timeStampMilliseconds;

  KalmanFilter({double processNoise = 3.0}) : _Q_metres_per_second = processNoise;

  /// 초기화 여부 확인
  bool get isInitialized => _lat != null && _lng != null;

  /// 필터 초기화
  void reset() {
    _lat = null;
    _lng = null;
    _variance = 0;
    _timeStampMilliseconds = null;
  }

  /// GPS 측정값 처리
  /// 
  /// [lat], [lng]: 측정된 위도, 경도
  /// [accuracy]: GPS 정확도 (미터 단위, R값으로 사용됨)
  /// [timestamp]: 측정 시간 (ms)
  /// 
  /// 반환값: [smoothedLat, smoothedLng]
  List<double> process(double lat, double lng, double accuracy, int timestamp) {
    if (_accuracyToVariance(accuracy) < 0.0001) return [lat, lng]; // 정확도가 너무 좋거나 이상하면 원본 반환

    if (!isInitialized) {
      _lat = lat;
      _lng = lng;
      _variance = _accuracyToVariance(accuracy);
      _timeStampMilliseconds = timestamp;
      return [lat, lng];
    }

    // 1. 시간 경과 계산 (초 단위)
    double duration = (timestamp - _timeStampMilliseconds!) / 1000.0;
    if (duration < 0) duration = 0; // 역전 방지
    _timeStampMilliseconds = timestamp;

    // 2. Process Noise (Q) 업데이트: 시간이 지날수록 위치 불확실성 증가
    // variance += duration * Q^2
    _variance += duration * _Q_metres_per_second * _Q_metres_per_second;

    // 3. Kalman Gain (K) 계산
    // K = P / (P + R)
    // R: 측정 노이즈 (GPS Accuracy의 제곱)
    double r = _accuracyToVariance(accuracy);
    double k = _variance / (_variance + r);

    // 4. 상태 업데이트 (Update State)
    // x = x + K * (z - x)
    _lat = _lat! + k * (lat - _lat!);
    _lng = _lng! + k * (lng - _lng!);

    // 5. 오차 공분산 업데이트 (Update Covariance)
    // P = (1 - K) * P
    _variance = (1 - k) * _variance;

    return [_lat!, _lng!];
  }

  /// 정확도(Accuracy, meters)를 분산(Variance)으로 변환
  double _accuracyToVariance(double accuracy) {
    return accuracy * accuracy;
  }
  
  /// 현재 추정 위치 반환
  List<double>? getCurrentPosition() {
    if (!isInitialized) return null;
    return [_lat!, _lng!];
  }
}
