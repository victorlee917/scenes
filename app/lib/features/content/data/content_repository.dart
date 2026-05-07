import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../main.dart' show supabaseUrl;
import '../../home/models/place_hit.dart';
import '../../home/models/spotify_hit.dart';
import '../../home/models/tmdb_film.dart';
import '../models/content.dart';

/// `contents` 테이블 read + photo 업로드 전용 Repository.
///
/// 업로드는 `upload-photo-content` Edge Function 경유 — service-role로
/// scene_media 버킷에 full+thumb 두 변형을 한 번에 올리고 contents row까지
/// insert한다. 클라이언트가 직접 storage에 못 쓰는 publishable-key 이슈
/// (memory: project_supabase_keys) 우회 + transactional insertion이 목적.
class ContentRepository {
  ContentRepository(this._client);

  final SupabaseClient _client;

  /// 한 scene의 contents 개수만 조회 — pre-flight 한도 체크용. row를 가져오지
  /// 않고 head count만 받아 latency·payload 절약. RLS는 select 정책이라
  /// 페어 멤버에게만 보임.
  Future<int> countByScene(String sceneId) async {
    final response = await _client
        .from('contents')
        .count(CountOption.exact)
        .eq('scene_id', sceneId);
    return response;
  }

  /// 한 scene의 contents 전부 + 각 photo의 full/thumb signed URL.
  /// position 오름차순. row 별 hydrate(URL signing)는 `Future.wait`으로 병렬
  /// 처리 — 50장 photo면 100번의 createSignedUrl이 순차로 돌면 ~20s 걸리던
  /// 게 동시 발행으로 ~수백ms 수준이 됨.
  Future<List<Content>> listByScene(String sceneId) async {
    final rows = await _client
        .from('contents')
        .select()
        .eq('scene_id', sceneId)
        .order('position', ascending: true);
    final bases = (rows as List)
        .cast<Map<String, dynamic>>()
        .map(Content.fromJson)
        .toList(growable: false);
    return Future.wait(bases.map(_hydrateUrls));
  }

  /// type별 cached storage 객체에 대해 signed URL을 채움. photo는 full+thumb
  /// 두 변형, film은 단일 poster. music은 Spotify CDN URL을 payload에서 직접
  /// 슬롯에 채워 grid 위젯이 type 분기 없이 동일 ProgressivePhoto 인터페이스로
  /// 사용. place(MapBox)는 추후 동일 패턴 추가.
  Future<Content> _hydrateUrls(Content content) async {
    if (content.type == 'photo') {
      return _hydratePhotoUrls(content);
    }
    if (content.type == 'film') {
      return _hydrateFilmUrls(content);
    }
    if (content.type == 'music') {
      // Spotify CDN URL은 signing 없음 — payload에서 그대로 슬롯 채움.
      // album_art_url은 TOS상 우리 쪽 캐싱 금지라 영구히 외부 URL.
      final url = content.payload['album_art_url'] as String?;
      return content.copyWith(fullSignedUrl: url, thumbSignedUrl: url);
    }
    if (content.type == 'place') {
      return _hydratePlaceUrls(content);
    }
    return content;
  }

  /// Place 정적지도는 scene_media에 캐싱(MapBox TOS 허용) — signed URL 발급.
  /// 옛 row(캐싱 실패)는 storage_path null이라 슬롯도 null.
  Future<Content> _hydratePlaceUrls(Content content) async {
    final cachedPath =
        content.payload['mapbox_static_storage_path'] as String?;
    String? url;
    if (cachedPath != null && cachedPath.isNotEmpty) {
      try {
        url = await _client.storage
            .from('scene_media')
            .createSignedUrl(cachedPath, 86400);
      } catch (_) {}
    }
    return content.copyWith(fullSignedUrl: url, thumbSignedUrl: url);
  }

  Future<Content> _hydratePhotoUrls(Content content) async {
    final fullPath = content.storagePath;
    final thumbPath = content.thumbPath;
    // full/thumb 두 개를 동시에 발행 — 한쪽 실패해도 다른 쪽은 살리려고
    // 각자 try/catch로 감싸 null fallback. Future.wait는 한쪽 throw하면 전체
    // throw라 안 쓰고 평이하게 두 await을 병행 시작 후 합류.
    Future<String?> sign(String? path) async {
      if (path == null || path.isEmpty) return null;
      try {
        return await _client.storage
            .from('scene_media')
            .createSignedUrl(path, 86400);
      } catch (_) {
        return null;
      }
    }

    final results = await Future.wait([
      sign(fullPath),
      sign(thumbPath),
    ]);
    return content.copyWith(
      fullSignedUrl: results[0],
      thumbSignedUrl: results[1],
    );
  }

