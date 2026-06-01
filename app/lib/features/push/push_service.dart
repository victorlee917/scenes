import 'dart:async';
import 'dart:io';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'data/notification_preferences_repository.dart';

/// FCM 토큰 등록·갱신 서비스.
///
/// 흐름:
///   1. 로그인 직후 / 앱 resume 시 [ensureRegistered] 호출 — 권한 OK이고
///      토큰 미등록이면 등록 시도. 성공 후엔 noop.
///   2. noti-prompt 화면이 [requestPermissionFromOnboarding] 호출 시 OS
///      다이얼로그 → 결과에 따라 즉시 등록.
///   3. token rotation은 onTokenRefresh로 자동 갱신.
///
/// **재시도 메커니즘**: 첫 launch 시 iOS APNs 연결이 백그라운드로 establish되
/// 느라 `getAPNSToken()`이 잠시 null인 케이스가 있어. polling으로 5초 대기 +
/// 그래도 null이면 [ensureRegistered]를 그대로 두고 다음 호출(앱 resume)에서
/// 재시도. 영구 락(_bootstrapped) 패턴은 폐기.
class PushService {
  PushService(this._supabase, this._prefsRepo);

  final SupabaseClient _supabase;
  final NotificationPreferencesRepository _prefsRepo;

  StreamSubscription<String>? _refreshSub;
  // 한 번 토큰을 저장 성공한 뒤로는 더 안 시도. 같은 토큰을 매 resume마다
  // upsert하지 않아도 됨 (onTokenRefresh가 변경 감지).
  bool _tokenSaved = false;
  // 동시 호출 race 방지.
  Future<void>? _inflight;

  /// 권한 OK + 토큰 미등록일 때 등록 시도. 실패해도 락 안 걸림 → 다음 resume
  /// 등에서 재시도 가능.
  Future<void> ensureRegistered() async {
    if (_tokenSaved) return;
    final pending = _inflight;
    if (pending != null) return pending;

    final task = () async {
      final fcm = FirebaseMessaging.instance;
      try {
        final settings = await fcm.getNotificationSettings();
        final auth = settings.authorizationStatus;
        final authorized = auth == AuthorizationStatus.authorized ||
            auth == AuthorizationStatus.provisional;
        if (!authorized) return;
        await _registerTokenAndPrefs(fcm);
      } catch (e) {
        debugPrint('PushService ensureRegistered failed: $e');
      }
    }();
    _inflight = task;
    try {
      await task;
    } finally {
      _inflight = null;
    }
  }

  /// noti-prompt 화면이 호출 — OS 다이얼로그 띄우고 결과 status 반환.
  /// authorized/provisional이면 token 등록 + noti pref row init까지.
  Future<AuthorizationStatus> requestPermissionFromOnboarding() async {
    final fcm = FirebaseMessaging.instance;
    final settings = await fcm.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
    final status = settings.authorizationStatus;
    if (status == AuthorizationStatus.authorized ||
        status == AuthorizationStatus.provisional) {
      try {
        await _registerTokenAndPrefs(fcm);
      } catch (e) {
        debugPrint('PushService post-onboarding register failed: $e');
      }
    }
    return status;
  }

  Future<void> _registerTokenAndPrefs(FirebaseMessaging fcm) async {
    try {
      await _prefsRepo.initializeIfMissing(allOn: true);
    } catch (e) {
      debugPrint('PushService prefs init failed: $e');
    }

    if (Platform.isIOS) {
      // iOS: APNs token attach 후에야 FCM token 발급 가능. 첫 launch 시 즉시
      // 호출하면 null이 떨어지는 케이스가 흔해서 최대 5초 폴링.
      String? apns;
      for (var i = 0; i < 10; i++) {
        try {
          apns = await fcm.getAPNSToken();
        } catch (_) {
          apns = null;
        }
        if (apns != null) break;
        await Future<void>.delayed(const Duration(milliseconds: 500));
      }
      if (apns == null) {
        debugPrint(
          'PushService: APNs token still null after 5s — abort, will retry on next resume',
        );
        return;
      }
    }

    String? token;
    try {
      token = await fcm.getToken();
    } catch (e) {
      debugPrint('PushService getToken failed: $e');
    }
    if (token == null || token.isEmpty) {
      debugPrint(
        'PushService: FCM getToken returned null — will retry on next resume',
      );
      return;
    }
    await _saveToken(token);
    _tokenSaved = true;

    _refreshSub?.cancel();
    _refreshSub = fcm.onTokenRefresh.listen((newToken) async {
      // ignore: discarded_futures
      _saveToken(newToken);
    });
  }

  Future<void> _saveToken(String token) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return;
    final platform = Platform.isIOS ? 'ios' : 'android';
    try {
      // 직접 upsert 대신 register_device_token RPC를 호출 — token이 다른
      // user에 등록돼 있던 경우 RLS UPDATE 정책(USING auth.uid() = old.user_id)
      // 에 막혀 거부되는 race를 우회한다 (RPC는 SECURITY DEFINER로 다른 user
      // 소유 row를 먼저 delete 후 insert/upsert).
      await _supabase.rpc(
        'register_device_token',
        params: {
          'p_token': token,
          'p_platform': platform,
        },
      );
    } catch (e) {
      debugPrint('PushService save token failed: $e');
    }
  }

  /// 로그아웃 직전 호출 — 이 디바이스의 토큰 행 삭제 + 다음 로그인 때 재등록
  /// 가능하도록 _tokenSaved 리셋.
  Future<void> clearForCurrentDevice() async {
    try {
      final token = await FirebaseMessaging.instance.getToken();
      if (token == null) return;
      await _supabase.from('device_tokens').delete().eq('token', token);
    } catch (e) {
      debugPrint('PushService clear failed: $e');
    } finally {
      _tokenSaved = false;
    }
  }

  void dispose() {
    _refreshSub?.cancel();
  }
}

final pushServiceProvider = Provider<PushService>((ref) {
  final service = PushService(
    Supabase.instance.client,
    ref.read(notificationPreferencesRepositoryProvider),
  );
  ref.onDispose(service.dispose);
  return service;
});
