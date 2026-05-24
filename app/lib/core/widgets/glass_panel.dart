import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../theme/app_colors_ext.dart';

/// 앱 전역의 글래스(블러 + 반투명 틴트) 표면.
///
/// 바텀시트·다이얼로그·토스트가 공유한다 — `BackdropFilter` 블러 위에 반투명
/// `clickableArea` 틴트와 얇은 테두리. 블러 강도·틴트는 한 곳에서 관리하고
/// 호출부는 모서리 반경(과 필요 시 테두리 알파)만 정한다.
class GlassPanel extends StatelessWidget {
  const GlassPanel({
    super.key,
    required this.borderRadius,
    required this.child,
    this.borderAlpha = 0.08,
  });

  final BorderRadius borderRadius;
  final Widget child;

  /// 테두리 foreground 알파. 기본 0.08.
  final double borderAlpha;

  /// 모든 글래스 표면이 공유하는 블러 sigma.
  static const double blurSigma = 28;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: borderRadius,
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: context.colors.clickableArea.withValues(alpha: 0.82),
            borderRadius: borderRadius,
            border: Border.all(
              color: context.colors.foreground.withValues(alpha: borderAlpha),
              width: 0.5,
            ),
          ),
          child: child,
        ),
      ),
    );
  }
}
