import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_colors_ext.dart';
import '../theme/app_radii.dart';

/// 플로팅 형태의 바텀시트.
///
/// 좌우·하단 여백이 있고, 전체 radius가 적용된 카드 형태로 떠 있다.
/// BackdropFilter blur + 반투명 바탕. FloatingActionSheet과 동일한 스타일.
/// `FloatingBottomSheet.show()`로 열고, [builder]로 내부 콘텐츠를 구성한다.
class FloatingBottomSheet extends StatelessWidget {
  const FloatingBottomSheet({super.key, required this.child});

  final Widget child;

  static Future<T?> show<T>({
    required BuildContext context,
    required WidgetBuilder builder,
  }) {
    return showModalBottomSheet<T>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => FloatingBottomSheet(child: builder(ctx)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final padding = MediaQuery.paddingOf(context);
    final viewInsets = MediaQuery.viewInsetsOf(context);
    final bottomPadding = viewInsets.bottom > 0
        ? viewInsets.bottom + 8
        : padding.bottom;
    return Padding(
      padding: EdgeInsets.only(
        left: 12,
        right: 12,
        bottom: bottomPadding,
      ),
      child: ClipRRect(
        borderRadius: AppRadii.sheetBorder,
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 28, sigmaY: 28),
          child: Container(
            decoration: BoxDecoration(
              color: context.colors.clickableArea.withValues(alpha: 0.82),
              borderRadius: AppRadii.sheetBorder,
              border: Border.all(
                color: context.colors.foreground.withValues(alpha: 0.06),
                width: 0.5,
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 10, bottom: 12),
                  child: Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: context.colors.foreground.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                child,
              ],
            ),
          ),
        ),
      ),
    );
  }
}
