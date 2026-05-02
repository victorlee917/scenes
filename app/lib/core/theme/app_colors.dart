import 'package:flutter/material.dart';

/// 디자인 토큰 — 색상.
///
/// 기존 다크 모드 색상은 static const로 유지(기존 코드 호환).
/// 라이트 팔레트는 `AppColorPalette.light`로 접근.
/// 테마 전환 시 `AppColorPalette`을 context로 주입해 사용.
class AppColors {
  AppColors._();

  // ── Neutral dark (기본) ──────────────────────────────────────
  static const background = Color(0xFF151517);
  static const surface = Color(0xFF1E1E21);
  static const surfaceElevated = Color(0xFF272729);

  // ── Semantic surface ────────────────────────────────────────
  static const clickableArea = Color(0xFF242427);
  static const nonClickableArea = Color(0xFF1A1A1C);

  // ── Neutral cream foreground ─────────────────────────────────
  static const foreground = Color(0xFFEEEEEC);
  static const foregroundMuted = Color(0xFFA8A8A6);

  // ── Utility ──────────────────────────────────────────────────
  static const hairline = Color(0x14FFFFFF);
  static const scrimTransparent = Color(0x00000000);
  static const scrimSolid = Color(0xD9000000);

  // ── Film stock ───────────────────────────────────────────────
  static const filmStock = Color(0xFF0A0A0B);
}

/// 다크/라이트 팔레트 세트. 테마 전환에 사용.
class AppColorPalette {
  const AppColorPalette._({
    required this.background,
    required this.surface,
    required this.surfaceElevated,
    required this.clickableArea,
    required this.nonClickableArea,
    required this.foreground,
    required this.foregroundMuted,
    required this.hairline,
    required this.scrimSolid,
    required this.filmStock,
    required this.gradientBase,
  });

  final Color background;
  final Color surface;
  final Color surfaceElevated;
  final Color clickableArea;
  final Color nonClickableArea;
  final Color foreground;
  final Color foregroundMuted;
  final Color hairline;
  final Color scrimSolid;
  final Color filmStock;

  /// 그라데이션 scrim 기본색 (앱바, 상하단 shadow 등).
  final Color gradientBase;

  static const dark = AppColorPalette._(
    background: Color(0xFF151517),
    surface: Color(0xFF1E1E21),
    surfaceElevated: Color(0xFF272729),
    clickableArea: Color(0xFF242427),
    nonClickableArea: Color(0xFF1A1A1C),
    foreground: Color(0xFFEEEEEC),
    foregroundMuted: Color(0xFFA8A8A6),
    hairline: Color(0x14FFFFFF),
    scrimSolid: Color(0xD9000000),
    filmStock: Color(0xFF0A0A0B),
    gradientBase: Color(0xFF151517),
  );

  static const light = AppColorPalette._(
    background: Color(0xFFF5F5F3),
    surface: Color(0xFFEBEBE9),
    surfaceElevated: Color(0xFFE0E0DE),
    clickableArea: Color(0xFFE5E5E3),
    nonClickableArea: Color(0xFFF0F0EE),
    foreground: Color(0xFF1A1A1C),
    foregroundMuted: Color(0xFF6E6E6C),
    hairline: Color(0x14000000),
    scrimSolid: Color(0xD9FFFFFF),
    filmStock: Color(0xFFD8D8D6),
    gradientBase: Color(0xFFF5F5F3),
  );
}