  /// film은 단일 poster 변형만 캐싱. 캐싱된 path가 있으면 signed URL,
  /// 없으면 payload의 poster_source_url(TMDB CDN)을 fallback으로 둠 — 옛 row나
  /// 캐싱 실패 케이스 대비. 둘 다 fullSignedUrl/thumbSignedUrl 슬롯에 동일하게
  /// 넣어 grid에서 photo와 같은 ProgressivePhoto 인터페이스로 사용 가능.
  Future<Content> _hydrateFilmUrls(Content content) async {
    final cachedPath = content.payload['poster_storage_path'] as String?;
    final sourceUrl = content.payload['poster_source_url'] as String?;
    String? url;
    if (cachedPath != null && cachedPath.isNotEmpty) {
      try {
        url = await _client.storage
            .from('scene_media')
            .createSignedUrl(cachedPath, 86400);
      } catch (_) {}
    }
    url ??= sourceUrl;
    return content.copyWith(
      fullSignedUrl: url,
      thumbSignedUrl: url,
    );
  }

  /// photo content 한 장 업로드. EF가 storage 두 객체 + contents row 모두
  /// 책임지므로 호출자는 결과 Content만 받는다.
  ///
  /// [client]를 주입하면 호출자가 `client.close()`로 in-flight HTTP 요청을
  /// abort 가능 — picker의 batch upload 취소에 사용. 주입 안 하면 내부에서
  /// 일회용 client를 만들고 finally에서 close.
  Future<Content> uploadPhoto({
    required String sceneId,
    required Uint8List fullBytes,
    required Uint8List thumbBytes,
    required Map<String, dynamic> payloadMeta,
    DateTime? occurredAt,
    http.Client? client,
  }) async {
    final session = _client.auth.currentSession;
    final accessToken = session?.accessToken;
    if (accessToken == null) {
      throw StateError('Not signed in.');
    }
    final url = Uri.parse(
      '$supabaseUrl/functions/v1/upload-photo-content',
    );
    final request = http.MultipartRequest('POST', url);
    request.headers['Authorization'] = 'Bearer $accessToken';
    request.fields['scene_id'] = sceneId;
    request.fields['payload'] = jsonEncode(payloadMeta);
    if (occurredAt != null) {
      // 사용자가 명시적으로 고른 날짜. EF가 payload.taken_at(EXIF)보다 우선.
      request.fields['occurred_at'] = occurredAt.toIso8601String();
    }
    request.files.add(
      http.MultipartFile.fromBytes(
        'full',
        fullBytes,
        filename: 'full.jpg',
        contentType: MediaType('image', 'jpeg'),
      ),
    );
    request.files.add(
      http.MultipartFile.fromBytes(
        'thumb',
        thumbBytes,
        filename: 'thumb.jpg',
        contentType: MediaType('image', 'jpeg'),
      ),
    );

    final injected = client != null;
    final c = client ?? http.Client();
    try {
      final streamed = await c.send(request);
      final body = await streamed.stream.bytesToString();
      if (streamed.statusCode != 200) {
        throw StateError(
          'upload-photo-content ${streamed.statusCode}: $body',
        );
      }
      final json = jsonDecode(body) as Map<String, dynamic>;
      final base = Content.fromJson(json['content'] as Map<String, dynamic>);
      return base.copyWith(
        fullSignedUrl: json['full_signed_url'] as String?,
        thumbSignedUrl: json['thumb_signed_url'] as String?,
      );
    } finally {
      if (!injected) c.close();
    }
  }

