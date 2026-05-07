import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../couple/couple_view_model.dart';

/// 페어링 직후 한 번 노출되는 noti-prompt 화면을 보여줄지 여부.
///
/// 조건 (모두 true이면 보여줌):
///  - active couple이 존재 (페어링 완료)
///  - OS 권한 status가 `notDetermined` (한 번도 묻지 않음)
///  - 로컬 SharedPreferences flag(`noti_prompt_shown`)가 false
///
/// "보여줄 필요 있음 = true / 없음 = false" 형태로 return. 라우터의 redirect가
/// 이 값을 보고 /noti-prompt로 보낼지 /home으로 보낼지 결정.
class NotiPromptStateNotifier extends AsyncNotifier<bool> {
  static const _flagKey = 'noti_prompt_shown';

  @override
  Future<bool> build() async {
    final activeCouple = ref.watch(activeCoupleProvider).valueOrNull;
    if (activeCouple == null) return false;

    final prefs = await SharedPreferences.getInstance();
    final shown = prefs.getBool(_flagKey) ?? false;
    if (shown) return false;

    final settings =
        await FirebaseMessaging.instance.getNotificationSettings();
    return settings.authorizationStatus == AuthorizationStatus.notDetermined;
  }

  /// 사용자가 Allow/Skip 어느 쪽이든 선택 후 호출 — 더는 화면을 보여주지
  /// 않도록 로컬 flag 세팅 + state 갱신해 라우터가 즉시 home으로 보내게.
  Future<void> markShown() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_flagKey, true);
    state = const AsyncValue.data(false);
  }
}

final notiPromptStateProvider =
    AsyncNotifierProvider<NotiPromptStateNotifier, bool>(
  NotiPromptStateNotifier.new,
);
