import 'dart:async';
import 'dart:developer' as developer;
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

/// Scenes HD 구독에 사용되는 RevenueCat entitlement 식별자. RC 대시보드와
/// `revenuecat-webhook` Edge Function에서도 같은 이름으로 매핑. 클라/서버 어디
/// 서든 이 상수로만 참조한다.
const String kScenesHdEntitlement = 'scenes_hd';

/// 로그 태그 — 콘솔에서 `[rc]`로 필터해 RC 관련 진단만 볼 수 있게.
const String _logName = 'rc';

void _log(String message, {Object? error, StackTrace? stackTrace}) {
  developer.log(message, name: _logName, error: error, stackTrace: stackTrace);
}

/// 키 식별용 fingerprint — 보안상 전체 키는 로그에 남기지 않고 앞 6자 + 길이만
/// 흘림. "키가 비었나?", "키가 prod인가 test인가?" 정도는 분간 가능.
String _maskKey(String key) {
  if (key.isEmpty) return '<empty>';
  final prefix = key.substring(0, key.length < 6 ? key.length : 6);
  return '$prefix...(len=${key.length})';
}

/// 사용자 id 마스킹 — 전체는 남기지 않고 앞 8자만. 같은 사용자인지 비교는
/// 가능하면서 PII 노출은 최소화.
String _maskUserId(String? id) {
  if (id == null || id.isEmpty) return '<null>';
  return id.length < 8 ? id : '${id.substring(0, 8)}...';
}

/// `Purchases` 호출을 전부 감싸는 Repository.
///
/// View/ViewModel은 SDK 타입을 직접 import하지 않고 이 클래스를 통해서만
/// 인터랙트 — 추후 SDK 교체나 Android 분기 시 영향 면적이 작다.
///
/// 호출 전 [configure]가 반드시 선행되어야 한다. main.dart에서 1회 호출.
class PurchasesRepository {
  PurchasesRepository();

  // SDK는 프로세스 단위로 한 번만 configure 가능. 동일 프로세스 안에서 여러
  // Repository 인스턴스가 만들어져도(테스트/Provider rebuild 등) configure가
  // 중복 실행되지 않도록 static으로.
  static bool _configured = false;
  bool get isConfigured => _configured;

  /// SDK 초기화. iOS만 등록(현재 출시 타깃). Android 출시 시 goog_ 키로 분기.
  /// 키가 비어 있으면 조용히 스킵 — 개발 환경에서 RC 키 없이도 앱이 떠야 함.
  Future<void> configure() async {
    if (_configured) {
      _log('configure: already configured, skipping');
      return;
    }
    if (!Platform.isIOS) {
      _log('configure: skipped (platform != iOS)');
      return;
    }
    const key = String.fromEnvironment('REVENUECAT_IOS_API_KEY');
    if (key.isEmpty) {
      _log(
        'configure: SKIPPED — REVENUECAT_IOS_API_KEY dart-define empty. '
        'Subscription features will be inert.',
      );
      return;
    }
    try {
      await Purchases.setLogLevel(LogLevel.warn);
      await Purchases.configure(PurchasesConfiguration(key));
      _configured = true;
      _log('configure: OK key=${_maskKey(key)}');
    } catch (e, st) {
      _log('configure: FAILED key=${_maskKey(key)}', error: e, stackTrace: st);
    }
  }

  /// Supabase auth.uid를 RC app_user_id에 동기화. webhook 매핑이 이 id 기준이라
  /// 인증 직후 반드시 호출. profile 미준비 등으로 userId가 없으면 [logOut].
  Future<void> logIn(String userId) async {
    if (!_configured) {
      _log('logIn: skipped (not configured) user=${_maskUserId(userId)}');
      return;
    }
    try {
      final result = await Purchases.logIn(userId);
      _log(
        'logIn: OK user=${_maskUserId(userId)} created=${result.created}',
      );
    } catch (e, st) {
      _log(
        'logIn: FAILED user=${_maskUserId(userId)}',
        error: e,
        stackTrace: st,
      );
    }
  }

  /// 익명 사용자로 리셋. 이미 익명이면 SDK가 ConfigurationException을 던질 수
  /// 있는데 무시(상태 일치라 행위 동일).
  Future<void> logOut() async {
    if (!_configured) {
      _log('logOut: skipped (not configured)');
      return;
    }
    try {
      await Purchases.logOut();
      _log('logOut: OK');
    } catch (e) {
      // 이미 anonymous인 경우의 ConfigurationException은 의도된 noop이므로
      // info level. 그 외 에러도 흐름 차단할 정도는 아니라 silent.
      _log('logOut: noop or error: $e');
    }
  }

  /// 현재 CustomerInfo 단발 조회. 캐시된 값이면 즉시 반환, 없으면 fetch.
  Future<CustomerInfo?> getCustomerInfo() async {
    if (!_configured) return null;
    try {
      final info = await Purchases.getCustomerInfo();
      return info;
    } catch (e, st) {
      _log('getCustomerInfo: FAILED', error: e, stackTrace: st);
      return null;
    }
  }

