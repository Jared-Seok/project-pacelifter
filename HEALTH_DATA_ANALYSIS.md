# Apple Health 데이터 분석 기능

PaceLifter 앱에 Apple Health 데이터를 import하고 분석하는 기능이 추가되었습니다.

## 기능 개요

### 1. 데이터 모델
- **HealthWorkout**: 운동 세션 데이터 (거리, 시간, 페이스, 속도)
- **HealthRecord**: 건강 기록 데이터 (심박수, 걸음 수 등)

### 2. XML 파서
- Apple Health export.xml 파일 파싱
- 운동 데이터 추출 및 분석
- 통계 생성 (총 거리, 운동 시간, 평균 페이스 등)

### 3. UI 화면
- **홈 화면**: PaceLifter 메인 화면
- **Health Import 화면**: 데이터 불러오기 및 분석
- **Workout List 화면**: 전체 운동 기록 보기

## 사용 방법

### 1. iPhone에서 건강 데이터 내보내기

1. iPhone에서 **건강(Health)** 앱 열기
2. 오른쪽 상단 **프로필 아이콘** 탭
3. 맨 아래로 스크롤 → **"건강 데이터 내보내기"** 선택
4. **"내보내기"** 확인
5. 처리 완료 후 공유 방법 선택:
   - **AirDrop**으로 Mac에 전송 (권장)
   - **iCloud Drive**에 저장
   - **이메일**로 전송 (파일이 큰 경우 시간 소요)

6. `export.zip` 파일 받기
7. 압축 해제하여 `export.xml` 파일 추출

### 2. 앱에서 데이터 불러오기

1. PaceLifter 앱 실행
2. **"Apple Health 데이터 불러오기"** 버튼 클릭
3. **"export.xml 파일 선택"** 버튼 클릭
4. export.xml 파일 선택
5. 자동으로 파싱 시작 (큰 파일의 경우 시간 소요)
6. 분석 결과 확인

### 3. 분석 결과 보기

**운동 통계**
- 총 운동 횟수
- 총 거리 (km)
- 총 운동 시간
- 운동 유형별 통계 (러닝, 걷기, 사이클 등)

**최근 운동 기록**
- 최근 10개 운동 미리보기
- 날짜, 시간, 거리, 페이스 표시
- "전체보기" 버튼으로 모든 기록 확인

## 앱 실행 방법

### iOS 시뮬레이터
```bash
flutter run
```

### 실제 iPhone
```bash
# 연결된 디바이스 확인
flutter devices

# 특정 디바이스로 실행
flutter run -d "석지원의 iPhone"
```

### 빌드
```bash
# iOS 디버그 빌드
flutter build ios --debug

# Android 디버그 빌드
flutter build apk --debug
```

## 구현된 기능

### 데이터 분석
- ✅ 운동 유형별 분류 (러닝, 걷기, 사이클 등)
- ✅ 거리/시간/페이스 계산
- ✅ 운동 통계 생성
- ✅ 최근 운동 필터링
- ✅ 날짜 범위별 조회

### UI
- ✅ 파일 선택 (file_picker)
- ✅ 로딩 인디케이터
- ✅ 에러 처리
- ✅ 통계 카드
- ✅ 운동 리스트
- ✅ 전체 기록 화면

### 데이터 타입 지원
- ✅ Workout (운동 세션)
- ⏳ HeartRate (심박수) - 모델만 구현, UI 미구현
- ⏳ 기타 Record 타입 - 확장 가능

## 파일 구조

```
lib/
├── main.dart                           # 앱 진입점, 홈 화면
├── models/
│   ├── health_workout.dart             # 운동 데이터 모델
│   └── health_record.dart              # 건강 기록 모델
├── services/
│   └── health_xml_parser.dart          # XML 파싱 서비스
└── screens/
    └── health_import_screen.dart       # Import & 분석 화면
```

## 주의사항

### 파일 크기
- Apple Health export.xml은 **매우 클 수 있습니다** (수십 MB ~ 수백 MB)
- 처음 파싱 시 **10초 ~ 수분** 소요될 수 있음
- 메모리 사용량 고려 필요

### 성능 최적화 (향후 개선)
- 현재: 전체 파일을 메모리에 로드
- 개선 방안:
  - Streaming XML 파서 사용
  - 필요한 데이터만 선택적 파싱
  - 백그라운드 isolate 사용
  - 파싱 결과 캐싱

### 데이터 프라이버시
- 모든 데이터는 **로컬에서만 처리**
- 서버로 전송하지 않음
- 사용자 기기에서만 분석

## 향후 개발 계획

### 단기
1. 심박수 데이터 시각화
2. 차트/그래프 추가 (fl_chart)
3. 데이터 필터링 기능 (날짜, 운동 유형)
4. 로컬 DB 저장 (SQLite)

### 중기
1. 페이스 분석 및 인사이트
2. 러닝 폼 분석 (센서 데이터)
3. 대회 목표 설정 및 페이스 계산
4. 훈련 계획 제안

### 장기
1. GPS 러닝 트래킹 실시간 연동
2. Apple Watch 앱 개발
3. 하이록스 특화 기능
4. 소셜 기능 (기록 공유)

## 문제 해결

### XML 파싱 오류
```
파싱 오류: FormatException
```
- export.xml 파일이 손상되었을 가능성
- 다시 export 시도
- 파일 인코딩 확인 (UTF-8)

### 파일 선택 안됨
```
파일 선택 오류: PlatformException
```
- 앱 권한 확인
- iOS: Info.plist에 파일 접근 권한 필요 (이미 설정됨)
- 파일 위치 확인 (iCloud Drive, 로컬 등)

### 메모리 부족
```
Out of Memory
```
- 파일이 너무 큰 경우
- 앱 재시작 후 다시 시도
- 향후 streaming 파서로 개선 예정

## 개발자 노트

### 의존성
```yaml
xml: ^6.5.0              # XML 파싱
file_picker: ^8.0.0      # 파일 선택
path_provider: ^2.1.5    # 파일 경로
```

### 테스트
```bash
# 단위 테스트 (향후 추가)
flutter test

# 정적 분석
flutter analyze
```

---

**개발 완료**: 2024-12-04
**상태**: 기본 기능 구현 완료, 테스트 필요
