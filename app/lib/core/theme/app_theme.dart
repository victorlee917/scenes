import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'app_typography.dart';

/// 앱 테마 팩토리. `MaterialApp.theme` / `darkTheme`에 주입한다.
class AppTheme {
  AppTheme._();

  static ThemeData get light => _base(
        brightness: Brightness.light,
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColors.brand,
          brightness: Brightness.light,
          surface: AppColors.lightSurface,
          onSurface: AppColors.lightOnSurface,
        ),
        scaffoldBackground: AppColors.lightBackground,
      );

  static ThemeData get dark => _base(
        brightness: Brightness.dark,
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColors.brand,
          brightness: Brightness.dark,
          surface: AppColors.darkSurface,
          onSurface: AppColors.darkOnSurface,
        ),
        scaffoldBackground: AppColors.darkBackground,
      );

  static ThemeData _base({
    required Brightness brightness,
    required ColorScheme colorScheme,
    required Color scaffoldBackground,
  }) {
    return ThemeData(
      brightness: brightness,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: scaffoldBackground,
      textTheme: AppTypography.textTheme.apply(
        bodyColor: colorScheme.onSurface,
        displayColor: colorScheme.onSurface,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: colorScheme.surface,
        foregroundColor: colorScheme.onSurface,
        elevation: 0,
        centerTitle: false,
      ),
      useMaterial3: true,
    );
  }
}
