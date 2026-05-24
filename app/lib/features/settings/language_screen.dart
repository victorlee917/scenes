import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../../core/locale/locale_provider.dart';
import '../../core/theme/app_colors_ext.dart';
import '../../core/theme/app_typography.dart';
import '../../l10n/app_localizations.dart';
import '../home/widgets/detail_app_bar.dart';

/// 앱 표시 언어 선택 화면.
///
/// 옵션: 디바이스 언어 사용(기본) / English / 한국어. 추후 새 로케일 추가 시
/// [AppLocaleOption] enum과 supportedLocales(=ARB 파일)에만 추가하면 됨.
class LanguageScreen extends ConsumerWidget {
  const LanguageScreen({super.key});

  static Route<void> route() {
    return MaterialPageRoute<void>(
      builder: (_) => const LanguageScreen(),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final padding = MediaQuery.paddingOf(context);
    final l10n = AppLocalizations.of(context);
    final selected =
        ref.watch(appLocaleProvider).valueOrNull ?? AppLocaleOption.system;

    return Scaffold(
      body: Stack(
        children: [
          ListView(
            padding: EdgeInsets.only(
              top: padding.top + DetailAppBar.barHeight + 16,
              bottom: padding.bottom + 40,
            ),
            children: [
              _LanguageOption(
                label: l10n.languageSystem,
                selected: selected == AppLocaleOption.system,
                onTap: () => ref
                    .read(appLocaleProvider.notifier)
                    .set(AppLocaleOption.system),
              ),
              _LanguageOption(
                label: l10n.languageEnglish,
                selected: selected == AppLocaleOption.english,
                onTap: () => ref
                    .read(appLocaleProvider.notifier)
                    .set(AppLocaleOption.english),
              ),
              _LanguageOption(
                label: l10n.languageKorean,
                selected: selected == AppLocaleOption.korean,
                onTap: () => ref
                    .read(appLocaleProvider.notifier)
                    .set(AppLocaleOption.korean),
              ),
            ],
          ),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: DetailAppBar(
              topInset: padding.top,
              title: l10n.languageScreenTitle,
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

class _LanguageOption extends StatelessWidget {
  const _LanguageOption({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
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
                  color: context.colors.foreground,
                ),
              ),
            ),
            if (selected)
              FaIcon(
                FontAwesomeIcons.check,
                size: 16,
                color: context.colors.foreground,
              ),
          ],
        ),
      ),
    );
  }
}
