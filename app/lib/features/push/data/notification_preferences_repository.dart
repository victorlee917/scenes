import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/notification_preferences.dart';

/// `notification_preferences` 테이블 read/write Repository.
/// RLS는 `auth.uid() = user_id` row만 허용.
class NotificationPreferencesRepository {
  NotificationPreferencesRepository(this._client);

  final SupabaseClient _client;

  String? get _myId => _client.auth.currentUser?.id;

  /// 본인 row. 없으면 null. (아직 한 번도 푸시 권한 부여 안 했으면 row가
  /// 없을 수 있음 — initializeIfMissing이 그걸 채움.)
  Future<NotificationPreferences?> getMy() async {
    final myId = _myId;
    if (myId == null) return null;
    final row = await _client
        .from('notification_preferences')
        .select()
        .eq('user_id', myId)
        .maybeSingle();
    if (row == null) return null;
    return NotificationPreferences.fromJson(row);
  }

  /// row가 없으면 default 값으로 insert. 이미 있으면 noop.
  ///
  /// [allOn]이 true면 **기능성** 알림(partner/anniversary)을 on으로 초기화 —
  /// "처음 푸시 동의 시 기능성 알림 on" 정책. **마케팅(앱 소식)은 옵트인이라
  /// [allOn]과 무관하게 항상 off**로 둔다(GDPR·스토어 정책상 마케팅은 사용자가
  /// 직접 켜야 함). DB 컬럼 default(marketing=false) 및 가입 트리거와도 일치.
  Future<NotificationPreferences> initializeIfMissing({bool allOn = true}) async {
    final myId = _myId;
    if (myId == null) {
      throw StateError('Cannot initialize prefs while signed out.');
    }
    final existing = await getMy();
    if (existing != null) return existing;
    final inserted = await _client
        .from('notification_preferences')
        .insert({
          'user_id': myId,
          'partner_activity_enabled': allOn,
          'anniversary_reminders_enabled': allOn,
          // 마케팅은 옵트인 — 자동 on 안 함.
          'marketing_enabled': false,
        })
        .select()
        .single();
    return NotificationPreferences.fromJson(inserted);
  }

  /// 전체 prefs를 한 번에 upsert. 부분 update가 다른 컬럼을 default로 reset
  /// 하는 위험을 피하려고 항상 full row.
  Future<NotificationPreferences> upsert(NotificationPreferences prefs) async {
    final updated = await _client
        .from('notification_preferences')
        .upsert(prefs.toUpsertJson())
        .select()
        .single();
    return NotificationPreferences.fromJson(updated);
  }
}

final notificationPreferencesRepositoryProvider =
    Provider<NotificationPreferencesRepository>((ref) {
  return NotificationPreferencesRepository(Supabase.instance.client);
});
