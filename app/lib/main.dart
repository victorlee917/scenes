import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:kakao_flutter_sdk_user/kakao_flutter_sdk_user.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/theme_provider.dart';
import 'features/auth/auth_view_model.dart';
import 'features/profile/profile_view_model.dart';
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
    loggingEnabled: true, // 디버그용. 운영 시 false 또는 제거.
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

class ScenesApp extends ConsumerWidget {
  const ScenesApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);
    final themeMode = ref.watch(themeModeProvider).valueOrNull ?? ThemeMode.dark;

    // 첫 frame 직후 + 이후 auth/profile 변동 때마다 splash 제거 조건 평가.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _maybeRemoveSplash(ref);
    });
    ref.listen(isLoggedInProvider, (_, _) => _maybeRemoveSplash(ref));
    ref.listen(myProfileProvider, (_, _) => _maybeRemoveSplash(ref));

    // 로그인 세션이 생기면 PushService.bootstrap() 호출. session이 사라지면
    // (로그아웃) 현재 디바이스 토큰 정리. ConsumerWidget의 build에서 listen
    // 사용해 한 번만 등록.
    ref.listen(
      authViewModelProvider.select((s) => s.session?.user.id),
      (prev, next) {
        if (prev == null && next != null) {
          // ignore: discarded_futures
          ref.read(pushServiceProvider).bootstrap();
        } else if (prev != null && next == null) {
          // ignore: discarded_futures
          ref.read(pushServiceProvider).clearForCurrentDevice();
        }
      },
    );
    // build 첫 frame에서 이미 로그인된 상태면 즉시 bootstrap. listen은 변화
    // 시점에만 트리거되므로 시작 직후 단발성 체크가 별도로 필요.
    final initialUserId = ref.read(
      authViewModelProvider.select((s) => s.session?.user.id),
    );
    if (initialUserId != null) {
      // ignore: discarded_futures
      ref.read(pushServiceProvider).bootstrap();
    }

    return MaterialApp.router(
      onGenerateTitle: (context) => AppLocalizations.of(context).appTitle,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: themeMode,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: const Locale('en'),
      routerConfig: router,
    );
  }
}
