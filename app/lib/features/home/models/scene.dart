import 'package:flutter/foundation.dart';

/// 하나의 데이트(혹은 기념이 되는 순간)에 대응하는 기록 단위.
///
/// - 여러 날짜를 포함할 수 있음 (주말 여행, 연휴 등).
/// - Scene 내부에 다양한 미디어(사진/영상/영화/음악/책)가 들어가지만,
///   홈 화면 모델은 커버 이미지 한 장과 메타만 보유한다. 상세 미디어는
///   Scene Detail 화면에서 별도 모델로 다룬다.
@immutable
class Scene {
  const Scene({
    required this.id,
    required this.number,
    required this.title,
    required this.dates,
    required this.coverImageUrl,
  });

  final String id;

  /// 영구 번호. 로마 숫자로 표기되어 홈 카드에 노출.
  final int number;

  /// 사용자가 지은 Scene 타이틀. l10n 대상 아님(자유 입력).
  final String title;

  /// 이 Scene에 포함된 날짜들. 최소 1개, 순서 상관 없음(포맷 시 정렬).
  final List<DateTime> dates;

  /// 홈 카드에 쓰이는 커버 이미지. 현재는 네트워크 URL, 이후 Supabase
  /// Storage signed URL로 대체 예정.
  final String coverImageUrl;
}
