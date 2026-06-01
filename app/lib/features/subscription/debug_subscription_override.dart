import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// 디버그 전용 구독 오버라이드.
///
/// 시뮬레이터에서는 StoreKit이 상품을 못 불러와 실제 IAP 테스트가 불가능하다.
/// 그래서 지정된 테스트 계정에 한해 Settings에서 "강제 HD"를 켜 앱이 HD 구독
/// 상태처럼 동작하게 한다. [SubscriptionViewModel]이 이 값을 watch해 read 모델을
/// 덮어쓴다. 클라이언트 한정 오버라이드라 서버측 enforcement(업로드 용량 등)는
/// 우회하지 못한다 — UI 게이팅/상태 표시 테스트 용도.
const String kDebugSubscriptionEmail = 'victorlee917@gmail.com';

/// 현재 로그인 유저가 디버그 토글을 쓸 수 있는 계정인지.
bool canUseDebugSubscriptionToggle() {
  return Supabase.instance.client.auth.currentUser?.email ==
      kDebugSubscriptionEmail;
}

const _key = 'debug_force_hd';

/// "강제 HD" on/off 상태. SharedPreferences로 영속(앱 재시작 후에도 유지).
class DebugForceHdNotifier extends AsyncNotifier<bool> {
  @override
  Future<bool> build() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_key) ?? false;
  }

  Future<void> set(bool value) async {
    state = AsyncData(value);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_key, value);
  }
}

final debugForceHdProvider =
    AsyncNotifierProvider<DebugForceHdNotifier, bool>(
  DebugForceHdNotifier.new,
);
