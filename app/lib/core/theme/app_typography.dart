import 'package:flutter/material.dart';

/// 타이포그래피 토큰.
///
/// 규칙:
/// - **Playfair Display** (en) / **Hahmlet** (ko) — 디스플레이 전용.
///   `display(size, locale:)` 호출 시 로케일에 따라 자동 선택.
/// - **Pretendard** — 본문·메타 전체. 한/영 모두 커버하는 variable 폰트.
/// - **모노는 사용 금지** — 톤이 기술적이라 제외.
///
/// 모든 폰트는 `fonts/`에 번들 — 런타임 fetch 없음(첫 진입 OS 폰트 깜빡임
/// 방지). 사이즈는 호출부에서 결정하고, 여기는 family·weight·italic 축만 고정.
class AppTypography {
  AppTypography._();

  static final RegExp _hangulRegex = RegExp(r'[가-힯]');

  /// Display — Scene 타이틀·로고 등. [text]에 한글이 포함되어 있으면
  /// Hahmlet, 아니면 Playfair Display를 사용한다.
  static TextStyle display(double size, {String? text}) {
    if (text != null && _hangulRegex.hasMatch(text)) {
      return TextStyle(
        fontFamily: 'Hahmlet',
        fontSize: size,
        fontWeight: FontWeight.w400,
        height: 1.1,
        letterSpacing: -0.2,
      );
    }
    return TextStyle(
      fontFamily: 'PlayfairDisplay',
      fontSize: size,
      height: 1.02,
      letterSpacing: -0.3,
    );
  }

  /// Body — 본문·메타. Pretendard (번들). 한/영 모두 커버.
  static TextStyle body(
    double size, {
    FontWeight weight = FontWeight.w400,
  }) =>
      TextStyle(
        fontFamily: 'Pretendard',
        fontSize: size,
        fontWeight: weight,
        height: 1.35,
      );
}
