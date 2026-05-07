import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../home/models/scene.dart';

/// `scenes` 테이블 read/write Repository. RLS가 active couple 멤버만 INSERT/UPDATE
/// 허용하므로 클라이언트는 그냥 query만 보내면 됨.
class SceneRepository {
  SceneRepository(this._client);

  final SupabaseClient _client;

  /// `pair_id` 기준 scene 리스트. position 오름차순 (= 사용자 편집 순서).
  ///
  /// `scene_summary` 뷰를 읽어 type별 count도 함께 받음 → `Scene.media`가
  /// 진짜 데이터로 채워짐. cover_storage_path가 있는 scene은 1시간 짜리
  /// signed URL을 함께 받아 `Scene.coverImageUrl`로 채움. 없는 scene은
  /// 빈 문자열.
  Future<List<Scene>> listByPair(String pairId) async {
    final rows = await _client
        .from('scene_summary')
        .select()
        .eq('pair_id', pairId)
        .order('position', ascending: true);
    final scenes = <Scene>[];
    for (final row in (rows as List).cast<Map<String, dynamic>>()) {
      final coverPath = row['cover_storage_path'] as String?;
      String url = '';
      if (coverPath != null && coverPath.isNotEmpty) {
        try {
          url = await _client.storage
              .from('scene_media')
              .createSignedUrl(coverPath, 86400);
        } catch (_) {
          // signed URL 실패 시 빈 문자열로 fallback — 카드는 colored box로 표시.
        }
      }
      // 뷰는 scene_id로 키를 노출 → Scene.fromJson은 'id' 키를 기대하므로
      // 매핑해서 넘김.
      final mapped = <String, dynamic>{
        'id': row['scene_id'],
        'number': row['number'],
        'position': row['position'],
        'title': row['title'],
        'dates': row['dates'],
        'created_by': row['created_by'],
      };
      final media = SceneMediaCounts(
        photos: (row['photos_count'] as num?)?.toInt() ?? 0,
        films: (row['films_count'] as num?)?.toInt() ?? 0,
        music: (row['musics_count'] as num?)?.toInt() ?? 0,
        places: (row['places_count'] as num?)?.toInt() ?? 0,
      );
      scenes.add(Scene.fromJson(mapped, coverImageUrl: url, media: media));
    }
    return scenes;
  }

  /// 생성된 scene의 cover image를 `upload-scene-cover` Edge Function 경유로 업로드.
  /// 반환: scene_media path와 1시간 signed URL.
  Future<({String storagePath, String signedUrl})> uploadCover({
    required String sceneId,
    required File file,
  }) async {
    final bytes = await file.readAsBytes();
    final response = await _client.functions.invoke(
      'upload-scene-cover',
      body: bytes,
      headers: {
        'Content-Type': 'image/jpeg',
        'X-Scene-Id': sceneId,
      },
    );
    final data = response.data;
    if (data is! Map<String, dynamic>) {
      throw StateError('upload-scene-cover unexpected payload: $data');
    }
    final path = data['storage_path'] as String?;
    final signed = data['signed_url'] as String?;
    if (path == null || signed == null) {
      throw StateError('upload-scene-cover missing fields: $data');
    }
    return (storagePath: path, signedUrl: signed);
  }

  /// 새 scene 생성. number/position은 trigger가 자동 부여.
  Future<Scene> create({
    required String pairId,
    required String title,
    required List<DateTime> dates,
  }) async {
    final myId = _client.auth.currentUser?.id;
    if (myId == null) {
      throw StateError('Cannot create scene while signed out.');
    }
    final inserted = await _client
        .from('scenes')
        .insert({
          'pair_id': pairId,
          'title': title,
          'dates': dates
              .map((d) =>
                  '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}')
              .toList(),
          'created_by': myId,
        })
        .select()
        .single();
    return Scene.fromJson(inserted);
  }

  /// title/dates 등 메타 업데이트. number/position/pair_id는 immutable이라 못 바꿈.
  Future<Scene> update({
    required String id,
    String? title,
    List<DateTime>? dates,
  }) async {
    final patch = <String, dynamic>{};
    if (title != null) patch['title'] = title;
    if (dates != null) {
      patch['dates'] = dates
          .map((d) =>
              '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}')
          .toList();
    }
    if (patch.isEmpty) {
      // 변경 없음 — 현재 row 그대로 반환.
      final row = await _client
          .from('scenes')
          .select()
          .eq('id', id)
          .single();
      return Scene.fromJson(row);
    }
    final updated = await _client
        .from('scenes')
        .update(patch)
        .eq('id', id)
        .select()
        .single();
    return Scene.fromJson(updated);
  }

  /// 드래그 정렬 후 새 순서를 일괄 반영. UI에서 정렬 변경 시 호출.
  ///
  /// upsert 대신 개별 UPDATE를 병렬 실행 — upsert는 RLS의 INSERT 정책까지
  /// 통과해야 하는데 그 정책이 `created_by = auth.uid()`라 파트너가 만든
  /// scene을 reorder할 때 막힌다. UPDATE 정책은 active pair member 누구나
  /// 허용하므로 순수 UPDATE만 쓰면 통과.
  ///
  /// `number`도 같이 업데이트 — 사용자 멘탈 모델은 "scene number = order"라
  /// position과 number를 동기화. 트리거의 number immutability와 (pair_id,
  /// number) unique 제약은 0022 마이그레이션에서 풀어둠.
  Future<void> reorder(List<({String id, int position})> updates) async {
    if (updates.isEmpty) return;
    await Future.wait([
      for (final u in updates)
        _client
            .from('scenes')
            .update({'position': u.position, 'number': u.position})
            .eq('id', u.id),
    ]);
  }

  Future<void> delete(String id) async {
    await _client.from('scenes').delete().eq('id', id);
  }
}

final sceneRepositoryProvider = Provider<SceneRepository>((ref) {
  return SceneRepository(Supabase.instance.client);
});
