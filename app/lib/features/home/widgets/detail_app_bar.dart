import 'package:flutter/material.dart';

import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../../../core/theme/app_colors_ext.dart';
import '../../../core/theme/app_typography.dart';
import '../../../l10n/app_localizations.dart';

/// Detail 모드 상단에 떠 있는 앱바.
///
/// - leading: X(close) 버튼 — 이전 화면으로.
/// - trailing: ellipsis 버튼 — 씬 편집/삭제 메뉴.
/// - 하단 1px hairline 경계선.
/// - `titleOpacity`로 스크롤에 따라 타이틀 텍스트를 fade-in.
class DetailAppBar extends StatelessWidget {
  const DetailAppBar({
    super.key,
    required this.topInset,
    required this.title,
    required this.titleOpacity,
    required this.onClose,
    this.onMoreActions,
    this.trailing,
    this.leading,
    this.borderOpacity = 1.0,
    this.useGradient = true,
  });

  /// 기기 safe area top inset. Padding으로 반영.
  final double topInset;

  /// 앱바에 들어갈 Scene 타이틀. 스크롤로 메인 타이틀이 가려지면 나타남.
  final String title;

  /// 0.0 → 1.0. HomeView가 DetailContentPanel 스크롤 오프셋을 기반으로 계산.
  final double titleOpacity;

  final VoidCallback onClose;

  /// 기본 ellipsis 버튼의 콜백. [trailing]이 지정되면 무시됨.
  final VoidCallback? onMoreActions;

  /// 기본 ellipsis 대신 표시할 커스텀 trailing 위젯.
  final Widget? trailing;

  /// 기본 X(close) 대신 표시할 커스텀 leading 위젯.
  final Widget? leading;

  /// 하단 hairline 경계선의 opacity. 0.0 = 투명, 1.0 = 표시.
  /// 배경 blur/tint alpha도 함께 제어한다.
  final double borderOpacity;

  /// false이면 그라데이션 없이 bar만 반환.
  final bool useGradient;

  static const double barHeight = 48;
  static const double _buttonSize = 36;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    Widget bar = Padding(
      padding: EdgeInsets.only(top: topInset),
      child: SizedBox(
        height: barHeight,
          child: Stack(
            children: [
              // 타이틀 — 가운데 정렬, 스크롤 임계점을 지나면 fade-in.
              Positioned.fill(
                child: IgnorePointer(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 56),
                    child: Center(
                      child: Opacity(
                        opacity: titleOpacity,
                        child: Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                          style: AppTypography.body(
                            15,
                            weight: FontWeight.w500,
                          ).copyWith(color: context.colors.foreground),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              // Leading
              Align(
                alignment: Alignment.centerLeft,
                child: Padding(
                  padding: const EdgeInsets.only(left: 16),
                  child: leading ??
                      _BarButton(
                        size: _buttonSize,
                        semanticLabel: l10n.detailBack,
                        onTap: onClose,
                        child: FaIcon(FontAwesomeIcons.xmark,
                            size: 18,
                            color: context.colors.foreground
                                .withValues(alpha: 0.9)),
                      ),
                ),
              ),
              // Trailing
              Align(
                alignment: Alignment.centerRight,
                child: Padding(
                  padding: const EdgeInsets.only(right: 16),
                  child: trailing ??
                      _BarButton(
                        size: _buttonSize,
                        semanticLabel: l10n.detailMoreActions,
                        onTap: onMoreActions ?? () {},
                        child: FaIcon(FontAwesomeIcons.ellipsis,
                            size: 18,
                            color: context.colors.foreground
                                .withValues(alpha: 0.9)),
                      ),
                ),
              ),
                ],
              ),
            ),
          );

    if (!useGradient) return bar;

    final gradientHeight = topInset + barHeight + 40;
    final base = context.colors.gradientBase;
    return SizedBox(
      height: gradientHeight,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              base.withValues(alpha: 1.0),
              base.withValues(alpha: 0.9),
              base.withValues(alpha: 0.58),
              base.withValues(alpha: 0.22),
              base.withValues(alpha: 0.0),
            ],
            stops: const [0.0, 0.35, 0.6, 0.82, 1.0],
          ),
        ),
        child: Align(
          alignment: Alignment.topLeft,
          child: bar,
        ),
      ),
    );
  }
}

class _BarButton extends StatelessWidget {
  const _BarButton({
    required this.size,
    required this.semanticLabel,
    required this.onTap,
    required this.child,
  });

  final double size;
  final String semanticLabel;
  final VoidCallback onTap;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: semanticLabel,
      button: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: SizedBox(
          width: size,
          height: size,
          child: Center(child: child),
        ),
      ),
    );
  }
}

