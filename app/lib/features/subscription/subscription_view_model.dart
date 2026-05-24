import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../couple/couple_view_model.dart';
import '../profile/profile_view_model.dart';
import 'data/purchases_repository.dart';

/// Scenes HD 구독 상태.
///
/// 페어 단위 혜택이라 본인이 구독중이거나 파트너가 구독중이면 [isSubscribed]
/// = true. 결정 로직은 [SubscriptionViewModel.build]가 myProfile + 활성 페어
/// 정보 + `pair_has_active_hd` RPC를 종합.
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

/// 구독 상태 ViewModel.
///
/// 흐름:
///   1. [myProfileProvider]를 watch — 본인 tier/expires_at 변동 시 재계산.
///   2. [myActivePairIdProvider]를 watch — 페어 변동(연결/해제) 시 재계산.
///   3. 페어가 있으면 `pair_has_active_hd(pair_id)` RPC로 페어 단위 HD 여부
///      판정 (한쪽이라도 HD면 페어 전체가 HD).
///   4. 페어가 없으면 본인 [Profile.hasActiveSubscription]만 본다.
///
/// `subscribedBySelf`는 본인 프로필 기준만 판단(RPC는 누구인지 알려주지
/// 않으므로). 본인이 HD가 아니면서 페어 전체는 HD인 경우 → "파트너 덕분에
/// HD" 시나리오로 처리됨.
class SubscriptionViewModel extends AsyncNotifier<SubscriptionState> {
  @override
  Future<SubscriptionState> build() async {
    final profile = ref.watch(myProfileProvider).valueOrNull;
    final pairId = ref.watch(myActivePairIdProvider);
    // RC CustomerInfo도 watch — 결제/복구 직후 RC SDK가 즉시 푸시하므로
    // webhook → DB 반영을 기다리지 않고도 self HD 상태가 UI에 반영됨.
    final rcInfo = ref.watch(customerInfoProvider).valueOrNull;
    final rcHasHd =
        ref.read(purchasesRepositoryProvider).hasEntitlement(rcInfo);

    // self HD는 profile(서버 진실) OR RC(로컬 즉시) — 둘 중 하나라도 true면 self
    // HD로 간주. 정기 갱신/만료는 결국 webhook이 profile을 갱신하면서 수렴.
    final selfHd = (profile?.hasActiveSubscription ?? false) || rcHasHd;

    bool pairHd;
    if (pairId == null) {
      pairHd = selfHd;
    } else {
      // pairId별로 캐시되는 provider — RC CustomerInfo push로 이 build가
      // 재실행돼도 RPC는 pairId가 실제로 바뀔 때만 다시 돈다.
      final partnerHd =
          await ref.watch(_pairHasActiveHdProvider(pairId).future);
      pairHd = partnerHd || selfHd;
    }

    return SubscriptionState(
      isSubscribed: pairHd,
      subscribedBySelf: selfHd,
    );
  }
}

/// `pair_has_active_hd` RPC 결과 — pairId별로 캐시. pairId가 실제로 바뀔 때만
/// RPC를 호출하므로, RevenueCat CustomerInfo push로 SubscriptionViewModel이
/// 재빌드돼도 RPC는 다시 돌지 않는다. (파트너의 HD 변동은 다음 앱 실행 시
/// 반영 — HD 상태 변경 자체가 드물어 허용 가능한 trade-off.)
final _pairHasActiveHdProvider =
    FutureProvider.family<bool, String>((ref, pairId) async {
  try {
    final res = await Supabase.instance.client.rpc(
      'pair_has_active_hd',
      params: {'p_pair_id_text': pairId},
    );
    return res == true;
  } catch (_) {
    // RPC 실패 시 보수적으로 false — selfHd로 fallback되고 다음 평가에 재시도.
    return false;
  }
});

final subscriptionViewModelProvider =
    AsyncNotifierProvider<SubscriptionViewModel, SubscriptionState>(
  SubscriptionViewModel.new,
);

/// 자주 쓰는 셀렉터: 구독 여부만 필요한 위젯에서 `ref.watch(isSubscribedProvider)`.
/// 결정되기 전(loading/error)엔 false로 본다 — 잠깐의 deny 가 false 노출보다
/// 안전(예: HD 전용 액션 버튼 무료처럼 잘못 노출되는 것 방지).
final isSubscribedProvider = Provider<bool>((ref) {
  return ref.watch(
    subscriptionViewModelProvider
        .select((s) => s.valueOrNull?.isSubscribed ?? false),
  );
});
