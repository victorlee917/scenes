import 'package:flutter/material.dart';

import '../../../core/theme/app_colors_ext.dart';
import '../../../core/theme/app_typography.dart';

/// scene cover 이미지가 없거나 로드 실패했을 때 보여줄 fallback.
///
/// 타이틀의 첫 grapheme 한 글자를 가운데에 크게. 100×100 reference 박스에서
/// `display(42, text: initial)`로 한 번만 layout한 뒤 FittedBox가 부모 크기에
/// 맞춰 visual scale만 적용 — 어떤 크기(36/48/캐니스터)에서도 비례 스케일.
/// 한/영 폰트는 display(text:)가 자동 선택 (한글 → Hahmlet, 영문 → Playfair).
class SceneTitleFallback extends StatelessWidget {
  const SceneTitleFallback({super.key, required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    final trimmed = title.trim();
    final initial = trimmed.isEmpty
        ? ''
        : String.fromCharCodes(trimmed.runes.take(1)).toUpperCase();
    return ColoredBox(
      color: context.colors.nonClickableArea,
      child: FittedBox(
        fit: BoxFit.contain,
        child: SizedBox(
          width: 100,
          height: 100,
          // baseline 보정을 위해 살짝 위로.
          child: Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Center(
              child: Text(
                initial,
                textAlign: TextAlign.center,
                textHeightBehavior: const TextHeightBehavior(
                  applyHeightToFirstAscent: false,
                  applyHeightToLastDescent: false,
                ),
                style: AppTypography.display(42, text: initial).copyWith(
                  color: context.colors.foregroundMuted,
                  fontWeight: FontWeight.w500,
                  height: 1.0,
                  // Hero/Material 조상 없을 수 있어 노란 underline 명시적 차단.
                  decoration: TextDecoration.none,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
