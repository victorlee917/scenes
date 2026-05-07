import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../couple/couple_view_model.dart';
import '../home/models/scene.dart';
import 'data/scene_repository.dart';

/// 현재 active pair의 scene 리스트.
///
/// pair_id가 바뀌면 (페어링/리페어링) 자동 refetch. 미페어링 시 빈 리스트.
class ScenesViewModel extends AsyncNotifier<List<Scene>> {
  @override
  Future<List<Scene>> build() async {
    final pairId = ref.watch(myActivePairIdProvider);
    if (pairId == null) return const [];
    return ref.read(sceneRepositoryProvider).listByPair(pairId);
  }

  /// scene 생성. [coverFile]이 있으면 생성 직후 cover 이미지도 업로드.
  Future<Scene> create({
    required String title,
    required List<DateTime> dates,
    File? coverFile,
  }) async {
    final pairId = ref.read(myActivePairIdProvider);
    if (pairId == null) {
      throw StateError('Cannot create scene without an active pair.');
    }
    final repo = ref.read(sceneRepositoryProvider);
    var created = await repo.create(
      pairId: pairId,
      title: title,
      dates: dates,
    );
    if (coverFile != null) {
      try {
        final result = await repo.uploadCover(
          sceneId: created.id,
          file: coverFile,
        );
        created = created.copyWith(coverImageUrl: result.signedUrl);
      } catch (_) {
        // 커버 업로드 실패 — scene은 이미 생성됐으니 cover 없이 진행.
      }
    }
    // 리스트에 append (position이 가장 뒤에 들어가는 trigger 정의대로).
    final current = state.valueOrNull ?? const <Scene>[];
    state = AsyncValue<List<Scene>>.data([...current, created]);
    return created;
  }

  /// 기존 scene의 title/dates 수정. cover 이미지도 새로 받았으면 [coverFile]로 전달.
  /// (AsyncNotifier가 이미 `update` 시그니처를 가지므로 충돌 회피용 명명.)
  Future<Scene> editScene({
    required String id,
    String? title,
    List<DateTime>? dates,
    File? coverFile,
  }) async {
    final repo = ref.read(sceneRepositoryProvider);
    var updated = await repo.update(id: id, title: title, dates: dates);
    if (coverFile != null) {
      try {
        final result = await repo.uploadCover(sceneId: id, file: coverFile);
        updated = updated.copyWith(coverImageUrl: result.signedUrl);
      } catch (_) {
        // cover 업로드 실패해도 메타 update는 이미 적용됨.
      }
    }
    final current = state.valueOrNull ?? const <Scene>[];
    state = AsyncValue<List<Scene>>.data([
      for (final s in current)
        if (s.id == id)
          // repo.update는 scenes 테이블에서 row를 받기 때문에 [Scene.fromJson]
          // 의 default media(전부 0)가 들어있다. 그대로 state에 넣으면 count
          // 0으로 덮어써서 FocusedSceneInfo의 media/date 라인이 사라지는
          // 버그가 생긴다 → 기존 s.media를 살려 보존.
          updated.copyWith(
            coverImageUrl: coverFile == null && updated.coverImageUrl.isEmpty
                ? s.coverImageUrl
                : updated.coverImageUrl,
            media: s.media,
          )
        else
          s,
    ]);
    return updated;
  }

  Future<void> reorder(List<Scene> newOrder) async {
    // 클라가 결정한 새 순서로 number/position 재할당. 둘 다 1-based, 동일.
    // number == position 의미로 통합 — UI는 #(number)로 표시되고 position은
    // DB sort key로 작동.
    final updates = <({String id, int position})>[];
    for (var i = 0; i < newOrder.length; i++) {
      updates.add((id: newOrder[i].id, position: i + 1));
    }
    // Optimistic update — DB call 끝나기 전에 state를 먼저 새 순서로 갱신해
    // edit mode 종료 직후 깜빡임(옛 순서 → 새 순서) 제거. 실패 시 이전 상태
    // 로 롤백.
    final previous = state.valueOrNull;
    state = AsyncValue<List<Scene>>.data(
      [
        for (var i = 0; i < newOrder.length; i++)
          newOrder[i].copyWith(position: i + 1, number: i + 1),
      ],
    );
    try {
      await ref.read(sceneRepositoryProvider).reorder(updates);
    } catch (e) {
      if (previous != null) {
        state = AsyncValue<List<Scene>>.data(previous);
      }
      rethrow;
    }
  }

  Future<void> delete(String id) async {
    await ref.read(sceneRepositoryProvider).delete(id);
    final current = state.valueOrNull ?? const <Scene>[];
    state = AsyncValue<List<Scene>>.data(
      current.where((s) => s.id != id).toList(growable: false),
    );
  }

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final pairId = ref.read(myActivePairIdProvider);
      if (pairId == null) return const [];
      return ref.read(sceneRepositoryProvider).listByPair(pairId);
    });
  }

  /// loading state로 진입하지 않고 silently 재조회. pull-to-refresh처럼
  /// 기존 카드는 유지하면서 갱신되어야 하는 경우용. 실패하면 swallow.
  Future<void> softRefresh() async {
    final pairId = ref.read(myActivePairIdProvider);
    if (pairId == null) return;
    try {
      final fresh = await ref.read(sceneRepositoryProvider).listByPair(pairId);
      state = AsyncValue<List<Scene>>.data(fresh);
    } catch (_) {
      // best-effort. 기존 state 유지.
    }
  }
}

final scenesProvider =
    AsyncNotifierProvider<ScenesViewModel, List<Scene>>(ScenesViewModel.new);
