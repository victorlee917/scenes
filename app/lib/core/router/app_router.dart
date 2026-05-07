import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/auth_view_model.dart';
import '../../features/couple/couple_view_model.dart';
import '../../features/home/home_view.dart';
import '../../features/onboarding/noti_prompt_screen.dart';
import '../../features/onboarding/onboarding_screen.dart';
import '../../features/onboarding/profile_setup_screen.dart';
import '../../features/pairing/pairing_screen.dart';
import '../../features/profile/profile_view_model.dart';
import '../../features/push/noti_prompt_state.dart';

class AppRoutes {
  AppRoutes._();
  static const home = '/';
  static const onboarding = '/onboarding';
  static const profileSetup = '/profile-setup';
  static const pairing = '/pairing';
  static const notiPrompt = '/noti-prompt';
}

/// router 재평가를 트리거하는 Listenable. auth/profile 상태가 변하면 notify해서
/// GoRouter의 redirect가 다시 실행되도록 함.
///
/// **중요**: GoRouter 인스턴스 자체는 Provider rebuild로 재생성하면 안 됨.
/// 재생성하면 navigation stack(예: 사용자가 push한 ProfileScreen 등)이 통째로
/// 날아간다. 대신 같은 인스턴스에 refresh listenable로 redirect만 다시 평가.
class _RouterRefreshNotifier extends ChangeNotifier {
  _RouterRefreshNotifier(this._ref) {
    _ref.listen(isLoggedInProvider, (_, _) => notifyListeners());
    _ref.listen(myProfileProvider, (_, _) => notifyListeners());
    _ref.listen(activeCoupleProvider, (_, _) => notifyListeners());
    _ref.listen(notiPromptStateProvider, (_, _) => notifyListeners());
  }

  final Ref _ref;
}

final appRouterProvider = Provider<GoRouter>((ref) {
  final refresh = _RouterRefreshNotifier(ref);
  ref.onDispose(refresh.dispose);

  String? targetRoute() {
    final session =
        ref.read(authViewModelProvider.select((s) => s.session));
    if (session == null) return AppRoutes.onboarding;

    final myProfileAsync = ref.read(myProfileProvider);
    // 다음 두 경우는 redirect 보류 — 미온보딩으로 오판해서 profile-setup이
    // 깜빡이는 걸 방지:
    //  1. 한 번도 로드된 적 없음 (`!hasValue`).
    //  2. AsyncLoading.copyWithPrevious — 재로그인 직후 `myProfileProvider`
    //     가 새 build를 시작했지만 아직 stale value(이전 세션의 null)를 들고
    //     있는 한 프레임. 이 때 `hasValue == true`이라 1번 가드를 통과해
    //     profile-setup으로 잘못 분기되는 race를 막는다.
    if (!myProfileAsync.hasValue || myProfileAsync.isLoading) return null;
    final profile = myProfileAsync.value;
    // 추가 안전망: profile이 있는데 user id가 현재 세션과 다르면 직전 세션의
    // stale data — 새 build를 기다림.
    if (profile != null && profile.id != session.user.id) return null;
    // deleted_at이 박힌 profile은 fresh user처럼 onboarding부터 다시 시작 —
    // profile-setup 완료 시 deleted_at이 null로 풀리면서 재가입 완성. 옛
    // couple은 abandoned로 영구 종료라 재페어 불가는 그대로.
    if (profile == null || !profile.isOnboarded || profile.isDeleted) {
      return AppRoutes.profileSetup;
    }

    // active couple도 동일한 stale race를 피하기 위해 isLoading까지 본다.
    final coupleAsync = ref.read(activeCoupleProvider);
    if (!coupleAsync.hasValue || coupleAsync.isLoading) return null;
    if (coupleAsync.value == null) return AppRoutes.pairing;

    // 페어링 직후 한 번 노출되는 noti 권한 유도 화면. 이미 권한을 한번 묻거나
    // 로컬 flag가 세팅됐으면 false를 돌려줘 home으로. 로딩 중이면 보류.
    final notiPromptAsync = ref.read(notiPromptStateProvider);
    if (!notiPromptAsync.hasValue || notiPromptAsync.isLoading) return null;
    if (notiPromptAsync.value == true) return AppRoutes.notiPrompt;
    return AppRoutes.home;
  }

  return GoRouter(
    initialLocation: AppRoutes.home,
    refreshListenable: refresh,
    redirect: (context, state) {
      final target = targetRoute();
      if (target == null) return null;
      if (state.matchedLocation != target) return target;
      return null;
    },
    routes: [
      GoRoute(
        path: AppRoutes.home,
        name: 'home',
        builder: (context, state) => const HomeView(),
      ),
      GoRoute(
        path: AppRoutes.onboarding,
        name: 'onboarding',
        builder: (context, state) => const OnboardingScreen(),
      ),
      GoRoute(
        path: AppRoutes.profileSetup,
        name: 'profile-setup',
        builder: (context, state) => const ProfileSetupScreen(),
      ),
      GoRoute(
        path: AppRoutes.pairing,
        name: 'pairing',
        builder: (context, state) => const PairingScreen(),
      ),
      GoRoute(
        path: AppRoutes.notiPrompt,
        name: 'noti-prompt',
        builder: (context, state) => const NotiPromptScreen(),
      ),
    ],
  );
});
