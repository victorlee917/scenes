import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_colors_ext.dart';
import '../../core/theme/app_typography.dart';
import '../../core/theme/theme_provider.dart';
import '../../l10n/app_localizations.dart';
import '../home/widgets/detail_app_bar.dart';

/// 테마 선택 화면.
class ThemeScreen extends ConsumerWidget {
  const ThemeScreen({super.key});

  static Route<void> route() {
    return MaterialPageRoute<void>(
      builder: (_) => const ThemeScreen(),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final padding = MediaQuery.paddingOf(context);
    final l10n = AppLocalizations.of(context);
    final selected = ref.watch(themeModeProvider).valueOrNull ?? ThemeMode.dark;

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
              _ThemeOption(
                label: 'Dark',
                selected: selected == ThemeMode.dark,
                onTap: () =>
                    ref.read(themeModeProvider.notifier).set(ThemeMode.dark),
              ),
              _ThemeOption(
                label: 'Light',
                selected: selected == ThemeMode.light,
                onTap: () =>
                    ref.read(themeModeProvider.notifier).set(ThemeMode.light),
              ),
              _ThemeOption(
                label: 'System',
                selected: selected == ThemeMode.system,
                onTap: () =>
                    ref.read(themeModeProvider.notifier).set(ThemeMode.system),
              ),
            ],
          ),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: DetailAppBar(
              topInset: padding.top,
              title: l10n.settingsTheme,
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

class _ThemeOption extends StatelessWidget {
  const _ThemeOption({
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
