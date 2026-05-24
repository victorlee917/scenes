import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:kakao_flutter_sdk_user/kakao_flutter_sdk_user.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/locale/locale_provider.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/theme_provider.dart';
import 'features/auth/auth_view_model.dart';
import 'features/lock/lock_view_model.dart';
import 'features/lock/widgets/lock_challenge_screen.dart';
import 'features/profile/profile_view_model.dart';
import 'features/subscription/data/purchases_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'features/push/push_deeplink.dart';
import 'features/push/push_service.dart';
import 'l10n/app_localizations.dart';

// 모두 의도된 공개 값 — 앱 번들 임베드 표준 (Supabase publishable key,
// Kakao native key, Google OAuth client IDs 모두 client-side embed 의도).
// dart-define보다 하드코딩이 안정적이라 그렇게 둠.
const supabaseUrl = 'https://cmnzpmswkaykjjlmxkut.supabase.co';
const supabaseAnonKey = 'sb_publishable_QKullI5zS6GGUVKv3LsvyA_Lg6tZmUq';
const kakaoNativeAppKey = '49345eb4969f4d9834180b3afa18789f';

/// Google OAuth 2.0 iOS Client ID. iOS 네이티브 로그인 + Info.plist URL scheme
/// (reversed)에서 사용.
const googleIosClientId =
    '433814039366-b898nr8ssbjn7dghmk9oip5faf5b0uop.apps.googleusercontent.com';

/// Google OAuth 2.0 Web Client ID. `serverClientId`로 전달하면 idToken의
/// audience가 이 값으로 발급됨 — Supabase Google 프로바이더가 이걸 audience로
/// 검증하므로 일치해야 통과.
const googleWebClientId =
    '433814039366-67dhk75no12mamcgsierdjrgqu02e8lb.apps.googleusercontent.com';

/// Mapbox public access token (pk.*) — Recap의 Place 매체 풀스크린 지도에서
/// tile/style을 받기 위해 사용. 클라이언트 임베드용 public 토큰이라 코드
/// 베이스에 노출돼도 문제 없음. SDK 다운로드용 secret 토큰(sk.*)은 ~/.netrc /
/// gradle.properties에 따로 둔다.
const mapboxPublicToken =
    'pk.eyJ1IjoidGFwYXNtYWtlciIsImEiOiJjbW9iaTJkNWEwMHljMnNweTlhaW10dGlzIn0.iOBhy3mgtWIIkLgpv7d9SQ';

Future<void> main() async {
  final widgetsBinding = WidgetsFlutterBinding.ensureInitialized();
  // 네이티브 스플래시(로고 + 테마 배경)를 첫 frame이 그려진 후에도 그대로
  // 유지 — Supabase 세션 복원 + profile 로드가 끝날 때까지 holding. 라우팅이
  // 결정되면 ScenesApp이 FlutterNativeSplash.remove() 호출.
  FlutterNativeSplash.preserve(widgetsBinding: widgetsBinding);
  // 가로 모드 미지원. iOS Info.plist + Android Manifest에도 같은 제약이 걸려
  // 있고 여기는 belt-and-suspenders.
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
  ]);
  await initializeDateFormatting();
  KakaoSdk.init(
    nativeAppKey: kakaoNativeAppKey,
    // production build에선 OAuth 토큰이 콘솔에 찍히지 않도록 debug 한정.
    loggingEnabled: kDebugMode,
  );
  // Firebase는 GoogleService-Info.plist / google-services.json에서 자동 로드.
  // 푸시 토큰 발급은 PushService.bootstrap()에서 로그인 시점에 수행.
  await Firebase.initializeApp();
  // 모든 provider(Apple/Google/Kakao)가 signInWithIdToken을 쓰고 OAuth redirect
  // 흐름은 안 씀. SDK 기본값 PKCE가 모든 deep link을 verifier 콜백으로 오인해
  // "Code verifier could not be found" warning을 뱉기 때문에 implicit으로 둠.
  await Supabase.initialize(
    url: supabaseUrl,
    anonKey: supabaseAnonKey,
    authOptions: const FlutterAuthClientOptions(
      authFlowType: AuthFlowType.implicit,
    ),
  );
  // Mapbox SDK가 tile 요청에 사용할 public access token 등록. 한 번만 호출.
  MapboxOptions.setAccessToken(mapboxPublicToken);
  // RevenueCat SDK 초기화 — 익명 사용자로 시작. profile이 로드되면 ScenesApp
  // 의 ref.listen이 Purchases.logIn(auth.uid)으로 identity를 동기화한다.
  // API 키는 --dart-define=REVENUECAT_IOS_API_KEY=... 로 주입.
  await PurchasesRepository().configure();
  runApp(const ProviderScope(child: ScenesApp()));
}

