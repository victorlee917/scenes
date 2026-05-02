import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../../../core/theme/app_colors_ext.dart';
import '../../../core/theme/app_radii.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/floating_bottom_sheet.dart';
import '../../subscription/subscription_screen.dart';
import 'film_picker_screen.dart';
import 'music_picker_screen.dart';
import 'photo_picker_screen.dart';
import 'place_picker_screen.dart';
import '../home_view_model.dart';
import '../models/scene.dart';

/// + 버튼을 눌렀을 때 올라오는 미디어 추가 바텀시트.
class AddMediaSheet extends ConsumerStatefulWidget {
  const AddMediaSheet({
    super.key,
    required this.initialScene,
    this.isSubscribed = false,
    this.showSceneHeader = true,
  });

  final Scene initialScene;
  final bool isSubscribed;
  final bool showSceneHeader;

  static Future<void> show({
    required BuildContext context,
    required Scene scene,
    bool isSubscribed = false,
    bool showSceneHeader = true,
  }) {
    return FloatingBottomSheet.show(
      context: context,
      builder: (_) => AddMediaSheet(
        initialScene: scene,
        isSubscribed: isSubscribed,
        showSceneHeader: showSceneHeader,
      ),
    );
  }

  @override
  ConsumerState<AddMediaSheet> createState() => _AddMediaSheetState();
}

class _AddMediaSheetState extends ConsumerState<AddMediaSheet> {
  late Scene _selectedScene;

  @override
  void initState() {
    super.initState();
    _selectedScene = widget.initialScene;
  }

