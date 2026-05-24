import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'contents_view_model.dart';
import 'data/content_repository.dart';
import 'models/reaction.dart';

/// 한 scene의 contents에 달린 모든 리액션 (나 + 파트너).
///
/// `Map<contentId, List<Reaction>>`로 들고 있어 각 content가 자기 reaction을
/// 빠르게 lookup 가능. 보통 List 길이는 0~2 (커플 둘만 reactor).
///
/// 변경(set/remove)은 optimistic — 즉시 state 업데이트, 서버 결과로 reconcile.
class ReactionsForSceneViewModel
    extends FamilyAsyncNotifier<Map<String, List<Reaction>>, String> {
  @override
  Future<Map<String, List<Reaction>>> build(String sceneId) async {
    final contents = await ref.watch(contentsForSceneProvider(sceneId).future);
    if (contents.isEmpty) return const {};
    final reactions = await ref
        .read(contentRepositoryProvider)
        .reactionsForContentIds(contents.map((c) => c.id));
    return _group(reactions);
  }

  /// 리액션 set/edit. emoji는 [ReactionEmojis.all] 중 하나, comment는 HD pair
  /// 에서만 의미있는 값. server-side 트리거가 free pair의 comment를 reject.
  Future<void> setMyReaction({
    required String userId,
    required String contentId,
    required String emoji,
    String? comment,
  }) async {
    final previous = state.valueOrNull ?? const {};
    // optimistic — 같은 contentId의 본인 row를 새 reaction으로 교체.
    final next = Map<String, List<Reaction>>.from(previous);
    final list = List<Reaction>.from(next[contentId] ?? const []);
    list.removeWhere((r) => r.userId == userId);
    list.add(Reaction(
      userId: userId,
      contentId: contentId,
      emoji: emoji,
      comment: (comment != null && comment.isNotEmpty) ? comment : null,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    ));
    next[contentId] = list;
    state = AsyncValue.data(next);

    try {
      final saved = await ref.read(contentRepositoryProvider).setReaction(
            contentId: contentId,
            emoji: emoji,
            comment: comment,
          );
      // 서버가 normalize한 결과로 재정합 (예: 빈 comment → null).
      final current = Map<String, List<Reaction>>.from(
        state.valueOrNull ?? const {},
      );
      final updatedList = List<Reaction>.from(current[contentId] ?? const []);
      updatedList.removeWhere((r) => r.userId == userId);
      updatedList.add(saved);
      current[contentId] = updatedList;
      state = AsyncValue.data(current);
    } catch (e, st) {
      state = AsyncValue.data(previous);
      Error.throwWithStackTrace(e, st);
    }
  }

  /// 본인 리액션 제거.
  Future<void> removeMyReaction({
    required String userId,
    required String contentId,
  }) async {
    final previous = state.valueOrNull ?? const {};
    final next = Map<String, List<Reaction>>.from(previous);
    final list = List<Reaction>.from(next[contentId] ?? const []);
    list.removeWhere((r) => r.userId == userId);
    if (list.isEmpty) {
      next.remove(contentId);
    } else {
      next[contentId] = list;
    }
    state = AsyncValue.data(next);

    try {
      await ref.read(contentRepositoryProvider).removeReaction(contentId);
    } catch (e, st) {
      state = AsyncValue.data(previous);
      Error.throwWithStackTrace(e, st);
    }
  }

  Map<String, List<Reaction>> _group(List<Reaction> reactions) {
    final result = <String, List<Reaction>>{};
    for (final r in reactions) {
      result.putIfAbsent(r.contentId, () => []).add(r);
    }
    return result;
  }
}

final reactionsForSceneProvider = AsyncNotifierProviderFamily<
    ReactionsForSceneViewModel,
    Map<String, List<Reaction>>,
    String>(
  ReactionsForSceneViewModel.new,
);
