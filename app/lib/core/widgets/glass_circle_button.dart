import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../theme/app_colors_ext.dart';

/// 배경을 blur하고 낮은 alpha 흰색 틴트를 얹은 glass morphism 원형 버튼.
///
/// 홈 하단 transport와 scene detail의 액션 버튼 등에서 공통으로 사용.
class GlassCircleButton extends StatelessWidget {
  const GlassCircleButton({
    super.key,
    required this.size,
    required this.onTap,
    required this.semanticLabel,
    required this.child,
  });

  final double size;
  final VoidCallback onTap;
  final String semanticLabel;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: semanticLabel,
      button: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: ClipOval(
          child: BackdropFilter(
            filter: ui.ImageFilter.blur(sigmaX: 28, sigmaY: 28),
            child: Container(
              width: size,
              height: size,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: context.colors.foreground.withValues(alpha: 0.06),
                border: Border.all(
                  color: context.colors.foreground.withValues(alpha: 0.10),
                  width: 0.6,
                ),
              ),
              alignment: Alignment.center,
              child: child,
            ),
          ),
        ),
      ),
    );
  }
}