  void _showScenePicker() {
    final scenes = ref.read(homeViewModelProvider).scenes;
    showDialog<Scene>(
      context: context,
      builder: (ctx) => _ScenePickerDialog(
        scenes: scenes,
        selectedId: _selectedScene.id,
      ),
    ).then((picked) {
      if (picked != null) {
        setState(() => _selectedScene = picked);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final scene = _selectedScene;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(height: 8),
        Text(
          'New Moment',
          style: AppTypography.display(20).copyWith(
            color: context.colors.foreground,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 24),
        if (widget.showSceneHeader) ...[
          // Scene 정보 (중앙 정렬, 세로 배치)
          GestureDetector(
            onTap: _showScenePicker,
            behavior: HitTestBehavior.opaque,
            child: Column(
              children: [
                ClipOval(
                  child: SizedBox(
                    width: 48,
                    height: 48,
                    child: Image.network(
                      scene.coverImageUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => Container(
                        color: context.colors.nonClickableArea,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  '#${scene.number}',
                  style: AppTypography.display(12).copyWith(
                    color: context.colors.foregroundMuted,
                  ),
                ),
                const SizedBox(height: 4),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 40),
                  child: Text(
                    scene.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: AppTypography.body(
                      15,
                      weight: FontWeight.w600,
                    ).copyWith(color: context.colors.foreground),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 32),
        ],

        if (widget.isSubscribed)
          // 구독자: 1행 Photo, 2행 Film/Music/Place
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              children: [
                // 1행: Photo (전체 폭)
                SizedBox(
                  width: double.infinity,
                  height: 80,
                  child: _MediaTypeCell(
                    icon: FontAwesomeIcons.image,
                    label: 'Photo',
                    onTap: () {
                      Navigator.of(context).pop();
                      Navigator.of(context).push(
                        PhotoPickerScreen.route(scene: _selectedScene),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 12),
                // 2행: Film, Music, Place
                SizedBox(
                  height: 80,
                  child: Row(
                    children: [
                      Expanded(
                        child: _MediaTypeCell(
                          icon: FontAwesomeIcons.film,
                          label: 'Film',
                          onTap: () {
                            Navigator.of(context).pop();
                            Navigator.of(context).push(
                              FilmPickerScreen.route(
                                  scene: _selectedScene),
                            );
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _MediaTypeCell(
                          icon: FontAwesomeIcons.music,
                          label: 'Music',
                          onTap: () {
                            Navigator.of(context).pop();
                            Navigator.of(context).push(
                              MusicPickerScreen.route(
                                  scene: _selectedScene),
                            );
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _MediaTypeCell(
                          icon: FontAwesomeIcons.locationDot,
                          label: 'Place',
                          onTap: () {
                            Navigator.of(context).pop();
                            Navigator.of(context).push(
                              PlacePickerScreen.route(
                                  scene: _selectedScene),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          )
        else
          // 비구독자: Photo만 + 구독 배너
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              children: [
                SizedBox(
                  width: double.infinity,
                  height: 80,
                  child: _MediaTypeCell(
                    icon: FontAwesomeIcons.image,
                    label: 'Photo',
                    onTap: () {
                      Navigator.of(context).pop();
                      Navigator.of(context).push(
                        PhotoPickerScreen.route(scene: _selectedScene),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 14),
                GestureDetector(
                  onTap: () {
                    Navigator.of(context).pop();
                    Navigator.of(context)
                        .push(SubscriptionScreen.route());
                  },
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 18,
                    ),
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
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment:
                                CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Scenes HD',
                                style: AppTypography.display(16)
                                    .copyWith(
                                  color: context.colors.foreground,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Unlock films, music, and places.',
                                style:
                                    AppTypography.body(12).copyWith(
                                  color: context.colors.foregroundMuted,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        FaIcon(
                          FontAwesomeIcons.chevronRight,
                          size: 14,
                          color: context.colors.foregroundMuted,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        const SizedBox(height: 20),
      ],
    );
  }
}

// ── Scene 선택 다이얼로그 ────────────────────────────────────

class _ScenePickerDialog extends StatelessWidget {
  const _ScenePickerDialog({
    required this.scenes,
    required this.selectedId,
  });

  final List<Scene> scenes;
  final String selectedId;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 40),
        constraints: const BoxConstraints(maxHeight: 400),
        decoration: BoxDecoration(
          color: context.colors.background,
          borderRadius: AppRadii.lgBorder,
          border: Border.all(
            color: context.colors.foreground.withValues(alpha: 0.06),
            width: 0.5,
          ),
        ),
        child: ClipRRect(
          borderRadius: AppRadii.lgBorder,
          child: Material(
            color: Colors.transparent,
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 8),
              shrinkWrap: true,
              itemCount: scenes.length,
              itemBuilder: (context, index) {
                final scene = scenes[index];
                final isSelected = scene.id == selectedId;
                return GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => Navigator.of(context).pop(scene),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 12,
                    ),
                    child: Row(
                      children: [
                        ClipOval(
                          child: SizedBox(
                            width: 36,
                            height: 36,
                            child: Image.network(
                              scene.coverImageUrl,
                              fit: BoxFit.cover,
                              errorBuilder: (_, _, _) => Container(
                                color: context.colors.nonClickableArea,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            '#${scene.number}  ${scene.title}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTypography.body(14).copyWith(
                              color: context.colors.foreground,
                            ),
                          ),
                        ),
                        if (isSelected)
                          FaIcon(
                            FontAwesomeIcons.check,
                            size: 14,
                            color: context.colors.foreground,
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

// ── 매체 셀 ──────────────────────────────────────────────────

class _MediaTypeCell extends StatelessWidget {
  const _MediaTypeCell({
    required this.icon,
    required this.label,
    this.onTap,
    this.iconSize = 20,
  });

  final FaIconData icon;
  final String label;
  final VoidCallback? onTap;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap ?? () {
        Navigator.of(context).pop();
      },
      child: Container(
        decoration: BoxDecoration(
          color: context.colors.clickableArea,
          borderRadius: AppRadii.sheetInnerBorder,
          border: Border.all(
            color: context.colors.foreground.withValues(alpha: 0.04),
            width: 0.5,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            FaIcon(
              icon,
              size: iconSize,
              color: context.colors.foreground.withValues(alpha: 0.7),
            ),
            const SizedBox(height: 6),
            Text(
              label,
              style: AppTypography.body(12).copyWith(
                color: context.colors.foregroundMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
