import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../../../core/theme/app_colors_ext.dart';
import '../../../core/theme/app_typography.dart';
import '../../../l10n/app_localizations.dart';
import '../../home/widgets/detail_app_bar.dart';
import '../lock_view_model.dart';
import 'pin_pad.dart';

/// PIN 설정/변경/해제 인증 화면. [mode]로 단계 흐름 결정.
///
///   setup       : enter → confirm → save → pop(true)
///   change      : verify current → enter new → confirm → save → pop(true)
///   verifyOnly  : verify → pop(true). 잠금 끄기 등 confirmation에 사용.
enum PinSetupMode { setup, change, verifyOnly }

class PinSetupScreen extends ConsumerStatefulWidget {
  const PinSetupScreen({super.key, required this.mode});

  final PinSetupMode mode;

  static Route<bool> route(PinSetupMode mode) {
    return MaterialPageRoute<bool>(
      builder: (_) => PinSetupScreen(mode: mode),
      fullscreenDialog: true,
    );
  }

  @override
  ConsumerState<PinSetupScreen> createState() => _PinSetupScreenState();
}

enum _Step { verifyCurrent, enterNew, confirmNew }

class _PinSetupScreenState extends ConsumerState<PinSetupScreen> {
  final _controller = PinController();
  late _Step _step;
  String _firstEntry = '';
  bool _shake = false;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _step = switch (widget.mode) {
      PinSetupMode.setup => _Step.enterNew,
      PinSetupMode.change => _Step.verifyCurrent,
      PinSetupMode.verifyOnly => _Step.verifyCurrent,
    };
    _controller.addListener(_onPinChanged);
  }

  @override
  void dispose() {
    _controller.removeListener(_onPinChanged);
    _controller.dispose();
    super.dispose();
  }

  Future<void> _onPinChanged() async {
    if (_busy) return;
    if (_controller.value.length < 4) return;

    setState(() => _busy = true);
    final pin = _controller.value;
    try {
      switch (_step) {
        case _Step.verifyCurrent:
          final ok = await ref
              .read(lockViewModelProvider.notifier)
              .verifyPin(pin);
          if (!ok) {
            _flashError();
            return;
          }
          if (widget.mode == PinSetupMode.verifyOnly) {
            if (!mounted) return;
            Navigator.of(context).pop(true);
            return;
          }
          // mode == change → enter new
          setState(() {
            _step = _Step.enterNew;
            _controller.clear();
          });
        case _Step.enterNew:
          setState(() {
            _firstEntry = pin;
            _step = _Step.confirmNew;
            _controller.clear();
          });
        case _Step.confirmNew:
          if (pin != _firstEntry) {
            _flashError();
            setState(() {
              _step = _Step.enterNew;
              _firstEntry = '';
              _controller.clear();
            });
            return;
          }
          await ref.read(lockViewModelProvider.notifier).setPin(pin);
          if (!mounted) return;
          Navigator.of(context).pop(true);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _flashError() {
    setState(() => _shake = true);
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) {
        setState(() {
          _shake = false;
          _controller.clear();
        });
      }
    });
  }

  String _title(AppLocalizations l10n) {
    return switch (_step) {
      _Step.verifyCurrent => l10n.lockEnterCurrent,
      _Step.enterNew => l10n.lockEnterNew,
      _Step.confirmNew => l10n.lockConfirmNew,
    };
  }

  String _subtitle(AppLocalizations l10n) {
    return switch (_step) {
      _Step.verifyCurrent => l10n.lockEnterCurrentDesc,
      _Step.enterNew => l10n.lockEnterNewDesc,
      _Step.confirmNew => l10n.lockConfirmNewDesc,
    };
  }

  String _appBarTitle(AppLocalizations l10n) {
    return switch (widget.mode) {
      PinSetupMode.setup => l10n.lockTitleSetup,
      PinSetupMode.change => l10n.lockTitleChange,
      PinSetupMode.verifyOnly => l10n.lockTitleVerify,
    };
  }

  @override
  Widget build(BuildContext context) {
    final padding = MediaQuery.paddingOf(context);
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      body: Stack(
        children: [
          Padding(
            padding: EdgeInsets.only(
              top: padding.top + DetailAppBar.barHeight + 40,
              bottom: padding.bottom + 24,
              left: 24,
              right: 24,
            ),
            child: Column(
              children: [
                // 상단 절반 — title/subtitle/dots가 시각 중앙에 함께 위치.
                Expanded(
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _title(l10n),
                          textAlign: TextAlign.center,
                          style: AppTypography.body(17,
                                  weight: FontWeight.w600)
                              .copyWith(color: context.colors.foreground),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _subtitle(l10n),
                          textAlign: TextAlign.center,
                          style: AppTypography.body(13).copyWith(
                            color: context.colors.foregroundMuted,
                            height: 1.4,
                          ),
                        ),
                        const SizedBox(height: 36),
                        PinDots(controller: _controller, shake: _shake),
                      ],
                    ),
                  ),
                ),
                // 하단 절반 — 키패드 단독, 화면 폭 가득 사용.
                Expanded(
                  child: PinKeypad(controller: _controller),
                ),
              ],
            ),
          ),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: DetailAppBar(
              topInset: padding.top,
              title: _appBarTitle(l10n),
              titleOpacity: 1.0,
              borderOpacity: 0,
              onClose: () => Navigator.of(context).pop(false),
              trailing: const SizedBox.shrink(),
              leading: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => Navigator.of(context).pop(false),
                child: SizedBox(
                  width: 36,
                  height: 36,
                  child: Center(
                    child: FaIcon(
                      FontAwesomeIcons.xmark,
                      size: 20,
                      color:
                          context.colors.foreground.withValues(alpha: 0.9),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
