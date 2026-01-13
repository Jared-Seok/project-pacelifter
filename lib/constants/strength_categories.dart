
class StrengthCategory {
  final String id;
  final String name;
  final String iconPath;

  const StrengthCategory({
    required this.id,
    required this.name,
    required this.iconPath,
  });
}

class StrengthCategories {
  static const List<StrengthCategory> categories = [
    StrengthCategory(
      id: 'chest',
      name: '가슴',
      iconPath: 'assets/images/strength/category/chest.svg',
    ),
    StrengthCategory(
      id: 'shoulders',
      name: '어깨',
      iconPath: 'assets/images/strength/category/shoulders.svg',
    ),
    StrengthCategory(
      id: 'back',
      name: '등',
      iconPath: 'assets/images/strength/category/back.svg',
    ),
    StrengthCategory(
      id: 'biceps',
      name: '이두',
      iconPath: 'assets/images/strength/category/biceps.svg',
    ),
    StrengthCategory(
      id: 'triceps',
      name: '삼두',
      iconPath: 'assets/images/strength/category/triceps.svg',
    ),
    StrengthCategory(
      id: 'forearms',
      name: '전완',
      iconPath: 'assets/images/strength/category/forearms.svg',
    ),
    StrengthCategory(
      id: 'legs',
      name: '하체',
      iconPath: 'assets/images/strength/category/legs.svg',
    ),
    StrengthCategory(
      id: 'core',
      name: '코어',
      iconPath: 'assets/images/strength/category/core.svg',
    ),
    StrengthCategory(
      id: 'compound',
      name: '복합',
      iconPath: 'assets/images/strength/lifter-icon.svg',
    ),
  ];

  static StrengthCategory getById(String id) {
    return categories.firstWhere(
      (c) => c.id == id,
      orElse: () => const StrengthCategory(
        id: 'unknown',
        name: '기타',
        iconPath: 'assets/images/strength/lifter-icon.svg',
      ),
    );
  }
}
