# PaceLifter 개발 환경 설정 완료

러닝 및 하이록스 대회를 위한 피트니스 앱 개발 환경이 설정되었습니다.

## 완료된 설정

### 1. 기본 환경
- ✅ Flutter SDK 설치 (v3.38.3)
- ✅ Android Studio + SDK 설치 및 라이선스 동의
- ✅ Xcode + CLI 설정
- ✅ VS Code 확장 프로그램 설치
- ✅ NDK + CMake 설치

### 2. 프로젝트 생성
- ✅ Flutter 프로젝트 `pacelifter` 생성

### 3. 필수 패키지 설치 (pubspec.yaml)

**건강/피트니스 데이터**
- health: ^10.0.0 (Apple Health, Google Fit 연동)
- pedometer: ^4.0.0 (걸음 수 추적)
- sensors_plus: ^6.0.0 (가속도계, 자이로스코프)

**위치 추적**
- geolocator: ^13.0.0 (GPS)
- google_maps_flutter: ^2.9.0 (지도)
- background_location: ^0.13.0 (백그라운드 위치)

**백그라운드 실행**
- workmanager: ^0.5.2

**권한 관리**
- permission_handler: ^11.0.0

**상태 관리**
- provider: ^6.1.0

**로컬 데이터 저장**
- sqflite: ^2.3.0 (운동 기록 DB)
- shared_preferences: ^2.2.0 (앱 설정)
- hive: ^2.2.3 (캐시)

**차트/그래프**
- fl_chart: ^0.69.0

**유틸리티**
- intl: ^0.19.0 (날짜/시간 포맷)
- uuid: ^4.5.0 (고유 ID)
- http: ^1.1.0 (API 통신)

### 4. Android 권한 설정 (AndroidManifest.xml)
- ✅ 위치 추적 권한 (FINE, COARSE, BACKGROUND)
- ✅ 건강 데이터 권한 (ACTIVITY_RECOGNITION, BODY_SENSORS)
- ✅ 백그라운드 실행 권한 (FOREGROUND_SERVICE, WAKE_LOCK)
- ✅ 인터넷 권한
- ✅ Google Fit 권한

### 5. iOS 권한 설정 (Info.plist)
- ✅ 위치 사용 권한 (NSLocationWhenInUse, NSLocationAlways)
- ✅ 건강 데이터 권한 (NSHealthShare, NSHealthUpdate)
- ✅ 모션 센서 권한 (NSMotion)
- ✅ 백그라운드 모드 (location, fetch, processing)

### 6. Android WearOS 지원 (build.gradle.kts)
- ✅ play-services-wearable
- ✅ play-services-location
- ✅ play-services-fitness

### 7. 프로젝트 구조
```
lib/
├── main.dart
├── models/          # 데이터 모델
├── services/        # 비즈니스 로직
├── screens/         # UI 화면
├── widgets/         # 재사용 위젯
├── providers/       # 상태 관리
├── utils/          # 유틸리티
└── constants/      # 상수
```

## 다음 단계

### 즉시 시작 가능
1. 기본 UI 구현
   - 홈 화면
   - 운동 기록 화면
   - 대회 정보/페이스 계산 화면

2. 핵심 기능 구현
   - GPS 위치 추적 서비스
   - 운동 데이터 저장 (SQLite)
   - 페이스 계산 로직

### 테스트 필요
3. 실제 디바이스에서 권한 테스트
   ```bash
   flutter run
   ```

4. GPS 기능 테스트 (실외 필요)
   - 백그라운드 위치 추적
   - 경로 기록

5. 건강 데이터 연동 테스트
   - Apple Health 연동 (iOS)
   - Google Fit 연동 (Android)

### 추가 설정 (선택사항)
- Firebase 설정 (사용자 인증, 클라우드 백업)
- Apple Watch 앱 개발 (별도 타겟 추가)
- WearOS 앱 개발 (별도 모듈 추가)
- Google Maps API 키 설정

## 주의사항

### iOS 개발
- Apple Developer 계정 필요 (실제 기기 테스트 및 배포)
- Health 데이터는 시뮬레이터에서 제한적
- 백그라운드 위치 추적은 실제 기기에서만 테스트 가능

### Android 개발
- Google Play Services 필요
- Google Maps API 키 필요 (지도 사용 시)
- 백그라운드 위치 추적 시 배터리 최적화 해제 필요

### 개발 팁
- 실제 러닝 테스트는 실외에서 진행
- 배터리 소모 최적화 고려
- 백그라운드 실행 시 사용자 알림 표시 (법적 요구사항)

## 문제 해결

### 패키지 설치 오류
```bash
flutter pub get
flutter clean
flutter pub get
```

### iOS 빌드 오류
```bash
cd ios
pod install
cd ..
flutter clean
flutter build ios
```

### Android 빌드 오류
```bash
cd android
./gradlew clean
cd ..
flutter clean
flutter build apk
```

## 연락처
- Flutter 공식 문서: https://docs.flutter.dev/
- 프로젝트 위치: /Users/admin/Desktop/ aiCoding/pacelifter/pacelifter

---

개발 환경 설정이 완료되었습니다. 이제 본격적인 앱 개발을 시작할 수 있습니다!
