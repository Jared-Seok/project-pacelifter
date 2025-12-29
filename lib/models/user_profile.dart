/// 사용자 프로필 정보를 담는 모델
class UserProfile {
  // Step 1: Basic Info
  final String? gender; // 'male', 'female'
  final double? height; // cm
  final double? weight; // kg
  final DateTime? birthDate;

  // Step 2: Running Profile (New)
  final double? runningExperience; // 연 단위 구력
  final String? runningLevel; // 'beginner', 'intermediate', 'advanced'

  // Step 3: Strength Profile (New)
  final double? strengthExperience; // 연 단위 구력
  final String? strengthLevel; // 'beginner', 'intermediate', 'advanced'

  // Step 4: Body Composition (Optional)
  final double? skeletalMuscleMass; // kg
  final double? bodyFatPercentage; // %

  // Step 5: Running Records (Optional)
  final Duration? fullMarathonTime;
  final Duration? halfMarathonTime;
  final Duration? tenKmTime;
  final Duration? fiveKmTime;

  // Step 6: Bodyweight Exercises (Optional)
  final int? maxPullUps;
  final int? maxPushUps;

  // Step 7: 3-Rep Max (3RM) (Optional)
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

  /// 최대 심박수 예상치 계산 (220 - 나이)
  int? get maxHeartRate {
    final currentAge = age;
    if (currentAge == null) return null;
    return 220 - currentAge;
  }

  /// UserProfile을 복사하여 새로운 인스턴스를 생성하는 메서드
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

  /// Map(JSON)에서 UserProfile 객체를 생성하는 팩토리 생성자
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

  /// UserProfile 객체를 Map(JSON)으로 변환하는 메서드
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
