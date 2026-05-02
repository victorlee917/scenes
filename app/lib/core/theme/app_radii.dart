import 'package:flutter/widgets.dart';

/// 앱 전반에서 재사용되는 모서리 반경 토큰.
///
/// 컴포넌트에서 `BorderRadius.circular(14)` 같은 매직 넘버를 직접 쓰는 대신
/// `AppRadii.md` 또는 `AppRadii.mdBorder`를 사용한다. 토큰은 중앙에서 한 번
/// 조정하면 전체 UI에 동일하게 반영된다.
class AppRadii {
  AppRadii._();

  /// 작은 칩, 인풋 등.
  static const double xs = 6;

  /// 일반적인 버튼·필드.
  static const double sm = 10;

  /// 컨텐츠 카드(미디어 타일 등) 기본값.
  static const double md = 14;

  /// 큰 카드 / 시트.
  static const double lg = 20;

  /// 모달 / 영웅 카드.
  static const double xl = 28;

  /// 바텀시트 등 화면 곡률에 맞추는 값. iPhone 기준 ~44pt.
  static const double sheet = 44;

  /// 시트 내부 요소. sheet − 내부 padding(20) = 24.
  static const double sheetInner = 24;

  // Pre-built `BorderRadius` 헬퍼. 컴포넌트에서 매번 새 인스턴스를
  // 만들지 않고 const 값을 재사용할 수 있다.
  static const BorderRadius xsBorder =
      BorderRadius.all(Radius.circular(xs));
  static const BorderRadius smBorder =
      BorderRadius.all(Radius.circular(sm));
  static const BorderRadius mdBorder =
      BorderRadius.all(Radius.circular(md));
  static const BorderRadius lgBorder =
      BorderRadius.all(Radius.circular(lg));
  static const BorderRadius xlBorder =
      BorderRadius.all(Radius.circular(xl));
  static const BorderRadius sheetBorder =
      BorderRadius.all(Radius.circular(sheet));
  static const BorderRadius sheetInnerBorder =
      BorderRadius.all(Radius.circular(sheetInner));
}
