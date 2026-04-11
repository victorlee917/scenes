import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../l10n/app_localizations.dart';
import 'sharp_icons.dart';

/// 홈 캐러셀의 **마지막 슬롯**에 놓이는 "새 Scene 추가" 카드.
///
/// Scene 카드와 같은 **원형 캐니스터** 형태를 쓰되, 내부는 비어 있는
/// 다크 서페이스에 중앙 `+` 아이콘과 라벨만. Scene이 하나도 없으면 이
/// 카드가 단독 노출되고 하단 탭은 숨겨진다 (HomeView 분기).
class AddSceneCard extends StatelessWidget {
  const AddSceneCard({super.key, required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return GestureDetector(
      onTap: onTap,
      child: LayoutBuilder(
        builder: (context, constraints) {
          // 지름: 슬롯의 짧은 변에서 80dp(40 each side) 여백 둠.
          final diameter = math.min(
            constraints.maxWidth - 80,
            constraints.maxHeight - 80,
          );
          return Center(
            child: SizedBox.square(
              dimension: diameter,
              child: Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.surface,
                  border: Border.all(
                    color: AppColors.foreground.withValues(alpha: 0.16),
                    width: 1,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.62),
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
                        SharpPlus(
                          size: 36,
                          color: AppColors.foregroundMuted,
                          strokeWidth: 1.5,
                        ),
                        const SizedBox(height: 14),
                        Text(
                          l10n.addSceneCardLabel,
                          style: AppTypography.body(13,
                                  italic: FontStyle.italic)
                              .copyWith(color: AppColors.foregroundMuted),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
