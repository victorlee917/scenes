/// `couples` 테이블의 한 row.
///
/// 페어 소유 콘텐츠는 모두 [pairId]를 외래키로 참조한다 (memory:
/// `feedback_content_keyed_by_pair_id`). 상대방 프로필은 [CoupleWithPartner]에서
/// join해 함께 들고 다닌다.
class CoupleRecord {
  const CoupleRecord({
    required this.id,
    required this.pairId,
    required this.partnerAId,
    required this.partnerBId,
    required this.sinceDate,
    required this.status,
    required this.linkedAt,
  });

  final String id;
  final String pairId;
  final String partnerAId;
  final String partnerBId;
  final DateTime sinceDate;
  final String status; // 'active' | 'ended'
  final DateTime linkedAt;

  bool get isActive => status == 'active';

  /// 호출자 본인의 partner id (= 상대방).
  String partnerIdFor(String myId) =>
      myId == partnerAId ? partnerBId : partnerAId;

  factory CoupleRecord.fromJson(Map<String, dynamic> json) {
    return CoupleRecord(
      id: json['id'] as String,
      pairId: json['pair_id'] as String,
      partnerAId: json['partner_a_id'] as String,
      partnerBId: json['partner_b_id'] as String,
      sinceDate: DateTime.parse(json['since_date'] as String),
      status: json['status'] as String,
      linkedAt: DateTime.parse(json['linked_at'] as String),
    );
  }
}
