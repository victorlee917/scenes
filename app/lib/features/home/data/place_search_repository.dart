import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/data/lru_cache.dart';
import '../models/place_hit.dart';

/// 장소 검색 Repository — platform별로 비용 다른 소스를 사용한다.
///
/// - **iOS**: Apple Maps `MKLocalSearch` (platform channel `app.scenes/place_search`).
///   외부 비용 0, iOS 자체 데이터(KR/EN 품질 양호). Apple MapKit attribution이
///   필요해 picker UI 하단에 Apple 표시가 노출되어야 한다.
/// - **그 외(Android 등)**: Mapbox Geocoding via Edge Function `mapbox-geocode`.
///   iOS native 동급 무료 API가 없어 fallback. 단가가 발생하므로 추후 사용량
///   보고 Google Places 등으로 옮길지 재검토.
///
/// 저장 시점에는 platform과 무관하게 `mapbox-static-cache` Edge Function이
/// 정적지도를 1회 캐싱(content_repository에서 호출). 검색만 platform별로
/// 갈라도 표시용 지도는 통일된 Mapbox 스타일을 유지.
class PlaceSearchRepository {
  PlaceSearchRepository(this._client);

  final SupabaseClient _client;

  static const _channel = MethodChannel('app.scenes/place_search');

  /// `(locale, query)`별 결과 캐시. 같은 키워드 재검색·picker 재진입 시
  /// 호출을 건너뛴다 — Android의 Mapbox geocode는 유료라 직접적인 비용 절감.
  final LruCache<String, List<PlaceHit>> _cache = LruCache();

  Future<List<PlaceHit>> search(
    String query, {
    String locale = 'en',
  }) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return const [];

    final cacheKey = '$locale|$trimmed';
    final cached = _cache.get(cacheKey);
    if (cached != null) return cached;

    final results = Platform.isIOS
        ? await _searchViaAppleMaps(trimmed, locale: locale)
        : await _searchViaMapbox(trimmed, locale: locale);
    // 두 경로 모두 실패를 빈 리스트로 swallow하므로 비어있지 않은 결과만
    // 캐싱 — 일시적 네트워크 실패가 캐시에 굳지 않게.
    if (results.isNotEmpty) _cache.put(cacheKey, results);
    return results;
  }

  Future<List<PlaceHit>> _searchViaAppleMaps(
    String query, {
    required String locale,
  }) async {
    try {
      final raw = await _channel.invokeMethod<List<dynamic>>(
        'search',
        {'query': query, 'locale': locale},
      );
      if (raw == null) return const [];
      return raw
          .whereType<Map<dynamic, dynamic>>()
          .map((m) => Map<String, dynamic>.from(m))
          .map(_fromNative)
          .toList(growable: false);
    } on PlatformException {
      return const [];
    } on MissingPluginException {
      return const [];
    }
  }

  Future<List<PlaceHit>> _searchViaMapbox(
    String query, {
    required String locale,
  }) async {
    try {
      final response = await _client.functions.invoke(
        'mapbox-geocode',
        body: {'query': query, 'locale': locale},
      );
      final data = response.data;
      if (data is! Map<String, dynamic>) return const [];
      final raw = data['results'];
      if (raw is! List) return const [];
      return raw
          .whereType<Map<String, dynamic>>()
          .map(PlaceHit.fromJson)
          .toList(growable: false);
    } catch (_) {
      return const [];
    }
  }

  /// MKLocalSearch native dict → PlaceHit. 키 이름이 fromJson과 약간 달라
  /// 별도 매핑.
  PlaceHit _fromNative(Map<String, dynamic> json) {
    return PlaceHit(
      id: json['id'] as String,
      name: json['name'] as String,
      region: json['region'] as String?,
      country: json['country'] as String?,
      fullAddress: json['fullAddress'] as String? ?? '',
      lat: (json['lat'] as num).toDouble(),
      lng: (json['lng'] as num).toDouble(),
    );
  }
}

final placeSearchRepositoryProvider = Provider<PlaceSearchRepository>((ref) {
  return PlaceSearchRepository(Supabase.instance.client);
});
