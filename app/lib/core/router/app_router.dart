import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/home/home_view.dart';

/// 앱의 라우트 경로. 문자열 리터럴은 여기서만 관리하고 화면 이동 시 이 상수만 참조.
class AppRoutes {
  AppRoutes._();
  static const home = '/';
}

/// GoRouter 인스턴스를 Riverpod provider로 노출. Supabase 세션 등 인증 redirect는
/// 향후 여기서 `refreshListenable` / `redirect`로 연결한다.
final appRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: AppRoutes.home,
    routes: [
      GoRoute(
        path: AppRoutes.home,
        name: 'home',
        builder: (context, state) => const HomeView(),
      ),
    ],
  );
});
