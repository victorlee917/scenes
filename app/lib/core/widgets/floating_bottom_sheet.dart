import 'package:flutter/material.dart';

import '../theme/app_colors_ext.dart';
import '../theme/app_radii.dart';
import 'glass_panel.dart';

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
    // 플로팅 카드라 항상 좌우(12)와 대칭되는 기본 하단 여백을 준다. 안전영역
    // inset만 쓰면 Android(3버튼 내비 등 padding.bottom==0)에서 소프트바에
    // 바로 붙는다 — iOS는 홈 인디케이터(~34) 덕에 가려졌던 문제.
    final bottomPadding = viewInsets.bottom > 0
        ? viewInsets.bottom + 8
        : padding.bottom + 12;
    return Padding(
      padding: EdgeInsets.only(
        left: 12,
        right: 12,
        bottom: bottomPadding,
      ),
      child: GlassPanel(
        borderRadius: AppRadii.sheetBorder,
        borderAlpha: 0.06,
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
    );
  }
}
