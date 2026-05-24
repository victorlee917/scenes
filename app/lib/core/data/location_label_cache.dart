import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geocoding/geocoding.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 좌표 → 사람이 읽는 주소 라벨을 reverse-geocoding하고 영속 캐시하는 서비스.
///
/// 외부 API 의존 없이 OS 내장 reverse geocoder(iOS: CLGeocoder via MapKit,
/// Android: system Geocoder) 사용 — 무료 + 별도 API 키 불필요. KR/해외 모두
/// 디바이스가 알고 있는 최선의 주소를 반환.
///
/// 캐시는 좌표를 4자리(약 ~10m)로 quantize한 키로 SharedPreferences에 저장.
/// 같은 좌표 인근 사진들이 같은 라벨을 공유 + 한 번 resolve 후 영구 hit.
class LocationLabelCache {
  LocationLabelCache() {
    // 생성 즉시 SharedPreferences 로드 시작 — 이후 [peek] 동기 호출이 빨리
    // 동작하도록.
    // ignore: discarded_futures
    _ensureLoaded();
  }

  static const _prefsKey = 'location_label_cache_v1';

  Map<String, String>? _mem;
  bool _persistDirty = false;
  // path 동시 fetch 시 중복 호출 방지.
  final Map<String, Future<String?>> _inflight = {};
  // reverse-geocoding 실패 좌표의 마지막 실패 시각(ms). 메모리 전용 — 영구
  // 캐시가 아니라 TTL 경과·앱 재시작 시 다시 시도된다(일시적 실패 대응).
  final Map<String, int> _failedAt = {};
  static const _failureRetryAfter = Duration(minutes: 10);

  Future<void> _ensureLoaded() async {
    if (_mem != null) return;
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_prefsKey);
    if (raw == null || raw.isEmpty) {
      _mem = {};
      return;
    }
    try {
      final json = jsonDecode(raw) as Map<String, dynamic>;
      final loaded = json.map((k, v) => MapEntry(k, v as String));
      // 옛 버전은 실패 좌표를 빈 문자열로 영구 저장했음 — 로드 시 정리해
      // 일시적 실패가 영구히 굳지 않게.
      loaded.removeWhere((_, v) => v.isEmpty);
      _mem = loaded;
    } catch (_) {
      _mem = {};
    }
  }

  Future<void> _persist() async {
    if (!_persistDirty) return;
    _persistDirty = false;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKey, jsonEncode(_mem ?? const {}));
  }

  /// 좌표를 ~10m 정밀도로 quantize. 4자리 소수점 (위도 ≈ 11m). 같은 셀 안의
  /// 사진들은 같은 라벨 공유 → 캐시 hit률 ↑.
  String _key(double lat, double lng) =>
      '${lat.toStringAsFixed(4)},${lng.toStringAsFixed(4)}';

  /// 동기 lookup — 메모리 캐시에 이미 있으면 라벨 반환, 미로드/miss이면 null.
  /// FutureBuilder의 초기 frame swap 회피용. 위젯이 이 결과를 먼저 사용하고
  /// null이면 [labelFor]로 async 시도.
  String? peek(double lat, double lng) {
    if (_mem == null) return null;
    final v = _mem![_key(lat, lng)];
    if (v == null || v.isEmpty) return null;
    return v;
  }

  /// 좌표에서 사람이 읽는 라벨을 반환. 캐시 hit이면 즉시, miss면 native
  /// reverse geocoder를 호출하고 결과를 영속 저장. 실패 시 null.
  Future<String?> labelFor(double lat, double lng) async {
    await _ensureLoaded();
    final key = _key(lat, lng);
    final cached = _mem![key];
    if (cached != null && cached.isNotEmpty) return cached;
    // 최근 실패한 좌표는 TTL 동안 재호출하지 않음. 단 영구 캐시가 아니라
    // 일시적 실패면 TTL 후·앱 재시작 시 다시 시도된다.
    final failedAt = _failedAt[key];
    if (failedAt != null &&
        DateTime.now().millisecondsSinceEpoch - failedAt <
            _failureRetryAfter.inMilliseconds) {
      return null;
    }
    final pending = _inflight[key];
    if (pending != null) return pending;

    final future = _resolve(lat, lng).then((label) {
      _inflight.remove(key);
      if (label != null && label.isNotEmpty) {
        _mem![key] = label;
        _persistDirty = true;
        // ignore: discarded_futures
        _persist();
      } else {
        // 실패는 메모리에만 짧게 마킹 — 영구 저장하지 않는다.
        _failedAt[key] = DateTime.now().millisecondsSinceEpoch;
      }
      return label;
    });
    _inflight[key] = future;
    return future;
  }

  Future<String?> _resolve(double lat, double lng) async {
    try {
      final placemarks = await placemarkFromCoordinates(lat, lng);
      if (placemarks.isEmpty) return null;
      final p = placemarks.first;
      return _format(p);
    } catch (_) {
      return null;
    }
  }

  /// Placemark의 의미있는 필드를 짧고 자연스럽게 조합.
  ///
  /// 우선순위: locality(시/구) > subAdministrativeArea > administrativeArea
  /// + country (해외일 때만). 너무 길어지지 않게 최대 2~3개 필드만.
  String? _format(Placemark p) {
    final parts = <String>[];

    // 가장 작은 단위(가까운 곳) 먼저 — 동/리/지구
    final sublocal = p.subLocality;
    if (sublocal != null && sublocal.isNotEmpty) parts.add(sublocal);

    // 시/구
    final local = p.locality;
    if (local != null && local.isNotEmpty && local != sublocal) {
      parts.add(local);
    }

    // 시·도. KR 기준 광역시는 locality와 같을 수 있어 중복 제거.
    final admin = p.administrativeArea;
    if (admin != null &&
        admin.isNotEmpty &&
        admin != local &&
        admin != sublocal) {
      parts.add(admin);
    }

    // 해외(다른 나라)일 때만 country 추가. iOS는 Korea면 country='Republic of
    // Korea' 또는 '대한민국' — 너무 길어 KR이면 생략.
    final country = p.country;
    final isoCode = p.isoCountryCode?.toUpperCase();
    if (country != null && country.isNotEmpty && isoCode != 'KR') {
      parts.add(country);
    }

    if (parts.isEmpty) return null;
    return parts.join(', ');
  }
}

final locationLabelCacheProvider = Provider<LocationLabelCache>((ref) {
  return LocationLabelCache();
});
