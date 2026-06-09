import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../couple/couple_view_model.dart';
import 'data/share_repository.dart';

/// active pair의 공유 닉네임(slug)을 노출하는 ViewModel.
///
/// pair가 없거나 닉네임 미설정이면 `null`. [myActivePairIdProvider]를 watch하므로
/// 페어가 바뀌면 자동으로 다시 로드된다.
class ShareSlugViewModel extends AsyncNotifier<String?> {
  @override
  Future<String?> build() async {
    // active 커플(=pair)이 확정될 때까지 대기한다. 로딩 중 myActivePairId가
    // 잠깐 null이 되는 사이 섣불리 AsyncData(null)로 떨어지면 "ID 미등록"으로
    // 깜빡인다(등록했는데 미등록처럼 보임). activeCoupleProvider.future로 첫
    // 값이 emit될 때까지 이 provider를 로딩 상태로 유지.
    final couple = await ref.watch(activeCoupleProvider.future);
    final pairId = couple?.couple.pairId;
    if (pairId == null) return null;
    return ref.read(shareRepositoryProvider).getSlug(pairId);
  }

  /// 닉네임 설정/변경. 성공하면 state를 새 slug로 갱신.
  /// 충돌/형식 오류는 [SlugTakenException]/[SlugInvalidException]으로 throw.
  Future<void> setSlug(String slug) async {
    final pairId = ref.read(myActivePairIdProvider);
    if (pairId == null) {
      throw StateError('No active pair to set a share nickname for.');
    }
    final normalized = slug.trim().toLowerCase();
    await ref
        .read(shareRepositoryProvider)
        .setSlug(pairId: pairId, slug: normalized);
    state = AsyncData(normalized);
  }
}

final shareSlugProvider =
    AsyncNotifierProvider<ShareSlugViewModel, String?>(ShareSlugViewModel.new);
