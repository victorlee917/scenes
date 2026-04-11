import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// 타이포그래피 토큰.
///
/// 규칙:
/// - **Instrument Serif italic** — Scene 타이틀·월 타이틀 등 디스플레이 전용.
/// - **Fraunces** — 본문·메타 전체. 작은 크기는 italic을 기본으로.
/// - **모노는 사용 금지** — 톤이 기술적이라 제외.
///
/// 사이즈는 호출부에서 결정하고, 여기는 family·weight·italic 축만 고정한다.
class AppTypography {
  AppTypography._();

  /// Display — Scene 타이틀 류. 기본 italic.
  static TextStyle display(double size) => GoogleFonts.instrumentSerif(
        fontSize: size,
        fontStyle: FontStyle.italic,
        height: 1.02,
        letterSpacing: -0.3,
      );

  /// Body — 본문·메타. `italic`은 소문자 시스템 텍스트용.
  static TextStyle body(
    double size, {
    FontStyle italic = FontStyle.normal,
    FontWeight weight = FontWeight.w400,
  }) =>
      GoogleFonts.fraunces(
        fontSize: size,
        fontStyle: italic,
        fontWeight: weight,
        height: 1.35,
      );
}
