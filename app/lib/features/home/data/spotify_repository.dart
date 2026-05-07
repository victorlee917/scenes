import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/spotify_hit.dart';

/// Spotify 검색을 Edge Function `spotify-search`로 위임하는 Repository.
///
/// Spotify client_id/secret는 절대 클라이언트에 노출되지 않는다.
/// (memory: project_api_key_management)
class SpotifyRepository {
  SpotifyRepository(this._client);

  final SupabaseClient _client;

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

    return raw
        .whereType<Map<String, dynamic>>()
        .map(SpotifyHit.fromJson)
        .toList(growable: false);
  }
}

final spotifyRepositoryProvider = Provider<SpotifyRepository>((ref) {
  return SpotifyRepository(Supabase.instance.client);
});
