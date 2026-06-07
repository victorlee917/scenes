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
    final pairId = ref.watch(myActivePairIdProvider);
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
