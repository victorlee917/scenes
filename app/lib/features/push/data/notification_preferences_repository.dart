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
  /// [allOn]이 true면 모든 카테고리(partner/anniversary/marketing)를 true로
  /// 만들어 "처음 푸시 동의 시 전부 on" 정책을 구현. 백엔드 컬럼 default는
  /// marketing=false라 명시적으로 override 필요.
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
          'marketing_enabled': allOn,
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
