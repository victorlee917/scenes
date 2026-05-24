import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/data/lru_cache.dart';
import '../models/spotify_hit.dart';

/// Spotify 검색을 Edge Function `spotify-search`로 위임하는 Repository.
///
/// Spotify client_id/secret는 절대 클라이언트에 노출되지 않는다.
/// (memory: project_api_key_management)
class SpotifyRepository {
  SpotifyRepository(this._client);

  final SupabaseClient _client;

  /// `(locale, query)`별 결과 캐시. 같은 키워드 재검색·picker 재진입 시 유료
  /// Spotify API + Edge Function 호출을 건너뛴다.
  final LruCache<String, List<SpotifyHit>> _cache = LruCache();

  /// `query`로 Spotify track + album 검색.
  ///
  /// [locale]은 `ko`/`en` 등 BCP-47 첫 두 글자. Edge Function이 KR/US market
  /// 으로 매핑.
  Future<List<SpotifyHit>> search(
    String query, {
    String locale = 'en',
  }) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return const [];

    final cacheKey = '$locale|$trimmed';
    final cached = _cache.get(cacheKey);
    if (cached != null) return cached;

    final response = await _client.functions.invoke(
      'spotify-search',
      body: {
        'query': trimmed,
        'locale': locale,
      },
    );

    final data = response.data;
    if (data is! Map<String, dynamic>) return const [];

    final raw = data['results'];
    if (raw is! List) return const [];

    final results = raw
        .whereType<Map<String, dynamic>>()
        .map(SpotifyHit.fromJson)
        .toList(growable: false);
    // 성공한 비어있지 않은 결과만 캐싱 — malformed 응답·에러는 캐시에 굳히지
    // 않는다(에러는 invoke가 throw하므로 여기 도달 전에 propagate).
    if (results.isNotEmpty) _cache.put(cacheKey, results);
    return results;
  }
}

final spotifyRepositoryProvider = Provider<SpotifyRepository>((ref) {
  return SpotifyRepository(Supabase.instance.client);
});
