import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/data/lru_cache.dart';
import '../models/place_hit.dart';

/// 장소 검색 범위. 국내 로케일 사용자에게만 picker에서 토글로 노출된다.
///
/// - [domestic]: Kakao 로컬 검색(EF `kakao-local-search`). 한국 장소 데이터
///   품질이 월등하지만 데이터가 한국 한정.
/// - [overseas]: 기존 경로(iOS Apple / 그 외 Mapbox). 전 세계 커버.
enum PlaceSearchMode { domestic, overseas }

/// 디바이스 region이 한국인지. "국내/해외" 토글 노출 + 기본 모드 판정에 쓴다.
/// 언어가 아니라 country(region) 기준이라 "영어 앱 + 한국 거주"도 국내로 잡는다.
bool isDomesticDeviceLocale() {
  final country =
      ui.PlatformDispatcher.instance.locale.countryCode?.toUpperCase();
  return country == 'KR';
}

/// 장소 검색 Repository — 모드·platform별로 비용 다른 소스를 사용한다.
///
/// - **국내 모드**: Kakao 로컬 검색 via Edge Function `kakao-local-search`.
///   한국 데이터 한정이지만 POI 품질이 최상. 무료(할당량 기반).
/// - **해외 모드 · iOS**: Apple Maps `MKLocalSearch` (platform channel
///   `app.scenes/place_search`). 외부 비용 0. Apple MapKit attribution 필요.
/// - **해외 모드 · 그 외(Android 등)**: Mapbox Geocoding via EF `mapbox-geocode`.
///   iOS native 동급 무료 API가 없어 fallback. 단가 발생.
///
/// 저장 시점에는 모드·platform과 무관하게 `mapbox-static-cache` Edge Function이
/// 정적지도를 1회 캐싱(content_repository에서 호출). 검색 소스가 무엇이든
/// 표시용 지도는 통일된 Mapbox 스타일을 유지한다.
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
    PlaceSearchMode mode = PlaceSearchMode.overseas,
  }) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return const [];

    // 같은 단어라도 모드가 다르면 결과가 다르므로 키에 모드 포함.
    final cacheKey = '${mode.name}|$locale|$trimmed';
    final cached = _cache.get(cacheKey);
    if (cached != null) return cached;

    final List<PlaceHit> results;
    if (mode == PlaceSearchMode.domestic) {
      results = await _searchViaKakao(trimmed, locale: locale);
    } else {
      // iOS의 MKLocalSearch는 결과 텍스트를 디바이스 OS 언어로만 돌려주고
      // request 단위로 language를 override할 공개 API가 없음. 그래서 앱 locale
      // ≠ 디바이스 primary locale이면 Apple Maps로는 일관된 표기 보장 불가 —
      // Mapbox EF로 폴백해서 language-specific field를 강제로 가져옴.
      final deviceLang =
          ui.PlatformDispatcher.instance.locale.languageCode.toLowerCase();
      final requestedLang = locale.toLowerCase().split('-').first;
      final canUseApple = Platform.isIOS && deviceLang == requestedLang;
      results = canUseApple
          ? await _searchViaAppleMaps(trimmed, locale: locale)
          : await _searchViaMapbox(trimmed, locale: locale);
    }
    // 모든 경로가 실패를 빈 리스트로 swallow하므로 비어있지 않은 결과만
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

  Future<List<PlaceHit>> _searchViaKakao(
    String query, {
    required String locale,
  }) async {
    try {
      final response = await _client.functions.invoke(
        'kakao-local-search',
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
