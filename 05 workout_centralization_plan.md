# 운동 기록 표시 로직 중앙 관리 및 일원화 계획 (완료 보고)

## 1. 기본 원칙 (Core Principle)
- **대시보드 벤치마킹:** 현재 의도대로 가장 잘 표현되고 있는 `lib/screens/dashboard_screen.dart`의 `_buildWorkoutItem` 디자인과 로직을 표준으로 삼습니다.
- **위젯화 및 재사용:** 표준화된 단일 위젯(`WorkoutItemCard`)을 생성하고, 이를 **대시보드**, **상세 피드(주/월/연/레이스)**, **캘린더**에서 동일하게 호출합니다.
- **데이터 통합:** PaceLifter 내부 기록(`WorkoutSession`)과 외부 연동 기록(`HealthDataPoint`)을 `WorkoutDataWrapper`를 통해 완벽히 통합하여 표시합니다.

## 2. 세부 구현 전략 (완료)

### 2.1 중앙 데이터 엔진: `WorkoutUIUtils` 확장
각 화면에서 파편화되어 있던 데이터 판별 로직을 `WorkoutUIUtils`로 완전히 이관했습니다.
- **통합 정보 추출:** `getWorkoutDisplayInfo` 메서드를 통해 데이터 소스 판별, 이름 포맷팅, 색상/아이콘 결정을 한 곳에서 처리합니다.
- **카테고리 판별:** `Strength`, `Endurance`, `Hybrid` 및 코어/기능성 특수 로직을 일원화했습니다.
- **디스플레이 모델 도입:** 가공된 UI 데이터를 안전하게 전달하기 위한 `WorkoutDisplayInfo` 모델을 추가했습니다.

### 2.2 공통 UI 컴포넌트: `WorkoutItemCard`
대시보드의 고품질 디자인을 모든 화면에서 재사용할 수 있도록 독립 위젯으로 분리했습니다.
- **구조:** `Card` -> `ListTile` 기반의 표준 레이아웃 적용.
- **확장성:** `activityOnly` 모드를 지원하여 대시보드와 상세 피드 간의 미세한 디자인 차이를 수용합니다.

## 3. 리팩토링 결과 (Execution Results)

### 3.1 중앙화된 파일 구조
- **Model:** `lib/models/workout_display_info.dart` (UI용 데이터 구조체)
- **Logic:** `lib/utils/workout_ui_utils.dart` (데이터 가공 엔진)
- **UI:** `lib/widgets/workout_item_card.dart` (공통 카드 위젯)

### 3.2 코드 감소 및 최적화 성과
중복된 UI 코드와 데이터 처리 로직을 제거함으로써 프로젝트 전반의 코드량을 대폭 절감했습니다.
- **DashboardScreen:** 약 100라인의 `_buildWorkoutItem` 메서드 제거.
- **WorkoutFeedScreen:** 약 80라인의 중복 로직 제거.
- **CalendarScreen:** 약 80라인의 `_buildEventItem` 및 로컬 색상 판별 로직 제거.
- **총합:** 약 **260+ 라인의 중복 코드 제거** 및 유지보수 포인트 단일화.

## 4. 기대 효과 및 향후 관리
- **완벽한 디자인 일관성:** 이제 어떤 화면에서든 동일한 운동은 동일한 아이콘, 제목, 색상으로 표시됩니다.
- **유지보수 효율 극대화:** 운동 카테고리 색상을 변경하거나 새로운 운동 유형을 추가할 때 `WorkoutUIUtils` 한 곳만 수정하면 전체 앱에 즉시 반영됩니다.
- **사용자 경험(UX) 통일:** 캘린더 등 기존에 투박했던 UI가 대시보드 수준의 세련된 디자인으로 상향 평준화되었습니다.
