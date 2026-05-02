import 'package:flutter/foundation.dart';

/// Scene에 업로드된 미디어들의 개수 요약. 홈 화면에서 한 줄로 표시할 때
/// 사용. 상세 미디어 목록은 Scene Detail 화면에서 별도 모델로 다룬다.
@immutable
class SceneMediaCounts {
  const SceneMediaCounts({
    this.photos = 0,
    this.videos = 0,
    this.films = 0,
    this.music = 0,
    this.books = 0,
    this.places = 0,
  });

  final int photos;
  final int videos;
  final int films;
  final int music;
  final int books;
  final int places;

  bool get isEmpty =>
      photos == 0 && videos == 0 && films == 0 && music == 0 && books == 0 && places == 0;

  int get total => photos + videos + films + music + books + places;

  SceneMediaCounts operator +(SceneMediaCounts other) => SceneMediaCounts(
        photos: photos + other.photos,
        videos: videos + other.videos,
        films: films + other.films,
        music: music + other.music,
        books: books + other.books,
        places: places + other.places,
      );
}

/// 하나의 데이트(혹은 기념이 되는 순간)에 대응하는 기록 단위.
///
/// - 여러 날짜를 포함할 수 있음 (주말 여행, 연휴 등).
/// - Scene 내부에 다양한 미디어(사진/영상/영화/음악/책)가 들어가지만,
///   홈 화면 모델은 커버 이미지 한 장 + 개수 요약만 보유한다. 실제 파일
///   목록은 Scene Detail 화면에서 별도 모델로 다룬다.
@immutable
class Scene {
  const Scene({
    required this.id,
    required this.number,
    required this.title,
    required this.dates,
    required this.coverImageUrl,
    this.media = const SceneMediaCounts(),
  });

  final String id;

  /// 영구 번호. 로마 숫자로 표기되어 홈 카드에 노출.
  final int number;

  /// 사용자가 지은 Scene 타이틀. l10n 대상 아님(자유 입력).
  final String title;

  /// 이 Scene에 포함된 날짜들. 최소 1개, 순서 상관 없음(포맷 시 정렬).
  final List<DateTime> dates;

  /// 홈 카드에 쓰이는 커버 이미지. 현재는 네트워크 URL, 이후 Supabase
  /// Storage signed URL로 대체 예정.
  final String coverImageUrl;

  /// 각 미디어 종류별 개수. 0인 종류는 화면에서 숨김.
  final SceneMediaCounts media;

  Scene copyWith({
    String? id,
    int? number,
    String? title,
    List<DateTime>? dates,
    String? coverImageUrl,
    SceneMediaCounts? media,
  }) =>
      Scene(
        id: id ?? this.id,
        number: number ?? this.number,
        title: title ?? this.title,
        dates: dates ?? this.dates,
        coverImageUrl: coverImageUrl ?? this.coverImageUrl,
        media: media ?? this.media,
      );
}
