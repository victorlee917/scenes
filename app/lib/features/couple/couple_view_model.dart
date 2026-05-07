import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../auth/auth_view_model.dart';
import 'data/couple_repository.dart';

/// 현재 사용자의 active couple + 상대방 profile.
///
/// auth session 변동 시 자동 refetch. 페어가 없으면 null.
class ActiveCoupleViewModel
    extends AsyncNotifier<ActiveCoupleAndPartner?> {
  StreamSubscription<void>? _coupleUpdateSub;
  StreamSubscription<void>? _partnerProfileSub;
  String? _watchedPartnerId;

  @override
  Future<ActiveCoupleAndPartner?> build() async {
    final session = ref.watch(authViewModelProvider.select((s) => s.session));

    // couples UPDATE 구독 — since_date / status 전이를 양쪽 클라 동기화.
    _coupleUpdateSub?.cancel();
    _coupleUpdateSub = null;
    if (session != null) {
      _coupleUpdateSub = ref
          .read(coupleRepositoryProvider)
          .watchActiveCoupleUpdates()
          .listen((_) => refresh());
    }
    ref.onDispose(() {
      _coupleUpdateSub?.cancel();
      _partnerProfileSub?.cancel();
    });

    if (session == null) {
      _swapPartnerSub(null);
      return null;
    }
    final result =
        await ref.read(coupleRepositoryProvider).getMyActiveCouple();
    // 파트너가 새로 나타났거나 바뀌었으면 partner profile UPDATE 구독을 갈아
    // 끼움 — 닉네임/아바타/탈퇴 변경 즉시 반영.
    _swapPartnerSub(result?.partner.id);
    return result;
  }

  void _swapPartnerSub(String? partnerId) {
    if (partnerId == _watchedPartnerId) return;
    _partnerProfileSub?.cancel();
    _partnerProfileSub = null;
    _watchedPartnerId = partnerId;
    if (partnerId == null) return;
    _partnerProfileSub = ref
        .read(coupleRepositoryProvider)
        .watchPartnerProfileUpdates(partnerId)
        .listen((_) => refresh());
  }

  /// 외부에서 강제 갱신 (예: pairing wiring 후, realtime 이벤트 도착, pull-to-
  /// refresh 등). loading 단계를 거치지 않고 새 데이터를 받아 그대로 swap —
  /// 그렇지 않으면 watcher들이 한 프레임 동안 null/empty를 보고 rebuild하면서
  /// Hero 비행 중 destination layout이 갈아엎혀 teleport 같은 현상 발생.
  Future<void> refresh() async {
    state = await AsyncValue.guard(() {
      return ref.read(coupleRepositoryProvider).getMyActiveCouple();
    });
  }

  /// since_date 변경. 성공 시 state의 CoupleRecord만 교체 (loading 안 거침 →
  /// router/UI flicker 없음).
  Future<void> updateSinceDate(DateTime date) async {
    final current = state.valueOrNull;
    if (current == null) {
      throw StateError('No active couple to update.');
    }
    final updatedCouple = await ref
        .read(coupleRepositoryProvider)
        .updateSinceDate(current.couple.id, date);
    state = AsyncValue<ActiveCoupleAndPartner?>.data(
      ActiveCoupleAndPartner(
        couple: updatedCouple,
        partner: current.partner,
      ),
    );
  }
}

final activeCoupleProvider =
    AsyncNotifierProvider<ActiveCoupleViewModel, ActiveCoupleAndPartner?>(
  ActiveCoupleViewModel.new,
);

/// 자주 쓰는 셀렉터: 현재 active pair_id. null이면 미페어링.
final myActivePairIdProvider = Provider<String?>((ref) {
  return ref.watch(
    activeCoupleProvider.select((s) => s.valueOrNull?.couple.pairId),
  );
});

/// 자주 쓰는 셀렉터: 페어 멤버십 여부.
final isPairedProvider = Provider<bool>((ref) {
  return ref.watch(myActivePairIdProvider) != null;
});
