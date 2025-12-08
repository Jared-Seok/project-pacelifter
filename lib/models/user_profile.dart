/// 사용자 프로필 정보를 담는 모델
class UserProfile {
  // Step 1: Basic Info
  final String? gender; // 'male', 'female'
  final double? height; // cm
  final double? weight; // kg

  // Step 2: Body Composition
  final double? skeletalMuscleMass; // kg
  final double? bodyFatPercentage; // %

  // Step 3: Running Records
  final Duration? fullMarathonTime;
  final Duration? halfMarathonTime;
  final Duration? tenKmTime;
  final Duration? fiveKmTime;

  // Step 4: Bodyweight Exercises
  final int? maxPullUps;
  final int? maxPushUps;

  // Step 5: 3-Rep Max (3RM)
  final double? squat3RM;
  final double? benchPress3RM;
  final double? deadlift3RM;

  UserProfile({
    this.gender,
    this.height,
    this.weight,
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

  /// UserProfile을 복사하여 새로운 인스턴스를 생성하는 메서드
  UserProfile copyWith({
    String? gender,
    double? height,
    double? weight,
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
      skeletalMuscleMass: json['skeletalMuscleMass'],
      bodyFatPercentage: json['bodyFatPercentage'],
      fullMarathonTime: json['fullMarathonTime'] != null
          ? Duration(seconds: json['fullMarathonTime'])
          : null,
      halfMarathonTime: json['halfMarathonTime'] != null
          ? Duration(seconds: json['halfMarathonTime'])
          : null,
      tenKmTime: json['tenKmTime'] != null
          ? Duration(seconds: json['tenKmTime'])
          : null,
      fiveKmTime: json['fiveKmTime'] != null
          ? Duration(seconds: json['fiveKmTime'])
          : null,
      maxPullUps: json['maxPullUps'],
      maxPushUps: json['maxPushUps'],
      squat3RM: json['squat3RM'],
      benchPress3RM: json['benchPress3RM'],
      deadlift3RM: json['deadlift3RM'],
    );
  }

  /// UserProfile 객체를 Map(JSON)으로 변환하는 메서드
  Map<String, dynamic> toJson() {
    return {
      'gender': gender,
      'height': height,
      'weight': weight,
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
