import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_colors_ext.dart';
import '../theme/app_radii.dart';
import '../theme/app_typography.dart';

/// 플로팅 원형(pill-radius) 바텀 시트.
///
/// 화면 하단에 좌우 여백을 두고 떠 있는 glass 느낌의 액션 시트.
/// `FloatingActionSheet.show()`로 열고, 내부에 [FloatingActionItem]
/// 리스트를 전달한다.
class FloatingActionSheet extends StatelessWidget {
  const FloatingActionSheet({
    super.key,
    required this.items,
  });

  final List<FloatingActionItem> items;

  static Future<void> show({
    required BuildContext context,
    required List<FloatingActionItem> items,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black38,
      builder: (_) => FloatingActionSheet(items: items),
    );
  }

  @override
  Widget build(BuildContext context) {
    final padding = MediaQuery.paddingOf(context);

    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        bottom: padding.bottom + 16,
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
                color: context.colors.foreground.withValues(alpha: 0.08),
                width: 0.5,
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (int i = 0; i < items.length; i++) ...[
                  _ActionTile(item: items[i]),
                  if (i < items.length - 1)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Container(
                        height: 0.5,
                        color: context.colors.foreground.withValues(alpha: 0.06),
                      ),
                    ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 하나의 액션 항목.
class FloatingActionItem {
  const FloatingActionItem({
    required this.label,
    required this.onTap,
    this.isDestructive = false,
    this.badge,
  });

  final String label;
  final VoidCallback onTap;
  final bool isDestructive;
  final String? badge;
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({required this.item});

  final FloatingActionItem item;

  @override
  Widget build(BuildContext context) {
    final color = item.isDestructive
        ? const Color(0xFFE06C75)
        : context.colors.foreground;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        Navigator.of(context).pop();
        item.onTap();
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
        child: Center(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                item.label,
                textAlign: TextAlign.center,
                style: AppTypography.body(15, weight: FontWeight.w500)
                    .copyWith(color: color),
              ),
              if (item.badge != null) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(4),
                    color: context.colors.foreground.withValues(alpha: 0.08),
                  ),
                  child: Text(
                    item.badge!,
                    style: AppTypography.body(10, weight: FontWeight.w600)
                        .copyWith(
                      color: context.colors.foregroundMuted,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
