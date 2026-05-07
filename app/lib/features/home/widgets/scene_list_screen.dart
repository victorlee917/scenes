import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_colors_ext.dart';
import '../../../core/widgets/floating_action_sheet.dart';
import '../../../l10n/app_localizations.dart';
import '../../../core/theme/app_typography.dart';
import '../formatters.dart';
import '../home_view_model.dart';
import '../models/scene.dart';
import '../../subscription/subscription_screen.dart';
import '../../subscription/subscription_view_model.dart';
import 'detail_app_bar.dart';
import 'scene_detail_screen.dart';
import 'scene_title_fallback.dart';

/// Scene 전체 리스트를 풀 페이지로 보여주는 화면.
///
/// 하단 transport Sort 버튼에서 진입. 항목 탭 시 [onSceneTap]으로
/// scene.id를 넘기고 pop.
class SceneListScreen extends ConsumerStatefulWidget {
  const SceneListScreen({
    super.key,
    required this.scenes,
    required this.onSceneTap,
  });

  final List<Scene> scenes;
  final ValueChanged<String> onSceneTap;

  static Route<void> route({
    required List<Scene> scenes,
    required ValueChanged<String> onSceneTap,
  }) {
    return PageRouteBuilder<void>(
      opaque: true,
      transitionDuration: const Duration(milliseconds: 340),
      reverseTransitionDuration: const Duration(milliseconds: 280),
      pageBuilder: (context, animation, secondaryAnimation) {
        return SceneListScreen(scenes: scenes, onSceneTap: onSceneTap);
      },
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        return FadeTransition(opacity: animation, child: child);
      },
    );
  }

  @override
  ConsumerState<SceneListScreen> createState() => _SceneListScreenState();
}

class _SceneListScreenState extends ConsumerState<SceneListScreen> {
  bool _newestFirst = true;
  bool _isEditing = false;
  late List<Scene> _editableScenes;
  double _borderOpacity = 0.0;

  bool _onScroll(ScrollNotification n) {
    final border = (n.metrics.pixels / 20).clamp(0.0, 1.0);
    if ((border - _borderOpacity).abs() > 0.01) {
      setState(() => _borderOpacity = border);
    }
    return false;
  }

  Future<void> _handleRefresh() async {
    // TODO: Supabase에서 scene 데이터 다시 로드
    await Future<void>.delayed(const Duration(milliseconds: 600));
  }

  /// 라이브 provider 데이터 — reorder/생성/삭제 후 즉시 반영. 초기 인자(widget
  /// .scenes)는 reorder 직전 스냅샷이라 새 순서를 못 봐서 사용 안 함.
  List<Scene> get _liveScenes =>
      ref.watch(homeViewModelProvider).scenes;

  List<Scene> get _sortedScenes =>
      _newestFirst ? _liveScenes.reversed.toList() : _liveScenes;

  void _enterEditMode() {
    setState(() {
      _isEditing = true;
      _editableScenes = List.of(_sortedScenes);
    });
  }

  void _cancelEdit() {
    setState(() => _isEditing = false);
  }

  void _saveEdit(BuildContext context) {
    final container = ProviderScope.containerOf(context);
    // _editableScenes는 display 순서(newestFirst면 newest가 위). DB는 position
    // 오름차순(1 = 가장 오래된)이라, newestFirst 모드에서는 reverse해서 보내
    // 줘야 display의 위쪽 항목이 가장 높은 position을 받음.
    final dbOrder = _newestFirst
        ? _editableScenes.reversed.toList()
        : _editableScenes;
    container.read(homeViewModelProvider.notifier).reorderScenes(dbOrder);
    setState(() => _isEditing = false);
  }

  void _onReorder(int oldIndex, int newIndex) {
    setState(() {
      if (newIndex > oldIndex) newIndex--;
      final item = _editableScenes.removeAt(oldIndex);
      _editableScenes.insert(newIndex, item);
    });
  }

