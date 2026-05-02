import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_colors_ext.dart';
import '../../core/theme/app_radii.dart';
import '../../core/theme/app_typography.dart';
import '../home/widgets/detail_app_bar.dart';

/// Share our Scenes 노출 관리 화면.
///
/// 공유 페이지에 표시할 항목을 개별 토글로 관리한다.
class ShareSettingsScreen extends StatefulWidget {
  const ShareSettingsScreen({super.key});

  static Route<void> route() {
    return MaterialPageRoute<void>(
      builder: (_) => const ShareSettingsScreen(),
    );
  }

  @override
  State<ShareSettingsScreen> createState() => _ShareSettingsScreenState();
}

class _ShareSettingsScreenState extends State<ShareSettingsScreen> {
  bool _showPhotos = true;
  bool _showVideos = true;
  bool _showFilms = true;
  bool _showMusic = true;
  bool _showBooks = true;
  bool _showPlaces = true;
  bool _showDates = true;
  double _borderOpacity = 0.0;

  bool _onScroll(ScrollNotification n) {
    final border = (n.metrics.pixels / 20).clamp(0.0, 1.0);
    if ((border - _borderOpacity).abs() > 0.01) {
      setState(() => _borderOpacity = border);
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final padding = MediaQuery.paddingOf(context);

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
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 16,
                  ),
                  child: Text(
                    'Choose what to show on your shared webpage.',
                    style: AppTypography.body(14).copyWith(
                      color: context.colors.foregroundMuted,
                    ),
                  ),
                ),
                _VisibilityTile(
                  label: 'Photos',
                  value: _showPhotos,
                  onChanged: (v) => setState(() => _showPhotos = v),
                ),
                _VisibilityTile(
                  label: 'Videos',
                  value: _showVideos,
                  onChanged: (v) => setState(() => _showVideos = v),
                ),
                _VisibilityTile(
                  label: 'Films',
                  value: _showFilms,
                  onChanged: (v) => setState(() => _showFilms = v),
                ),
                _VisibilityTile(
                  label: 'Music',
                  value: _showMusic,
                  onChanged: (v) => setState(() => _showMusic = v),
                ),
                _VisibilityTile(
                  label: 'Books',
                  value: _showBooks,
                  onChanged: (v) => setState(() => _showBooks = v),
                ),
                _VisibilityTile(
                  label: 'Places',
                  value: _showPlaces,
                  onChanged: (v) => setState(() => _showPlaces = v),
                ),
                _VisibilityTile(
                  label: 'Dates',
                  value: _showDates,
                  onChanged: (v) => setState(() => _showDates = v),
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
              title: 'Share our Scenes',
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

          // 하단 고정 — 링크 공유 영역
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              padding: EdgeInsets.only(
                left: 24,
                right: 24,
                top: 20,
                bottom: padding.bottom + 24,
              ),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [
                    Color(0xFF151517),
                    Color(0xE6151517),
                    Color(0x94151517),
                    Color(0x00151517),
                  ],
                  stops: [0.0, 0.5, 0.8, 1.0],
                ),
              ),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  borderRadius: AppRadii.smBorder,
                  color: context.colors.clickableArea,
                  border: Border.all(
                    color: context.colors.foreground.withValues(alpha: 0.06),
                    width: 0.5,
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'scenes.app/s/sora-jun',
                        style: AppTypography.body(14).copyWith(
                          color: context.colors.foreground,
                        ),
                      ),
                    ),
                    GestureDetector(
                      onTap: () {
                        SharePlus.instance.share(
                          ShareParams(
                            uri: Uri.parse(
                                'https://scenes.app/s/sora-jun'),
                          ),
                        );
                      },
                      child: FaIcon(
                        FontAwesomeIcons.shareFromSquare,
                        size: 16,
                        color:
                            context.colors.foreground.withValues(alpha: 0.7),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _VisibilityTile extends StatelessWidget {
  const _VisibilityTile({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 6),
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
          Switch.adaptive(
            value: value,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}
