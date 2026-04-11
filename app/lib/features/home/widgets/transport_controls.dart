import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import 'sharp_icons.dart';

/// 홈 하단 — 세 개의 **glass morphism 원형 버튼** (sort / add / play).
///
/// 각 버튼은 `BackdropFilter`로 뒤 콘텐츠를 blur한 뒤, 얇은 흰색 보더와
/// 낮은 alpha 필을 얹어서 유리처럼 떠 있는 감각을 준다. 아이콘은
/// [SharpPlus] / [SharpSort] / [SharpPlay] — 고정 stroke의 sharp line.
class TransportControls extends StatelessWidget {
  const TransportControls({
    super.key,
    required this.onSort,
    required this.onAdd,
    required this.onPlay,
  });

  final VoidCallback onSort;
  final VoidCallback onAdd;
  final VoidCallback onPlay;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final screenWidth = MediaQuery.sizeOf(context).width;
    final buttonSize = screenWidth >= 420 ? 54.0 : 48.0;
    final gap = screenWidth >= 420 ? 28.0 : 22.0;
    final iconSize = buttonSize * 0.38;
    final iconColor = Colors.white.withValues(alpha: 0.9);

    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 18),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _GlassButton(
            size: buttonSize,
            onTap: onSort,
            semanticLabel: l10n.transportSort,
            child: SharpSort(size: iconSize, color: iconColor),
          ),
          SizedBox(width: gap),
          _GlassButton(
            size: buttonSize,
            onTap: onAdd,
            semanticLabel: l10n.transportAdd,
            child: SharpPlus(size: iconSize, color: iconColor),
          ),
          SizedBox(width: gap),
          _GlassButton(
            size: buttonSize,
            onTap: onPlay,
            semanticLabel: l10n.transportPlay,
            child: SharpPlay(size: iconSize, color: iconColor),
          ),
        ],
      ),
    );
  }
}

class _GlassButton extends StatelessWidget {
  const _GlassButton({
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
            filter: ui.ImageFilter.blur(sigmaX: 24, sigmaY: 24),
            child: Container(
              width: size,
              height: size,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.1),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.22),
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
