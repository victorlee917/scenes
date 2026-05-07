import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/place_hit.dart';

/// Mapbox geocoding을 Edge Function `mapbox-geocode`로 위임.
///
/// MAPBOX_TOKEN은 절대 클라이언트에 노출되지 않는다.
/// (memory: project_api_key_management)
class MapboxRepository {
  MapboxRepository(this._client);

  final SupabaseClient _client;

  /// `query`로 장소 검색 (forward geocoding).
  ///
  /// [locale]은 `ko`/`en` 등. Edge Function이 Mapbox `language` 파라미터로
  /// 매핑(ko 디바이스는 ko,en 폴백).
  Future<List<PlaceHit>> search(
    String query, {
    String locale = 'en',
  }) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return const [];

    final response = await _client.functions.invoke(
      'mapbox-geocode',
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
        .map(PlaceHit.fromJson)
        .toList(growable: false);
  }
}

final mapboxRepositoryProvider = Provider<MapboxRepository>((ref) {
  return MapboxRepository(Supabase.instance.client);
});
