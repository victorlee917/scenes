import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../formatters.dart';
import '../models/scene.dart';

/// Scene 한 장을 **필름 릴 캐니스터(원형 통)** 형태로 표시하는 카드.
///
/// - 외곽: `Container.shape = circle` + 얇은 metallic 림 + drop shadow
/// - 내부: `ClipOval`로 커버 이미지 원형 크롭
/// - 상단 중앙: `#014` (앰버, 캐니스터 라벨 느낌)
/// - 하단 중앙: 타이틀 + 날짜 (radial scrim 위, 가운데 정렬)
///
/// 카드는 PageView 슬롯의 가운데에 배치되며, 지름은 슬롯의 짧은 변 - 32dp로
/// 반응형 결정. 캐러셀에서 스케일·opacity는 [HomeView]의 AnimatedBuilder가 담당.
class SceneCard extends StatelessWidget {
  const SceneCard({
    super.key,
    required this.scene,
    required this.onTap,
  });

  final Scene scene;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
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
              child: _FilmCanister(
                child: _CanisterContent(scene: scene),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// 원형 캐니스터 셸: 색·테두리·그림자만 담당. 내용은 자식으로 주입.
class _FilmCanister extends StatelessWidget {
  const _FilmCanister({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppColors.filmStock,
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
      child: ClipOval(child: child),
    );
  }
}

class _CanisterContent extends StatelessWidget {
  const _CanisterContent({required this.scene});

  final Scene scene;

  @override
  Widget build(BuildContext context) {
    final locale = Localizations.localeOf(context);
    final dateLine = formatSceneDateRange(scene.dates, locale.toLanguageTag());
    final size = MediaQuery.sizeOf(context);
    final titleSize = size.width >= 420 ? 32.0 : 26.0;

    return Stack(
      fit: StackFit.expand,
      children: [
        // Cover image
        ColoredBox(
          color: AppColors.surface,
          child: Image.network(
            scene.coverImageUrl,
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) =>
                const ColoredBox(color: AppColors.surface),
            loadingBuilder: (context, child, progress) => progress == null
                ? child
                : const ColoredBox(color: AppColors.surface),
          ),
        ),

        // Centered radial scrim — 캐니스터 가운데를 어둡게 해서 라벨 가독성 확보.
        const IgnorePointer(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: Alignment.center,
                radius: 0.85,
                colors: [
                  Color(0xCC000000),
                  Color(0x00000000),
                ],
                stops: [0.0, 0.9],
              ),
            ),
          ),
        ),

        // 가운데 정렬된 텍스트 블록 — #014, 타이틀, 날짜가 한 덩어리로 중앙에.
        Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(
                  '#${scene.number.toString().padLeft(3, '0')}',
                  textAlign: TextAlign.center,
                  style:
                      AppTypography.body(11, italic: FontStyle.italic).copyWith(
                    color: AppColors.filmAmber,
                    letterSpacing: 2.0,
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  scene.title,
                  textAlign: TextAlign.center,
                  style: AppTypography.display(titleSize).copyWith(
                    color: AppColors.foreground,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 8),
                Text(
                  dateLine,
                  textAlign: TextAlign.center,
                  style: AppTypography.body(11, italic: FontStyle.italic)
                      .copyWith(
                    color: AppColors.foreground.withValues(alpha: 0.65),
                    letterSpacing: 0.4,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
