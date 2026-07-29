import 'dart:async';
import 'dart:convert';

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
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/locale/locale_provider.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/theme_provider.dart';
import 'features/auth/auth_view_model.dart';
import 'features/couple/couple_view_model.dart';
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

/// Sentry DSN — write-only 공개 값이라 클라 임베드 안전(다른 공개 토큰과 동일
/// 컨벤션). 하드코딩해 빌드 때 dart-define 누락으로 에러 수집이 조용히 꺼지는
/// 사고를 막는다. 실제 활성화는 release 빌드에서만(main의 kReleaseMode 게이트).
const sentryDsn =
    'https://e869f47c4791a39abe3acce046b53f26@o4511484750462976.ingest.us.sentry.io/4511484752101376';

Future<void> main() async {
  // 잡히지 않은 Flutter/Dart 예외를 Sentry로 수집해 유저 문의 시 역추적한다.
  // release 빌드에서만 전송(개발 중 핫리로드 예외·테스트 throw가 쿼터를 먹지
  // 않게). debug/profile에선 DSN을 비워 비활성. SentryFlutter.init이
  // FlutterError.onError + PlatformDispatcher.onError + runZonedGuarded를 모두
  // 설정하므로, 부트스트랩을 appRunner 안에서 돌려 초기화 단계 예외까지 캡처.
  await SentryFlutter.init(
    (options) {
      options.dsn = kReleaseMode ? sentryDsn : '';
      options.environment = kReleaseMode ? 'production' : 'development';
      // 에러만 수집 — 퍼포먼스 트레이싱은 끔(비용/노이즈 절감).
      options.tracesSampleRate = 0;
      // PII 최소화: IP 등 기본 PII 자동수집 끔. 유저는 우리가 id만 명시 부착.
      options.sendDefaultPii = false;
    },
    appRunner: _bootstrap,
  );
}

Future<void> _bootstrap() async {
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
  // Android도 iOS처럼 상태바/내비바 뒤로 콘텐츠가 깔리는 edge-to-edge. 이게
  // 없으면 안드로이드가 상태바를 불투명 기본색으로 직접 그려 상단 그라데이션이
  // 상태바 밑에서 끊긴다(iOS는 항상 edge-to-edge라 문제 없었음). 실제 상태바/
  // 내비바 투명 처리는 ScenesApp builder의 AnnotatedRegion에서 테마에 맞춰 적용.
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
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
      try {
        final decoded = jsonDecode(raw);
        if (decoded is! Map) return null;
        final data = decoded.map<String, dynamic>(
          (k, v) => MapEntry(k.toString(), v),
        );
        final intent = PushDeeplink.fromMap(data);
        if (intent != null) {
          ref.read(pushDeeplinkProvider.notifier).set(intent);
        }
      } catch (e, st) {
        // ignore: discarded_futures
        Sentry.captureException(e, stackTrace: st);
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
    // 콜드 스타트: 종료 상태에서 알림 탭 → getInitialMessage()가 한 번 반환.
    FirebaseMessaging.instance.getInitialMessage().then((msg) {
      if (msg == null) return;
      final intent = PushDeeplink.fromRemote(msg);
      if (intent != null) {
        ref.read(pushDeeplinkProvider.notifier).set(intent);
      }
    }).catchError((e, st) {
      // ignore: discarded_futures
      Sentry.captureException(e, stackTrace: st);
    });

    // 백그라운드: 떠있는 상태에서 알림 탭 → onMessageOpenedApp 스트림.
    _onMessageOpenedSub = FirebaseMessaging.onMessageOpenedApp.listen((msg) {
      final intent = PushDeeplink.fromRemote(msg);
      if (intent != null) {
        ref.read(pushDeeplinkProvider.notifier).set(intent);
      }
    }, onError: (e, st) {
      // ignore: discarded_futures
      Sentry.captureException(e, stackTrace: st);
    });
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
        // 파트너가 백그라운드 동안 탈퇴/연결 해지했을 수 있음 → active couple
        // 강제 refetch. couple이 사라졌으면 라우터 redirect가 pairing으로 이동.
        // ignore: discarded_futures
        ref.read(activeCoupleProvider.notifier).refresh();
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
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return;
      final data = decoded.map<String, dynamic>(
        (k, v) => MapEntry(k.toString(), v),
      );
      final intent = PushDeeplink.fromMap(data);
      if (intent != null) {
        ref.read(pushDeeplinkProvider.notifier).set(intent);
      }
    } catch (e, st) {
      // ignore: discarded_futures
      Sentry.captureException(e, stackTrace: st);
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
        // Sentry 유저 컨텍스트 — 문의 인입 시 user id로 에러를 역추적. id만
        // 부착하고 이메일 등 PII는 넣지 않는다(필요 시 Supabase에서 id로 조회).
        // ignore: discarded_futures
        Sentry.configureScope(
          (scope) => scope.setUser(next == null ? null : SentryUser(id: next)),
        );
        final repo = ref.read(purchasesRepositoryProvider);
        if (next != null && next != prev) {
          // ignore: discarded_futures
          repo.logIn(next);
        } else if (prev != null && next == null) {
          // ignore: discarded_futures
          repo.logOut();
        }
      },
    );
    if (initialUserId != null) {
      // ignore: discarded_futures
      Sentry.configureScope(
        (scope) => scope.setUser(SentryUser(id: initialUserId)),
      );
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
        // 상태바/내비바를 투명으로 만들어 상단 그라데이션이 그 뒤까지 이어지게
        // 한다(edge-to-edge). AppBar 없는 화면(홈 등)까지 커버하려고 여기 root에
        // 건다. 아이콘 밝기는 현재 테마 밝기에 맞춰 반전.
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return AnnotatedRegion<SystemUiOverlayStyle>(
          value: SystemUiOverlayStyle(
            statusBarColor: Colors.transparent,
            statusBarIconBrightness:
                isDark ? Brightness.light : Brightness.dark,
            statusBarBrightness: isDark ? Brightness.dark : Brightness.light,
            systemNavigationBarColor: Colors.transparent,
            systemNavigationBarIconBrightness:
                isDark ? Brightness.light : Brightness.dark,
            systemNavigationBarContrastEnforced: false,
          ),
          child: LockOverlay(child: child ?? const SizedBox.shrink()),
        );
      },
    );
  }
}
