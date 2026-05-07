import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_colors_ext.dart';
import '../../../core/theme/app_radii.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/floating_bottom_sheet.dart';
import '../../subscription/subscription_screen.dart';
import '../../subscription/subscription_view_model.dart';
import '../home_view_model.dart';
import '../models/scene.dart';
import 'play_scene_screen.dart';
import 'scene_title_fallback.dart';

/// 재생할 Scene을 선택하는 바텀시트.
///
/// [lockedSceneIds]가 지정되면 scene 선택 영역을 숨기고 그 scene(들)으로
/// 재생을 고정. scene detail에서 single-scene 재생할 때 사용 — 매체 필터만
/// 노출.
class PlaySceneSheet extends ConsumerStatefulWidget {
  const PlaySceneSheet({
    super.key,
    required this.defaultSceneId,
    this.lockedSceneIds,
  });

  final String defaultSceneId;
  final Set<String>? lockedSceneIds;

  static Future<void> show({
    required BuildContext context,
    required String defaultSceneId,
    Set<String>? lockedSceneIds,
  }) {
    return FloatingBottomSheet.show(
      context: context,
      builder: (_) => PlaySceneSheet(
        defaultSceneId: defaultSceneId,
        lockedSceneIds: lockedSceneIds,
      ),
    );
  }

  @override
  ConsumerState<PlaySceneSheet> createState() => _PlaySceneSheetState();
}

class _PlaySceneSheetState extends ConsumerState<PlaySceneSheet> {
  final Set<String> _selectedIds = {};
  final Set<String> _selectedMediaTypes = {'photo', 'film', 'music', 'place'};
  final ScrollController _scrollController = ScrollController();
  static const double _tileHeight = 64;

  static const _mediaTypes = ['photo', 'film', 'music', 'place'];
  static const _mediaLabels = {
    'photo': 'Photo',
    'film': 'Film',
    'music': 'Music',
    'place': 'Place',
  };
  static const _mediaIcons = {
    'photo': FontAwesomeIcons.solidImage,
    'film': FontAwesomeIcons.film,
    'music': FontAwesomeIcons.music,
    'place': FontAwesomeIcons.locationDot,
  };

