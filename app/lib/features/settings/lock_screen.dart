import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../../core/theme/app_colors_ext.dart';
import '../../core/theme/app_radii.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/confirm_dialog.dart';
import '../../l10n/app_localizations.dart';
import '../home/widgets/detail_app_bar.dart';
import '../lock/lock_view_model.dart';
import '../lock/widgets/pin_setup_screen.dart';

/// 앱 잠금 설정 화면.
///
/// - 잠금 OFF: "PIN 설정" 버튼 단일 노출.
/// - 잠금 ON: "PIN 변경", "생체 인증 토글"(기기 지원 시), "잠금 끄기" 노출.
/// - 하단에 비밀번호 분실 시 복구 흐름(재로그인 → 잠금 OFF) 안내문.
class LockScreen extends ConsumerWidget {
  const LockScreen({super.key});

  static Route<void> route() {
    return MaterialPageRoute<void>(builder: (_) => const LockScreen());
  }

  Future<void> _setupPin(BuildContext context, WidgetRef ref) async {
    await Navigator.of(context).push<bool>(
      PinSetupScreen.route(PinSetupMode.setup),
    );
  }

  Future<void> _changePin(BuildContext context, WidgetRef ref) async {
    await Navigator.of(context).push<bool>(
      PinSetupScreen.route(PinSetupMode.change),
    );
  }

  Future<void> _disableLock(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context);
    // 잠금 끄기 전에 PIN 한 번 더 확인 — 옆에 있던 사람이 임의로 끄지 못하게.
    final verified = await Navigator.of(context).push<bool>(
      PinSetupScreen.route(PinSetupMode.verifyOnly),
    );
    if (verified != true || !context.mounted) return;
    final confirmed = await ConfirmDialog.show(
      context: context,
      title: l10n.lockDisableConfirmTitle,
      message: l10n.lockDisableConfirmBody,
      confirmLabel: l10n.lockDisableConfirmAction,
      cancelLabel: l10n.commonCancel,
      isDestructive: true,
    );
    if (!confirmed) return;
    await ref.read(lockViewModelProvider.notifier).disable();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final padding = MediaQuery.paddingOf(context);
    final l10n = AppLocalizations.of(context);
    final stateAsync = ref.watch(lockViewModelProvider);
    final state = stateAsync.valueOrNull;
    final enabled = state?.enabled ?? false;
    final biometricEnabled = state?.biometricEnabled ?? false;
    final biometricAvailable = state?.biometricAvailable ?? false;

    return Scaffold(
      body: Stack(
        children: [
          ListView(
            padding: EdgeInsets.only(
              top: padding.top + DetailAppBar.barHeight + 16,
              bottom: padding.bottom + 40,
            ),
            children: [
              if (!enabled)
                _ActionRow(
                  label: l10n.lockSetUpButton,
                  onTap: () => _setupPin(context, ref),
                )
              else ...[
                _ActionRow(
                  label: l10n.lockChangePinButton,
                  onTap: () => _changePin(context, ref),
                ),
                _BiometricRow(
                  enabled: biometricEnabled,
                  available: biometricAvailable,
                  onChanged: (v) => ref
                      .read(lockViewModelProvider.notifier)
                      .setBiometricEnabled(v),
                ),
                _ActionRow(
                  label: l10n.lockDisableButton,
                  destructive: true,
                  onTap: () => _disableLock(context, ref),
                ),
              ],
              const SizedBox(height: 24),
              // 비밀번호 분실 시 복구 흐름 안내.
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: _NoticeBox(text: l10n.lockRecoveryNotice),
              ),
            ],
          ),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: DetailAppBar(
              topInset: padding.top,
              title: l10n.lockSettingsHeader,
              titleOpacity: 1.0,
              borderOpacity: 0,
              onClose: () => Navigator.of(context).pop(),
              trailing: const SizedBox.shrink(),
              leading: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => Navigator.of(context).pop(),
                child: SizedBox(
                  width: 36,
                  height: 36,
                  child: Center(
                    child: FaIcon(
                      FontAwesomeIcons.chevronLeft,
                      size: 18,
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

class _ActionRow extends StatelessWidget {
  const _ActionRow({
    required this.label,
    required this.onTap,
    this.destructive = false,
  });

  final String label;
  final VoidCallback onTap;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final color = destructive
        ? const Color(0xFFE5484D)
        : context.colors.foreground;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: AppTypography.body(15).copyWith(color: color),
              ),
            ),
            FaIcon(
              FontAwesomeIcons.chevronRight,
              size: 12,
              color: context.colors.foregroundMuted,
            ),
          ],
        ),
      ),
    );
  }
}

class _BiometricRow extends StatelessWidget {
  const _BiometricRow({
    required this.enabled,
    required this.available,
    required this.onChanged,
  });

  final bool enabled;
  final bool available;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  l10n.lockBiometricToggle,
                  style: AppTypography.body(15).copyWith(
                    color: context.colors.foreground,
                  ),
                ),
                if (!available) ...[
                  const SizedBox(height: 4),
                  Text(
                    l10n.lockBiometricUnavailable,
                    style: AppTypography.body(12).copyWith(
                      color: context.colors.foregroundMuted,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 12),
          Transform.translate(
            offset: const Offset(8, 0),
            child: Switch.adaptive(
              value: available && enabled,
              onChanged: available ? onChanged : null,
            ),
          ),
        ],
      ),
    );
  }
}

class _NoticeBox extends StatelessWidget {
  const _NoticeBox({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: context.colors.clickableArea,
        borderRadius: AppRadii.mdBorder,
        border: Border.all(
          color: context.colors.foreground.withValues(alpha: 0.06),
          width: 0.5,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          FaIcon(
            FontAwesomeIcons.circleInfo,
            size: 14,
            color: context.colors.foregroundMuted,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: AppTypography.body(12).copyWith(
                color: context.colors.foregroundMuted,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
