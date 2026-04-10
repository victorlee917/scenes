import 'package:flutter/material.dart';

/// 타이포그래피 토큰. 폰트 패밀리·사이즈·웨이트를 한 곳에서 관리한다.
class AppTypography {
  AppTypography._();

  static const _fontFamily = 'Inter';

  static const textTheme = TextTheme(
    displayLarge: TextStyle(fontFamily: _fontFamily, fontSize: 32, fontWeight: FontWeight.w700),
    headlineMedium: TextStyle(fontFamily: _fontFamily, fontSize: 24, fontWeight: FontWeight.w600),
    titleLarge: TextStyle(fontFamily: _fontFamily, fontSize: 20, fontWeight: FontWeight.w600),
    bodyLarge: TextStyle(fontFamily: _fontFamily, fontSize: 16, fontWeight: FontWeight.w400),
    bodyMedium: TextStyle(fontFamily: _fontFamily, fontSize: 14, fontWeight: FontWeight.w400),
    labelLarge: TextStyle(fontFamily: _fontFamily, fontSize: 14, fontWeight: FontWeight.w500),
  );
}
