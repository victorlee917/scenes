import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_colors_ext.dart';
import '../models/scene.dart';

/// Scene 한 장을 **필름 릴 캐니스터(원형 통)** 형태로 표시하는 카드.
///
/// - 외곽: `Container.shape = circle` + 얇은 metallic 림 + drop shadow
/// - 내부: `ClipOval`로 커버 이미지 원형 크롭
/// - **텍스트는 여기 없음** — #번호·타이틀·날짜는 [FocusedSceneInfo]가
///   캐니스터 아래 별도 영역에 표시한다.
class SceneCard extends StatelessWidget {
  const SceneCard({
    super.key,
    required this.scene,
  });

  final Scene scene;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // 지름: 슬롯의 짧은 변에서 16dp 여백 둠.
        // 가로 캐러셀에서는 슬롯 폭이 좁아지므로 여백도 작게.
        final diameter = math.min(
          constraints.maxWidth - 16,
          constraints.maxHeight - 16,
        );
        return Center(
          child: SizedBox.square(
            dimension: diameter,
            child: _FilmCanister(
              child: _CanisterImage(scene: scene),
            ),
          ),
        );
      },
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
        color: context.colors.filmStock,
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
      child: ClipOval(child: child),
    );
  }
}

class _CanisterImage extends StatelessWidget {
  const _CanisterImage({required this.scene});

  final Scene scene;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: context.colors.nonClickableArea,
      child: Image.network(
        scene.coverImageUrl,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => ColoredBox(color: context.colors.nonClickableArea),
        loadingBuilder: (context, child, progress) => progress == null
            ? child
            : ColoredBox(color: context.colors.nonClickableArea),
      ),
    );
  }
}
