import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors_ext.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/confirm_dialog.dart';
import '../../../l10n/app_localizations.dart';
import '../../auth/auth_view_model.dart';
import '../lock_view_model.dart';
import 'pin_pad.dart';

/// 잠금 challenge — `lockViewModelProvider.isLocked == true`일 때 [LockOverlay]
/// 가 띄움.
///
/// - mount 시 생체 인증이 enabled이고 available이면 자동 prompt → 성공 시 해제.
/// - PIN 입력 4자리 도달 시 검증, 일치하면 해제.
/// - "PIN 잊음" → 로그아웃 dialog → 로그아웃 + 잠금 wipe (재로그인 후 OFF).
class LockChallengeScreen extends ConsumerStatefulWidget {
  const LockChallengeScreen({super.key});

  @override
  ConsumerState<LockChallengeScreen> createState() =>
      _LockChallengeScreenState();
}

class _LockChallengeScreenState extends ConsumerState<LockChallengeScreen> {
  final _controller = PinController();
  bool _shake = false;
  bool _busy = false;
  bool _biometricAttempted = false;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onPinChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _maybePromptBiometric();
    });
  }

  @override
  void dispose() {
    _controller.removeListener(_onPinChanged);
    _controller.dispose();
    super.dispose();
  }

  Future<void> _maybePromptBiometric() async {
    if (_biometricAttempted) return;
    _biometricAttempted = true;
    final state = ref.read(lockViewModelProvider).valueOrNull;
    if (state == null || !state.biometricEnabled || !state.biometricAvailable) {
      return;
    }
    final l10n = AppLocalizations.of(context);
    await ref
        .read(lockViewModelProvider.notifier)
        .unlockWithBiometric(reason: l10n.lockBiometricPrompt);
    // 실패하면 PIN 입력으로 자연스럽게 fallback — 사용자가 키패드로 입력 가능.
  }

  Future<void> _onPinChanged() async {
    if (_busy) return;
    if (_controller.value.length < 4) return;

    setState(() => _busy = true);
    try {
      final ok = await ref
          .read(lockViewModelProvider.notifier)
          .verifyPin(_controller.value);
      if (!ok) {
        _flashError();
      }
      // 성공이면 isLocked=false → LockOverlay가 자동으로 child를 보여줌.
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

  Future<void> _onForgotPin() async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await ConfirmDialog.show(
      context: context,
      title: l10n.lockForgotConfirmTitle,
      message: l10n.lockForgotConfirmBody,
      confirmLabel: l10n.lockForgotConfirmAction,
      cancelLabel: l10n.commonCancel,
      isDestructive: true,
    );
    if (!confirmed || !mounted) return;
    // 잠금 데이터 wipe → 다음 로그인 후 다시 설정 가능.
    await ref.read(lockViewModelProvider.notifier).resetForAuthChange();
    if (!mounted) return;
    // 그 다음 로그아웃. router가 onboarding으로 전환.
    await ref.read(authViewModelProvider.notifier).signOut();
  }

  @override
  Widget build(BuildContext context) {
    final padding = MediaQuery.paddingOf(context);
    final l10n = AppLocalizations.of(context);
    // 자동 prompt + PIN fallback이면 UI는 충분 — state watch는 불필요.
    return Scaffold(
      backgroundColor: context.colors.background,
      body: Padding(
        // SafeArea로 감싸지 않음 — setup 화면이 padding.top을 직접 인셋으로
        // 더하는데 SafeArea도 같은 padding을 다시 적용하면 이중 inset이 되어
        // 콘텐츠가 더 아래로 밀림. setup과 동일하게 raw padding.top + 88로
        // 한 번만 적용.
        padding: EdgeInsets.only(
          top: padding.top + 88,
          bottom: padding.bottom + 16,
        ),
          child: Column(
            children: [
              // 상단 절반 — title + dots가 시각 중앙에 함께 위치.
              Expanded(
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        l10n.lockChallengeTitle,
                        textAlign: TextAlign.center,
                        style: AppTypography.body(17, weight: FontWeight.w600)
                            .copyWith(color: context.colors.foreground),
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
              TextButton(
                onPressed: _busy ? null : _onForgotPin,
                child: Text(
                  l10n.lockForgotPin,
                  style: AppTypography.body(13).copyWith(
                    color: context.colors.foregroundMuted,
                  ),
                ),
              ),
            ],
          ),
        ),
    );
  }
}

/// 앱 전체를 wrapping해서 `isLocked == true`이면 child 위에 challenge 표시.
/// `MaterialApp.router(builder: ...)`에서 사용.
///
/// challenge 화면 안에서 ConfirmDialog / 모달 시트가 동작하려면 자체 Navigator
/// 가 필요. router의 Navigator는 [child] 안쪽이라 형제 위치(this Stack 자식)
/// 에선 못 찾는다. 따라서 LockChallengeScreen을 nested Navigator로 감쌈.
class LockOverlay extends ConsumerWidget {
  const LockOverlay({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(lockViewModelProvider).valueOrNull;
    final isLocked = state?.isLocked == true;
    return Stack(
      children: [
        child,
        if (isLocked)
          Positioned.fill(
            child: Navigator(
              onGenerateRoute: (_) => MaterialPageRoute<void>(
                builder: (_) => const LockChallengeScreen(),
              ),
            ),
          ),
      ],
    );
  }
}