final supabase = Supabase.instance.client;

// 스플래시는 한 번만 제거 — 이후 provider rebuild에서 또 호출되는 걸 방지.
bool _splashRemoved = false;

void _maybeRemoveSplash(WidgetRef ref) {
  if (_splashRemoved) return;
  final isLoggedIn = ref.read(isLoggedInProvider);
  if (!isLoggedIn) {
    _splashRemoved = true;
    FlutterNativeSplash.remove();
    return;
  }
  final myProfile = ref.read(myProfileProvider);
  // profile 데이터가 도착해야(== route 결정 가능) splash 내림. 그 사이엔 로고
  // 화면 유지 → home_view의 CircularProgressIndicator 깜빡임 방지.
  if (myProfile.hasValue && !myProfile.isLoading) {
    _splashRemoved = true;
    FlutterNativeSplash.remove();
  }
}

class ScenesApp extends ConsumerStatefulWidget {
  const ScenesApp({super.key});

  @override
  ConsumerState<ScenesApp> createState() => _ScenesAppState();
}

class _ScenesAppState extends ConsumerState<ScenesApp>
    with WidgetsBindingObserver {
  StreamSubscription<RemoteMessage>? _onMessageOpenedSub;

  static const _pushTapChannel = MethodChannel('scenes.app/push_tap');

  /// 앱이 실제로 백그라운드(paused)를 거쳤는지. inactive(생체 인증 prompt,
  /// 컨트롤 센터, 알림 배너 등)는 false로 유지 — 그런 경우엔 잠금 재발화 X.
  bool _wasBackgrounded = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _wireUpPushTapHandlers();
    _wireUpNativePushTapChannel();
    // 콜드 스타트 시 native가 NSUserDefaults에 적어둔 pending tap 처리.
    // ignore: discarded_futures
    _drainPendingPushTap();
  }

  /// AppDelegate.PushTapBridge가 알림 탭 발생 시 즉시 invokeMethod로 페이로드
  /// 전달. 앱이 foreground/background 상관없이 실시간 발화 — `didChange
  /// AppLifecycleState`가 발화 안 하는 foreground 탭 케이스도 커버.
  void _wireUpNativePushTapChannel() {
    _pushTapChannel.setMethodCallHandler((call) async {
      if (call.method != 'onTap') return null;
      final raw = call.arguments;
      if (raw is! String || raw.isEmpty) return null;
      // ignore: discarded_futures
      _logDeeplink('channel_payload', detail: raw);
      try {
        final decoded = jsonDecode(raw);
        if (decoded is! Map) return null;
        final data = decoded.map<String, dynamic>(
          (k, v) => MapEntry(k.toString(), v),
        );
        final intent = PushDeeplink.fromMap(data);
        // ignore: discarded_futures
        _logDeeplink('channel_intent',
            detail: intent == null
                ? 'parse_failed'
                : 'kind=${intent.kind} scene=${intent.sceneId} content=${intent.contentId}');
        if (intent != null) {
          ref.read(pushDeeplinkProvider.notifier).set(intent);
        }
      } catch (e) {
        // ignore: discarded_futures
        _logDeeplink('channel_decode_error', detail: '$e');
      }
      return null;
    });
  }

  @override
  void dispose() {
    _onMessageOpenedSub?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// 푸시 알림 탭 흐름 두 갈래를 다 잡는다:
  ///   1) 콜드 스타트 — 앱이 종료된 상태에서 알림 탭 → getInitialMessage()
  ///      가 한 번 RemoteMessage를 반환.
  ///   2) 백그라운드 — 앱이 뒤에 떠있다가 알림 탭 → onMessageOpenedApp 스트림.
  ///
  /// 둘 다 [pushDeeplinkProvider] state로 흘려보내고, 라우팅은 HomeView가
  /// 담당.
  void _wireUpPushTapHandlers() {
    // ignore: discarded_futures
    _logDeeplink('wiring_start');

    // getInitialMessage Future의 호출/완료/예외/타임아웃을 모두 별개로 로그.
    // .then이 안 찍히면 Future가 hang인지 throw인지 timeout인지 판별 가능.
    final initialFuture = FirebaseMessaging.instance.getInitialMessage();
    // ignore: discarded_futures
    _logDeeplink('initial_call_returned');
    initialFuture.then((msg) {
      _logDeeplink('cold_start_msg',
          detail: msg == null ? 'null' : 'data=${msg.data}');
      if (msg == null) return;
      final intent = PushDeeplink.fromRemote(msg);
      _logDeeplink('cold_start_intent',
          detail: intent == null
              ? 'parse_failed'
              : 'kind=${intent.kind} scene=${intent.sceneId} content=${intent.contentId}');
      if (intent != null) {
        ref.read(pushDeeplinkProvider.notifier).set(intent);
      }
    }).catchError((e, st) {
      _logDeeplink('cold_start_error', detail: '$e');
    }).whenComplete(() {
      // ignore: discarded_futures
      _logDeeplink('cold_start_done');
    });
    // 안전망 — 5초 내에 whenComplete가 안 찍히면 Future가 hang. timeout 별도
    // 로그.
    initialFuture.timeout(const Duration(seconds: 5), onTimeout: () {
      // ignore: discarded_futures
      _logDeeplink('cold_start_timeout');
      return null;
    });

    _onMessageOpenedSub = FirebaseMessaging.onMessageOpenedApp.listen((msg) {
      _logDeeplink('opened_msg', detail: 'data=${msg.data}');
      final intent = PushDeeplink.fromRemote(msg);
      _logDeeplink('opened_intent',
          detail: intent == null
              ? 'parse_failed'
              : 'kind=${intent.kind} scene=${intent.sceneId} content=${intent.contentId}');
      if (intent != null) {
        ref.read(pushDeeplinkProvider.notifier).set(intent);
      }
    }, onError: (e, st) {
      // ignore: discarded_futures
      _logDeeplink('opened_stream_error', detail: '$e');
    });
    // ignore: discarded_futures
    _logDeeplink('opened_listen_attached');
  }

  Future<void> _logDeeplink(String step, {String? detail}) async {
    // 진단용 계측 — release 빌드에선 push_debug_log 쓰기를 건너뛴다.
    if (!kDebugMode) return;
    try {
      final client = Supabase.instance.client;
      final row = <String, dynamic>{
        'user_id': client.auth.currentUser?.id,
        'step': 'dl_$step',
      };
      if (detail != null) row['detail'] = detail;
      await client.from('push_debug_log').insert(row);
    } catch (_) {}
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // paused/hidden/detached로 진입했다는 건 진짜 백그라운드 — 다음 resume 때
    // 재잠금 발화. inactive는 무시(생체 인증 prompt, control center 등 단순
    // 일시 비활성이라 잠금 재발화 X — 그렇지 않으면 biometric 무한 루프).
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden ||
        state == AppLifecycleState.detached) {
      _wasBackgrounded = true;
    }
    // 앱 resume 시 push 토큰 등록을 한 번 더 시도. 첫 launch에서 APNs가
    // 늦게 ready되어 등록 실패한 케이스, 사용자가 OS Settings에서 권한 켜고
    // 돌아온 케이스 등 모두 catch.
    if (state == AppLifecycleState.resumed) {
      // ignore: discarded_futures
      ref.read(pushServiceProvider).ensureRegistered();
      // 백그라운드에서 알림 탭으로 돌아온 경우 native가 이미 NSUserDefaults
      // 에 페이로드를 기록한 상태. 여기서 드레인.
      // ignore: discarded_futures
      _drainPendingPushTap();
      // 진짜 백그라운드를 거친 경우에만 잠금 재발화. biometric prompt가 만든
      // inactive→resumed transition은 _wasBackgrounded=false라 무시.
      if (_wasBackgrounded) {
        _wasBackgrounded = false;
        ref.read(lockViewModelProvider.notifier).markLocked();
      }
    }
  }

  /// 네이티브 AppDelegate가 NSUserDefaults('flutter.pendingPushTap')에
  /// 적어둔 알림 페이로드를 읽어 deeplink intent로 변환. 한 번 처리하면 비움.
  Future<void> _drainPendingPushTap() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString('pendingPushTap');
      if (raw == null || raw.isEmpty) return;
      await prefs.remove('pendingPushTap');
      _logDeeplink('native_payload', detail: raw);
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return;
      final data = decoded.map<String, dynamic>(
        (k, v) => MapEntry(k.toString(), v),
      );
      final intent = PushDeeplink.fromMap(data);
      _logDeeplink('native_intent',
          detail: intent == null
              ? 'parse_failed'
              : 'kind=${intent.kind} scene=${intent.sceneId} content=${intent.contentId}');
      if (intent != null) {
        ref.read(pushDeeplinkProvider.notifier).set(intent);
      }
    } catch (e) {
      // ignore: discarded_futures
      _logDeeplink('native_drain_error', detail: '$e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(appRouterProvider);
    final themeMode = ref.watch(themeModeProvider).valueOrNull ?? ThemeMode.dark;
    // 표시 언어 — 사용자가 설정에서 명시적으로 고른 값이 있으면 그걸로 강제,
    // system이면 null → Flutter가 supportedLocales 중 디바이스 언어로 매칭.
    final localeOption =
        ref.watch(appLocaleProvider).valueOrNull ?? AppLocaleOption.system;

    // 첫 frame 직후 + 이후 auth/profile 변동 때마다 splash 제거 조건 평가.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _maybeRemoveSplash(ref);
    });
    ref.listen(isLoggedInProvider, (_, _) => _maybeRemoveSplash(ref));
    ref.listen(myProfileProvider, (_, _) => _maybeRemoveSplash(ref));

    // 로그인 세션이 생기면 push 토큰 등록 시도. session이 사라지면(로그아웃)
    // 현재 디바이스 토큰 정리.
    ref.listen(
      authViewModelProvider.select((s) => s.session?.user.id),
      (prev, next) {
        if (prev == null && next != null) {
          // ignore: discarded_futures
          ref.read(pushServiceProvider).ensureRegistered();
        } else if (prev != null && next == null) {
          // ignore: discarded_futures
          ref.read(pushServiceProvider).clearForCurrentDevice();
        }
      },
    );
    // build 첫 frame에서 이미 로그인된 상태면 즉시 시도.
    final initialUserId = ref.read(
      authViewModelProvider.select((s) => s.session?.user.id),
    );
    if (initialUserId != null) {
      // ignore: discarded_futures
      ref.read(pushServiceProvider).ensureRegistered();
    }

    // 로그인/로그아웃 시 잠금 상태 초기화 — 비밀번호 분실 복구 흐름의 핵심.
    // 사용자가 PIN을 잊어 로그아웃→재로그인하면 잠금이 자동 OFF로 풀린다.
    // 일반 로그아웃 후 재로그인도 마찬가지(spec).
    ref.listen(
      authViewModelProvider.select((s) => s.session?.user.id),
      (prev, next) {
        if (prev != next) {
          // ignore: discarded_futures
          ref.read(lockViewModelProvider.notifier).resetForAuthChange();
        }
      },
    );

    // RevenueCat app_user_id를 Supabase auth.uid와 동기화. webhook의
    // `app_user_id` 매핑이 이 id 기준이라 인증 직후 logIn 해야 자기 구매가
    // 자기 profile에 반영됨. 로그아웃 시 logOut.
    ref.listen(
      authViewModelProvider.select((s) => s.session?.user.id),
      (prev, next) {
        final repo = ref.read(purchasesRepositoryProvider);
        if (next != null && next != prev) {
          developer.log('auth->rc logIn transition', name: 'rc');
          // ignore: discarded_futures
          repo.logIn(next);
        } else if (prev != null && next == null) {
          developer.log('auth->rc logOut transition', name: 'rc');
          // ignore: discarded_futures
          repo.logOut();
        }
      },
    );
    if (initialUserId != null) {
      developer.log('auth->rc initial logIn', name: 'rc');
      // ignore: discarded_futures
      ref.read(purchasesRepositoryProvider).logIn(initialUserId);
    }

    return MaterialApp.router(
      onGenerateTitle: (context) => AppLocalizations.of(context).appTitle,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: themeMode,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: localeOption.toLocale(),
      routerConfig: router,
      // 라우터 child를 LockOverlay로 감싸 isLocked=true일 때 challenge 노출.
      builder: (context, child) {
        return LockOverlay(child: child ?? const SizedBox.shrink());
      },
    );
  }
}
