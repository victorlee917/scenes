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
///   1. 로그인 직후 `bootstrap()` 호출 — 이미 OS 권한이 authorized면 token만
///      등록. 권한 요청은 onboarding의 noti-prompt 화면에서 별도로.
///   2. noti-prompt 화면이 `requestPermissionFromOnboarding()` 호출 시 OS 다이
///      얼로그 → 결과에 따라 row init + token 등록.
///   3. token rotation은 onTokenRefresh로 자동 갱신.
///
/// 에러는 user-flow 막지 않도록 모두 swallow + debugPrint.
class PushService {
  PushService(this._supabase, this._prefsRepo);

  final SupabaseClient _supabase;
  final NotificationPreferencesRepository _prefsRepo;

  StreamSubscription<String>? _refreshSub;
  bool _bootstrapped = false;

  /// 로그인 상태일 때 호출. OS 권한이 이미 authorized이면 token 등록까지 진행.
  /// notDetermined/denied면 token 등록만 skip하고 noti-prompt 화면이 권한
  /// 요청을 owner. 한 번만 실행, 이후 호출은 noop.
  Future<void> bootstrap() async {
    if (_bootstrapped) return;
    _bootstrapped = true;
    final fcm = FirebaseMessaging.instance;

    try {
      final settings = await fcm.getNotificationSettings();
      final authorized =
          settings.authorizationStatus == AuthorizationStatus.authorized ||
              settings.authorizationStatus == AuthorizationStatus.provisional;
      if (!authorized) {
        // 권한 미허용 상태에서는 token 등록 skip — APNs token 자체도 안 떨어
        // 짐. 사용자가 noti-prompt에서 Allow 누르면 그때 또는 시스템 설정에서
        // 켜고 돌아왔을 때 다시 호출되는 경로로 처리.
        return;
      }
      await _registerTokenAndPrefs(fcm);
    } catch (e) {
      debugPrint('PushService bootstrap failed: $e');
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
    // 처음 동의 사용자는 모든 카테고리 default-on. row 이미 있으면 노op.
    try {
      await _prefsRepo.initializeIfMissing(allOn: true);
    } catch (e) {
      debugPrint('PushService prefs init failed: $e');
    }

    // iOS는 APNs token attach된 뒤에야 FCM token 발급 — 시뮬레이터엔 APNs
    // 미지원이라 null 나올 수 있고 정상.
    if (Platform.isIOS) {
      await fcm.getAPNSToken();
    }
    final token = await fcm.getToken();
    if (token != null) {
      await _saveToken(token);
    }
    _refreshSub?.cancel();
    _refreshSub = fcm.onTokenRefresh.listen(_saveToken);
  }

  Future<void> _saveToken(String token) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return;
    final platform = Platform.isIOS ? 'ios' : 'android';
    try {
      // token이 unique라 다른 user에 등록돼있던 경우(디바이스 양도 등) user_id
      // 갱신이 필요. onConflict: 'token'으로 upsert.
      await _supabase.from('device_tokens').upsert(
        {
          'user_id': userId,
          'token': token,
          'platform': platform,
          'last_seen_at': DateTime.now().toUtc().toIso8601String(),
        },
        onConflict: 'token',
      );
    } catch (e) {
      debugPrint('PushService save token failed: $e');
    }
  }

  /// 로그아웃 직전 호출 — 이 디바이스의 토큰 행 삭제. 안 하면 새 사용자가
  /// 같은 디바이스에 로그인할 때 onConflict로 자동 갱신되긴 하지만, 명시적
  /// 정리가 깔끔.
  Future<void> clearForCurrentDevice() async {
    try {
      final token = await FirebaseMessaging.instance.getToken();
      if (token == null) return;
      await _supabase.from('device_tokens').delete().eq('token', token);
    } catch (e) {
      debugPrint('PushService clear failed: $e');
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
