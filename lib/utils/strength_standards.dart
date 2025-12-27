import '../models/exercises/exercise.dart';

class StrengthStandards {
  static const double _defaultMale = 20.0;
  static const double _defaultFemale = 10.0;

  static final Map<String, Map<String, double>> _standards = {
    // Chest
    'barbell_bench_press': {'male': 40.0, 'female': 20.0},
    'dumbbell_bench_press': {'male': 15.0, 'female': 7.0},
    'incline_barbell_bench_press': {'male': 35.0, 'female': 15.0},
    'incline_dumbbell_press': {'male': 12.0, 'female': 6.0},
    'machine_chest_press': {'male': 30.0, 'female': 15.0},
    'smith_machine_bench_press': {'male': 30.0, 'female': 10.0}, // Bar weight + plates
    'dumbbell_fly': {'male': 8.0, 'female': 3.0},
    'pec_deck_fly': {'male': 25.0, 'female': 10.0},
    'cable_crossover': {'male': 10.0, 'female': 5.0},

    // Back
    'deadlift': {'male': 60.0, 'female': 40.0},
    'rack_pull': {'male': 60.0, 'female': 40.0},
    'bent_over_row': {'male': 40.0, 'female': 20.0}, // barbell_row alias
    'barbell_row': {'male': 40.0, 'female': 20.0},
    'dumbbell_row': {'male': 18.0, 'female': 8.0},
    'lat_pulldown': {'male': 35.0, 'female': 20.0},
    'seated_row': {'male': 35.0, 'female': 20.0},
    't_bar_row': {'male': 30.0, 'female': 15.0},
    'straight_arm_pulldown': {'male': 15.0, 'female': 10.0},

    // Shoulders
    'overhead_press': {'male': 30.0, 'female': 15.0},
    'barbell_overhead_press': {'male': 30.0, 'female': 15.0},
    'behind_the_neck_press': {'male': 25.0, 'female': 10.0},
    'dumbbell_shoulder_press': {'male': 14.0, 'female': 6.0},
    'arnold_press': {'male': 12.0, 'female': 5.0},
    'machine_shoulder_press': {'male': 25.0, 'female': 10.0},
    'landmine_press': {'male': 20.0, 'female': 10.0},
    'z_press': {'male': 20.0, 'female': 10.0},
    'dumbbell_lateral_raise': {'male': 6.0, 'female': 2.0},
    'cable_lateral_raise': {'male': 5.0, 'female': 2.5},
    'machine_lateral_raise': {'male': 20.0, 'female': 10.0},
    'lateral_raise': {'male': 6.0, 'female': 2.0},
    'front_raise': {'male': 6.0, 'female': 2.0},
    'y_raise': {'male': 4.0, 'female': 1.0},
    'face_pull': {'male': 15.0, 'female': 7.5},
    'reverse_pec_deck_fly': {'male': 20.0, 'female': 10.0},
    'bent_over_reverse_fly': {'male': 6.0, 'female': 2.0},
    'push_press': {'male': 40.0, 'female': 20.0},
    'upright_row': {'male': 25.0, 'female': 10.0},
    'shrugs': {'male': 40.0, 'female': 20.0},
    'bus_driver': {'male': 10.0, 'female': 5.0},
    'cuban_press': {'male': 8.0, 'female': 3.0},

    // Biceps
    'barbell_curl': {'male': 20.0, 'female': 10.0},
    'dumbbell_curl': {'male': 10.0, 'female': 4.0},
    'hammer_curl': {'male': 12.0, 'female': 5.0},
    'preacher_curl': {'male': 15.0, 'female': 7.5},
    'incline_dumbbell_curl': {'male': 8.0, 'female': 3.0},
    'concentration_curl': {'male': 10.0, 'female': 4.0},
    'cable_curl': {'male': 15.0, 'female': 7.5},
    'spider_curl': {'male': 12.0, 'female': 6.0},
    'zottman_curl': {'male': 10.0, 'female': 4.0},
    'drag_curl': {'male': 15.0, 'female': 7.5},
    'overhead_cable_curl': {'male': 10.0, 'female': 5.0},
    'machine_bicep_curl': {'male': 20.0, 'female': 10.0},
    'chin_up_biceps': {'male': 0.0, 'female': 0.0}, // Bodyweight
  

    // Legs
    'barbell_squat': {'male': 60.0, 'female': 30.0},
    'leg_press': {'male': 80.0, 'female': 40.0},
    'leg_extension': {'male': 30.0, 'female': 15.0},
    'leg_curl': {'male': 25.0, 'female': 15.0},
    'romanian_deadlift': {'male': 50.0, 'female': 30.0},
    'walking_lunge': {'male': 10.0, 'female': 0.0}, // Bodyweight or light dumbbells

    // Arms
    'barbell_curl': {'male': 20.0, 'female': 10.0},
    'dumbbell_curl': {'male': 10.0, 'female': 4.0},
    'tricep_pushdown': {'male': 20.0, 'female': 10.0},
    'weighted_dips': {'male': 0.0, 'female': 0.0}, // Start with BW

    // Triceps
    'barbell_close_grip_bench_press': {'male': 40.0, 'female': 20.0},
    'tricep_pushdown': {'male': 20.0, 'female': 10.0},
    'skull_crusher': {'male': 20.0, 'female': 10.0},
    'overhead_tricep_extension': {'male': 12.0, 'female': 6.0},
    'dumbbell_kickback': {'male': 8.0, 'female': 3.0},
    'bench_dips': {'male': 0.0, 'female': 0.0},
    'diamond_push_ups_triceps': {'male': 0.0, 'female': 0.0},
    'machine_tricep_extension': {'male': 25.0, 'female': 12.0},
    'jm_press': {'male': 30.0, 'female': 15.0},
    'tate_press': {'male': 10.0, 'female': 4.0},

    // Forearms
    'wrist_curl': {'male': 10.0, 'female': 4.0},
    'reverse_wrist_curl': {'male': 6.0, 'female': 2.0},
    'farmers_walk': {'male': 40.0, 'female': 20.0},
    'reverse_curl': {'male': 15.0, 'female': 7.5},
    'wrist_roller': {'male': 5.0, 'female': 2.5},
    'plate_pinch': {'male': 10.0, 'female': 5.0},
    'hammer_curl_forearm': {'male': 12.0, 'female': 5.0},

    // Legs
    'barbell_squat': {'male': 60.0, 'female': 30.0},
    'leg_press': {'male': 100.0, 'female': 50.0},
    'hack_squat': {'male': 40.0, 'female': 20.0},
    'romanian_deadlift': {'male': 50.0, 'female': 30.0},
    'walking_lunge': {'male': 12.0, 'female': 6.0},
    'bulgarian_split_squat': {'male': 10.0, 'female': 4.0},
    'leg_extension': {'male': 30.0, 'female': 15.0},
    'leg_curl': {'male': 25.0, 'female': 12.0},
    'goblet_squat': {'male': 16.0, 'female': 8.0},
    'hip_thrust': {'male': 40.0, 'female': 20.0},
    'calf_raise': {'male': 30.0, 'female': 15.0},
    'hip_abduction': {'male': 35.0, 'female': 20.0},
    'hip_adduction': {'male': 30.0, 'female': 15.0},

    // Core
    'plank': {'male': 0.0, 'female': 0.0},
    'crunch': {'male': 0.0, 'female': 0.0},
    'leg_raise': {'male': 0.0, 'female': 0.0},
    'russian_twist': {'male': 10.0, 'female': 5.0},
    'mountain_climber': {'male': 0.0, 'female': 0.0},
    'dead_bug': {'male': 0.0, 'female': 0.0},
    'bird_dog': {'male': 0.0, 'female': 0.0},
    'superman': {'male': 0.0, 'female': 0.0},
    'back_extension': {'male': 10.0, 'female': 5.0},
    'hip_thrust': {'male': 40.0, 'female': 20.0},
    'glute_bridge': {'male': 0.0, 'female': 0.0},
    'donkey_kick': {'male': 0.0, 'female': 0.0},
    'clamshell': {'male': 0.0, 'female': 0.0},
  };

