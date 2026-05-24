import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Storage 객체 path → signed URL 매핑을 SharedPreferences에 영속 캐시.
///
/// **동기**: Supabase Smart CDN은 URL 단위로 캐시한다. 매 fetch마다 새
/// signed URL을 발급하면 token이 매번 달라져 cache key가 어긋나고 origin hit
/// 이 누적된다. 같은 path엔 같은 URL을 일정 기간 재사용해 CDN을 활용.
///
/// **TTL**: 발급 시 7일. 캐시 hit 판정엔 1시간 buffer를 둬 만료 직전 토큰을
/// 사용하지 않게(요청 도중 만료 회피).
///
/// **Trade-off**: signed URL은 발급 시 권한이 박힌 bearer token이라 TTL 동안
/// RLS와 무관하게 유효하다. URL이 누설되면 만료까지 접근 가능하므로 보안
/// 모델은 "URL은 사용자 디바이스 안에서만 유통된다"를 전제로 설계됐다.
class SignedUrlCache {
  SignedUrlCache(this._client);

  final SupabaseClient _client;

  static const _prefsKey = 'signed_url_cache_v1';
  static const _bucket = 'scene_media';
  static const _defaultTtl = Duration(days: 7);
  // hit 판정 시 만료 직전(1h 이내)이면 무효 처리.
  static const _hitBuffer = Duration(hours: 1);

  Map<String, _Entry>? _mem;
  bool _persistDirty = false;
  Timer? _persistTimer;

  /// persist를 디바운스 — cold load 시 수십~수백 건의 miss가 매번 전체 맵을
  /// 직렬화하지 않도록 마지막 변경 후 400ms에 한 번만 기록.
  void _schedulePersist() {
    _persistDirty = true;
    _persistTimer?.cancel();
    _persistTimer = Timer(const Duration(milliseconds: 400), () {
      // ignore: discarded_futures
      _persist();
    });
  }

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
      final loaded = <String, _Entry>{};
      json.forEach((k, v) {
        loaded[k] = _Entry.fromJson(v as Map<String, dynamic>);
      });
      // load 시점에 만료 항목 정리 — prefs 비대화 방지.
      final now = DateTime.now().millisecondsSinceEpoch;
      loaded.removeWhere((_, v) => v.expiresAtMs <= now);
      _mem = loaded;
    } catch (_) {
      _mem = {};
    }
  }

  Future<void> _persist() async {
    if (!_persistDirty) return;
    _persistDirty = false;
    final prefs = await SharedPreferences.getInstance();
    final json = <String, dynamic>{
      for (final e in (_mem ?? const {}).entries) e.key: e.value.toJson(),
    };
    await prefs.setString(_prefsKey, jsonEncode(json));
  }

  /// path에 대한 유효한 URL을 반환. 캐시 hit이면 origin 호출 없이 즉시,
  /// miss이거나 만료 임박이면 새로 발급해 캐시. 실패 시 null.
  Future<String?> getOrSign(
    String path, {
    Duration ttl = _defaultTtl,
  }) async {
    if (path.isEmpty) return null;
    await _ensureLoaded();
    final now = DateTime.now();
    final entry = _mem![path];
    if (entry != null &&
        entry.expiresAtMs - _hitBuffer.inMilliseconds >
            now.millisecondsSinceEpoch) {
      return entry.url;
    }
    try {
      final url = await _client.storage
          .from(_bucket)
          .createSignedUrl(path, ttl.inSeconds);
      _mem![path] = _Entry(
        url: url,
        expiresAtMs: now.add(ttl).millisecondsSinceEpoch,
      );
      _schedulePersist();
      return url;
    } catch (_) {
      return null;
    }
  }

  /// 명시적으로 path 항목 제거 — 콘텐츠/scene 삭제 직후 stale URL 정리에 사용.
  Future<void> invalidate(String path) async {
    if (path.isEmpty) return;
    await _ensureLoaded();
    if (_mem!.remove(path) != null) {
      _schedulePersist();
    }
  }
}

class _Entry {
  _Entry({required this.url, required this.expiresAtMs});

  final String url;
  final int expiresAtMs;

  Map<String, dynamic> toJson() => {
        'url': url,
        'expiresAtMs': expiresAtMs,
      };

  static _Entry fromJson(Map<String, dynamic> json) => _Entry(
        url: json['url'] as String,
        expiresAtMs: (json['expiresAtMs'] as num).toInt(),
      );
}

final signedUrlCacheProvider = Provider<SignedUrlCache>((ref) {
  return SignedUrlCache(Supabase.instance.client);
});
