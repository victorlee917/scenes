import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../../core/theme/app_colors_ext.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/confirm_dialog.dart';
import '../../l10n/app_localizations.dart';
import '../home/widgets/detail_app_bar.dart';
import '../profile/account_deletion.dart';
import 'disconnect_confirm_sheet.dart';

/// 파트너 disconnect / 계정 삭제 등 되돌릴 수 없는 작업을 모아두는 화면.
/// Settings의 Account 섹션에서 단일 'Danger zone' 진입점을 통해서만 도달.
class DangerZoneScreen extends ConsumerStatefulWidget {
  const DangerZoneScreen({super.key});

  static Route<void> route() {
    return MaterialPageRoute<void>(
      builder: (_) => const DangerZoneScreen(),
    );
  }

  @override
  ConsumerState<DangerZoneScreen> createState() => _DangerZoneScreenState();
}

class _DangerZoneScreenState extends ConsumerState<DangerZoneScreen> {
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
                _DangerTile(
                  label: l10n.settingsDisconnect,
                  onTap: () async {
                    final confirmed = await ConfirmDialog.show(
                      context: context,
                      title: l10n.disconnectConfirmTitle,
                      message: l10n.disconnectConfirmMessage,
                      noticeText: l10n.disconnectConfirmNotice,
                      confirmLabel: l10n.disconnectConfirmAction,
                      isDestructive: true,
                    );
                    if (!confirmed) return;
                    if (!context.mounted) return;
                    // 첫 confirm 통과 후 타이핑 서명 시트. 실 실행/에러 처리는
                    // 시트 내부에서.
                    await DisconnectConfirmSheet.show(context);
                  },
                ),
                _DangerTile(
                  label: l10n.settingsDeleteAccount,
                  onTap: () => AccountDeletion.confirmAndDelete(
                    context: context,
                    ref: ref,
                  ),
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
              title: l10n.dangerZoneTitle,
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

/// 빨간 라벨 + chevron 만 있는 단순 행. settings의 _SettingsTile과 시각 일관성
/// 유지하되 destructive 색을 강제.
class _DangerTile extends StatelessWidget {
  const _DangerTile({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
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
                style: AppTypography.body(15).copyWith(
                  color: const Color(0xFFE06C75),
                ),
              ),
            ),
            FaIcon(
              FontAwesomeIcons.chevronRight,
              size: 14,
              color: context.colors.foregroundMuted,
            ),
          ],
        ),
      ),
    );
  }
}