  @override
  Widget build(BuildContext context) {
    final padding = MediaQuery.paddingOf(context);
    final l10n = AppLocalizations.of(context);
    final listPadding = EdgeInsets.only(
      top: padding.top + DetailAppBar.barHeight + 8,
      bottom: padding.bottom + 24,
    );

    return Scaffold(
      // backgroundColor handled by theme
      body: Stack(
        children: [
          NotificationListener<ScrollNotification>(
            onNotification: _onScroll,
            child: _isEditing
                ? ReorderableListView.builder(
              padding: listPadding,
              proxyDecorator: (child, index, animation) {
                return Material(
                  color: Colors.transparent,
                  elevation: 0,
                  child: child,
                );
              },
              onReorder: _onReorder,
              itemCount: _editableScenes.length,
              itemBuilder: (context, index) {
                    final scene = _editableScenes[index];
                    return _SceneListTile(
                      key: ValueKey(scene.id),
                      scene: scene,
                      onTap: () {},
                      showDragHandle: true,
                      index: index,
                    );
                  },
                )
                : RefreshIndicator(
                    onRefresh: _handleRefresh,
                    color: context.colors.foreground,
                    backgroundColor: context.colors.clickableArea,
                    elevation: 0,
                    displacement: padding.top + 48 + 10,
                    edgeOffset: 0,
                    child: ListView.builder(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: listPadding,
                      itemCount: _sortedScenes.length,
                      itemBuilder: (context, index) {
                        final scene = _sortedScenes[index];
                        final canisterSize =
                            MediaQuery.sizeOf(context).width * 0.5;
                        return _SceneListTile(
                          scene: scene,
                          onTap: () {
                            Navigator.of(context).push(
                              SceneDetailScreen.fadeRoute(
                                scene: scene,
                                canisterSize: canisterSize,
                              ),
                            );
                          },
                        );
                      },
                    ),
                  ),
          ),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: _isEditing
                ? DetailAppBar(
                    topInset: padding.top,
                    title: l10n.sceneListEditOrder,
                    titleOpacity: 1.0,
                    borderOpacity: _borderOpacity,
                    onClose: _cancelEdit,
                    trailing: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => _saveEdit(context),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 12,
                        ),
                        child: Text(
                          l10n.sceneListSave,
                          style: AppTypography.body(
                            15,
                            weight: FontWeight.w600,
                          ).copyWith(color: context.colors.foreground),
                        ),
                      ),
                    ),
                  )
                : DetailAppBar(
                    topInset: padding.top,
                    title: 'Scenes',
                    titleOpacity: 1.0,
                    borderOpacity: _borderOpacity,
                    onClose: () => Navigator.of(context).pop(),
                    onMoreActions: () {
                      FloatingActionSheet.show(
                        context: context,
                        items: [
                          FloatingActionItem(
                            label: _newestFirst
                                ? l10n.sceneListOldestFirst
                                : l10n.sceneListNewestFirst,
                            onTap: () {
                              setState(
                                () => _newestFirst = !_newestFirst,
                              );
                            },
                          ),
                          FloatingActionItem(
                            label: l10n.sceneListEditOrder,
                            badge: ref.read(isSubscribedProvider) ? null : 'HD',
                            onTap: () {
                              if (ref.read(isSubscribedProvider)) {
                                _enterEditMode();
                              } else {
                                Navigator.of(context).push(
                                  SubscriptionScreen.route(),
                                );
                              }
                            },
                          ),
                        ],
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _SceneListTile extends StatelessWidget {
  const _SceneListTile({
    super.key,
    required this.scene,
    required this.onTap,
    this.showDragHandle = false,
    this.index = 0,
  });

  final Scene scene;
  final VoidCallback onTap;
  final bool showDragHandle;
  final int index;

  static const double _thumbSize = 56;

  @override
  Widget build(BuildContext context) {
    final locale = Localizations.localeOf(context);
    final localeTag = locale.toLanguageTag();
    // 날짜는 콘텐츠 있을 때만 노출. TODO: contents의 min/max occurred_at에서 계산.
    final dateLine = scene.media.total > 0
        ? formatSceneDateRange(scene.dates, localeTag)
        : '';

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        child: Row(
          children: [
            // 대표 이미지 + 씬 넘버 오버레이
            ClipOval(
              child: SizedBox(
                width: _thumbSize,
                height: _thumbSize,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    if (scene.coverImageUrl.isEmpty)
                      SceneTitleFallback(title: scene.title)
                    else
                      Image.network(
                        scene.coverImageUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) =>
                            SceneTitleFallback(title: scene.title),
                      ),
                    Container(
                      color: Colors.black.withValues(alpha: 0.4),
                    ),
                    Align(
                      alignment: const Alignment(0, -0.12),
                      child: Text(
                        '#${scene.number}',
                        style: AppTypography.display(16).copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 1.0,
                          height: 1.0,
                          leadingDistribution:
                              TextLeadingDistribution.even,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 14),
            // 타이틀 + 날짜
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    scene.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.body(15, weight: FontWeight.w500)
                        .copyWith(color: context.colors.foreground),
                  ),
                  if (dateLine.isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Text(
                      dateLine,
                      style: AppTypography.body(12).copyWith(
                        color: context.colors.foregroundMuted,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (showDragHandle)
              ReorderableDragStartListener(
                index: index,
                child: Padding(
                  padding: const EdgeInsets.only(left: 12),
                  child: Icon(
                    Icons.drag_handle,
                    size: 20,
                    color: context.colors.foregroundMuted,
                  ),
                ),
              )
            else if (scene.media.total > 0)
              Padding(
                padding: const EdgeInsets.only(left: 12),
                child: Text(
                  '${scene.media.total}',
                  style: AppTypography.body(12).copyWith(
                    color: context.colors.foregroundMuted,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
