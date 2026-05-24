import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../auth/auth_view_model.dart';
import 'data/notification_preferences_repository.dart';
import 'models/notification_preferences.dart';

/// 본인 알림 설정. 화면에서 토글이 변경되면 setPartnerActivity / setMarketing
/// 으로 호출 → 백엔드 upsert + state 갱신. row가 아예 없는 케이스에서 toggle
/// 하면 자동으로 default-all-on을 먼저 만들어 row를 보장한 뒤 변경 적용.
class NotificationPreferencesViewModel
    extends AsyncNotifier<NotificationPreferences?> {
  @override
  Future<NotificationPreferences?> build() async {
    // user.id만 관찰 — 토큰 갱신으로 Session 객체만 바뀔 땐 refetch하지 않게.
    ref.watch(authViewModelProvider.select((s) => s.session?.user.id));
    return ref.read(notificationPreferencesRepositoryProvider).getMy();
  }

  Future<void> refresh() async {
    state = await AsyncValue.guard(() {
      return ref.read(notificationPreferencesRepositoryProvider).getMy();
    });
  }

  Future<void> _ensureRowAndApply(
    NotificationPreferences Function(NotificationPreferences current) mutate,
  ) async {
    final repo = ref.read(notificationPreferencesRepositoryProvider);
    final current =
        state.valueOrNull ?? await repo.initializeIfMissing(allOn: true);
    final next = mutate(current);
    state = AsyncValue<NotificationPreferences?>.data(next);
    try {
      final saved = await repo.upsert(next);
      state = AsyncValue<NotificationPreferences?>.data(saved);
    } catch (_) {
      // 저장 실패 — 낙관적 변경을 되돌린다(토글이 실제 값으로 되돌아옴).
      // provider를 error 상태로 만들면 화면이 토글 대신 에러 문구로 통째
      // 바뀌므로 data(current)로만 롤백한다.
      state = AsyncValue<NotificationPreferences?>.data(current);
    }
  }

  Future<void> setPartnerActivity(bool value) =>
      _ensureRowAndApply((c) => c.copyWith(partnerActivityEnabled: value));

  Future<void> setMarketing(bool value) =>
      _ensureRowAndApply((c) => c.copyWith(marketingEnabled: value));
}

final notificationPreferencesProvider = AsyncNotifierProvider<
    NotificationPreferencesViewModel, NotificationPreferences?>(
  NotificationPreferencesViewModel.new,
);