  /// film content 추가. EF가 TMDB CDN에서 w780 poster를 pull → scene_media에
  /// 캐싱 → contents row insert까지 처리. 클라이언트는 메타데이터만 보냄.
  /// signed URL은 photo와 동일하게 fullSignedUrl/thumbSignedUrl 슬롯 둘 다에
  /// 넣어 grid 위젯이 type 분기 없이 동일한 progressive 위젯으로 표시 가능.
  Future<Content> uploadFilm({
    required String sceneId,
    required TmdbFilm film,
    DateTime? occurredAt,
  }) async {
    final session = _client.auth.currentSession;
    final accessToken = session?.accessToken;
    if (accessToken == null) {
      throw StateError('Not signed in.');
    }
    final url = Uri.parse(
      '$supabaseUrl/functions/v1/tmdb-poster-cache',
    );
    final yearInt =
        film.year != null ? int.tryParse(film.year!) : null;
    final response = await http.post(
      url,
      headers: {
        'Authorization': 'Bearer $accessToken',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'scene_id': sceneId,
        'tmdb_id': film.tmdbId,
        'media_type': film.mediaType,
        'title': film.title,
        'release_year': yearInt,
        'director': film.director,
        'genres': film.genres,
        'runtime': film.runtime,
        'overview': film.overview,
        'poster_path': film.posterPath,
        if (occurredAt != null)
          'occurred_at': occurredAt.toIso8601String(),
      }),
    );
    if (response.statusCode != 200) {
      throw StateError(
        'tmdb-poster-cache ${response.statusCode}: ${response.body}',
      );
    }
    final json = jsonDecode(response.body) as Map<String, dynamic>;
    final base = Content.fromJson(json['content'] as Map<String, dynamic>);
    final posterUrl = json['poster_signed_url'] as String? ??
        // EF 캐싱 실패해도 source_url로 fallback 가능.
        (base.payload['poster_source_url'] as String?);
    return base.copyWith(
      fullSignedUrl: posterUrl,
      thumbSignedUrl: posterUrl,
    );
  }

  /// music content 추가. Spotify TOS상 album art/메타데이터의 standalone
  /// 캐싱 금지라 EF 거치지 않고 payload만 contents에 직접 insert. RLS가
  /// pair member + active couple 체크 → 권한 OK.
  ///
  /// album_art_url은 Spotify CDN URL을 그대로 보관 (캐싱 X). 표시할 때 외부
  /// URL로 직접 로드. 링크백 의무는 grid 타일의 Spotify 배지로 충족.
  Future<Content> uploadMusic({
    required String sceneId,
    required SpotifyHit hit,
    DateTime? occurredAt,
  }) async {
    final myId = _client.auth.currentUser?.id;
    if (myId == null) {
      throw StateError('Not signed in.');
    }
    final payload = <String, dynamic>{
      'service': 'spotify',
      'external_id': hit.id,
      'kind': hit.kind,
      'title': hit.title,
      'artist': hit.artist,
      'album': hit.album,
      'year': hit.year,
      'album_art_url': hit.coverUrl,
      'spotify_uri': hit.spotifyUri,
      'external_url': hit.externalUrl,
    };
    final inserted = await _client
        .from('contents')
        .insert({
          'scene_id': sceneId,
          'type': 'music',
          'payload': payload,
          'created_by': myId,
          'occurred_at': occurredAt?.toIso8601String(),
        })
        .select()
        .single();
    final base = Content.fromJson(inserted);
    final url = hit.coverUrl;
    return base.copyWith(fullSignedUrl: url, thumbSignedUrl: url);
  }

  /// 현재 유저가 좋아요를 누른 contents의 id 집합. content_likes 테이블에서
  /// (user_id = me, content_id IN (...)) 조회. 빈 입력은 빈 결과 즉시 반환.
  Future<Set<String>> myLikesForContentIds(Iterable<String> contentIds) async {
    final myId = _client.auth.currentUser?.id;
    if (myId == null || contentIds.isEmpty) return const {};
    final rows = await _client
        .from('content_likes')
        .select('content_id')
        .eq('user_id', myId)
        .inFilter('content_id', contentIds.toList(growable: false));
    return (rows as List)
        .cast<Map<String, dynamic>>()
        .map((r) => r['content_id'] as String)
        .toSet();
  }

  /// content 삭제. RLS가 author + active couple 체크하므로 클라가 row만
  /// 지우면 됨. scene_media의 연관 객체(full/thumb/poster/map)는 storage
  /// orphan으로 남으나 빈도 낮고 추후 cleanup으로 정리.
  Future<void> deleteContent(String contentId) async {
    await _client.from('contents').delete().eq('id', contentId);
  }

  /// 작성자가 사후에 moment date를 수정. RLS는 created_by = auth.uid() 인 row만
  /// update 허용 — 클라이언트 가드는 단순 UX(작성자에만 탭 활성화)고 권한 강제는
  /// 정책에서 보장됨.
  Future<void> updateOccurredAt(String contentId, DateTime occurredAt) async {
    await _client
        .from('contents')
        .update({'occurred_at': occurredAt.toIso8601String()})
        .eq('id', contentId);
  }

  /// like 토글. RPC가 한 round-trip으로 INSERT/DELETE 결정하고 `true`(이제
  /// 좋아요 됨) 또는 `false`(취소됨)를 반환.
  Future<bool> toggleLike(String contentId) async {
    final result = await _client.rpc(
      'toggle_content_like',
      params: {'p_content_id': contentId},
    );
    return result == true;
  }

  /// place content 추가. EF가 MapBox token으로 정적지도 PNG 받아 scene_media에
  /// 캐싱하고 contents row까지 insert. 클라는 좌표 + 메타만 넘김.
  Future<Content> uploadPlace({
    required String sceneId,
    required PlaceHit place,
    DateTime? occurredAt,
  }) async {
    final session = _client.auth.currentSession;
    final accessToken = session?.accessToken;
    if (accessToken == null) {
      throw StateError('Not signed in.');
    }
    final url = Uri.parse(
      '$supabaseUrl/functions/v1/mapbox-static-cache',
    );
    final response = await http.post(
      url,
      headers: {
        'Authorization': 'Bearer $accessToken',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'scene_id': sceneId,
        'external_id': place.id,
        'name': place.name,
        'region': place.region,
        'country': place.country,
        'address': place.fullAddress,
        'lat': place.lat,
        'lng': place.lng,
        if (occurredAt != null)
          'occurred_at': occurredAt.toIso8601String(),
      }),
    );
    if (response.statusCode != 200) {
      throw StateError(
        'mapbox-static-cache ${response.statusCode}: ${response.body}',
      );
    }
    final json = jsonDecode(response.body) as Map<String, dynamic>;
    final base = Content.fromJson(json['content'] as Map<String, dynamic>);
    final mapUrl = json['map_signed_url'] as String?;
    return base.copyWith(fullSignedUrl: mapUrl, thumbSignedUrl: mapUrl);
  }
}

final contentRepositoryProvider = Provider<ContentRepository>((ref) {
  return ContentRepository(Supabase.instance.client);
});
