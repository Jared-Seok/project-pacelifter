
/// 사용자 프로필 정보를 담는 모델
class UserProfile {
  // Step 1: Basic Info
  final String? gender; // 'male', 'female'
  final double? height; // cm
  final double? weight; // kg
  final DateTime? birthDate;

  // Step 2: Running Profile
  final double? runningExperience; // 연 단위 구력
  final String? runningLevel; // 'beginner', 'intermediate', 'advanced'

  // Step 3: Strength Profile
  final double? strengthExperience; // 연 단위 구력
  final String? strengthLevel; // 'beginner', 'intermediate', 'advanced'

  // Step 4: Body Composition
  final double? skeletalMuscleMass; // kg
  final double? bodyFatPercentage; // %

  // 추가: 선호하는 최대 심박수 계산 공식
  // 'fox', 'tanaka', 'gellish', 'gulati'
  final String? preferredMhrFormula;

  // 기록 필드들 (Optional)
  final Duration? fullMarathonTime;
  final Duration? halfMarathonTime;
  final Duration? tenKmTime;
  final Duration? fiveKmTime;
  final int? maxPullUps;
  final int? maxPushUps;
  final double? squat3RM;
  final double? benchPress3RM;
  final double? deadlift3RM;

  UserProfile({
    this.gender,
    this.height,
    this.weight,
    this.birthDate,
    this.runningExperience,
    this.runningLevel,
    this.strengthExperience,
    this.strengthLevel,
    this.skeletalMuscleMass,
    this.bodyFatPercentage,
    this.preferredMhrFormula = 'fox',
    this.fullMarathonTime,
    this.halfMarathonTime,
    this.tenKmTime,
    this.fiveKmTime,
    this.maxPullUps,
    this.maxPushUps,
    this.squat3RM,
    this.benchPress3RM,
    this.deadlift3RM,
  });

  /// 나이 계산 (만 나이)
  int? get age {
    if (birthDate == null) return null;
    final now = DateTime.now();
    int age = now.year - birthDate!.year;
    if (now.month < birthDate!.month ||
        (now.month == birthDate!.month && now.day < birthDate!.day)) {
      age--;
    }
    return age;
  }

  /// 다중 공식을 활용한 최대 심박수 계산
  int? get maxHeartRate {
    final currentAge = age;
    if (currentAge == null) return null;

    final formula = preferredMhrFormula ?? 'fox';
    double mhr;

    switch (formula) {
      case 'tanaka':
        mhr = 208 - (0.7 * currentAge);
        break;
      case 'gellish':
        mhr = 207 - (0.7 * currentAge);
        break;
      case 'gulati':
        // 여성 전용 공식이나 성별 정보가 없거나 남성이면 Fox로 대체
        if (gender == 'female') {
          mhr = 206 - (0.88 * currentAge);
        } else {
          mhr = 220.0 - currentAge;
        }
        break;
      case 'fox':
      default:
        mhr = 220.0 - currentAge;
        break;
    }
    return mhr.round();
  }

  /// 심박수 존(Zone 1~5) 계산 결과 반환
  Map<int, Map<String, int>> get hrZones {
    final mhr = maxHeartRate;
    if (mhr == null) return {};

    return {
      1: {'min': (mhr * 0.50).round(), 'max': (mhr * 0.60).round()},
      2: {'min': (mhr * 0.60).round(), 'max': (mhr * 0.70).round()},
      3: {'min': (mhr * 0.70).round(), 'max': (mhr * 0.80).round()},
      4: {'min': (mhr * 0.80).round(), 'max': (mhr * 0.90).round()},
      5: {'min': (mhr * 0.90).round(), 'max': mhr},
    };
  }

