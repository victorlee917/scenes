import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../theme/app_colors_ext.dart';
import '../theme/app_radii.dart';
import '../theme/app_typography.dart';

class ConfirmDialog extends StatelessWidget {
  const ConfirmDialog({
    super.key,
    required this.title,
    this.message,
    required this.confirmLabel,
    this.cancelLabel = 'Cancel',
    this.isDestructive = false,
  });

  final String title;
  final String? message;
  final String confirmLabel;
  final String cancelLabel;
  final bool isDestructive;

  static Future<bool> show({
    required BuildContext context,
    required String title,
    String? message,
    required String confirmLabel,
    String cancelLabel = 'Cancel',
    bool isDestructive = false,
  }) async {
    final result = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black38,
      builder: (_) => ConfirmDialog(
        title: title,
        message: message,
        confirmLabel: confirmLabel,
        cancelLabel: cancelLabel,
        isDestructive: isDestructive,
      ),
    );
    return result ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final padding = MediaQuery.paddingOf(context);

    return Padding(
      padding: EdgeInsets.only(
        left: 12,
        right: 12,
        bottom: padding.bottom,
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
                const SizedBox(height: 24),
                Text(
                  title,
                  style: AppTypography.display(17).copyWith(
                    color: context.colors.foreground,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (message != null) ...[
                  const SizedBox(height: 8),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: Text(
                      message!,
                      textAlign: TextAlign.center,
                      style: AppTypography.body(14).copyWith(
                        color: context.colors.foregroundMuted,
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 24),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: () => Navigator.of(context).pop(false),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            decoration: BoxDecoration(
                              borderRadius: AppRadii.sheetInnerBorder,
                              color: context.colors.nonClickableArea,
                            ),
                            child: Center(
                              child: Text(
                                cancelLabel,
                                style: AppTypography.body(15,
                                        weight: FontWeight.w600)
                                    .copyWith(
                                        color: context.colors.foreground),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: GestureDetector(
                          onTap: () => Navigator.of(context).pop(true),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            decoration: BoxDecoration(
                              borderRadius: AppRadii.sheetInnerBorder,
                              color: isDestructive
                                  ? const Color(0xFFDC3545)
                                  : context.colors.foreground,
                            ),
                            child: Center(
                              child: Text(
                                confirmLabel,
                                style: AppTypography.body(15,
                                        weight: FontWeight.w600)
                                    .copyWith(
                                  color: isDestructive
                                      ? Colors.white
                                      : context.colors.background,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
