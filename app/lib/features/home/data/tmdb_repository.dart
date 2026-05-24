import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/data/lru_cache.dart';
import '../models/tmdb_film.dart';

/// TMDB 검색을 Edge Function `tmdb-search`로 위임하는 Repository.
///
/// 클라이언트는 절대 TMDB API 키를 직접 보유하지 않는다.
/// (memory: project_api_key_management)
class TmdbRepository {
  TmdbRepository(this._client);

  final SupabaseClient _client;

  /// `(locale, query)`별 결과 캐시. 같은 키워드 재검색·picker 재진입 시 유료
  /// TMDB API + Edge Function 호출을 건너뛴다. locale은 닫힌 집합(BCP-47
  /// 태그)이라 `|` 구분자 충돌이 없다.
  final LruCache<String, List<TmdbFilm>> _cache = LruCache();

  /// `query`로 TMDB multi 검색.
  ///
  /// [locale]은 `ko-KR`, `en-US` 같은 BCP-47 태그. TMDB가 해당 언어 메타가
  /// 없으면 영어로 폴백하므로 안전하게 전달 가능.
  Future<List<TmdbFilm>> search(
    String query, {
    String locale = 'en-US',
  }) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return const [];

    final cacheKey = '$locale|$trimmed';
    final cached = _cache.get(cacheKey);
    if (cached != null) return cached;

    final response = await _client.functions.invoke(
      'tmdb-search',
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
        .map(TmdbFilm.fromJson)
        .toList(growable: false);
    // 성공한 비어있지 않은 결과만 캐싱 — malformed 응답·에러를 캐시에 굳히지
    // 않는다(에러는 invoke가 throw하므로 여기 도달 전에 propagate).
    if (results.isNotEmpty) _cache.put(cacheKey, results);
    return results;
  }
}

final tmdbRepositoryProvider = Provider<TmdbRepository>((ref) {
  return TmdbRepository(Supabase.instance.client);
});
