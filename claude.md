# PaceLifter 프로젝트 가이드

> 하이브리드 애슬릿(Hybrid Athlete)을 위한 차세대 피트니스 앱
> "Endurance + Strength = 통합 인사이트"

---

## 📋 목차

1. [디자인 시스템 (Frontend)](#1-디자인-시스템-frontend)
2. [로직 아키텍처 (Backend/Logic)](#2-로직-아키텍처-backendlogic)
3. [구현 예정 MVP](#3-구현-예정-mvp)

---

## 1. 디자인 시스템 (Frontend)

### 1.1 색상 팔레트 (Color Scheme)

**위치**: [lib/main.dart](lib/main.dart#L25-L37)

```dart
ColorScheme(
  brightness: Brightness.dark,

  // Primary - Khaki (카키색)
  primary: Color(0xFF8F9779),
  onPrimary: Color(0xFFEEEEEE),

  // Secondary - Accent (네온 옐로우 그린)
  secondary: Color(0xFFD4E157),
  onSecondary: Color(0xFF121212),

  // Tertiary
  tertiary: Color(0xFFD4E157),
  onTertiary: Color(0xFF121212),

  // Surface - Dark Background
  surface: Color(0xFF121212),
  onSurface: Color(0xFFEEEEEE),

  // Error
  error: Colors.red,
  onError: Colors.white,
)
```

#### 색상 사용 규칙

- **Primary (Khaki #8F9779)**:
  - 근력(Strength) 운동 관련 요소
  - 주요 버튼 배경색
  - 로고 및 브랜딩 요소

- **Secondary (Neon Yellow-Green #D4E157)**:
  - 지구력(Endurance) 운동 관련 요소
  - 강조 텍스트 및 액센트
  - 활성 상태 표시

- **Surface (#121212)**:
  - 앱 배경색
  - 카드 배경색

- **onSurface (#EEEEEE)**:
  - 일반 텍스트 색상

### 1.2 아이콘 시스템

**위치**: `assets/images/`

#### 사용 가능한 SVG 아이콘

```
assets/images/
├── pllogo.svg              # PaceLifter 로고
├── runner-icon.svg         # 러닝/지구력 운동
├── lifter-icon.svg         # 웨이트/근력 운동
├── pullup-icon.svg         # 맨몸 운동/풀업
├── core-icon.svg           # 코어 운동
└── trail-icon.svg          # 트레일 러닝
```

#### 아이콘 사용 규칙

1. **우선순위**: Material Icons < SVG Icons
   - 커스텀 SVG 아이콘이 있으면 **반드시** SVG 사용
   - Material Icons는 SVG가 없는 경우에만 사용

2. **SVG 로드 방법**:
   ```dart
   import 'package:flutter_svg/flutter_svg.dart';

   SvgPicture.asset(
     'assets/images/runner-icon.svg',
     width: 24,
     height: 24,
     colorFilter: ColorFilter.mode(
       Theme.of(context).colorScheme.secondary,
       BlendMode.srcIn,
     ),
   )
   ```

3. **아이콘 색상**:
   - Endurance 운동: `secondary` (네온 옐로우)
   - Strength 운동: `primary` (카키)
   - 일반 UI 요소: `onSurface` 또는 투명도 조절

#### 운동 타입별 아이콘 매핑

**구현 위치**: [lib/screens/workout_detail_screen.dart:971-982](lib/screens/workout_detail_screen.dart#L971-L982)

```dart
// Strength 운동
CORE_TRAINING, FUNCTIONAL_STRENGTH_TRAINING
  → core-icon.svg (primary color)

TRADITIONAL_STRENGTH_TRAINING, WEIGHT_TRAINING
  → lifter-icon.svg (primary color)

// Endurance 운동
RUNNING (모든 러닝 타입)
  → runner-icon.svg (secondary color)

// 기타
Trail Running
  → trail-icon.svg (secondary color)
```

### 1.3 타이포그래피

**폰트**: Google Fonts (구성: [pubspec.yaml](pubspec.yaml#L39))

```yaml
dependencies:
  google_fonts: ^6.1.0
```

#### 텍스트 스타일 가이드

```dart
// 헤더
TextStyle(
  fontSize: 24,
  fontWeight: FontWeight.bold,
  color: Theme.of(context).colorScheme.secondary,
)

// 서브헤더
TextStyle(
  fontSize: 18,
  fontWeight: FontWeight.bold,
)

// Body Text
TextStyle(
  fontSize: 16,
  fontWeight: FontWeight.w500,
)

// Caption
TextStyle(
  fontSize: 12,
  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
)
```

### 1.4 UI 컴포넌트

#### 카드 (Card)

```dart
Card(
  child: Padding(
    padding: const EdgeInsets.all(16.0),
    child: // 내용
  ),
)
```

#### 버튼 스타일

```dart
// Primary Button
FilledButton(
  style: FilledButton.styleFrom(
    backgroundColor: Theme.of(context).colorScheme.secondary,
    foregroundColor: Colors.black,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(12),
    ),
  ),
)

// Outlined Button
OutlinedButton(
  style: OutlinedButton.styleFrom(
    side: BorderSide(
      color: Theme.of(context).colorScheme.secondary,
    ),
  ),
)
```

#### 다이얼로그

```dart
AlertDialog(
  shape: RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(16),
  ),
  backgroundColor: Theme.of(context).colorScheme.surface,
  // Material Design 3 스타일 우선
)
```

---

## 2. 로직 아키텍처 (Backend/Logic)

### 2.1 데이터 소스

#### Apple HealthKit 통합

**서비스**: [lib/services/health_service.dart](lib/services/health_service.dart)

```dart
class HealthService {
  final Health health = Health();

  // 읽기 권한 (P0 - MVP 필수)
  static final readTypes = [
    HealthDataType.WEIGHT,
    HealthDataType.HEIGHT,
    HealthDataType.DISTANCE_WALKING_RUNNING,
    HealthDataType.STEPS,
    HealthDataType.ACTIVE_ENERGY_BURNED,
    HealthDataType.HEART_RATE,
    HealthDataType.WORKOUT,
    HealthDataType.RESTING_HEART_RATE,
  ];

  // 쓰기 권한 (P0 - MVP 필수)
  static final writeTypes = [
    HealthDataType.DISTANCE_WALKING_RUNNING,
    HealthDataType.STEPS,
    HealthDataType.ACTIVE_ENERGY_BURNED,
    HealthDataType.HEART_RATE,
    HealthDataType.WORKOUT,
  ];
}
```

### 2.2 운동 데이터 처리

#### 페이스 계산 로직

**위치**: [lib/screens/workout_detail_screen.dart:87-267](lib/screens/workout_detail_screen.dart#L87-L267)

##### 평균 페이스 계산 (NRC 호환)

```dart
// 1. 운동 시간 계산
final workoutDuration = dateTo.difference(dateFrom);

// 2. 평균 페이스 계산 (분/km)
avgPaceMinPerKm = (workoutDuration.inSeconds / 60) / (totalDistance / 1000);
```

**공식**: `평균 페이스(분/km) = 운동 시간(분) ÷ 거리(km)`

**예시**:
- 운동 시간: 30분 (1800초)
- 거리: 5000m (5km)
- 계산: `(1800 / 60) / (5000 / 1000) = 30 / 5 = 6분/km`

##### 페이스 차트 생성

**위치**: [lib/screens/workout_detail_screen.dart:193-267](lib/screens/workout_detail_screen.dart#L193-L267)

**프로세스**:

1. **거리 샘플 로드**:
   ```dart
   final distanceData = await getHealthDataFromTypes(
     dateFrom, dateTo,
     [HealthDataType.DISTANCE_WALKING_RUNNING],
   );
   ```

2. **시간순 정렬** (NRC 데이터는 역순으로 제공됨):
   ```dart
   distanceData.sort((a, b) => a.dateFrom.compareTo(b.dateFrom));
   ```

3. **누적 거리 변환** (구간 거리 → 누적 거리):
   ```dart
   double cumulativeDistance = 0;
   for (var point in distanceData) {
     cumulativeDistance += point.value;
     cumulativeDistances.add(cumulativeDistance);
   }
   ```

4. **페이스 포인트 생성**:
   ```dart
   for (int i = 1; i < distanceData.length; i++) {
     final distanceDiff = cumulativeDistances[i] - cumulativeDistances[i-1];
     final timeDiff = dateFrom[i] - dateFrom[i-1];

     if (timeDiff > 0 && distanceDiff > 0) {
       final speedMs = distanceDiff / timeDiff; // m/s
       pacePoints.add(speedMs);
     }
   }
   ```

5. **페이스 변환** (속도 → 페이스):
   ```dart
   final paceMinPerKm = 1000 / (speedMs * 60);
   ```

##### 차트 스무딩

**위치**: [lib/screens/workout_detail_screen.dart:675-689](lib/screens/workout_detail_screen.dart#L675-L689)

**이동 평균 (Moving Average)** - Window Size: 3

```dart
for (int i = 1; i < rawPaces.length - 1; i++) {
  final average = (rawPaces[i-1] + rawPaces[i] + rawPaces[i+1]) / 3;
  smoothedPaces.add(average);
}
```

### 2.3 주요 함수 정리

#### HealthService

| 함수 | 설명 | 반환 타입 |
|------|------|----------|
| `requestAuthorization()` | HealthKit 권한 요청 | `Future<bool>` |
| `getHealthDataFromTypes()` | 건강 데이터 조회 | `Future<List<HealthDataPoint>>` |
| `fetchWorkoutData()` | 운동 데이터 조회 (10년) | `Future<List<HealthDataPoint>>` |

#### WorkoutDetailScreen

| 함수 | 설명 | 위치 |
|------|------|------|
| `_fetchPaceData()` | 페이스 데이터 로드 및 계산 | [L87-190](lib/screens/workout_detail_screen.dart#L87-L190) |
| `_calculatePaceFromDistance()` | 거리 샘플 → 페이스 변환 | [L193-267](lib/screens/workout_detail_screen.dart#L193-L267) |
| `_buildPaceChart()` | 페이스 차트 렌더링 | [L658-848](lib/screens/workout_detail_screen.dart#L658-L848) |
| `_formatPace()` | 페이스 포맷팅 (분'초"/km) | [L850-854](lib/screens/workout_detail_screen.dart#L850-L854) |

### 2.4 데이터 흐름

```
HealthKit (Apple Health)
  ↓
HealthService.getHealthDataFromTypes()
  ↓
_fetchPaceData()
  ├─ Workout 기본 데이터 (distance, duration)
  └─ DISTANCE_WALKING_RUNNING 샘플
      ↓
_calculatePaceFromDistance()
  ├─ 시간순 정렬
  ├─ 누적 거리 변환
  └─ 페이스 포인트 생성
      ↓
_buildPaceChart()
  ├─ 이동 평균 스무딩
  └─ LineChart 렌더링
```

### 2.5 데이터 저장

**로컬 스토리지**:
- `sqflite`: 관계형 데이터베이스
- `hive`: NoSQL 캐시
- `shared_preferences`: 설정 및 간단한 데이터

**구성**: [pubspec.yaml:64-67](pubspec.yaml#L64-L67)

---

## 3. 구현 예정 MVP

> 출처: `PaceLifter - 구현 예정 MVP.pdf`

### 서비스 청사진 (Service Blueprint)

#### Phase 1: 서비스 인지 (Service Awareness)
- 앱 스토어 페이지
- 명 아이콘
- 소셜 미디어
- 커뮤니티 구축
- 바이럴스 커뮤니티 입소문

#### Phase 2: 운동 전 (Pre-Workout)
- 대시보드 확인
- 레이스 카드
- 운동 사례 베이스
- 프로필 설정
- 5단계 입력폼
- 템플릿 카드
- Free Run, Interval 등

#### Phase 3: 운동 중 (During Workout)
- 실시간 추적 화면
- GPS 지도
- 페이스/거리/칼로리
- 일시정지/종료 버튼
- 진행바/타이머
- 실시간 알림
- 목표 달성 알림
- 운동 재개
- 운동 종료

#### Phase 4: 운동 후 (Post-Workout)
- 운동 요약 카드
- 완료 배지
- 워크아웃 카드
- 달력 배지
- 운동 타입 아이콘
- 개인 기록(PR) 표시
- 공유 이미지 ⭐ (추후 구현)

### 3.1 하이브리드 데이터 아키텍처

**목표**: Strength/Endurance 데이터 통합

#### 데이터 스키마 설계 (1:N:M)

```
Athlete (사용자)
  ├─ 1:N → Workouts (운동 세션)
  │         ├─ type: "Strength" | "Endurance" | "Hybrid"
  │         ├─ date, duration, calories
  │         └─ M:N → Exercises (운동 항목)
  │                   ├─ name, sets, reps, weight
  │                   └─ distance, pace, heart_rate
  └─ Profile
      ├─ bodyMetrics (weight, height, body_fat)
      └─ goals (target_race, target_1RM, etc)
```

**특징**:
- 근력(Strength)과 지구력(Endurance) 간의 상관관계 분석
- 복합 템플릿과 개별 운동 세션 간의 유연한 연동

### 3.2 듀얼 엔진 퍼포먼스 트래킹

**목표**: 통합 컨디셔닝 & 퍼포먼스 데이터 제공

#### 종합 지표 시각화

```
하이브리드 애슬릿 대시보드
├─ Strength Score
│   ├─ 1RM 추정치
│   ├─ Volume (총 중량)
│   └─ Progression (진행도)
├─ Endurance Score
│   ├─ VO2 Max 추정
│   ├─ 평균 페이스
│   └─ 거리/시간 추이
└─ Hybrid Index
    ├─ 밸런스 점수
    └─ 통합 피트니스 레벨
```

**기능**:
- 개별적으로 존재하던 근력/유산소 데이터를 통합
- 하이브리드 애슬릿을 위한 종합 컨디셔닝 지표

### 3.3 러닝 트래킹 고도화

**현재 상태**: 기본 페이스 차트 구현 완료

**추가 구현 필요**:

1. **GPS 정확도 개선**
   - 위치 필터링 알고리즘
   - Kalman Filter 적용
   - 고도 보정

2. **페이스(Pace) 분석**
   - ✅ 평균 페이스 (완료)
   - ✅ 페이스 차트 (완료)
   - 구간별 페이스 (Split)
   - 최대/최소 페이스
   - 페이스 변화율

3. **구간 기록 (Splits)**
   - 1km/1mile 자동 랩
   - 수동 랩 버튼
   - 구간별 비교 차트

4. **기타**
   - 경로 맵 (Route Map)
   - 고도 프로필 (Elevation Profile)
   - 케이던스 (Cadence) 추적

### 3.4 Strength 템플릿 세분화

**목표**: 정교한 리프팅 템플릿 및 루틴 커스터마이징

#### 트레이닝 목표별 템플릿

```
Strength Templates
├─ Hypertrophy (근비대)
│   ├─ Volume: 높음 (8-12 reps)
│   ├─ Rest: 60-90초
│   └─ Exercises: Compound + Isolation
├─ Strength (근력)
│   ├─ Intensity: 높음 (3-6 reps)
│   ├─ Rest: 3-5분
│   └─ Exercises: Big 3 중심
└─ Power (폭발력)
    ├─ Speed: 최대
    ├─ Rest: 2-3분
    └─ Exercises: Olympic Lifts, Plyometrics
```

#### 커스터마이징 옵션

- 운동 선택 (Exercise Library)
- 세트/렙/중량 설정
- 휴식 시간 조절
- 주간 프로그래밍 (Periodization)

### 3.5 운동 기록 공유 기능 (Social Share)

**목표**: SNS 공유를 통한 오가닉 마케팅

#### Workout Summary 이미지 Export

```
[PaceLifter Logo]
─────────────────
🏃 Running
5.2 km · 30:15
Avg Pace: 5'49"/km
Calories: 285 kcal
─────────────────
📅 2025-12-16
💪 Keep it up!
```

**기능**:
- 인스타그램 스토리 최적화 (1080x1920)
- 브랜드 워터마크 포함
- 커스텀 배경 테마
- 주요 지표 하이라이트

#### 운동 Recap 기능

- 월간 운동 통계
- 연간 운동 결산
- 베스트 기록 하이라이트
- SNS 공유 버튼

### 3.6 Athlete 계정 및 데이터 서버화

**목표**: 서버 기반 유저 DB 구축

#### 현재 상태
- 로컬 스토리지 (Hive, SQLite)
- 온디바이스 데이터 관리

#### 추가 구현
```
Server Architecture
├─ User Authentication
│   ├─ Firebase Auth / Supabase
│   └─ Social Login (Apple, Google)
├─ Cloud Database
│   ├─ User Profile (서버)
│   ├─ Workout History (서버)
│   └─ Body Metrics (온디바이스 → 익명화)
└─ Sync Service
    ├─ 기기 간 동기화
    ├─ 백업 & 복원
    └─ 데이터 마이그레이션
```

**개인정보 처리**:
- 신체 정보: 온디바이스 관리 유지
- 서버 저장 시: 상대화 및 포인트화
- 익명화된 데이터로 분석

### 3.7 iOS / WatchOS 우선 개발

**근거**:
- 개발 난이도 낮음
- HealthKit 중앙 관리
- Apple Watch 하드웨어 인터렉션

#### WatchOS 기능

```
Apple Watch App
├─ 운동 추적
│   ├─ 실시간 심박수
│   ├─ GPS 경로
│   └─ 페이스 알림
├─ 잠금화면 위젯
│   ├─ 오늘의 운동 요약
│   └─ 다음 운동 알림
└─ Complications
    ├─ 주간 통계
    └─ 운동 스트릭
```

---

## 4. 개발 가이드라인

### 4.1 코드 스타일

1. **Deprecated API 사용 금지**
   - ❌ `withOpacity(0.5)`
   - ✅ `withValues(alpha: 0.5)`

2. **비동기 처리**
   ```dart
   if (mounted) {
     setState(() {
       // 상태 업데이트
     });
   }
   ```

3. **에러 처리**
   ```dart
   try {
     // 작업
   } catch (e) {
     if (mounted) {
       setState(() {
         _error = '에러 메시지';
       });
     }
   }
   ```

### 4.2 새 기능 구현 시 체크리스트

- [ ] 기존 color scheme 사용
- [ ] SVG 아이콘 우선 사용
- [ ] Material Design 3 준수
- [ ] 에러 처리 구현
- [ ] mounted 체크
- [ ] 로딩 상태 표시
- [ ] 다크 모드 호환

### 4.3 파일 구조

```
lib/
├── main.dart                    # 앱 진입점, 테마 정의
├── screens/                     # UI 화면
│   ├── dashboard_screen.dart
│   ├── workout_detail_screen.dart
│   ├── profile_screen.dart
│   └── ...
├── services/                    # 비즈니스 로직
│   ├── health_service.dart
│   └── workout_tracking_service.dart
└── models/                      # 데이터 모델 (추후)

assets/
└── images/
    ├── *.svg                    # 아이콘
    └── app-icon/               # 앱 아이콘
```

---

## 5. 참고 자료

### 의존성 (pubspec.yaml)

- **UI**: `flutter_svg: ^2.0.0`, `fl_chart: ^1.1.1`
- **Health**: `health: ^13.2.1`, `pedometer: ^4.0.0`
- **Location**: `geolocator: ^14.0.2`, `google_maps_flutter: ^2.9.0`
- **Storage**: `sqflite: ^2.3.0`, `hive: ^2.2.3`, `shared_preferences: ^2.2.0`
- **State**: `provider: ^6.1.0`

### 주요 패키지 버전

```yaml
environment:
  sdk: ^3.10.1

dependencies:
  flutter:
    sdk: flutter
  cupertino_icons: ^1.0.8
  google_fonts: ^6.1.0
  health: ^13.2.1
  # ... (전체 목록은 pubspec.yaml 참조)
```

---

## 6. 문서 업데이트 이력

| 날짜 | 버전 | 변경사항 |
|------|------|----------|
| 2025-12-16 | 1.0.0 | 초기 문서 작성 |

---

**마지막 업데이트**: 2025-12-16
**작성자**: Claude (AI Assistant)
**프로젝트**: PaceLifter v1.0.0
