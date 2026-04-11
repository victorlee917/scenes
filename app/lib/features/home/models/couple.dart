import 'package:flutter/foundation.dart';

/// 두 사람의 관계 메타. 홈 상단 strip에만 사용되는 최소 정보만 보유.
/// 상세 프로필(이름, 닉네임 등)은 Couple Detail 화면 모델에서 다룬다.
@immutable
class Couple {
  const Couple({
    required this.partnerAImageUrl,
    required this.partnerBImageUrl,
    required this.sinceDate,
  });

  final String partnerAImageUrl;
  final String partnerBImageUrl;

  /// 사귀기 시작한 날. D-Day 계산의 기준.
  final DateTime sinceDate;

  /// [now] 기준으로 `sinceDate` 이후 경과일. D+0 부터 시작.
  int dDayFrom(DateTime now) {
    final a = DateTime(sinceDate.year, sinceDate.month, sinceDate.day);
    final b = DateTime(now.year, now.month, now.day);
    return b.difference(a).inDays;
  }
}
