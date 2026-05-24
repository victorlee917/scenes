import 'package:flutter/material.dart';

import '../theme/app_colors_ext.dart';
import '../theme/app_radii.dart';
import '../theme/app_typography.dart';
import 'glass_panel.dart';

class AppToast {
  AppToast._();

  // 현재 떠 있는 토스트. 새 토스트를 띄울 때 교체해 화면에 쌓이지 않게 한다.
  static OverlayEntry? _active;

  static void show(BuildContext context, String message) {
    final overlay = Overlay.of(context);
    // 이미 떠 있는 토스트가 있으면 제거하고 새 것으로 교체.
    if (_active?.mounted ?? false) _active!.remove();
    _active = null;

    late final OverlayEntry entry;
    entry = OverlayEntry(
      builder: (ctx) => _ToastOverlay(
        message: message,
        onDismiss: () {
          // 교체로 이미 제거됐을 수 있어 mounted 가드.
          if (entry.mounted) entry.remove();
          if (identical(_active, entry)) _active = null;
        },
      ),
    );
    _active = entry;
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

    // 좌우 24px 마진 — 긴 메시지도 화면 폭 끝까지 꽉 차지 않게. 짧은 메시지는
    // Center로 가운데에 작은 알약, 긴 메시지는 줄바꿈되며 가운데 정렬.
    return Positioned(
      left: 24,
      right: 24,
      bottom: bottom,
      child: FadeTransition(
        opacity: _opacity,
        child: Center(
          child: GlassPanel(
            borderRadius: AppRadii.xlBorder,
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 20,
                vertical: 10,
              ),
              child: DefaultTextStyle(
                textAlign: TextAlign.center,
                style: AppTypography.body(14, weight: FontWeight.w500)
                    .copyWith(color: context.colors.foreground, height: 1.4),
                child: Text(widget.message),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
