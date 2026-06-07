import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// 페어 공유 설정(`pair_shares`) 접근 Repository.
///
/// 공유 닉네임(slug)은 `pair_id` 기준으로 저장된다 — 재페어링에도 공유 URL이
/// 유지되도록(memory: content_keyed_by_pair_id). 쓰기는 active 커플만 가능하며
/// RLS가 강제한다.
class ShareRepository {
  ShareRepository(this._client);

  final SupabaseClient _client;

  String? get _myId => _client.auth.currentUser?.id;

  /// 해당 pair의 현재 공유 닉네임. 미설정이면 null.
  Future<String?> getSlug(String pairId) async {
    final row = await _client
        .from('pair_shares')
        .select('slug')
        .eq('pair_id', pairId)
        .maybeSingle();
    return row?['slug'] as String?;
  }

  /// slug 전역 사용 가능 여부. SELECT RLS가 본인 pair만 보여주므로 전역 중복
  /// 확인은 SECURITY DEFINER RPC로 위임.
  Future<bool> isSlugAvailable(String slug) async {
    final result = await _client.rpc(
      'share_slug_available',
      params: {'p_slug': slug.toLowerCase()},
    );
    return result as bool;
  }

  /// 특정 scene의 공유 대상 콘텐츠를 일괄 설정. [sharedIds]에 든 콘텐츠만
  /// shared=true, 같은 scene의 나머지는 false. active 페어 멤버 누구나 호출
  /// 가능(RPC가 권한 체크).
  Future<void> setSceneSharedContents({
    required String sceneId,
    required Set<String> sharedIds,
  }) async {
    await _client.rpc(
      'set_scene_shared_contents',
      params: {
        'p_scene_id': sceneId,
        'p_shared_ids': sharedIds.toList(),
      },
    );
  }

  /// pair의 공유 닉네임을 설정/변경. pair_id 충돌 시 update(upsert).
  ///
  /// slug가 다른 pair와 충돌하면 unique 위반(23505)을 [SlugTakenException]으로
  /// 변환. 형식 위반(check 23514)은 [SlugInvalidException]으로 변환.
  Future<void> setSlug({
    required String pairId,
    required String slug,
  }) async {
    final myId = _myId;
    if (myId == null) {
      throw StateError('Cannot set slug while signed out.');
    }
    final normalized = slug.trim().toLowerCase();
    try {
      await _client.from('pair_shares').upsert(
        {
          'pair_id': pairId,
          'slug': normalized,
          'created_by': myId,
        },
        onConflict: 'pair_id',
      );
    } on PostgrestException catch (e) {
      if (e.code == '23505') throw const SlugTakenException();
      if (e.code == '23514') throw const SlugInvalidException();
      rethrow;
    }
  }
}

/// 이미 다른 커플이 사용 중인 닉네임.
class SlugTakenException implements Exception {
  const SlugTakenException();
}

/// 형식에 맞지 않는 닉네임(길이/허용 문자 위반).
class SlugInvalidException implements Exception {
  const SlugInvalidException();
}

final shareRepositoryProvider = Provider<ShareRepository>((ref) {
  return ShareRepository(Supabase.instance.client);
});
