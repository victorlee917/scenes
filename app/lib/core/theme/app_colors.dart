import 'package:flutter/material.dart';

/// 디자인 토큰 — 색상. 위젯에서 직접 참조하지 말고 `Theme.of(context)`를 사용한다.
/// 여기는 `AppTheme`이 `ColorScheme`을 조립할 때와, scrim·hairline처럼 테마에
/// 실을 수 없는 토큰을 직접 참조할 때만 읽는다.
///
/// 팔레트 방향: "중립 다크 + 영화 느낌은 타이포·레이아웃에만". 브라운/세피아
/// 드리프트를 피하고 chroma를 극소량으로 유지.
class AppColors {
  AppColors._();

  // ── Neutral dark ─────────────────────────────────────────────
  static const background = Color(0xFF151517); // near-neutral dark
  static const surface = Color(0xFF1E1E21); // subtly lifted
  static const surfaceElevated = Color(0xFF272729);

  // ── Neutral cream foreground ─────────────────────────────────
  static const foreground = Color(0xFFEEEEEC); // off-white, near-neutral
  static const foregroundMuted = Color(0xFFA8A8A6);

  // ── Utility ──────────────────────────────────────────────────
  static const hairline = Color(0x14FFFFFF);

  // Bottom scrim on scene cards: transparent → near-black.
  static const scrimTransparent = Color(0x00000000);
  static const scrimSolid = Color(0xD9000000);

  // ── Film stock (used only in Scene card chrome) ──────────────
  /// Film-strip 바탕색. 거의 검정이지만 배경보다 살짝 어두워서
  /// 프레임과 스프로킷 구멍의 대비를 만든다.
  static const filmStock = Color(0xFF0A0A0B);

  /// 필름 스톡 에지 마킹용 앰버. 오직 Scene card의 작은 상/하 라벨에만
  /// 허용. 다른 화면·다른 위젯에는 쓰지 않는다.
  static const filmAmber = Color(0xFFD89A4A);
}
