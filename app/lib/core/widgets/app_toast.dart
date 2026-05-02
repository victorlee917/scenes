import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../theme/app_colors_ext.dart';
import '../theme/app_radii.dart';
import '../theme/app_typography.dart';

class AppToast {
  AppToast._();

  static void show(BuildContext context, String message) {
    final overlay = Overlay.of(context);
    late final OverlayEntry entry;

    entry = OverlayEntry(
      builder: (ctx) => _ToastOverlay(
        message: message,
        onDismiss: () => entry.remove(),
      ),
    );

    overlay.insert(entry);
  }
}

class _ToastOverlay extends StatefulWidget {
  const _ToastOverlay({
    required this.message,
    required this.onDismiss,
  });

  final String message;
  final VoidCallback onDismiss;

  @override
  State<_ToastOverlay> createState() => _ToastOverlayState();
}

class _ToastOverlayState extends State<_ToastOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _opacity;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    );
    _opacity = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0, end: 1), weight: 10),
      TweenSequenceItem(tween: ConstantTween(1), weight: 70),
      TweenSequenceItem(tween: Tween(begin: 1, end: 0), weight: 20),
    ]).animate(_controller);
    _controller.forward().then((_) => widget.onDismiss());
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.paddingOf(context).bottom + 80;

    return Positioned(
      left: 0,
      right: 0,
      bottom: bottom,
      child: FadeTransition(
        opacity: _opacity,
        child: Center(
          child: ClipRRect(
            borderRadius: AppRadii.xlBorder,
            child: BackdropFilter(
              filter: ui.ImageFilter.blur(sigmaX: 28, sigmaY: 28),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: context.colors.clickableArea.withValues(alpha: 0.82),
                  borderRadius: AppRadii.xlBorder,
                  border: Border.all(
                    color: context.colors.foreground.withValues(alpha: 0.08),
                    width: 0.5,
                  ),
                ),
                child: DefaultTextStyle(
                  style: AppTypography.body(14, weight: FontWeight.w500)
                      .copyWith(color: context.colors.foreground),
                  child: Text(widget.message),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
