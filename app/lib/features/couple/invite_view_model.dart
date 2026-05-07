import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../auth/auth_view_model.dart';
import 'data/couple_repository.dart';
import 'models/couple_invite.dart';

/// 본인 active invite 코드. 페어링 화면에서 사용.
///
/// 만료/사용된 invite는 `getOrCreateMyInvite`가 자동으로 새 코드를 발급해
/// build()는 항상 사용 가능한 invite를 돌려준다.
class MyInviteViewModel extends AsyncNotifier<CoupleInvite> {
  @override
  Future<CoupleInvite> build() async {
    // 로그인 세션이 바뀌면 자동 refetch.
    ref.watch(authViewModelProvider.select((s) => s.session));
    return ref.read(coupleRepositoryProvider).getOrCreateMyInvite();
  }

  /// 만료 카운트가 끝났을 때 등 강제 재발급. 기존 invite는 자연 만료되거나
  /// cron으로 정리되므로 클라가 명시적으로 지울 필요는 없음.
  Future<void> regenerate() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() {
      return ref.read(coupleRepositoryProvider).getOrCreateMyInvite();
    });
  }
}

final myInviteProvider =
    AsyncNotifierProvider<MyInviteViewModel, CoupleInvite>(
  MyInviteViewModel.new,
);
