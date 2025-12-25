class KoreanSearchUtils {
  static const List<String> _chosung = [
    'ㄱ', 'ㄲ', 'ㄴ', 'ㄷ', 'ㄸ', 'ㄹ', 'ㅁ', 'ㅂ', 'ㅃ', 'ㅅ',
    'ㅆ', 'ㅇ', 'ㅈ', 'ㅉ', 'ㅊ', 'ㅋ', 'ㅌ', 'ㅍ', 'ㅎ'
  ];

  /// 텍스트에서 초성만 추출 (공백 제거 포함)
  static String getChosung(String text) {
    String result = "";
    for (var i = 0; i < text.length; i++) {
      int charCode = text.codeUnitAt(i);
      if (charCode >= 0xAC00 && charCode <= 0xD7A3) {
        int chosungIndex = (charCode - 0xAC00) ~/ 588;
        result += _chosung[chosungIndex];
      } else if (text[i] != " ") {
        result += text[i].toLowerCase();
      }
    }
    return result;
  }

  /// 검색용 텍스트 정규화 (공백 제거 및 소문자화)
  static String normalize(String text) {
    return text.replaceAll(' ', '').toLowerCase();
  }

  /// 한글 초성 및 공백 무시 매칭 여부 확인
  static bool matches(String target, String query) {
    if (query.isEmpty) return true;

    final normalizedTarget = normalize(target);
    final normalizedQuery = normalize(query);

    // 1. 일반 포함 검색 (공백 무시)
    if (normalizedTarget.contains(normalizedQuery)) return true;

    // 2. 초성 검색
    // 검색어가 초성으로만 이루어져 있는지 확인 (완성형 한글이 없는지 확인)
    final isChosungOnly = !RegExp(r'[가-힣]').hasMatch(query);
    if (isChosungOnly) {
      final targetChosung = getChosung(target);
      return targetChosung.contains(normalizedQuery);
    }

    return false;
  }
}
