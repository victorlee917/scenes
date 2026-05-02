import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../../../core/theme/app_colors_ext.dart';
import '../../../core/widgets/glass_circle_button.dart';
import '../../../l10n/app_localizations.dart';

/// 홈 하단 — 세 개의 **glass morphism 원형 버튼** (sort / add / play).
///
/// 각 버튼이 플로팅 원형 안에 FA 아이콘을 품고 있어서 영화 플레이어
/// 컨트롤처럼 보인다. 바 자체에는 배경이 없음 — 버튼들만 떠 있는 형태.
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
    final iconSize = buttonSize * 0.36;
    final iconColor = context.colors.foreground.withValues(alpha: 0.9);

    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 18),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          GlassCircleButton(
            size: buttonSize,
            onTap: onSort,
            semanticLabel: l10n.transportSort,
            child: FaIcon(FontAwesomeIcons.bars,
                size: iconSize, color: iconColor),
          ),
          SizedBox(width: gap),
          GlassCircleButton(
            size: buttonSize,
            onTap: onAdd,
            semanticLabel: l10n.transportAdd,
            child: FaIcon(FontAwesomeIcons.plus,
                size: iconSize, color: iconColor),
          ),
          SizedBox(width: gap),
          GlassCircleButton(
            size: buttonSize,
            onTap: onPlay,
            semanticLabel: l10n.transportPlay,
            child: FaIcon(FontAwesomeIcons.play,
                size: iconSize, color: iconColor),
          ),
        ],
      ),
    );
  }
}
