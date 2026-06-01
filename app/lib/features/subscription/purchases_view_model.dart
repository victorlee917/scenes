import 'dart:developer' as developer;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

import '../profile/profile_view_model.dart';
import 'data/purchases_repository.dart';
import 'subscription_view_model.dart';

void _log(String message) => developer.log(message, name: 'rc');

/// 구매 결과 enum. SubscriptionScreen이 후속 처리(toast 등)에 사용.
enum PurchaseOutcome {
  purchased,
  cancelled,
  unavailable, // offering / monthly package 못 찾음
  error,
}

/// View가 [PurchasesActionState.error]에 담긴 코드를 l10n 키로 매핑할 때
/// 쓰는 sentinel. raw exception 메시지를 노출하지 않고 안정적인 코드만 전달.
class PurchasesErrorCode {
  static const unavailable = 'unavailable';
  static const generic = 'generic';
}

/// 구매 액션의 transient 상태. View는 이걸 watch해서 버튼 disable·spinner 토글.
class PurchasesActionState {
  const PurchasesActionState({this.isBusy = false, this.error});

  /// 구매 또는 restore 호출 진행 중 여부.
  final bool isBusy;

  /// 마지막 에러 메시지. UI에서 toast 띄울 때만 사용 후 자체 reset.
  final String? error;

  PurchasesActionState copyWith({bool? isBusy, Object? error = _sentinel}) {
    return PurchasesActionState(
      isBusy: isBusy ?? this.isBusy,
      error: identical(error, _sentinel) ? this.error : error as String?,
    );
  }
}

const _sentinel = Object();

/// 구매 흐름(직접 구매 / Restore / Customer Center) 액션을 관리.
///
/// SubscriptionViewModel은 "현재 HD인가?"를 답하는 read 모델이고, 이 ViewModel
/// 은 "사용자가 구매·복구를 시도할 때 일어나는 일"을 다룬다. 책임 분리.
///
/// RC 대시보드의 Paywall은 사용하지 않는다 — 우리 SubscriptionScreen이 곧
/// paywall이고, Subscribe 버튼은 [purchaseMonthly]로 StoreKit 결제 시트를 직접
/// 띄운다.
class PurchasesViewModel extends AutoDisposeNotifier<PurchasesActionState> {
  @override
  PurchasesActionState build() => const PurchasesActionState();

  /// 현재 offering의 monthly package를 구매. StoreKit이 자체 결제 시트를 띄움.
  ///
  /// 결과:
  ///   - [PurchaseOutcome.purchased]: 결제 성공. subscription 상태 즉시 재평가.
  ///   - [PurchaseOutcome.cancelled]: 사용자가 시트 닫음 — 에러 toast 표시 X.
  ///   - [PurchaseOutcome.unavailable]: RC offering 또는 monthly package 없음.
  ///     대시보드 셋업 미완으로 추정 — UI에서 안내.
  ///   - [PurchaseOutcome.error]: 그 외 모든 실패. [state.error]에 메시지 저장.
  Future<PurchaseOutcome> purchaseMonthly() async {
    _log('purchaseMonthly: start');
    state = state.copyWith(isBusy: true, error: null);
    final repo = ref.read(purchasesRepositoryProvider);
    try {
      final package = await repo.getMonthlyPackage();
      if (package == null) {
        _log('purchaseMonthly: unavailable (no monthly package)');
        // View가 l10n으로 매핑할 수 있도록 sentinel code만 저장.
        state = state.copyWith(
          isBusy: false,
          error: PurchasesErrorCode.unavailable,
        );
        return PurchaseOutcome.unavailable;
      }
      final info = await repo.purchasePackage(package);
      final hasHd = repo.hasEntitlement(info);
      _log('purchaseMonthly: done hasHd=$hasHd');
      if (hasHd) {
        _invalidateSubscriptionState();
      }
      state = state.copyWith(isBusy: false, error: null);
      return hasHd ? PurchaseOutcome.purchased : PurchaseOutcome.error;
    } catch (e, st) {
      if (repo.isPurchaseCancelled(e)) {
        _log('purchaseMonthly: cancelled');
        state = state.copyWith(isBusy: false, error: null);
        return PurchaseOutcome.cancelled;
      }
      _log('purchaseMonthly: error $e');
      // ignore: discarded_futures
      Sentry.captureException(e, stackTrace: st);
      state = state.copyWith(isBusy: false, error: PurchasesErrorCode.generic);
      return PurchaseOutcome.error;
    }
  }

  /// 다른 디바이스에서 산 구독을 현재 계정에 복구. 같은 RC app_user_id(= 같은
  /// Supabase 유저)면 entitlement이 자동 매칭됨.
  Future<bool> restorePurchases() async {
    _log('restorePurchases: start');
    state = state.copyWith(isBusy: true, error: null);
    try {
      final repo = ref.read(purchasesRepositoryProvider);
      final info = await repo.restorePurchases();
      final hasHd = repo.hasEntitlement(info);
      _log('restorePurchases: done hasHd=$hasHd');
      _invalidateSubscriptionState();
      state = state.copyWith(isBusy: false, error: null);
      return hasHd;
    } catch (e, st) {
      _log('restorePurchases: error $e');
      // ignore: discarded_futures
      Sentry.captureException(e, stackTrace: st);
      state = state.copyWith(isBusy: false, error: PurchasesErrorCode.generic);
      return false;
    }
  }

  /// View에서 에러를 한 번 소비한 뒤 reset.
  void clearError() {
    if (state.error == null) return;
    state = state.copyWith(error: null);
  }

  /// CustomerInfo는 SDK 리스너로 자동 push되지만, 서버 측 profile(webhook 반영)
  /// 과 pair_has_active_hd RPC는 명시적으로 invalidate. 페어 단위 결정은 RPC가
  /// 진실 출처라 갱신 필요.
  void _invalidateSubscriptionState() {
    ref.invalidate(subscriptionViewModelProvider);
    ref.invalidate(myProfileProvider);
  }
}

final purchasesViewModelProvider =
    NotifierProvider.autoDispose<PurchasesViewModel, PurchasesActionState>(
  PurchasesViewModel.new,
);