  UserProfile copyWith({
    String? gender,
    double? height,
    double? weight,
    DateTime? birthDate,
    double? runningExperience,
    String? runningLevel,
    double? strengthExperience,
    String? strengthLevel,
    double? skeletalMuscleMass,
    double? bodyFatPercentage,
    String? preferredMhrFormula,
    Duration? fullMarathonTime,
    Duration? halfMarathonTime,
    Duration? tenKmTime,
    Duration? fiveKmTime,
    int? maxPullUps,
    int? maxPushUps,
    double? squat3RM,
    double? benchPress3RM,
    double? deadlift3RM,
  }) {
    return UserProfile(
      gender: gender ?? this.gender,
      height: height ?? this.height,
      weight: weight ?? this.weight,
      birthDate: birthDate ?? this.birthDate,
      runningExperience: runningExperience ?? this.runningExperience,
      runningLevel: runningLevel ?? this.runningLevel,
      strengthExperience: strengthExperience ?? this.strengthExperience,
      strengthLevel: strengthLevel ?? this.strengthLevel,
      skeletalMuscleMass: skeletalMuscleMass ?? this.skeletalMuscleMass,
      bodyFatPercentage: bodyFatPercentage ?? this.bodyFatPercentage,
      preferredMhrFormula: preferredMhrFormula ?? this.preferredMhrFormula,
      fullMarathonTime: fullMarathonTime ?? this.fullMarathonTime,
      halfMarathonTime: halfMarathonTime ?? this.halfMarathonTime,
      tenKmTime: tenKmTime ?? this.tenKmTime,
      fiveKmTime: fiveKmTime ?? this.fiveKmTime,
      maxPullUps: maxPullUps ?? this.maxPullUps,
      maxPushUps: maxPushUps ?? this.maxPushUps,
      squat3RM: squat3RM ?? this.squat3RM,
      benchPress3RM: benchPress3RM ?? this.benchPress3RM,
      deadlift3RM: deadlift3RM ?? this.deadlift3RM,
    );
  }

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      gender: json['gender'],
      height: json['height'],
      weight: json['weight'],
      birthDate: json['birthDate'] != null ? DateTime.parse(json['birthDate']) : null,
      runningExperience: json['runningExperience']?.toDouble(),
      runningLevel: json['runningLevel'],
      strengthExperience: json['strengthExperience']?.toDouble(),
      strengthLevel: json['strengthLevel'],
      skeletalMuscleMass: json['skeletalMuscleMass']?.toDouble(),
      bodyFatPercentage: json['bodyFatPercentage']?.toDouble(),
      preferredMhrFormula: json['preferredMhrFormula'] ?? 'fox',
      fullMarathonTime: json['fullMarathonTime'] != null ? Duration(seconds: json['fullMarathonTime']) : null,
      halfMarathonTime: json['halfMarathonTime'] != null ? Duration(seconds: json['halfMarathonTime']) : null,
      tenKmTime: json['tenKmTime'] != null ? Duration(seconds: json['tenKmTime']) : null,
      fiveKmTime: json['fiveKmTime'] != null ? Duration(seconds: json['fiveKmTime']) : null,
      maxPullUps: json['maxPullUps'],
      maxPushUps: json['maxPushUps'],
      squat3RM: json['squat3RM']?.toDouble(),
      benchPress3RM: json['benchPress3RM']?.toDouble(),
      deadlift3RM: json['deadlift3RM']?.toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'gender': gender,
      'height': height,
      'weight': weight,
      'birthDate': birthDate?.toIso8601String(),
      'runningExperience': runningExperience,
      'runningLevel': runningLevel,
      'strengthExperience': strengthExperience,
      'strengthLevel': strengthLevel,
      'skeletalMuscleMass': skeletalMuscleMass,
      'bodyFatPercentage': bodyFatPercentage,
      'preferredMhrFormula': preferredMhrFormula,
      'fullMarathonTime': fullMarathonTime?.inSeconds,
      'halfMarathonTime': halfMarathonTime?.inSeconds,
      'tenKmTime': tenKmTime?.inSeconds,
      'fiveKmTime': fiveKmTime?.inSeconds,
      'maxPullUps': maxPullUps,
      'maxPushUps': maxPushUps,
      'squat3RM': squat3RM,
      'benchPress3RM': benchPress3RM,
      'deadlift3RM': deadlift3RM,
    };
  }
}