  /// CustomerInfo 변경(구매·만료·갱신) 푸시 스트림. RC SDK 리스너를 broadcast
  /// stream으로 노출 — Riverpod StreamProvider에서 그대로 watch 가능.
  Stream<CustomerInfo> customerInfoStream() {
    final controller = StreamController<CustomerInfo>.broadcast();
    void listener(CustomerInfo info) {
      controller.add(info);
    }

    if (_configured) {
      Purchases.addCustomerInfoUpdateListener(listener);
    }
    controller.onCancel = () {
      if (_configured) {
        Purchases.removeCustomerInfoUpdateListener(listener);
      }
    };
    return controller.stream;
  }

  /// 다른 기기에서 구매한 구독을 현재 디바이스에 복구. 같은 app_user_id (= 같은
  /// 로그인 계정)면 RC가 entitlement를 자동 매칭.
  Future<CustomerInfo?> restorePurchases() async {
    if (!_configured) {
      _log('restorePurchases: skipped (not configured)');
      return null;
    }
    _log('restorePurchases: start');
    try {
      final info = await Purchases.restorePurchases();
      _log(
        'restorePurchases: OK entitlements='
        '${info.entitlements.active.keys.toList()}',
      );
      return info;
    } catch (e, st) {
      _log('restorePurchases: FAILED', error: e, stackTrace: st);
      rethrow;
    }
  }

  /// 현재 offering의 monthly package fetch. RC 대시보드의 Offering에 "Monthly"
  /// package가 등록되어 있어야 하고, 그게 SDK의 `current.monthly` 슬롯에 매핑.
  /// 못 찾으면 null — 상위 레이어가 적절히 fallback/에러 처리.
  Future<Package?> getMonthlyPackage() async {
    if (!_configured) {
      _log('getMonthlyPackage: skipped (not configured)');
      return null;
    }
    try {
      final offerings = await Purchases.getOfferings();
      final current = offerings.current;
      if (current == null) {
        _log(
          'getMonthlyPackage: NO current offering '
          '(all=${offerings.all.keys.toList()}). RC dashboard에서 Offering을 '
          '"Current"로 지정했는지 확인 필요.',
        );
        return null;
      }
      final monthly = current.monthly;
      if (monthly == null) {
        _log(
          'getMonthlyPackage: current offering "${current.identifier}"에 '
          'monthly package 없음. packages='
          '${current.availablePackages.map((p) => p.identifier).toList()}',
        );
        return null;
      }
      _log(
        'getMonthlyPackage: OK offering=${current.identifier} '
        'product=${monthly.storeProduct.identifier} '
        'price=${monthly.storeProduct.priceString}',
      );
      return monthly;
    } catch (e, st) {
      _log('getMonthlyPackage: FAILED', error: e, stackTrace: st);
      return null;
    }
  }

  /// 지정 package 구매. 호출 시 StoreKit 결제 시트(Face ID/암호)가 자동으로 뜨고
  /// 완료되면 CustomerInfo 반환. 사용자가 시트를 닫으면
  /// [PurchasesErrorCode.purchaseCancelledError]로 throw — 호출부가 이걸 구분해
  /// 조용히 무시.
  Future<CustomerInfo> purchasePackage(Package package) async {
    _log(
      'purchasePackage: start product=${package.storeProduct.identifier} '
      'price=${package.storeProduct.priceString}',
    );
    try {
      final info = await Purchases.purchasePackage(package);
      _log(
        'purchasePackage: OK entitlements='
        '${info.entitlements.active.keys.toList()}',
      );
      return info;
    } catch (e, st) {
      if (isPurchaseCancelled(e)) {
        _log('purchasePackage: cancelled by user');
      } else {
        _log('purchasePackage: FAILED', error: e, stackTrace: st);
      }
      rethrow;
    }
  }

  /// PlatformException이 사용자 취소인지 빠르게 판별.
  bool isPurchaseCancelled(Object error) {
    if (error is! PlatformException) return false;
    return PurchasesErrorHelper.getErrorCode(error) ==
        PurchasesErrorCode.purchaseCancelledError;
  }

  /// CustomerInfo가 특정 entitlement을 active로 들고 있는지 검사.
  bool hasEntitlement(
    CustomerInfo? info, {
    String entitlement = kScenesHdEntitlement,
  }) {
    if (info == null) return false;
    return info.entitlements.active[entitlement] != null;
  }
}

final purchasesRepositoryProvider = Provider<PurchasesRepository>((ref) {
  return PurchasesRepository();
});

/// CustomerInfo의 실시간 변경을 노출. 진입 시점에 즉시 초기 값을 fetch한 뒤
/// 이후 변경분은 SDK 리스너로 push.
final customerInfoProvider = StreamProvider<CustomerInfo?>((ref) async* {
  final repo = ref.watch(purchasesRepositoryProvider);
  // 첫 값 — SDK가 캐시 있으면 즉시, 없으면 짧은 fetch.
  yield await repo.getCustomerInfo();
  await for (final info in repo.customerInfoStream()) {
    yield info;
  }
});

/// 현재 monthly 구독 상품의 지역화된 가격 문자열. App Store가 사용자 지역
/// 통화로 포맷한 값(예: "$4.99", "₩6,500") — 코드에서 통화 기호를 붙이지
/// 않는다. RC 미설정·offering/package 없음 등으로 못 가져오면 null.
final monthlyPriceProvider = FutureProvider<String?>((ref) async {
  final repo = ref.watch(purchasesRepositoryProvider);
  final package = await repo.getMonthlyPackage();
  return package?.storeProduct.priceString;
});
