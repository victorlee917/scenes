import 'package:flutter/foundation.dart';

/// 두 사람의 관계 메타. 홈 상단 strip에만 사용되는 최소 정보만 보유.
/// 상세 프로필(이름, 닉네임 등)은 Couple Detail 화면 모델에서 다룬다.
@immutable
class Couple {
  Couple({
    required this.name,
    required this.partnerAName,
    required this.partnerBName,
    required this.partnerAImageUrl,
    required this.partnerBImageUrl,
    required this.pairedAt,
    DateTime? sinceDate,
  }) : sinceDate = sinceDate ?? pairedAt;

  final String name;
  final String partnerAName;
  final String partnerBName;
  final String partnerAImageUrl;
  final String partnerBImageUrl;

  /// 페어링된 날짜. 시스템이 자동 설정.
  final DateTime pairedAt;

  /// 유저가 설정한 기념일. 기본값은 pairedAt.
  final DateTime sinceDate;

  /// [now] 기준으로 `sinceDate` 이후 경과일. D+0 부터 시작.
  int dDayFrom(DateTime now) {
    final a = DateTime(sinceDate.year, sinceDate.month, sinceDate.day);
    final b = DateTime(now.year, now.month, now.day);
    return b.difference(a).inDays;
  }

  Couple copyWith({
    String? name,
    String? partnerAName,
    String? partnerBName,
    String? partnerAImageUrl,
    String? partnerBImageUrl,
    DateTime? pairedAt,
    DateTime? sinceDate,
  }) =>
      Couple(
        name: name ?? this.name,
        partnerAName: partnerAName ?? this.partnerAName,
        partnerBName: partnerBName ?? this.partnerBName,
        partnerAImageUrl: partnerAImageUrl ?? this.partnerAImageUrl,
        partnerBImageUrl: partnerBImageUrl ?? this.partnerBImageUrl,
        pairedAt: pairedAt ?? this.pairedAt,
        sinceDate: sinceDate ?? this.sinceDate,
      );
}
