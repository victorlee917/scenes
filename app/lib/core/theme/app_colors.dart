import 'package:flutter/material.dart';

/// 디자인 토큰 — 색상. 위젯에서 직접 참조하지 말고 `Theme.of(context)`를 사용한다.
/// 여기는 `AppTheme`이 `ColorScheme`을 조립할 때만 읽는다.
class AppColors {
  AppColors._();

  static const brand = Color(0xFF6750A4);

  // Light
  static const lightBackground = Color(0xFFFDFBFF);
  static const lightSurface = Color(0xFFFFFFFF);
  static const lightOnSurface = Color(0xFF1C1B1F);

  // Dark
  static const darkBackground = Color(0xFF121016);
  static const darkSurface = Color(0xFF1C1B1F);
  static const darkOnSurface = Color(0xFFE6E1E5);
}
