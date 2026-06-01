import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'data/content_repository.dart';
import 'models/content.dart';

/// 한 scene의 contents를 관리. sceneId로 family 분리 — 다른 scene에 영향 없게.
///
/// 업로드 후 호출자는 [appendUploaded]로 새 row를 끼워 넣어 즉시 grid에 반영.
/// 또는 단순히 `ref.invalidate(contentsForSceneProvider(sceneId))`로 refetch.
class ContentsForSceneViewModel
    extends FamilyAsyncNotifier<List<Content>, String> {
  @override
  Future<List<Content>> build(String sceneId) async {
    return ref.read(contentRepositoryProvider).listByScene(sceneId);
  }

  /// 업로드 직후 받은 Content를 현재 리스트 끝에 append.
  void appendUploaded(Content content) {
    final current = state.valueOrNull ?? const <Content>[];
    state = AsyncValue<List<Content>>.data([...current, content]);
  }

  /// 삭제 직후 in-memory 리스트에서 제거 — 그리드에서 즉시 사라지게.
  void removeContent(String contentId) {
    final current = state.valueOrNull ?? const <Content>[];
    state = AsyncValue<List<Content>>.data(
      current.where((c) => c.id != contentId).toList(growable: false),
    );
  }

  /// row 내용 일부 변경(예: occurred_at) 반영. 같은 id를 in-place 교체.
  void replaceContent(Content updated) {
    final current = state.valueOrNull ?? const <Content>[];
    state = AsyncValue<List<Content>>.data(
      current
          .map((c) => c.id == updated.id ? updated : c)
          .toList(growable: false),
    );
  }

  /// scene 내 모든 contents의 occurred_at을 한 번에 설정 — bulk 날짜 변경 후
  /// in-memory state 동기화. RPC는 호출자가 별도로 실행.
  void replaceAllOccurredAt(DateTime occurredAt) {
    final current = state.valueOrNull ?? const <Content>[];
    state = AsyncValue<List<Content>>.data(
      current
          .map((c) => c.copyWith(occurredAt: occurredAt))
          .toList(growable: false),
    );
  }

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() {
      return ref.read(contentRepositoryProvider).listByScene(arg);
    });
  }

  /// contents 순서 변경 — optimistic으로 즉시 state 갱신 후 RPC. 실패 시
  /// 이전 순서로 revert. 입력 [newOrder]는 화면에 보이는 순서대로의 Content
  /// 리스트.
  Future<void> reorder(List<Content> newOrder) async {
    final previous = state.valueOrNull ?? const <Content>[];
    state = AsyncValue.data(List.unmodifiable(newOrder));

    try {
      await ref.read(contentRepositoryProvider).reorderContents(
            sceneId: arg,
            orderedIds: newOrder.map((c) => c.id).toList(growable: false),
          );
    } catch (e, st) {
      state = AsyncValue.data(previous);
      Error.throwWithStackTrace(e, st);
    }
  }
}

final contentsForSceneProvider = AsyncNotifierProviderFamily<
    ContentsForSceneViewModel, List<Content>, String>(
  ContentsForSceneViewModel.new,
);
