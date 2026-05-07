/// TMDB 검색 결과(영화·TV) 단일 항목.
///
/// `tmdb-search` Edge Function에서 정규화된 형태로 받아온 후 클라에서 사용.
/// 저장은 contents.payload 표준 스키마(memory: external_media_caching_policy)로
/// 변환하여 진행한다.
class TmdbFilm {
  const TmdbFilm({
    required this.tmdbId,
    required this.mediaType,
    required this.title,
    required this.year,
    required this.posterUrl,
    required this.posterPath,
    required this.director,
    required this.genres,
    required this.runtime,
    required this.overview,
  });

  final int tmdbId;

  /// `'movie'` 또는 `'tv'`.
  final String mediaType;

  final String title;

  /// 개봉/방영 시작 연도. TMDB가 미정인 경우 null.
  final String? year;

  /// 검색 picker에서 즉시 표시할 작은(w342) 포스터 URL.
  final String? posterUrl;

  /// TMDB raw poster path (예: `/abc123.jpg`). 사용자가 영화를 선택해 캐싱할
  /// 때 `tmdb-poster-cache`가 이 path를 받아 원하는 사이즈(w780)로 다운받아
  /// scene_media에 저장한다. null이면 포스터 자체 없음.
  final String? posterPath;

  /// 영화: Director(들). TV: Creator(들). 여러 명이면 `, ` join. 없으면 null.
  final String? director;

  /// 장르명 배열 (예: ['Drama', 'Romance']). 비어있을 수 있음.
  final List<String> genres;

  /// 러닝타임(분). 영화는 단편 길이, TV는 평균 에피소드 길이. null이면 미정.
  final int? runtime;

  final String overview;

  bool get isMovie => mediaType == 'movie';

  /// UI 라벨용. ko/en 공통.
  String get typeLabel => isMovie ? 'Movie' : 'TV Series';

  factory TmdbFilm.fromJson(Map<String, dynamic> json) {
    final genresRaw = json['genres'];
    return TmdbFilm(
      tmdbId: json['tmdb_id'] as int,
      mediaType: json['media_type'] as String,
      title: json['title'] as String,
      year: json['year'] as String?,
      posterUrl: json['poster_url'] as String?,
      posterPath: json['poster_path'] as String?,
      director: json['director'] as String?,
      genres: genresRaw is List
          ? genresRaw.whereType<String>().toList(growable: false)
          : const [],
      runtime: json['runtime'] as int?,
      overview: (json['overview'] as String?) ?? '',
    );
  }
}
