import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../../../core/theme/app_colors_ext.dart';
import '../../../core/theme/app_typography.dart';

/// PIN 입력 controller — 짧은 문자열 holder + listener.
class PinController extends ChangeNotifier {
  String _value = '';
  String get value => _value;

  void append(int d) {
    _value = _value + d.toString();
    notifyListeners();
  }

  void backspace() {
    if (_value.isEmpty) return;
    _value = _value.substring(0, _value.length - 1);
    notifyListeners();
  }

  void clear() {
    if (_value.isEmpty) return;
    _value = '';
    notifyListeners();
  }
}

/// PIN dots — controller 길이를 watch해 채워진 dot 표시. shake는 verify 실패
/// 등 외부에서 토글 시 진동(haptic + 시각). 키패드와 분리되어 화면 상단의
/// 시각 중앙에 자리잡도록 별도 widget.
class PinDots extends StatefulWidget {
  const PinDots({
    super.key,
    required this.controller,
    this.length = 4,
    this.shake = false,
  });

  final PinController controller;
  final int length;
  final bool shake;

  @override
  State<PinDots> createState() => _PinDotsState();
}

class _PinDotsState extends State<PinDots>
    with SingleTickerProviderStateMixin {
  late final AnimationController _shakeCtrl;

  @override
  void initState() {
    super.initState();
    _shakeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    widget.controller.addListener(_onChanged);
  }

  @override
  void didUpdateWidget(covariant PinDots old) {
    super.didUpdateWidget(old);
    if (widget.shake && !old.shake) {
      _shakeCtrl.forward(from: 0);
      // ignore: discarded_futures
      HapticFeedback.heavyImpact();
    }
    if (widget.controller != old.controller) {
      old.controller.removeListener(_onChanged);
      widget.controller.addListener(_onChanged);
    }
  }

  @override
  void dispose() {
    _shakeCtrl.dispose();
    widget.controller.removeListener(_onChanged);
    super.dispose();
  }

  void _onChanged() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _shakeCtrl,
      builder: (context, child) {
        // sin 기반 감쇠 진동 — 진폭 ~6px, 3 cycles.
        final t = _shakeCtrl.value;
        final shake = (1 - t) * 6 * math.sin(t * math.pi * 6);
        return Transform.translate(offset: Offset(shake, 0), child: child);
      },
      child: _Dots(
        length: widget.length,
        filled: widget.controller.value.length,
      ),
    );
  }
}

/// 1-9, 0, backspace 키패드. dots와 분리되어 화면 하단(엄지로 닿기 쉬운
/// 영역)에 둠.
class PinKeypad extends StatelessWidget {
  const PinKeypad({
    super.key,
    required this.controller,
    this.maxLength = 4,
  });

  final PinController controller;
  final int maxLength;

  void _onDigit(int d) {
    if (controller.value.length >= maxLength) return;
    controller.append(d);
    // ignore: discarded_futures
    HapticFeedback.lightImpact();
  }

  void _onBackspace() {
    controller.backspace();
    // ignore: discarded_futures
    HapticFeedback.selectionClick();
  }

  @override
  Widget build(BuildContext context) {
    return _Keypad(onDigit: _onDigit, onBackspace: _onBackspace);
  }
}

class _Dots extends StatelessWidget {
  const _Dots({required this.length, required this.filled});

  final int length;
  final int filled;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < length; i++) ...[
          if (i > 0) const SizedBox(width: 18),
          // 슬롯은 항상 14×14 — 채워질 때만 내부 원이 커지므로 row 높이가
          // 변하지 않아 상단 title/subtitle도 흔들리지 않음.
          SizedBox(
            width: 14,
            height: 14,
            child: Center(
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 120),
                width: i < filled ? 14 : 10,
                height: i < filled ? 14 : 10,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: i < filled
                      ? context.colors.foreground
                      : context.colors.foreground.withValues(alpha: 0.18),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _Keypad extends StatelessWidget {
  const _Keypad({required this.onDigit, required this.onBackspace});

  final ValueChanged<int> onDigit;
  final VoidCallback onBackspace;

  @override
  Widget build(BuildContext context) {
    // 키패드 자체는 maxWidth 280으로 묶고 화면 중앙에 배치. mainAxisAlignment
    // .center로 수직 중앙도 함께.
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 280),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
          _row([1, 2, 3]),
          const SizedBox(height: 14),
          _row([4, 5, 6]),
          const SizedBox(height: 14),
          _row([7, 8, 9]),
          const SizedBox(height: 14),
          Row(
            children: [
              const Expanded(child: SizedBox.shrink()),
              Expanded(child: _DigitButton(digit: 0, onTap: () => onDigit(0))),
              Expanded(child: _BackspaceButton(onTap: onBackspace)),
            ],
          ),
          ],
        ),
      ),
    );
  }

  Widget _row(List<int> digits) {
    return Row(
      children: [
        for (final d in digits)
          Expanded(child: _DigitButton(digit: d, onTap: () => onDigit(d))),
      ],
    );
  }
}

class _DigitButton extends StatelessWidget {
  const _DigitButton({required this.digit, required this.onTap});

  final int digit;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: SizedBox(
        height: 60,
        child: Center(
          child: Text(
            '$digit',
            style: AppTypography.display(28).copyWith(
              color: context.colors.foreground,
            ),
          ),
        ),
      ),
    );
  }
}

class _BackspaceButton extends StatelessWidget {
  const _BackspaceButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: SizedBox(
        height: 60,
        child: Center(
          child: FaIcon(
            FontAwesomeIcons.deleteLeft,
            size: 22,
            color: context.colors.foregroundMuted,
          ),
        ),
      ),
    );
  }
}
