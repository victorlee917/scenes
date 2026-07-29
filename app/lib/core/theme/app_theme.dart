import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app_colors.dart';
import 'app_typography.dart';

/// 앱 테마. 다크와 라이트 두 변형을 제공.
class AppTheme {
  AppTheme._();

  static ThemeData get dark => _build(AppColorPalette.dark, Brightness.dark);
  static ThemeData get light => _build(AppColorPalette.light, Brightness.light);

  static ThemeData _build(AppColorPalette c, Brightness brightness) {
    final colorScheme = ColorScheme(
      brightness: brightness,
      primary: c.foreground,
      onPrimary: c.background,
      secondary: c.foreground,
      onSecondary: c.background,
      error: const Color(0xFFE06C75),
      onError: c.foreground,
      surface: c.background,
      onSurface: c.foreground,
      surfaceContainerHighest: c.surfaceElevated,
      outline: c.hairline,
    );

    return ThemeData(
      brightness: brightness,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: c.background,
      useMaterial3: true,
      textTheme: TextTheme(
        displayLarge: AppTypography.display(48),
        displayMedium: AppTypography.display(36),
        displaySmall: AppTypography.display(28),
        headlineLarge: AppTypography.display(28),
        headlineMedium: AppTypography.display(24),
        titleLarge: AppTypography.display(22),
        titleMedium: AppTypography.body(16, weight: FontWeight.w500),
        titleSmall: AppTypography.body(14, weight: FontWeight.w500),
        bodyLarge: AppTypography.body(16),
        bodyMedium: AppTypography.body(14),
        bodySmall: AppTypography.body(12),
        labelLarge: AppTypography.body(13),
        labelMedium: AppTypography.body(12),
        labelSmall: AppTypography.body(11),
      ).apply(
        bodyColor: c.foreground,
        displayColor: c.foreground,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: c.background,
        foregroundColor: c.foreground,
        elevation: 0,
        centerTitle: false,
        // AppBar가 있으면 자체 systemOverlayStyle로 root AnnotatedRegion을
        // 덮어쓴다. 기본값은 배경색에서 유추한 불투명 상태바라 그라데이션을
        // 끊으므로, 여기서도 투명 + 테마 밝기에 맞춘 아이콘으로 명시.
        systemOverlayStyle: SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness:
              brightness == Brightness.dark ? Brightness.light : Brightness.dark,
          statusBarBrightness:
              brightness == Brightness.dark ? Brightness.dark : Brightness.light,
        ),
      ),
      splashFactory: NoSplash.splashFactory,
      splashColor: Colors.transparent,
      highlightColor: Colors.transparent,
      hoverColor: Colors.transparent,
    );
  }
}