  @override
  void initState() {
    super.initState();
    if (widget.lockedSceneIds != null) {
      _selectedIds.addAll(widget.lockedSceneIds!);
    } else {
      // 포커싱된 scene이 재생 가능한 콘텐츠를 갖고 있을 때만 pre-select.
      // 콘텐츠가 0개인 scene을 자동 선택하면 표시는 안 되는데(playable 필터에
      // 빠지므로) 선택은 돼있어 Play 활성/Deselect all 표시 같은 모순 발생.
      final hasPlayable = ref
          .read(homeViewModelProvider)
          .scenes
          .any((s) => s.id == widget.defaultSceneId && s.media.total > 0);
      if (hasPlayable) {
        _selectedIds.add(widget.defaultSceneId);
      }
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToSelected();
    });
  }

  void _scrollToSelected() {
    // 리스트는 콘텐츠가 1개 이상인 scene만 포함하므로 동일하게 필터.
    final scenes = ref
        .read(homeViewModelProvider)
        .scenes
        .where((s) => s.media.total > 0)
        .toList();
    final index = scenes.indexWhere((s) => s.id == widget.defaultSceneId);
    if (index <= 0 || !_scrollController.hasClients) return;
    final offset = (index * _tileHeight).clamp(
      0.0,
      _scrollController.position.maxScrollExtent,
    );
    _scrollController.jumpTo(offset);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _toggle(String id) {
    final isSubscribed = ref.read(isSubscribedProvider);
    setState(() {
      if (isSubscribed) {
        if (_selectedIds.contains(id)) {
          _selectedIds.remove(id);
        } else {
          _selectedIds.add(id);
        }
      } else {
        _selectedIds
          ..clear()
          ..add(id);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final allScenes =
        ref.watch(homeViewModelProvider.select((s) => s.scenes));
    final isSubscribed = ref.watch(isSubscribedProvider);
    // 재생 가능한 scene = 콘텐츠가 1개 이상 있는 scene.
    final scenes =
        allScenes.where((s) => s.media.total > 0).toList();
    final hasPlayable = scenes.isNotEmpty;

    final showSceneList = widget.lockedSceneIds == null;

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
        if (showSceneList)
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Container(
            decoration: BoxDecoration(
              color: context.colors.clickableArea,
              borderRadius: AppRadii.sheetInnerBorder,
              border: Border.all(
                color: context.colors.foreground.withValues(alpha: 0.04),
                width: 0.5,
              ),
            ),
            child: !hasPlayable
                ? Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 32),
                    child: Center(
                      child: Text(
                        'No scenes ready to play yet.',
                        textAlign: TextAlign.center,
                        style: AppTypography.body(13).copyWith(
                          color: context.colors.foregroundMuted,
                        ),
                      ),
                    ),
                  )
                : ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 280),
                    child: ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      shrinkWrap: true,
                      // Subscribed 사용자에게만 마지막에 "Select All" tile.
                      itemCount:
                          scenes.length + (isSubscribed ? 1 : 0),
                      itemBuilder: (context, index) {
                        if (index >= scenes.length) {
                          final allSelected =
                              _selectedIds.length == scenes.length;
                          return Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Center(
                                child: Container(
                                  width: 30,
                                  height: 0.5,
                                  color: context.colors.foreground
                                      .withValues(alpha: 0.06),
                                ),
                              ),
                              _SelectAllTile(
                                allSelected: allSelected,
                                onTap: () {
                                  setState(() {
                                    if (allSelected) {
                                      _selectedIds.clear();
                                    } else {
                                      _selectedIds.addAll(
                                        scenes.map((s) => s.id),
                                      );
                                    }
                                  });
                                },
                              ),
                            ],
                          );
                        }
                        final scene = scenes[index];
                        return _PlaySceneTile(
                          scene: scene,
                          selected: _selectedIds.contains(scene.id),
                          onTap: () => _toggle(scene.id),
                        );
                      },
                    ),
                  ),
          ),
        ),
        // 미디어 필터는 유료(scenes_hd) 회원에게만 노출.
        if (isSubscribed) ...[
        const SizedBox(height: 14),
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
                            _mediaLabels[type]!,
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
        ],
        // Scenes HD 유도 배너는 free 사용자에게만, play 버튼 바로 위에.
        if (!isSubscribed) ...[
          const SizedBox(height: 14),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: _HdBanner(
              onTap: () {
                Navigator.of(context).pop();
                Navigator.of(context).push(SubscriptionScreen.route());
              },
            ),
          ),
        ],
        const SizedBox(height: 14),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: SizedBox(
            width: double.infinity,
            child: GestureDetector(
              onTap: _selectedIds.isEmpty
                  ? null
                  : () {
                      final scenes = ref
                          .read(homeViewModelProvider)
                          .scenes
                          .where((s) => _selectedIds.contains(s.id))
                          .toList();
                      // 시트에서 토글한 매체 필터를 play 화면에 그대로 전달.
                      final mediaTypes = Set<String>.of(_selectedMediaTypes);
                      Navigator.of(context).pop();
                      Navigator.of(context).push(
                        PlaySceneScreen.route(
                          scenes: scenes,
                          initialMediaTypes: mediaTypes,
                        ),
                      );
                    },
              child: AnimatedOpacity(
                opacity: _selectedIds.isEmpty ? 0.4 : 1.0,
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
                        'Play',
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

class _PlaySceneTile extends StatelessWidget {
  const _PlaySceneTile({
    required this.scene,
    required this.selected,
    required this.onTap,
  });

  final Scene scene;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            ClipOval(
              child: SizedBox(
                width: 44,
                height: 44,
                child: scene.coverImageUrl.isEmpty
                    ? SceneTitleFallback(title: scene.title)
                    : Image.network(
                        scene.coverImageUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) =>
                            SceneTitleFallback(title: scene.title),
                      ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '#${scene.number}',
                    style: AppTypography.display(11).copyWith(
                      color: context.colors.foregroundMuted,
                    ),
                  ),
                  const SizedBox(height: 2),
                  SizedBox(
                    width: double.infinity,
                    child: ShaderMask(
                      shaderCallback: (bounds) => const LinearGradient(
                        colors: [Colors.white, Colors.white, Colors.transparent],
                        stops: [0.0, 0.85, 1.0],
                      ).createShader(bounds),
                      blendMode: BlendMode.dstIn,
                      child: Text(
                        scene.title,
                        maxLines: 1,
                        softWrap: false,
                        overflow: TextOverflow.clip,
                        style: AppTypography.body(15, weight: FontWeight.w500)
                            .copyWith(color: context.colors.foreground),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            if (selected)
              FaIcon(
                FontAwesomeIcons.check,
                size: 14,
                color: context.colors.foreground,
              )
            else
              const SizedBox(width: 14),
          ],
        ),
      ),
    );
  }
}

class _SelectAllTile extends StatelessWidget {
  const _SelectAllTile({
    required this.allSelected,
    required this.onTap,
  });

  final bool allSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Center(
          child: Text(
            allSelected ? 'Deselect all' : 'Select all',
            style: AppTypography.body(14, weight: FontWeight.w500)
                .copyWith(color: context.colors.foregroundMuted),
          ),
        ),
      ),
    );
  }
}

class _HdBanner extends StatelessWidget {
  const _HdBanner({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        decoration: BoxDecoration(
          borderRadius: AppRadii.sheetInnerBorder,
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [context.colors.surface, context.colors.surfaceElevated],
          ),
          border: Border.all(
            color: context.colors.foreground.withValues(alpha: 0.06),
            width: 0.5,
          ),
        ),
        child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Scenes HD',
                      style: AppTypography.display(16).copyWith(
                        color: context.colors.foreground,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Select multiple scenes to play together.',
                      style: AppTypography.body(12).copyWith(
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
    );
  }
}
