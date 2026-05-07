import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Scenes HD 구독 상태.
///
/// 페어 단위 혜택이라 본인이 구독중이거나 파트너가 구독중이면 true.
/// 실제 값은 추후 RevenueCat / StoreKit + Supabase `pair_has_active_hd`로 결정.
class SubscriptionState {
  const SubscriptionState({
    this.isSubscribed = false,
    this.subscribedBySelf = false,
  });

  final bool isSubscribed;
  // 누가 구독했는지. true=본인, false=파트너. isSubscribed=true 일 때만 의미.
  final bool subscribedBySelf;

  SubscriptionState copyWith({
    bool? isSubscribed,
    bool? subscribedBySelf,
  }) {
    return SubscriptionState(
      isSubscribed: isSubscribed ?? this.isSubscribed,
      subscribedBySelf: subscribedBySelf ?? this.subscribedBySelf,
    );
  }
}

/// 구독 상태를 관리하는 ViewModel.
///
/// 현재는 mock 값(`isSubscribed: true`)을 반환. 향후 RevenueCat 리스너와
/// Supabase `pair_has_active_hd` RPC를 결합해 실제 상태로 교체.
class SubscriptionViewModel extends Notifier<SubscriptionState> {
  @override
  SubscriptionState build() {
    // TODO: RevenueCat customerInfo 스트림 + pair_has_active_hd RPC 연동.
    // 실제 구현 시 구독자의 user_id를 받아와 myProfile.id 와 비교해 자기/파트너 판정.
    return const SubscriptionState(
      isSubscribed: false,
      subscribedBySelf: false,
    );
  }

  void setSubscribed(bool value, {bool bySelf = true}) {
    state = state.copyWith(
      isSubscribed: value,
      subscribedBySelf: bySelf,
    );
  }
}

final subscriptionViewModelProvider =
    NotifierProvider<SubscriptionViewModel, SubscriptionState>(
  SubscriptionViewModel.new,
);

/// 자주 쓰는 셀렉터: 구독 여부만 필요한 위젯에서 `ref.watch(isSubscribedProvider)`.
final isSubscribedProvider = Provider<bool>((ref) {
  return ref.watch(
    subscriptionViewModelProvider.select((s) => s.isSubscribed),
  );
});
