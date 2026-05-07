import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/theme/app_colors_ext.dart';
import '../../core/theme/app_radii.dart';
import '../../core/theme/app_typography.dart';
import '../../l10n/app_localizations.dart';
import '../couple/couple_view_model.dart';
import '../home/widgets/detail_app_bar.dart';
import '../push/notification_preferences_view_model.dart';

/// 알림 설정 화면.
///
/// 분기:
/// - OS 알림 권한이 authorized/provisional가 아니면 → 토글 리스트 대신
///   "Settings에서 켜라"는 배너만 노출. 탭 시 시스템 설정 앱의 본 앱 페이지
///   로 외부 이동.
/// - 권한 OK → notification_preferences 토글 리스트. 변경 시 즉시 백엔드
///   upsert.
///
/// 앱 lifecycle resume 시 권한 상태를 다시 fetch — 사용자가 시스템 설정에서
/// 켜고 돌아올 때 자동 반영.
class NotificationsScreen extends ConsumerStatefulWidget {
  const NotificationsScreen({super.key});

  static Route<void> route() {
    return MaterialPageRoute<void>(
      builder: (_) => const NotificationsScreen(),
    );
  }

  @override
  ConsumerState<NotificationsScreen> createState() =>
      _NotificationsScreenState();
}

class _NotificationsScreenState extends ConsumerState<NotificationsScreen>
    with WidgetsBindingObserver {
  AuthorizationStatus? _osStatus;
  bool _checkingStatus = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _refreshOsStatus();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _refreshOsStatus();
      // 사용자가 Settings에서 권한 켜고 돌아왔다면 prefs row도 비어있을 수
      // 있으니 같이 refresh.
      ref.read(notificationPreferencesProvider.notifier).refresh();
    }
  }

  Future<void> _refreshOsStatus() async {
    final settings =
        await FirebaseMessaging.instance.getNotificationSettings();
    if (!mounted) return;
    setState(() {
      _osStatus = settings.authorizationStatus;
      _checkingStatus = false;
    });
  }

  Future<void> _openSystemSettings() async {
    // iOS: app-settings: scheme. Android: app-specific notification settings.
    // url_launcher가 두 플랫폼 모두 처리.
    final uri = Uri.parse('app-settings:');
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      // 실패해도 사용자가 수동으로 열 수 있음 — 별도 처리 X.
    }
  }

  @override
  Widget build(BuildContext context) {
    final padding = MediaQuery.paddingOf(context);
    final l10n = AppLocalizations.of(context);

    final osAuthorized = _osStatus == AuthorizationStatus.authorized ||
        _osStatus == AuthorizationStatus.provisional;

    return Scaffold(
      body: Stack(
        children: [
          ListView(
            padding: EdgeInsets.only(
              top: padding.top + DetailAppBar.barHeight + 16,
              bottom: padding.bottom + 40,
            ),
            children: [
              if (_checkingStatus)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 60),
                  child: Center(
                    child: SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 1.5,
                        color: context.colors.foregroundMuted,
                      ),
                    ),
                  ),
                )
              else if (!osAuthorized)
                _PermissionBanner(onTap: _openSystemSettings)
              else
                const _PreferencesList(),
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

class _PermissionBanner extends ConsumerWidget {
  const _PermissionBanner({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final partnerName =
        ref.watch(activeCoupleProvider).valueOrNull?.partner.displayName ?? '';
    final activitySubject =
        partnerName.isEmpty ? 'partner' : "$partnerName's";
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
          decoration: BoxDecoration(
            color: context.colors.clickableArea,
            borderRadius: AppRadii.lgBorder,
            border: Border.all(
              color: context.colors.foreground.withValues(alpha: 0.06),
              width: 0.5,
            ),
          ),
          child: Row(
            children: [
              FaIcon(
                FontAwesomeIcons.bellSlash,
                size: 18,
                color: context.colors.foregroundMuted,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Turn on notifications',
                      style: AppTypography.body(15, weight: FontWeight.w600)
                          .copyWith(color: context.colors.foreground),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Enable in Settings to receive $activitySubject '
                      'activity and updates.',
                      style: AppTypography.body(12).copyWith(
                        color: context.colors.foregroundMuted,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              FaIcon(
                FontAwesomeIcons.chevronRight,
                size: 12,
                color: context.colors.foregroundMuted,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PreferencesList extends ConsumerWidget {
  const _PreferencesList();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final prefsAsync = ref.watch(notificationPreferencesProvider);

    return prefsAsync.when(
      loading: () => Padding(
        padding: const EdgeInsets.symmetric(vertical: 60),
        child: Center(
          child: SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(
              strokeWidth: 1.5,
              color: context.colors.foregroundMuted,
            ),
          ),
        ),
      ),
      error: (_, _) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 24),
        child: Center(
          child: Text(
            'Could not load preferences.',
            style: AppTypography.body(13).copyWith(
              color: context.colors.foregroundMuted,
            ),
          ),
        ),
      ),
      data: (prefs) {
        // row가 아직 없을 수도 있음(처음 진입 + permission grant flow가 비동기).
        // 이 경우 view model이 토글 시 자동으로 row를 만들어 주므로 default
        // 값(all-on 의도)으로 표시.
        final partner = prefs?.partnerActivityEnabled ?? true;
        final marketing = prefs?.marketingEnabled ?? true;
        final notifier =
            ref.read(notificationPreferencesProvider.notifier);
        return Column(
          children: [
            _NotificationTile(
              label: 'Partner activity',
              description:
                  'When your partner adds scenes, moments, or likes yours.',
              value: partner,
              onChanged: notifier.setPartnerActivity,
            ),
            _NotificationTile(
              label: 'App news',
              description:
                  'Updates about new features and announcements.',
              value: marketing,
              onChanged: notifier.setMarketing,
            ),
          ],
        );
      },
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
