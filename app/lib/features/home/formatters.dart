import 'package:intl/intl.dart';

import 'models/scene.dart';

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

/// Scene에 담긴 여러 날짜를 한 줄 메타로 축약한다. 결과는 로케일별 관습에
/// 맞춰 다르게 포맷된다.
///
/// **English/Latin locale (소문자):**
/// - 하루: `14 apr`
/// - 같은 달 범위: `11–14 apr`
/// - 월 걸침: `28 apr – 2 may`
/// - 해 걸침: `28 dec 2025 – 2 jan 2026`
///
/// **Korean locale:**
/// - 하루: `4월 14일`
/// - 같은 달 범위: `4월 11–14일`
/// - 월 걸침: `4월 28일 – 5월 2일`
/// - 해 걸침: `2025년 12월 28일 – 2026년 1월 2일`
String formatSceneDateRange(List<DateTime> dates, String locale) {
  if (dates.isEmpty) return '';
  final sorted = [...dates]..sort();
  final first = sorted.first;
  final last = sorted.last;
  final sameDay = _sameDay(first, last);
  final sameMonth = first.year == last.year && first.month == last.month;
  final sameYear = first.year == last.year;

  if (locale.startsWith('ko')) {
    if (sameDay) {
      return '${first.month}월 ${first.day}일';
    }
    if (sameMonth) {
      return '${first.month}월 ${first.day}–${last.day}일';
    }
    if (sameYear) {
      return '${first.month}월 ${first.day}일 – '
          '${last.month}월 ${last.day}일';
    }
    return '${first.year}년 ${first.month}월 ${first.day}일 – '
        '${last.year}년 ${last.month}월 ${last.day}일';
  }

  // Default — English/Latin locale (lowercase).
  final monthOnly = DateFormat('MMM', locale);
  final dayMonth = DateFormat('d MMM', locale);
  final dayMonthYear = DateFormat('d MMM yyyy', locale);

  String lower(String s) => s.toLowerCase();

  if (sameDay) return lower(dayMonth.format(first));
  if (sameMonth) {
    return lower('${first.day}–${last.day} ${monthOnly.format(first)}');
  }
  if (sameYear) {
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

/// Scene의 미디어 개수를 한 줄 요약으로 포맷. 0인 항목은 생략.
///
/// - English: `12 photos · 2 films · 5 songs`
/// - Korean:  `사진 12 · 영화 2 · 음악 5`
///
/// 아무 미디어도 없으면 빈 문자열.
String formatSceneMediaSummary(SceneMediaCounts counts, String locale) {
  if (counts.isEmpty) return '';
  final parts = <String>[];
  final isKo = locale.startsWith('ko');

  void add(int n, String enSingular, String enPlural, String ko) {
    if (n > 0) {
      if (isKo) {
        parts.add('$ko $n');
      } else {
        parts.add('$n ${n == 1 ? enSingular : enPlural}');
      }
    }
  }

  add(counts.photos, 'photo', 'photos', '사진');
  add(counts.videos, 'video', 'videos', '영상');
  add(counts.films, 'film', 'films', '영화');
  add(counts.music, 'song', 'songs', '음악');
  add(counts.books, 'book', 'books', '책');
  add(counts.places, 'place', 'places', '장소');
  return parts.join(' · ');
}

/// 전체 Scene의 미디어를 합산해 문장형으로 포맷.
///
/// 예: "took 79 photos, watched 3 films, listened to 31 songs, and read 4 books."
/// 0인 항목은 생략. 전부 0이면 빈 문자열.
String formatMediaNarrative(SceneMediaCounts counts) {
  final parts = <String>[];

  void add(int n, String verbSingular, String verbPlural,
      String nounSingular, String nounPlural) {
    if (n > 0) {
      final noun = n == 1 ? nounSingular : nounPlural;
      final verb = n == 1 ? verbSingular : verbPlural;
      parts.add('$verb $n $noun');
    }
  }

  add(counts.photos, 'took', 'took', 'photo', 'photos');
  add(counts.videos, 'recorded', 'recorded', 'video', 'videos');
  add(counts.films, 'watched', 'watched', 'film', 'films');
  add(counts.music, 'listened to', 'listened to', 'song', 'songs');
  add(counts.books, 'read', 'read', 'book', 'books');
  add(counts.places, 'visited', 'visited', 'place', 'places');

  if (parts.isEmpty) return '';
  if (parts.length == 1) return '${parts[0]}.';
  final last = parts.removeLast();
  return '${parts.join(', ')}, and $last.';
}
