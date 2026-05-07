import 'package:flutter/foundation.dart';

/// `couple_invites` 테이블 row 1:1.
///
/// 코드 자체는 짧은 랜덤 문자열(0002 마이그레이션의 check 6–12자). 만료
/// 시간(`expiresAt`)은 24h 기본. 페어링 화면은 자기 invite의 만료 카운트
/// 다운을 표시하고, 파트너가 redeem하면 [redeemedAt]이 채워진다.
@immutable
class CoupleInvite {
  const CoupleInvite({
    required this.id,
    required this.code,
    required this.inviterId,
    required this.createdAt,
    required this.expiresAt,
    this.redeemedAt,
    this.redeemedBy,
    this.coupleId,
  });

  final String id;
  final String code;
  final String inviterId;
  final DateTime createdAt;
  final DateTime expiresAt;
  final DateTime? redeemedAt;
  final String? redeemedBy;
  final String? coupleId;

  bool get isExpired => DateTime.now().isAfter(expiresAt);
  bool get isRedeemed => redeemedAt != null;
  bool get isActive => !isExpired && !isRedeemed;

  factory CoupleInvite.fromJson(Map<String, dynamic> json) => CoupleInvite(
        id: json['id'] as String,
        code: json['code'] as String,
        inviterId: json['inviter_id'] as String,
        createdAt: DateTime.parse(json['created_at'] as String),
        expiresAt: DateTime.parse(json['expires_at'] as String),
        redeemedAt: json['redeemed_at'] == null
            ? null
            : DateTime.parse(json['redeemed_at'] as String),
        redeemedBy: json['redeemed_by'] as String?,
        coupleId: json['couple_id'] as String?,
      );
}
