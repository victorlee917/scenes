import 'package:flutter/foundation.dart';

/// `notification_preferences` 테이블 row 1:1.
///
/// `anniversary_reminders_enabled`는 백엔드 컬럼은 유지하지만 오픈 스펙에서
/// UI 노출 X. 향후 anniversary 기능 도입 시 토글 추가.
@immutable
class NotificationPreferences {
  const NotificationPreferences({
    required this.userId,
    required this.partnerActivityEnabled,
    required this.anniversaryRemindersEnabled,
    required this.marketingEnabled,
  });

  final String userId;
  final bool partnerActivityEnabled;
  final bool anniversaryRemindersEnabled;
  final bool marketingEnabled;

  NotificationPreferences copyWith({
    bool? partnerActivityEnabled,
    bool? anniversaryRemindersEnabled,
    bool? marketingEnabled,
  }) =>
      NotificationPreferences(
        userId: userId,
        partnerActivityEnabled:
            partnerActivityEnabled ?? this.partnerActivityEnabled,
        anniversaryRemindersEnabled:
            anniversaryRemindersEnabled ?? this.anniversaryRemindersEnabled,
        marketingEnabled: marketingEnabled ?? this.marketingEnabled,
      );

  factory NotificationPreferences.fromJson(Map<String, dynamic> json) =>
      NotificationPreferences(
        userId: json['user_id'] as String,
        partnerActivityEnabled: json['partner_activity_enabled'] as bool,
        anniversaryRemindersEnabled:
            json['anniversary_reminders_enabled'] as bool,
        marketingEnabled: json['marketing_enabled'] as bool,
      );

  Map<String, dynamic> toUpsertJson() => {
        'user_id': userId,
        'partner_activity_enabled': partnerActivityEnabled,
        'anniversary_reminders_enabled': anniversaryRemindersEnabled,
        'marketing_enabled': marketingEnabled,
      };
}
