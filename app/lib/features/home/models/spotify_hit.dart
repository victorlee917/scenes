/// Spotify 검색 결과 단일 항목 (track 또는 album).
///
/// `spotify-search` Edge Function이 정규화해 반환. 캐싱은 TOS상 금지이므로
/// `coverUrl`은 Spotify CDN URL 그대로 사용. 표시 시 [spotifyUri]/[externalUrl]
/// 링크백 의무.
class SpotifyHit {
  const SpotifyHit({
    required this.kind,
    required this.id,
    required this.title,
    required this.artist,
    required this.album,
    required this.year,
    required this.coverUrl,
    required this.spotifyUri,
    required this.externalUrl,
  });

  /// `'track'` 또는 `'album'`.
  final String kind;

  /// Spotify ID.
  final String id;

  /// track인 경우 곡명, album인 경우 앨범명.
  final String title;

  final String artist;

  /// track인 경우 수록 앨범명. album인 경우 null (title이 곧 앨범명).
  final String? album;

  /// 'YYYY'. TMDB와 동일 포맷.
  final String? year;

  /// Spotify CDN URL. 캐싱/저장 금지.
  final String? coverUrl;

  final String spotifyUri;
  final String? externalUrl;

  bool get isTrack => kind == 'track';

  /// UI 라벨용. ko/en 공통.
  String get typeLabel => isTrack ? 'Track' : 'Album';

  factory SpotifyHit.fromJson(Map<String, dynamic> json) {
    return SpotifyHit(
      kind: json['kind'] as String,
      id: json['id'] as String,
      title: json['title'] as String,
      artist: json['artist'] as String,
      album: json['album'] as String?,
      year: json['year'] as String?,
      coverUrl: json['cover_url'] as String?,
      spotifyUri: json['spotify_uri'] as String,
      externalUrl: json['external_url'] as String?,
    );
  }
}
