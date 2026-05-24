import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/data/signed_url_cache.dart';
import '../../../main.dart' show supabaseUrl;
import '../../home/models/place_hit.dart';
import '../../home/models/spotify_hit.dart';
import '../../home/models/tmdb_film.dart';
import '../models/content.dart';
import '../models/reaction.dart';

/// `contents` 테이블 read + photo 업로드 전용 Repository.
///
/// 업로드는 `upload-photo-content` Edge Function 경유 — service-role로
/// scene_media 버킷에 full+thumb 두 변형을 한 번에 올리고 contents row까지
/// insert한다. 클라이언트가 직접 storage에 못 쓰는 publishable-key 이슈
/// (memory: project_supabase_keys) 우회 + transactional insertion이 목적.
class ContentRepository {
  ContentRepository(this._client, this._urlCache);

  final SupabaseClient _client;
  final SignedUrlCache _urlCache;

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
  /// 옛 row(캐싱 실패)는 storage_path null이라 슬롯도 null. SignedUrlCache가
  /// 7d TTL로 URL 재사용 → 같은 URL = Smart CDN cache hit.
  Future<Content> _hydratePlaceUrls(Content content) async {
    final cachedPath =
        content.payload['mapbox_static_storage_path'] as String?;
    final url = cachedPath == null
        ? null
        : await _urlCache.getOrSign(cachedPath);
    return content.copyWith(fullSignedUrl: url, thumbSignedUrl: url);
  }

  Future<Content> _hydratePhotoUrls(Content content) async {
    final fullPath = content.storagePath;
    final thumbPath = content.thumbPath;
    // full/thumb 두 개를 동시에 발행. 캐시 hit이면 origin 호출 없이 즉시
    // 반환되고, miss이면 SignedUrlCache가 createSignedUrl 호출 + 영속 저장.
    final results = await Future.wait([
      _urlCache.getOrSign(fullPath ?? ''),
      _urlCache.getOrSign(thumbPath ?? ''),
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
    final url = (cachedPath != null && cachedPath.isNotEmpty)
        ? await _urlCache.getOrSign(cachedPath) ?? sourceUrl
        : sourceUrl;
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
        filename: 'full.webp',
        contentType: MediaType('image', 'webp'),
      ),
    );
    request.files.add(
      http.MultipartFile.fromBytes(
        'thumb',
        thumbBytes,
        filename: 'thumb.webp',
        contentType: MediaType('image', 'webp'),
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

  /// content 삭제. RLS가 author + active couple 체크해 row 권한 보장.
  /// 더불어 storage 객체(full/thumb/poster/map)도 best-effort로 함께 제거 →
  /// orphan 누적 방지(시간이 갈수록 storage 비용 증가). 다음 흐름:
  ///   1. 메모리의 [content].payload에서 storage path 추출 (재조회 없음)
  ///   2. row delete (RLS 통과해야 storage 삭제 의미 있음)
  ///   3. storage objects 삭제 (실패는 swallow — row는 이미 삭제됐으니 UX는 OK)
  ///   4. SignedUrlCache invalidate — stale URL을 다른 곳에서 hit하지 않게
  Future<void> deleteContent(Content content) async {
    // payload에서 type별 storage path 후보들 추출 — 호출자가 이미 들고 있는
    // Content를 그대로 쓰므로 삭제 전 별도 SELECT가 필요 없다.
    final payload = content.payload;
    final paths = <String>[
      for (final key in const [
        'storage_path', // photo full
        'thumb_path', // photo thumb
        'poster_storage_path', // film
        'mapbox_static_storage_path', // place
      ])
        if (payload[key] is String && (payload[key] as String).isNotEmpty)
          payload[key] as String,
    ];

    await _client.from('contents').delete().eq('id', content.id);

    if (paths.isEmpty) return;
    try {
      await _client.storage.from('scene_media').remove(paths);
    } catch (_) {
      // best-effort — 실패는 무시. cron prune이 추후 catch하도록 둠.
    }
    // 캐시된 signed URL이 다른 화면에서 hit하지 않도록 정리.
    for (final p in paths) {
      // ignore: discarded_futures
      _urlCache.invalidate(p);
    }
  }

  /// scene 안의 contents 순서 재배열. RPC 한 번으로 position 1..N 일괄 업데이트.
  /// 일반 UPDATE는 created_by = auth.uid() 제약이라 본인이 안 올린 콘텐츠
  /// position을 못 바꿈 — RPC가 active couple 멤버 권한 체크 후 service
  /// definer로 일괄 처리.
  Future<void> reorderContents({
    required String sceneId,
    required List<String> orderedIds,
  }) async {
    if (orderedIds.isEmpty) return;
    await _client.rpc(
      'reorder_scene_contents',
      params: {
        'p_scene_id': sceneId,
        'p_ordered_ids': orderedIds,
      },
    );
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

  /// scene 안의 모든 contents에 달린 반응(나 + 파트너)을 한 번에 조회.
  /// `(user_id, content_id)` PK니까 contents id로 in-filter 후 client에서
  /// content별로 그룹핑해 사용.
  Future<List<Reaction>> reactionsForContentIds(Iterable<String> ids) async {
    final list = ids.toList(growable: false);
    if (list.isEmpty) return const [];
    final rows = await _client
        .from('content_reactions')
        .select()
        .inFilter('content_id', list);
    return (rows as List)
        .cast<Map<String, dynamic>>()
        .map(Reaction.fromJson)
        .toList(growable: false);
  }

  /// 본인 반응 upsert. 같은 (user_id, content_id) row가 있으면 emoji/comment
  /// 갱신. comment는 HD pair에서만 비어있지 않게 저장 가능 — free pair에서
  /// comment를 보내면 DB 트리거가 reject (P0001).
  ///
  /// 클라가 free일 땐 comment를 null로 보내고, HD일 땐 옵션. 빈 문자열은 트리거
  /// 가 null로 normalize.
  Future<Reaction> setReaction({
    required String contentId,
    required String emoji,
    String? comment,
  }) async {
    final myId = _client.auth.currentUser?.id;
    if (myId == null) {
      throw StateError('Not signed in.');
    }
    final inserted = await _client
        .from('content_reactions')
        .upsert({
          'user_id': myId,
          'content_id': contentId,
          'emoji': emoji,
          'comment': comment,
        }, onConflict: 'user_id,content_id')
        .select()
        .single();
    return Reaction.fromJson(inserted);
  }

  /// 본인 반응 제거. 없는 row를 삭제해도 무해 (no-op).
  Future<void> removeReaction(String contentId) async {
    final myId = _client.auth.currentUser?.id;
    if (myId == null) return;
    await _client
        .from('content_reactions')
        .delete()
        .eq('user_id', myId)
        .eq('content_id', contentId);
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
  return ContentRepository(
    Supabase.instance.client,
    ref.watch(signedUrlCacheProvider),
  );
});
