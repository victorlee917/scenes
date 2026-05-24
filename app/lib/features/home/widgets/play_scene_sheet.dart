import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../../../core/theme/app_colors_ext.dart';
import '../../../core/theme/app_radii.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/floating_bottom_sheet.dart';
import '../../../l10n/app_localizations.dart';
import '../models/scene.dart';
import 'play_scene_screen.dart';

/// 단일 scene 재생 전에 매체 필터(photo/film/music/place)를 고르는 시트.
/// 필터 선택은 HD 구독자 전용 기능이라 보통 구독자에게만 노출 — 비구독자는
/// 호출 측에서 시트를 거치지 않고 곧장 [PlaySceneScreen]으로 진입.
class PlaySceneSheet extends ConsumerStatefulWidget {
  const PlaySceneSheet({super.key, required this.scene});

  final Scene scene;

  static Future<void> show({
    required BuildContext context,
    required Scene scene,
  }) {
    return FloatingBottomSheet.show(
      context: context,
      builder: (_) => PlaySceneSheet(scene: scene),
    );
  }

  @override
  ConsumerState<PlaySceneSheet> createState() => _PlaySceneSheetState();
}

class _PlaySceneSheetState extends ConsumerState<PlaySceneSheet> {
  final Set<String> _selectedMediaTypes = {'photo', 'film', 'music', 'place'};

  static const _mediaTypes = ['photo', 'film', 'music', 'place'];
  static const _mediaIcons = {
    'photo': FontAwesomeIcons.solidImage,
    'film': FontAwesomeIcons.film,
    'music': FontAwesomeIcons.music,
    'place': FontAwesomeIcons.locationDot,
  };

  String _mediaLabel(AppLocalizations l10n, String type) {
    switch (type) {
      case 'photo':
        return l10n.mediaLabelPhoto;
      case 'film':
        return l10n.mediaLabelFilm;
      case 'music':
        return l10n.mediaLabelMusic;
      case 'place':
        return l10n.mediaLabelPlace;
    }
    return type;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(height: 8),
        Text(
          'Play Scene',
          style: AppTypography.display(20).copyWith(
            color: context.colors.foreground,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 24),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            children: [
              for (final type in _mediaTypes) ...[
                if (type != _mediaTypes.first) const SizedBox(width: 6),
                Expanded(
                  child: GestureDetector(
                    onTap: () {
                      setState(() {
                        if (_selectedMediaTypes.contains(type)) {
                          _selectedMediaTypes.remove(type);
                        } else {
                          _selectedMediaTypes.add(type);
                        }
                      });
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      decoration: BoxDecoration(
                        borderRadius: AppRadii.sheetInnerBorder,
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            context.colors.surface,
                            context.colors.surfaceElevated,
                          ],
                        ),
                        border: Border.all(
                          color: context.colors.foreground
                              .withValues(alpha: 0.06),
                          width: 0.5,
                        ),
                      ),
                      child: Column(
                        children: [
                          Stack(
                            alignment: Alignment.center,
                            children: [
                              FaIcon(
                                _mediaIcons[type]!,
                                size: 13,
                                color: _selectedMediaTypes.contains(type)
                                    ? context.colors.foreground
                                    : context.colors.foregroundMuted
                                        .withValues(alpha: 0.4),
                              ),
                              if (_selectedMediaTypes.contains(type))
                                Positioned(
                                  right: -2,
                                  top: -2,
                                  child: FaIcon(
                                    FontAwesomeIcons.check,
                                    size: 7,
                                    color: context.colors.foreground,
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _mediaLabel(l10n, type),
                            style: AppTypography.body(11,
                                    weight: FontWeight.w500)
                                .copyWith(
                              color: _selectedMediaTypes.contains(type)
                                  ? context.colors.foreground
                                  : context.colors.foregroundMuted
                                      .withValues(alpha: 0.4),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 14),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: SizedBox(
            width: double.infinity,
            child: GestureDetector(
              onTap: _selectedMediaTypes.isEmpty
                  ? null
                  : () {
                      final mediaTypes = Set<String>.of(_selectedMediaTypes);
                      Navigator.of(context).pop();
                      Navigator.of(context).push(
                        PlaySceneScreen.route(
                          scene: widget.scene,
                          initialMediaTypes: mediaTypes,
                        ),
                      );
                    },
              child: AnimatedOpacity(
                opacity: _selectedMediaTypes.isEmpty ? 0.4 : 1.0,
                duration: const Duration(milliseconds: 200),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: BoxDecoration(
                    borderRadius: AppRadii.sheetInnerBorder,
                    color: context.colors.foreground,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      FaIcon(
                        FontAwesomeIcons.play,
                        size: 14,
                        color: context.colors.background,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        l10n.playSceneAction,
                        style: AppTypography.body(
                          15,
                          weight: FontWeight.w600,
                        ).copyWith(color: context.colors.background),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }
}
