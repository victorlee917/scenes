import 'package:flutter/material.dart';

import 'app_colors.dart';

/// `BuildContext`에서 현재 테마 밝기에 맞는 팔레트를 바로 꺼낸다.
///
/// ```dart
/// final bg = context.colors.background;
/// ```
extension AppColorsX on BuildContext {
  AppColorPalette get colors =>
      Theme.of(this).brightness == Brightness.dark
          ? AppColorPalette.dark
          : AppColorPalette.light;
}
