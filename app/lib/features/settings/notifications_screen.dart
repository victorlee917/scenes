import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_colors_ext.dart';
import '../../core/theme/app_typography.dart';
import '../../l10n/app_localizations.dart';
import '../home/widgets/detail_app_bar.dart';

/// 알림 설정 화면.
class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  static Route<void> route() {
    return MaterialPageRoute<void>(
      builder: (_) => const NotificationsScreen(),
    );
  }

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  bool _newScene = true;
  bool _newMedia = true;
  bool _partnerActivity = true;
  bool _reminders = false;
  bool _appUpdates = false;

  @override
  Widget build(BuildContext context) {
    final padding = MediaQuery.paddingOf(context);
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      // backgroundColor handled by theme
      body: Stack(
        children: [
          ListView(
            padding: EdgeInsets.only(
              top: padding.top + DetailAppBar.barHeight + 16,
              bottom: padding.bottom + 40,
            ),
            children: [
              _NotificationTile(
                label: 'New Scene',
                description: 'When your partner creates a new scene.',
                value: _newScene,
                onChanged: (v) => setState(() => _newScene = v),
              ),
              _NotificationTile(
                label: 'New Media',
                description: 'When new photos, videos, or other media are added.',
                value: _newMedia,
                onChanged: (v) => setState(() => _newMedia = v),
              ),
              _NotificationTile(
                label: 'Partner Activity',
                description: 'When your partner views or edits a scene.',
                value: _partnerActivity,
                onChanged: (v) => setState(() => _partnerActivity = v),
              ),
              _NotificationTile(
                label: 'Reminders',
                description: 'Gentle nudges to capture moments together.',
                value: _reminders,
                onChanged: (v) => setState(() => _reminders = v),
              ),
              _NotificationTile(
                label: 'App Updates',
                description: 'News about new features and improvements.',
                value: _appUpdates,
                onChanged: (v) => setState(() => _appUpdates = v),
              ),
            ],
          ),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: DetailAppBar(
              topInset: padding.top,
              title: l10n.settingsPushNotifications,
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

class _NotificationTile extends StatelessWidget {
  const _NotificationTile({
    required this.label,
    required this.description,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final String description;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: AppTypography.body(15).copyWith(
                    color: context.colors.foreground,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: AppTypography.body(12).copyWith(
                    color: context.colors.foregroundMuted,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Transform.translate(
            offset: const Offset(8, 0),
            child: Switch.adaptive(
              value: value,
              onChanged: onChanged,
            ),
          ),
        ],
      ),
    );
  }
}
