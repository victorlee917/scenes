import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/home/home_view.dart';
import '../../features/home/home_view_model.dart';
import '../../features/onboarding/onboarding_screen.dart';
import '../../features/onboarding/profile_setup_screen.dart';
import '../../features/pairing/pairing_screen.dart';

class AppRoutes {
  AppRoutes._();
  static const home = '/';
  static const onboarding = '/onboarding';
  static const profileSetup = '/profile-setup';
  static const pairing = '/pairing';
}

final appRouterProvider = Provider<GoRouter>((ref) {
  final isLoggedIn = ref.watch(
    homeViewModelProvider.select((s) => s.isLoggedIn),
  );
  final hasProfile = ref.watch(
    homeViewModelProvider.select((s) => s.hasProfile),
  );
  final isPaired = ref.watch(
    homeViewModelProvider.select((s) => s.isPaired),
  );

  String? targetRoute() {
    if (!isLoggedIn) return AppRoutes.onboarding;
    if (!hasProfile) return AppRoutes.profileSetup;
    if (!isPaired) return AppRoutes.pairing;
    return AppRoutes.home;
  }

  return GoRouter(
    initialLocation: AppRoutes.home,
    redirect: (context, state) {
      final target = targetRoute();
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
    ],
  );
});
