import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'app_typography.dart';

/// 앱 테마. 현재 앱은 "중립 다크" 단일 테마로 운영한다.
/// 라이트 변형은 화면이 더 나온 다음 결정.
class AppTheme {
  AppTheme._();

  static ThemeData get dark {
    const colorScheme = ColorScheme(
      brightness: Brightness.dark,
      primary: AppColors.foreground,
      onPrimary: AppColors.background,
      secondary: AppColors.foreground,
      onSecondary: AppColors.background,
      error: Color(0xFFE06C75),
      onError: AppColors.foreground,
      surface: AppColors.background,
      onSurface: AppColors.foreground,
      surfaceContainerHighest: AppColors.surfaceElevated,
      outline: AppColors.hairline,
    );

    return ThemeData(
      brightness: Brightness.dark,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: AppColors.background,
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
        labelLarge: AppTypography.body(13, italic: FontStyle.italic),
        labelMedium: AppTypography.body(12, italic: FontStyle.italic),
        labelSmall: AppTypography.body(11, italic: FontStyle.italic),
      ).apply(
        bodyColor: AppColors.foreground,
        displayColor: AppColors.foreground,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.foreground,
        elevation: 0,
        centerTitle: false,
      ),
      splashColor: Colors.transparent,
      highlightColor: Colors.transparent,
    );
  }
}
