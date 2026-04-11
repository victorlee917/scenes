import 'package:intl/intl.dart';

/// 1..3999 범위의 정수를 소문자 로마 숫자로. 범위를 벗어나면 arabic 숫자로 폴백.
///
/// 홈 화면의 Scene 번호는 편집·영화 톤을 위해 로마 숫자로 표기한다.
String romanNumeralLower(int n) {
  if (n < 1 || n > 3999) return n.toString();
  const m = ['', 'm', 'mm', 'mmm'];
  const c = ['', 'c', 'cc', 'ccc', 'cd', 'd', 'dc', 'dcc', 'dccc', 'cm'];
  const x = ['', 'x', 'xx', 'xxx', 'xl', 'l', 'lx', 'lxx', 'lxxx', 'xc'];
  const i = ['', 'i', 'ii', 'iii', 'iv', 'v', 'vi', 'vii', 'viii', 'ix'];
  return m[n ~/ 1000] +
      c[(n % 1000) ~/ 100] +
      x[(n % 100) ~/ 10] +
      i[n % 10];
}

/// Scene에 담긴 여러 날짜를 한 줄 메타로 축약한다. 결과는 소문자.
///
/// - 하루: `14 apr`
/// - 같은 달 연속/비연속: `11–14 apr` (범위 표기로 단순화)
/// - 월이 걸치면: `28 apr – 2 may`
/// - 해가 다르면: `28 dec 2025 – 2 jan 2026`
///
/// [locale]은 월 이름 로컬라이즈에만 영향을 준다. 시스템 텍스트 톤을
/// 유지하기 위해 결과 전체를 `toLowerCase()` 처리한다.
String formatSceneDateRange(List<DateTime> dates, String locale) {
  if (dates.isEmpty) return '';
  final sorted = [...dates]..sort();
  final first = sorted.first;
  final last = sorted.last;

  final monthOnly = DateFormat('MMM', locale);
  final dayMonth = DateFormat('d MMM', locale);
  final dayMonthYear = DateFormat('d MMM yyyy', locale);

  String lower(String s) => s.toLowerCase();

  if (_sameDay(first, last)) {
    return lower(dayMonth.format(first));
  }
  if (first.year == last.year && first.month == last.month) {
    return lower('${first.day}–${last.day} ${monthOnly.format(first)}');
  }
  if (first.year == last.year) {
    return lower('${dayMonth.format(first)} – ${dayMonth.format(last)}');
  }
  return lower('${dayMonthYear.format(first)} – ${dayMonthYear.format(last)}');
}

bool _sameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

/// Scene 카드에 노출되는 한 줄 메타: `xiv — 11–14 apr`.
String formatSceneMetaLine(int number, List<DateTime> dates, String locale) {
  final roman = romanNumeralLower(number);
  final range = formatSceneDateRange(dates, locale);
  if (range.isEmpty) return roman;
  return '$roman — $range';
}
