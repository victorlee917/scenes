import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_colors_ext.dart';
import '../../../core/theme/app_typography.dart';
import '../../../l10n/app_localizations.dart';

/// 홈 캐러셀의 **마지막 슬롯**에 놓이는 "새 Scene 추가" 카드.
///
/// Scene 카드와 같은 **원형 캐니스터** 형태를 쓰되, 내부에는 세 개의 작은
/// 원형(캐니스터 상징)이 겹쳐 있고 가장 오른쪽 원에 + 아이콘이 들어간다.
class AddSceneCard extends StatelessWidget {
  const AddSceneCard({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return LayoutBuilder(
      builder: (context, constraints) {
        final diameter = math.min(
          constraints.maxWidth - 16,
          constraints.maxHeight - 16,
        );
        return Center(
          child: SizedBox.square(
            dimension: diameter,
            child: Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: context.colors.clickableArea,
                border: Border.all(
                  color: context.colors.foreground.withValues(alpha: 0.16),
                  width: 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: context.colors.scrimSolid,
                    blurRadius: 48,
                    offset: const Offset(0, 22),
                  ),
                ],
              ),
              child: ClipOval(
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _MiniCanisterStack(size: diameter * 0.16),
                      const SizedBox(height: 14),
                      Text(
                        l10n.addSceneCardLabel,
                        style: AppTypography.body(13)
                            .copyWith(color: context.colors.foregroundMuted),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// 세 개의 작은 원형이 겹쳐진 스택. 좌측 두 개는 그라데이션,
/// 가장 우측에 + 아이콘.
class _MiniCanisterStack extends StatelessWidget {
  const _MiniCanisterStack({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    final overlap = size * 0.4;
    final step = size - overlap;
    final totalWidth = size + step * 2;
    // 원호 곡률: 중앙이 위, 양옆이 아래로 내려감.
    final arcDip = size * 0.2;
    final totalHeight = size + arcDip;

    return SizedBox(
      width: totalWidth,
      height: totalHeight,
      child: Stack(
        children: [
          // 첫 번째 원 — 좌측, 아래로 내려감
          Positioned(
            left: 0,
            top: arcDip,
            child: Container(
              width: size,
              height: size,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: context.colors.foreground,
                border: Border.all(
                  color: context.colors.background,
                  width: 2,
                ),
              ),
            ),
          ),
          // 두 번째 원 — 중앙, 가장 위
          Positioned(
            left: step,
            top: 0,
            child: Container(
              width: size,
              height: size,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: context.colors.foreground,
                border: Border.all(
                  color: context.colors.background,
                  width: 2,
                ),
              ),
            ),
          ),
          // 세 번째 원 — 우측, 아래로 내려감 + 버튼
          Positioned(
            left: step * 2,
            top: arcDip,
            child: Container(
              width: size,
              height: size,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: context.colors.foreground,
                border: Border.all(
                  color: context.colors.background,
                  width: 2,
                ),
              ),
              child: Center(
                child: FaIcon(
                  FontAwesomeIcons.plus,
                  size: size * 0.38,
                  color: context.colors.background,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

