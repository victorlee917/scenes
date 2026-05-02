import 'package:flutter/material.dart';

import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_colors_ext.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/confirm_dialog.dart';
import '../../l10n/app_localizations.dart';
import '../home/widgets/detail_app_bar.dart';
import 'notifications_screen.dart';
import 'theme_screen.dart';

/// 설정 화면.
///
/// 세 섹션으로 구성:
/// - Preferences: 테마, 푸시 알림 (토글)
/// - About: 개인정보처리방침, 서비스이용약관, 인스타그램
/// - Account: 로그아웃, 탈퇴
///
/// 각 항목은 아직 동작을 연결하지 않았음.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  static Route<void> route() {
    return MaterialPageRoute<void>(
      builder: (_) => const SettingsScreen(),
    );
  }

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  double _borderOpacity = 0.0;

  bool _onScroll(ScrollNotification n) {
    final border = n.metrics.pixels > 0 ? 1.0 : 0.0;
    if (border != _borderOpacity) {
      setState(() => _borderOpacity = border);
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final padding = MediaQuery.paddingOf(context);
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      // backgroundColor handled by theme
      body: Stack(
        children: [
          NotificationListener<ScrollNotification>(
            onNotification: _onScroll,
            child: ListView(
              padding: EdgeInsets.only(
                top: padding.top + DetailAppBar.barHeight + 16,
                bottom: padding.bottom + 40,
              ),
              children: [
                _SectionHeader(label: 'Account'),
                _AccountTile(
                  email: 'scenes@example.com',
                  joinedDate: 'Joined Apr 3, 2025',
                  providerIcon: FontAwesomeIcons.google,
                ),
                const SizedBox(height: 24),
                _SectionHeader(label: l10n.settingsSectionPreferences),
                _SettingsTile(
                  label: l10n.settingsTheme,
                  onTap: () {
                    Navigator.of(context).push(ThemeScreen.route());
                  },
                ),
                _SettingsTile(
                  label: l10n.settingsPushNotifications,
                  onTap: () {
                    Navigator.of(context).push(NotificationsScreen.route());
                  },
                ),
                const SizedBox(height: 24),
                _SectionHeader(label: l10n.settingsSectionAbout),
                _SettingsTile(
                  label: l10n.settingsPrivacyPolicy,
                  onTap: () {},
                ),
                _SettingsTile(
                  label: l10n.settingsTermsOfService,
                  onTap: () {},
                ),
                _SettingsTile(
                  label: l10n.settingsInstagram,
                  onTap: () {},
                ),
                _SettingsTile(
                  label: 'Version',
                  trailing: Text(
                    '1.0.0',
                    style: AppTypography.body(14).copyWith(
                      color: context.colors.foregroundMuted,
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                _SectionHeader(label: l10n.settingsSectionAccount),
                _SettingsTile(
                  label: l10n.settingsLogout,
                  onTap: () {},
                ),
                _SettingsTile(
                  label: l10n.settingsDisconnect,
                  isDestructive: true,
                  onTap: () async {
                    final confirmed = await ConfirmDialog.show(
                      context: context,
                      title: 'Disconnect?',
                      message: 'You and your person will be unpaired.',
                      confirmLabel: 'Disconnect',
                      isDestructive: true,
                    );
                    if (confirmed) {
                      // TODO: disconnect 처리
                    }
                  },
                ),
                _SettingsTile(
                  label: l10n.settingsDeleteAccount,
                  isDestructive: true,
                  onTap: () async {
                    final confirmed = await ConfirmDialog.show(
                      context: context,
                      title: 'Delete account?',
                      message: 'All your data will be permanently deleted.',
                      confirmLabel: 'Delete',
                      isDestructive: true,
                    );
                    if (confirmed) {
                      // TODO: delete account 처리
                    }
                  },
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
              title: l10n.settingsTitle,
              titleOpacity: 1.0,
              borderOpacity: _borderOpacity,
              onClose: () => Navigator.of(context).pop(),
              trailing: const SizedBox.shrink(),
              leading: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => Navigator.of(context).pop(),
                child: SizedBox(
                  width: 36,
                  height: 36,
                  child: Center(
                    child: FaIcon(FontAwesomeIcons.chevronLeft,
                        size: 18,
                        color: context.colors.foreground
                            .withValues(alpha: 0.9)),
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

class _AccountTile extends StatelessWidget {
  const _AccountTile({
    required this.email,
    required this.joinedDate,
    required this.providerIcon,
  });

  final String email;
  final String joinedDate;
  final FaIconData providerIcon;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  email,
                  style: AppTypography.body(15, weight: FontWeight.w500)
                      .copyWith(color: context.colors.foreground),
                ),
                const SizedBox(height: 3),
                Text(
                  joinedDate,
                  style: AppTypography.body(12).copyWith(
                    color: context.colors.foregroundMuted,
                  ),
                ),
              ],
            ),
          ),
          FaIcon(
            providerIcon,
            size: 14,
            color: context.colors.foregroundMuted,
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
      child: Text(
        label.toUpperCase(),
        style: AppTypography.body(11, weight: FontWeight.w500).copyWith(
          color: context.colors.foregroundMuted,
          letterSpacing: 1.2,
        ),
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  const _SettingsTile({
    required this.label,
    this.onTap,
    this.trailing,
    this.isDestructive = false,
  });

  final String label;
  final VoidCallback? onTap;
  final Widget? trailing;
  final bool isDestructive;

  @override
  Widget build(BuildContext context) {
    final color = isDestructive
        ? const Color(0xFFE06C75)
        : context.colors.foreground;
    final trailingWidget = trailing ??
        (onTap != null
            ? FaIcon(
                FontAwesomeIcons.chevronRight,
                size: 14,
                color: context.colors.foregroundMuted,
              )
            : null);

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: AppTypography.body(15).copyWith(color: color),
              ),
            ),
            ?trailingWidget,
          ],
        ),
      ),
    );
  }
}
