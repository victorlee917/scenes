import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'contents_view_model.dart';
import 'data/content_repository.dart';

/// 한 scene의 contents 중 **현재 유저가 좋아요한 content_id 집합**.
///
/// scene 단위로 family를 두어 다른 scene 진입 시 자동 분리·캐싱. UI는
/// `state.valueOrNull?.contains(contentId)`로 좋아요 여부 즉시 read하고,
/// `toggle(contentId)`로 optimistic flip + RPC 호출.
class MyLikesForSceneViewModel
    extends FamilyAsyncNotifier<Set<String>, String> {
  @override
  Future<Set<String>> build(String sceneId) async {
    // contents가 로드돼야 그들의 id로 likes를 좁혀서 조회 가능.
    final contents = await ref.watch(contentsForSceneProvider(sceneId).future);
    if (contents.isEmpty) return const {};
    return ref
        .read(contentRepositoryProvider)
        .myLikesForContentIds(contents.map((c) => c.id));
  }

  /// optimistic 토글 — 즉시 UI에 반영하고 RPC가 끝나면 서버 결과로 reconcile.
  /// 실패 시 이전 상태로 revert. 다른 scene의 likes provider엔 영향 없음.
  Future<void> toggle(String contentId) async {
    final previous = state.valueOrNull ?? const <String>{};
    final next = Set<String>.from(previous);
    if (next.contains(contentId)) {
      next.remove(contentId);
    } else {
      next.add(contentId);
    }
    state = AsyncValue<Set<String>>.data(next);

    try {
      final isNowLiked = await ref
          .read(contentRepositoryProvider)
          .toggleLike(contentId);
      // RPC 결과로 다시 한 번 정합. 사이에 다른 toggle이 끼어들었을 수도 있어
      // 현재 state 기준으로 contentId만 정정.
      final current = Set<String>.from(state.valueOrNull ?? const {});
      if (isNowLiked) {
        current.add(contentId);
      } else {
        current.remove(contentId);
      }
      state = AsyncValue<Set<String>>.data(current);
    } catch (e, st) {
      state = AsyncValue<Set<String>>.data(previous);
      // 호출자가 토스트 등 띄울 수 있게 그대로 throw.
      Error.throwWithStackTrace(e, st);
    }
  }
}

final myLikesForSceneProvider = AsyncNotifierProviderFamily<
    MyLikesForSceneViewModel, Set<String>, String>(
  MyLikesForSceneViewModel.new,
);