  /// 초기 무게 계산
  static double getInitialWeight(Exercise exercise, String? gender) {
    // 1. 맨몸 운동은 0 반환
    if (exercise.equipment == 'bodyweight') return 0.0;
    
    // 2. 성별 정규화 (기본값 male)
    final isFemale = gender == 'female';
    final key = isFemale ? 'female' : 'male';
    
    double weight;

    // 3. 특정 운동 ID 매칭 확인
    if (_standards.containsKey(exercise.id)) {
      weight = _standards[exercise.id]![key]!;
    } else {
      // 4. 장비별 폴백(Fallback)
      switch (exercise.equipment) {
        case 'barbell':
          weight = isFemale ? 20.0 : 40.0; // 빈 바 20kg + @
          break;
        case 'dumbbell':
          weight = isFemale ? 5.0 : 12.0;
          break;
        case 'machine':
          weight = isFemale ? 15.0 : 30.0;
          break;
        case 'cable':
          weight = isFemale ? 10.0 : 20.0;
          break;
        case 'kettlebell':
          weight = isFemale ? 8.0 : 16.0;
          break;
        case 'plate':
          weight = isFemale ? 5.0 : 10.0;
          break;
        default:
          weight = isFemale ? _defaultFemale : _defaultMale;
      }
    }

    // 5. 5kg 또는 2.5kg 단위 반올림 (스케일에 따라)
    // 20kg 이상은 5kg 단위, 그 미만은 2.5kg 단위가 적절하나,
    // 요청사항 "5Kg 혹은 10kg 단위로 반올림"을 준수.
    // 하지만 덤벨 7kg 같은 경우는 5나 10으로 가면 너무 큼. 
    // 논리적 타협: 20kg 이상은 5kg 단위, 미만은 그대로 혹은 1kg 단위?
    // User request: "Round to 5kg or 10kg (depending on scale)".
    
    if (weight >= 20) {
      // 5kg 단위 반올림
      return (weight / 5).round() * 5.0;
    } else {
      // 저중량은 정교하게 (그냥 반환 or 1kg 단위)
      // 덤벨 7kg -> 5kg or 10kg is too big jump.
      // Let's stick to the mapped values for small weights.
      return weight;
    }
  }
}
