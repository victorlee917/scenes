import 'dart:math' as math;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:shimmer/shimmer.dart';

import '../../../core/theme/app_colors_ext.dart';
import '../../../core/theme/app_radii.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/app_toast.dart';
import '../../../core/widgets/confirm_dialog.dart';
import '../../../core/widgets/floating_action_sheet.dart';
import '../../../core/widgets/floating_bottom_sheet.dart';
import '../../content/data/content_repository.dart';
import '../../content/contents_view_model.dart';
import '../../content/models/content.dart';
import '../../content/models/reaction.dart';
import '../../content/reactions_view_model.dart';
import '../../content/widgets/progressive_photo.dart';
import '../../content/widgets/reaction_bar.dart';
import '../../content/widgets/source_badge.dart';
import '../../couple/couple_view_model.dart';
import '../../profile/profile_view_model.dart';
import '../../scene/scenes_view_model.dart';
import '../../subscription/subscription_screen.dart';
import '../../subscription/subscription_view_model.dart';
import 'add_media_sheet.dart';
import 'content_viewer_v2.dart';
import 'create_scene_sheet.dart';
import 'play_scene_screen.dart';
import 'play_scene_sheet.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../../../core/widgets/glass_circle_button.dart';
import '../../../l10n/app_localizations.dart';
import '../models/scene.dart';
import 'detail_app_bar.dart';
import 'focused_scene_info.dart';
import 'scene_card.dart';

/// Scene detail 라우트.
///
/// Hero 플라이트로 캐니스터와 정보 블록이 홈 화면의 위치에서 이 화면의
/// 최종 위치로 자연스럽게 이동한다. 배경색은 홈과 동일해서 "같은 화면에서
/// 컨텐츠만 바뀐" 듯한 감각을 낸다. 앱바·그리드는 route 애니메이션으로
/// fade-in.
class SceneDetailScreen extends ConsumerStatefulWidget {
  const SceneDetailScreen({
    super.key,
    required this.scene,
    required this.canisterSize,
    this.initialContentId,
  });

  final Scene scene;

  /// 홈 carousel의 slot width와 동일한 값. SceneCard의 LayoutBuilder가
  /// `size - 16`을 지름으로 잡으므로 여기에도 같은 값을 넘겨 Hero가 두
  /// 위치의 크기를 원활히 보간하도록 한다.
  final double canisterSize;

  /// 화면 진입 즉시 anchor할 콘텐츠 id. 푸시 알림 탭으로 진입한 경우 등에서
  /// 사용. contents가 로드되면 해당 id의 인덱스로 [ContentViewerV2]를
  /// 자동으로 연다. 한 번만 발화 — 사용자가 viewer를 닫으면 다시 안 열림.
  final String? initialContentId;

  static String canisterHeroTag(String sceneId) => 'scene-canister-$sceneId';
  static String infoHeroTag(String sceneId) => 'scene-info-$sceneId';

  /// 홈에서 detail로 push하는 라우트. 페이지 자체는 전환 애니메이션을 쓰지
  /// 않고, Hero가 canister/info를 플라이트 시키고 나머지(앱바·그리드)만
  /// FadeTransition으로 올라온다.
  /// Hero 플라이트를 사용하는 라우트. 홈 캐러셀에서 진입할 때 사용.
  static Route<void> route({
    required Scene scene,
    required double canisterSize,
    String? initialContentId,
  }) {
    return PageRouteBuilder<void>(
      opaque: true,
      transitionDuration: const Duration(milliseconds: 480),
      reverseTransitionDuration: const Duration(milliseconds: 480),
      pageBuilder: (context, animation, secondaryAnimation) {
        return SceneDetailScreen(
          scene: scene,
          canisterSize: canisterSize,
          initialContentId: initialContentId,
        );
      },
      // 페이지 자체에 FadeTransition을 입힘 — Hero 비행이 끝나기 전에 detail
      // 화면이 갑자기 unmount되며 home이 튀어나오는 현상 방지. 점진 fade로
      // Hero 도착 시점과 자연스럽게 맞물림.
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        return FadeTransition(opacity: animation, child: child);
      },
    );
  }

  /// Hero 없이 fade 전환하는 라우트. 리스트 등 다른 화면에서 진입할 때 사용.
  static Route<void> fadeRoute({
    required Scene scene,
    required double canisterSize,
    String? initialContentId,
  }) {
    return PageRouteBuilder<void>(
      opaque: true,
      transitionDuration: const Duration(milliseconds: 340),
      reverseTransitionDuration: const Duration(milliseconds: 280),
      pageBuilder: (context, animation, secondaryAnimation) {
        return HeroMode(
          enabled: false,
          child: SceneDetailScreen(
            scene: scene,
            canisterSize: canisterSize,
            initialContentId: initialContentId,
          ),
        );
      },
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        return FadeTransition(opacity: animation, child: child);
      },
    );
  }

  @override
  ConsumerState<SceneDetailScreen> createState() => _SceneDetailScreenState();
}

class _SceneDetailScreenState extends ConsumerState<SceneDetailScreen> {
  static const double _appBarHeight = 48;
  static const double _canisterAppBarGap = 24;

  final ScrollController _scrollController = ScrollController();
  double _appBarTitleOpacity = 0.0;
  double _borderOpacity = 0.0;
  double _titleFadeStart = 0;
  double _titleFadeEnd = 1;

  // Edit Order 모드 — 활성화 시 마손리 그리드 대신 ReorderableList. cancel
  // 또는 save로 빠져나옴. _editableContents는 드래그 동안 mutable로 들고
  // 있다가 save 시 ViewModel.reorder(...)로 commit.
  bool _isReordering = false;
  List<Content> _editableContents = const [];

  // initialContentId로 들어왔을 때 viewer를 한 번만 자동으로 열도록 가드.
  bool _initialAnchorOpened = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    // 푸시 딥링크로 진입한 경우(initialContentId 존재) — keepAlive된 family
    // 캐시가 stale일 수 있으므로 명시적으로 refetch 강제. invalidate는 race
    // 가능성 있어 notifier.refresh()로 state=loading 후 재fetch.
    if (widget.initialContentId != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        // ignore: discarded_futures
        ref.read(contentsForSceneProvider(widget.scene.id).notifier).refresh();
      });
    }
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final offset = _scrollController.offset;
    final span = (_titleFadeEnd - _titleFadeStart).clamp(1.0, 1e9);
    final next = ((offset - _titleFadeStart) / span).clamp(0.0, 1.0);
    final border = (offset / 20).clamp(0.0, 1.0);
    if ((next - _appBarTitleOpacity).abs() > 0.01 ||
        (border - _borderOpacity).abs() > 0.01) {
      setState(() {
        _appBarTitleOpacity = next;
        _borderOpacity = border;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final padding = MediaQuery.paddingOf(context);
    final appBarBottom = padding.top + _appBarHeight;
    final canisterTop = appBarBottom + _canisterAppBarGap;

    // Scroll 기반 앱바 타이틀 fade 구간.
    final infoApproxTop = canisterTop + widget.canisterSize + 16;
    _titleFadeStart = math.max(0.0, infoApproxTop - appBarBottom - 20);
    _titleFadeEnd = _titleFadeStart + 48;

    final routeAnim =
        ModalRoute.of(context)?.animation ??
        const AlwaysStoppedAnimation<double>(1);

    // scenesProvider에서 최신 scene을 watch — Edit으로 title/cover 바뀌면
    // 시트 닫힌 직후 자동 반영. 리스트에서 사라졌으면(=삭제) widget.scene을
    // 최후의 fallback으로 써서 pop 애니메이션 도중 깨지지 않게 함.
    final scenesAsync = ref.watch(scenesProvider);
    final scene =
        scenesAsync.valueOrNull?.firstWhere(
          (s) => s.id == widget.scene.id,
          orElse: () => widget.scene,
        ) ??
        widget.scene;

    return Scaffold(
      // backgroundColor handled by theme
      body: Stack(
        children: [
          RefreshIndicator(
            onRefresh: _handleRefresh,
            color: context.colors.foreground,
            backgroundColor: context.colors.clickableArea,
            elevation: 0,
            displacement: padding.top + 48 + 10,
            edgeOffset: 0,
            child: CustomScrollView(
              controller: _scrollController,
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                // reorder 모드에선 헤더(캐니스터·메타·+/Play row) 전체를 숨기고
                // 리스트만 보이도록 — 헤더 sliver를 빼고 앱바 아래 spacer만 둠.
                if (_isReordering)
                  SliverToBoxAdapter(
                    child: SizedBox(height: padding.top + 48 + 12),
                  )
                else
                  SliverToBoxAdapter(
                    child: Column(
                      children: [
                        SizedBox(height: canisterTop),
                        Hero(
                          tag: SceneDetailScreen.canisterHeroTag(scene.id),
                          transitionOnUserGestures: true,
                          // 비행 중 source/destination 트리가 rebuild되어도 영향
                          // 안 받도록 fresh SceneCard만 그림.
                          flightShuttleBuilder: (_, _, _, _, _) => Material(
                            type: MaterialType.transparency,
                            child: SceneCard(scene: scene),
                          ),
                          child: Material(
                            type: MaterialType.transparency,
                            child: GestureDetector(
                              onTap: _openEditSheet,
                              behavior: HitTestBehavior.opaque,
                              child: SizedBox(
                                width: widget.canisterSize,
                                height: widget.canisterSize,
                                child: SceneCard(scene: scene),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 40),
                        Hero(
                          tag: SceneDetailScreen.infoHeroTag(scene.id),
                          transitionOnUserGestures: true,
                          child: Material(
                            type: MaterialType.transparency,
                            child: GestureDetector(
                              onTap: _openEditSheet,
                              behavior: HitTestBehavior.opaque,
                              child: FocusedSceneInfo(
                                scene: scene,
                                onDateTap: _openSceneDateSheet,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 36),
                        FadeTransition(
                          opacity: routeAnim,
                          child: _DetailActionRow(
                            showPlay: scene.media.total > 0,
                            onAddMedia: () {
                              AddMediaSheet.show(
                                context: context,
                                scene: scene,
                                showSceneHeader: false,
                              );
                            },
                            onPlay: () {
                              // 구독자는 매체 필터를 고를 수 있도록 시트를
                              // 띄우되 scene 선택은 잠금. 비구독자는 매체 필터
                              // 자체가 노출 안 되니 시트 띄울 필요 없이 곧장 재생.
                              final isSubscribed = ref.read(
                                isSubscribedProvider,
                              );
                              if (isSubscribed) {
                                PlaySceneSheet.show(
                                  context: context,
                                  scene: scene,
                                );
                              } else {
                                Navigator.of(
                                  context,
                                ).push(PlaySceneScreen.route(scene: scene));
                              }
                            },
                          ),
                        ),
                        const SizedBox(height: 28),
                      ],
                    ),
                  ),
                // 미디어 그리드는 route 애니메이션에 맞춰 fade-in.
                SliverFadeTransition(
                  opacity: routeAnim,
                  sliver: _buildMediaSliver(scene),
                ),
                const SliverToBoxAdapter(child: SizedBox(height: 140)),
              ],
            ),
          ),
          // 앱바. route 애니메이션으로 fade-in. reorder 모드에선 close가
          // cancel, trailing이 Save로 swap.
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: FadeTransition(
              opacity: routeAnim,
              child: _isReordering
                  ? DetailAppBar(
                      topInset: padding.top,
                      title: AppLocalizations.of(context).sceneListEditOrder,
                      titleOpacity: 1.0,
                      borderOpacity: _borderOpacity,
                      onClose: _cancelReorder,
                      trailing: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: _saveReorder,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 12,
                          ),
                          child: Text(
                            AppLocalizations.of(context).sceneListSave,
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
                      title: scene.title,
                      titleOpacity: _appBarTitleOpacity,
                      borderOpacity: _borderOpacity,
                      onClose: () => Navigator.of(context).pop(),
                      onMoreActions: _handleMoreActions,
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _handleRefresh() async {
    // 두 provider 동시 갱신 — scenes로 카드/카운트, contents로 그리드.
    await Future.wait<void>([
      ref.read(scenesProvider.notifier).softRefresh(),
      ref.read(contentsForSceneProvider(widget.scene.id).notifier).refresh(),
    ]);
  }

  /// scenes는 공동 편집이라 누구나 edit. 헤더(커버/타이틀) 탭 + ellipsis의
  /// Edit 항목 모두 이 시트를 띄움. provider에서 latest를 다시 읽어 stale
  /// prefill 방지.
  void _openEditSheet() {
    final latest =
        ref
            .read(scenesProvider)
            .valueOrNull
            ?.firstWhere(
              (s) => s.id == widget.scene.id,
              orElse: () => widget.scene,
            ) ??
        widget.scene;
    CreateSceneSheet.show(context: context, editScene: latest);
  }

  void _handleMoreActions() {
    final l10n = AppLocalizations.of(context);
    // scenes/contents 모두 active 페어 멤버면 edit·delete 다 가능. 작성자만
    // 가능하던 옛 정책(created_by = auth.uid())은 RLS 레벨에서 풀렸음.
    const canDelete = true;
    FloatingActionSheet.show(
      context: context,
      items: [
        FloatingActionItem(label: l10n.sceneDetailEdit, onTap: _openEditSheet),
        // Edit Order — 콘텐츠 순서 재배열. HD only. 무료 회원은 HD 뱃지 노출
        // 후 탭 시 SubscriptionScreen으로 유도.
        FloatingActionItem(
          label: l10n.sceneListEditOrder,
          badge: ref.read(isSubscribedProvider) ? null : 'HD',
          onTap: _handleEditOrder,
        ),
        // Edit Date — scene 내 모든 contents의 occurred_at을 한 번에 변경.
        FloatingActionItem(
          label: l10n.sceneDetailEditDate,
          onTap: _openSceneDateSheet,
        ),
        if (canDelete)
          FloatingActionItem(
            label: l10n.actionDelete,
            isDestructive: true,
            onTap: () async {
              final confirmed = await ConfirmDialog.show(
                context: context,
                title: 'Delete this scene?',
                message: l10n.sceneDetailDeleteMessage,
                confirmLabel: l10n.actionDelete,
                isDestructive: true,
              );
              if (!confirmed || !mounted) return;
              try {
                await ref.read(scenesProvider.notifier).delete(widget.scene.id);
                if (mounted) Navigator.of(context).pop();
              } catch (_) {
                if (mounted) {
                  AppToast.show(context, l10n.sceneDetailDeleteFailedToast);
                }
              }
            },
          ),
      ],
    );
  }

  /// "Edit date" 메뉴 — scene 내 모든 contents의 occurred_at을 한 번에 설정
  /// 하는 시트. 안내 텍스트로 "모든 Moment에 적용"임을 알리고, 확정 시 bulk
  /// update + in-memory 상태 동기화.
  void _openSceneDateSheet() {
    final l10n = AppLocalizations.of(context);
    // scene_summary 뷰가 contents의 max(occurred_at)을 latest_occurred_at으로
    // 집계해 scene.dates 마지막 원소로 노출 → detail 상단 날짜 표기와 동일
    // 값을 default로 채워, "이 Scene의 가장 최근 콘텐츠 날짜"가 그대로 보임.
    // scenesProvider에서 fresh scene을 읽어 bulk edit 직후의 stale 값을 피함.
    // dates가 비어 있으면(전 콘텐츠 occurred_at null) contents in-memory의
    // occurred_at ?? createdAt 최댓값, 마지막 fallback은 today.
    final freshScene =
        ref.read(scenesProvider).valueOrNull?.firstWhere(
              (s) => s.id == widget.scene.id,
              orElse: () => widget.scene,
            ) ??
            widget.scene;
    DateTime initial = DateTime.now();
    if (freshScene.dates.isNotEmpty) {
      initial = freshScene.dates.last;
    } else {
      final contents =
          ref.read(contentsForSceneProvider(widget.scene.id)).valueOrNull ??
          const <Content>[];
      if (contents.isNotEmpty) {
        final dates = contents
            .map((c) => c.occurredAt ?? c.createdAt)
            .toList(growable: false)
          ..sort();
        initial = dates.last;
      }
    }
    FloatingBottomSheet.show<void>(
      context: context,
      builder: (_) => _SceneDateBulkSheet(
        initialDate: initial,
        infoText: l10n.sceneDetailEditDateSheetInfo,
        title: l10n.sceneDetailEditDateSheetTitle,
        onConfirm: (date) async {
          Navigator.of(context).pop();
          try {
            await ref
                .read(contentRepositoryProvider)
                .updateOccurredAtForScene(widget.scene.id, date);
            if (!mounted) return;
            // 1) viewer/그리드용 contents — in-memory에서 모두 새 date로.
            ref
                .read(contentsForSceneProvider(widget.scene.id).notifier)
                .replaceAllOccurredAt(date);
            // 2) scene.dates는 scene_summary 뷰가 contents에서 집계 → 다시
            //    fetch해야 detail 상단 날짜 표기도 갱신됨. invalidate는
            //    isLoading 상태를 거쳐 home의 ready 게이트가 잠깐 SplashView로
            //    빠지고 PageView가 unmount→remount되며 initialPage(가장 최신)
            //    로 스냅되는 버그가 있어, loading 없이 silently 갱신.
            // ignore: discarded_futures
            ref.read(scenesProvider.notifier).softRefresh();
          } catch (_) {
            if (!mounted) return;
            AppToast.show(context, l10n.sceneDetailEditDateFailedToast);
          }
        },
      ),
    );
  }

  /// Edit Order 진입. 무료 회원은 SubscriptionScreen 푸시.
  /// 더보기 메뉴의 "Edit Order" 항목 콜백. HD면 reorder, 무료면 구독 화면.
  /// 단 sub 상태 RPC가 아직 미응답(loading)이면 일단 무시 — false fallback으로
  /// HD user를 잘못 무료로 판단해 구독 화면으로 보내는 race 방지.
  void _handleEditOrder() {
    final subAsync = ref.read(subscriptionViewModelProvider);
    if (subAsync.isLoading || !subAsync.hasValue) return;
    final isHd = subAsync.valueOrNull?.isSubscribed ?? false;
    if (!isHd) {
      Navigator.of(context).push(SubscriptionScreen.route());
      return;
    }
    _enterReorderMode();
  }

  /// 콘텐츠 셀 long-press 콜백. HD만 reorder 진입 — 무료(또는 loading)는 무
  /// 반응. 메뉴와 달리 SubscriptionScreen 자동 유도하지 않음(scene_list와
  /// 일관).
  void _handleLongPressReorder() {
    if (!ref.read(isSubscribedProvider)) return;
    _enterReorderMode();
  }

  /// HD 회원이 reorder mode 진입. _editableContents에 현재 순서 스냅샷.
  void _enterReorderMode() {
    final current =
        ref.read(contentsForSceneProvider(widget.scene.id)).valueOrNull ??
        const <Content>[];
    if (current.isEmpty) return;
    setState(() {
      _isReordering = true;
      _editableContents = List.of(current);
    });
  }

  void _cancelReorder() {
    setState(() {
      _isReordering = false;
      _editableContents = const [];
    });
  }

  Future<void> _saveReorder() async {
    final committed = List<Content>.of(_editableContents);
    setState(() {
      _isReordering = false;
      _editableContents = const [];
    });
    try {
      await ref
          .read(contentsForSceneProvider(widget.scene.id).notifier)
          .reorder(committed);
    } catch (_) {
      if (mounted) {
        AppToast.show(
          context,
          AppLocalizations.of(context).sceneDetailReorderSaveFailedToast,
        );
      }
    }
  }

  void _onReorder(int oldIndex, int newIndex) {
    setState(() {
      if (newIndex > oldIndex) newIndex--;
      final item = _editableContents.removeAt(oldIndex);
      _editableContents.insert(newIndex, item);
    });
  }

  Widget _buildMediaSliver(Scene scene) {
    final l10n = AppLocalizations.of(context);
    final contentsAsync = ref.watch(contentsForSceneProvider(scene.id));
    return contentsAsync.when(
      loading: () {
        // scene_summary 뷰가 type별 count를 미리 알려주므로 1+장이면 실제
        // 레이아웃을 모방한 shimmer ghost grid로 — 그냥 spinner보다 등장
        // 직전 모습이 미리 보여 체감 latency 작음. 0장(매우 드문 케이스)은
        // 작은 spinner로 fallback.
        if (scene.media.total == 0) {
          return const SliverToBoxAdapter(
            child: SizedBox(
              height: 80,
              child: Center(
                child: SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(strokeWidth: 1.5),
                ),
              ),
            ),
          );
        }
        return _buildShimmerSliver(scene);
      },
      error: (e, st) => SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 48),
          child: Text(
            'Failed to load contents.',
            textAlign: TextAlign.center,
            style: AppTypography.body(
              14,
            ).copyWith(color: context.colors.foregroundMuted),
          ),
        ),
      ),
      data: (contents) {
        // 푸시 딥링크로 진입한 경우 — 일치하는 content_id를 찾으면 다음 frame
        // 에서 viewer 자동으로 open. 한 번만 발화.
        _maybeOpenInitialAnchor(scene, contents);
        if (contents.isEmpty) {
          return SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 48),
              child: Text(
                l10n.sceneDetailEmptyMedia,
                textAlign: TextAlign.center,
                style: AppTypography.body(
                  14,
                ).copyWith(color: context.colors.foregroundMuted, height: 1.5),
              ),
            ),
          );
        }
        if (_isReordering) {
          // 마손리(가변 height) → 단일 column ReorderableList로 전환. 각
          // 콘텐츠는 정사각 thumbnail + drag handle. scene_list reorder와
          // 동일 패턴.
          return SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            sliver: SliverReorderableList(
              itemCount: _editableContents.length,
              onReorder: _onReorder,
              proxyDecorator: (child, index, animation) => Material(
                color: Colors.transparent,
                elevation: 0,
                child: child,
              ),
              itemBuilder: (context, index) {
                final content = _editableContents[index];
                return _ReorderTile(
                  key: ValueKey(content.id),
                  content: content,
                  reorderIndex: index,
                );
              },
            ),
          );
        }
        return SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          sliver: SliverMasonryGrid.count(
            crossAxisCount: 2,
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
            childCount: contents.length,
            itemBuilder: (context, index) {
              final content = contents[index];
              return _ContentTile(
                content: content,
                onTap: () => _openContentViewer(scene, contents, index),
                onLongPress: _handleLongPressReorder,
              );
            },
          ),
        );
      },
    );
  }

  /// 로딩 중 ghost masonry grid. type별 aspect ratio로 round-robin 인터리브해
  /// 마손리가 자연스러운 모자이크로 채워지게 함 (전부 한 type 그룹화돼 있으면
  /// 막대 같이 어색).
  Widget _buildShimmerSliver(Scene scene) {
    final aspects = _ghostAspects(scene);
    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      sliver: SliverMasonryGrid.count(
        crossAxisCount: 2,
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
        childCount: aspects.length,
        itemBuilder: (context, i) => _GhostTile(aspect: aspects[i]),
      ),
    );
  }

  static List<double> _ghostAspects(Scene scene) {
    final groups = <List<double>>[
      List.filled(scene.media.photos, 0.75, growable: true), // 평균 3:4
      List.filled(scene.media.films, 2 / 3, growable: true), // 영화 포스터
      List.filled(scene.media.music, 1.0, growable: true), // 앨범 커버
      List.filled(scene.media.places, 1.0, growable: true), // 정적지도
    ];
    final result = <double>[];
    while (groups.any((g) => g.isNotEmpty)) {
      for (final g in groups) {
        if (g.isNotEmpty) result.add(g.removeAt(0));
      }
    }
    return result;
  }

  void _openContentViewer(
    Scene scene,
    List<Content> contents,
    int initialIndex,
  ) {
    ContentViewerV2.show(
      context: context,
      contents: contents,
      initialIndex: initialIndex,
      sceneImageUrl: scene.coverImageUrl,
      sceneName: scene.title,
    );
  }

  /// initialContentId로 진입한 경우 contents가 도착하는 첫 frame에 viewer를
  /// 자동으로 open. build 도중 직접 push하면 안 되므로 postFrameCallback에
  /// 예약. 이미 한 번 열었으면 재진입 시에도 다시 안 열림.
  void _maybeOpenInitialAnchor(Scene scene, List<Content> contents) {
    final anchorId = widget.initialContentId;
    if (anchorId == null || _initialAnchorOpened) return;
    final idx = contents.indexWhere((c) => c.id == anchorId);
    if (idx < 0) return;
    _initialAnchorOpened = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _openContentViewer(scene, contents, idx);
    });
  }
}

/// masonry grid의 한 칸. photo는 실 이미지, 그 외 type은 임시 placeholder
/// (다음 단계에서 type별 카드로 교체).
class _ContentTile extends StatelessWidget {
  const _ContentTile({
    required this.content,
    required this.onTap,
    this.onLongPress,
  });

  final Content content;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      child: ClipRRect(
        borderRadius: AppRadii.mdBorder,
        child: switch (content.type) {
          'photo' => _photoBody(context),
          'film' => _filmBody(context),
          'music' => _musicBody(context),
          'place' => _placeBody(context),
          _ => _placeholderBody(context),
        },
      ),
    );
  }

  Widget _photoBody(BuildContext context) {
    final w = (content.payload['width'] as num?)?.toDouble();
    final h = (content.payload['height'] as num?)?.toDouble();
    final aspect = (w != null && h != null && w > 0 && h > 0) ? w / h : 0.75;
    return AspectRatio(
      aspectRatio: aspect,
      child: Stack(
        fit: StackFit.expand,
        children: [
          ProgressivePhoto(
            thumbUrl: content.thumbSignedUrl,
            fullUrl: content.fullSignedUrl,
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: _GridReactionBadge(content: content),
          ),
        ],
      ),
    );
  }

  /// Film 포스터는 표준 2:3 비율. cached signed URL 또는 TMDB CDN fallback —
  /// repository._hydrateFilmUrls가 이미 fullSignedUrl 슬롯에 채워주므로
  /// ProgressivePhoto에 그대로 넘기면 됨. 우상단 TMDB 배지로 출처 표시.
  Widget _filmBody(BuildContext context) {
    return AspectRatio(
      aspectRatio: 2 / 3,
      child: Stack(
        fit: StackFit.expand,
        children: [
          ProgressivePhoto(
            thumbUrl: content.thumbSignedUrl,
            fullUrl: content.fullSignedUrl,
          ),
          const Positioned(top: 6, right: 6, child: TmdbBadge()),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: _GridReactionBadge(content: content),
          ),
        ],
      ),
    );
  }

  /// Music album cover는 1:1. Spotify CDN URL이 fullSignedUrl 슬롯에 들어옴.
  /// 우상단 작은 Spotify 로고 배지로 출처 표시 — TOS 링크백 의무 일부 충족.
  Widget _musicBody(BuildContext context) {
    return AspectRatio(
      aspectRatio: 1,
      child: Stack(
        fit: StackFit.expand,
        children: [
          ProgressivePhoto(
            thumbUrl: content.thumbSignedUrl,
            fullUrl: content.fullSignedUrl,
          ),
          const Positioned(top: 6, right: 6, child: SpotifyBadge()),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: _GridReactionBadge(content: content),
          ),
        ],
      ),
    );
  }

  /// Place 정적지도는 1:1. 비슷한 지도 패턴이 여러 개 쌓이면 시각적 구분이
  /// 어려워서 하단에 장소 이름 label 오버레이 — gradient scrim 위에 굵은 글씨.
  /// 그 영역이 MapBox baked-in attribution(우하단) 위치까지 함께 덮어
  /// scene detail에선 attribution이 시각적으로 노출되지 않음. 추후 content
  /// detail viewer에선 full map이 그대로 보여 attribution 자연 노출.
  Widget _placeBody(BuildContext context) {
    final name = content.payload['name'] as String?;
    return AspectRatio(
      aspectRatio: 1,
      child: Stack(
        fit: StackFit.expand,
        children: [
          ProgressivePhoto(
            thumbUrl: content.thumbSignedUrl,
            fullUrl: content.fullSignedUrl,
          ),
          const Positioned(top: 6, right: 6, child: MapboxBadge()),
          if (name != null && name.isNotEmpty)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Container(
                padding: const EdgeInsets.fromLTRB(10, 18, 10, 8),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.black.withValues(alpha: 0.7),
                    ],
                  ),
                ),
                child: Text(
                  name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.body(
                    11,
                    weight: FontWeight.w600,
                  ).copyWith(color: Colors.white, height: 1.2),
                ),
              ),
            ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: _GridReactionBadge(content: content),
          ),
        ],
      ),
    );
  }

  Widget _placeholderBody(BuildContext context) {
    return AspectRatio(
      aspectRatio: 1,
      child: Container(
        decoration: BoxDecoration(
          color: context.colors.clickableArea,
          border: Border.all(
            color: context.colors.foreground.withValues(alpha: 0.06),
            width: 1,
          ),
        ),
        alignment: Alignment.center,
        child: Text(
          content.type,
          style: AppTypography.body(
            11,
          ).copyWith(color: context.colors.foregroundMuted),
        ),
      ),
    );
  }
}

/// 그리드 셀의 우측 하단에 표시되는 리액션 뱃지. 본인·파트너 중 리액션
/// 남긴 사람의 아바타 + 이모지 뱃지를 ContentViewerV2의 ReactionBar와 같은
/// 톤으로 보여준다. 리액션이 하나도 없으면 빈 위젯을 반환해 Positioned
/// 안에서 0×0으로 안 보이게.
class _GridReactionBadge extends ConsumerWidget {
  const _GridReactionBadge({required this.content});

  final Content content;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reactions =
        ref
            .watch(reactionsForSceneProvider(content.sceneId))
            .valueOrNull?[content.id] ??
        const <Reaction>[];
    if (reactions.isEmpty) return const SizedBox.shrink();

    final myProfile = ref.watch(myProfileProvider).valueOrNull;
    final partner = ref.watch(activeCoupleProvider).valueOrNull?.partner;

    Reaction? mine;
    Reaction? theirs;
    for (final r in reactions) {
      if (myProfile != null && r.userId == myProfile.id) {
        mine = r;
      } else if (partner != null && r.userId == partner.id) {
        theirs = r;
      }
    }

    final children = <Widget>[];
    // 파트너 먼저(좌), 본인 우 — ReactionBar와 동일 순서.
    if (theirs != null && partner != null) {
      children.add(
        ReactionAvatarBadge(
          avatarUrl: partner.displayAvatarUrl,
          fallbackName: partner.displayName,
          emoji: theirs.emoji,
          avatarSize: 22,
          badgeSize: 13,
          emojiSize: 7,
          // emojiSize=7용 calibrate. 폰트 메트릭 shift가 비례 아니라 직접
          // 시각 보정. 위치 안 맞으면 여기서 미세 조정.
          emojiOffset: const Offset(0.45, -0.8),
        ),
      );
    }
    if (mine != null && myProfile != null) {
      if (children.isNotEmpty) children.add(const SizedBox(width: 4));
      children.add(
        ReactionAvatarBadge(
          avatarUrl: myProfile.displayAvatarUrl,
          fallbackName: myProfile.displayName,
          emoji: mine.emoji,
          avatarSize: 22,
          badgeSize: 13,
          emojiSize: 7,
          // emojiSize=7용 calibrate. 폰트 메트릭 shift가 비례 아니라 직접
          // 시각 보정. 위치 안 맞으면 여기서 미세 조정.
          emojiOffset: const Offset(0.45, -0.8),
        ),
      );
    }
    if (children.isEmpty) return const SizedBox.shrink();

    // 이미지가 밝거나 디테일이 많을 때 뱃지가 묻히지 않도록 하단에 은은한
    // 다크 그라데이션을 깔고 그 위에 우측 정렬로 뱃지를 둔다.
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.transparent, Colors.black.withValues(alpha: 0.35)],
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 24, 8, 8),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: children,
        ),
      ),
    );
  }
}

/// Reorder 모드용 단일 행 타일 — square thumbnail + drag handle. scene list
/// reorder와 시각 일관 (단일 column, 우측 핸들).
class _ReorderTile extends StatelessWidget {
  const _ReorderTile({
    super.key,
    required this.content,
    required this.reorderIndex,
  });

  final Content content;
  // 좌측 영역(thumb+label)은 long-press → reorder, 우측 grip은 즉시 → reorder.
  // 좌측이 long-press여야 vertical scroll이 가능.
  final int reorderIndex;

  static const double _thumbSize = 56;

  @override
  Widget build(BuildContext context) {
    final body = Row(
      children: [
        ClipRRect(
          borderRadius: AppRadii.smBorder,
          child: SizedBox(
            width: _thumbSize,
            height: _thumbSize,
            child: ProgressivePhoto(
              thumbUrl: content.thumbSignedUrl,
              fullUrl: content.fullSignedUrl,
            ),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Text(
            _typeLabel(content.type),
            style: AppTypography.body(
              14,
              weight: FontWeight.w500,
            ).copyWith(color: context.colors.foreground),
          ),
        ),
      ],
    );

    final handle = GestureDetector(
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: 56,
        height: 56,
        child: Center(
          child: FaIcon(
            FontAwesomeIcons.gripLines,
            size: 16,
            color: context.colors.foregroundMuted,
          ),
        ),
      ),
    );

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
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
            Expanded(
              child: ReorderableDelayedDragStartListener(
                index: reorderIndex,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  child: body,
                ),
              ),
            ),
            ReorderableDragStartListener(
              index: reorderIndex,
              child: handle,
            ),
          ],
        ),
      ),
    );
  }

  String _typeLabel(String type) {
    switch (type) {
      case 'photo':
        return 'Photo';
      case 'film':
        return 'Film';
      case 'music':
        return 'Music';
      case 'place':
        return 'Place';
      default:
        return type;
    }
  }
}

/// 로딩 중 placeholder 타일. `shimmer` 패키지로 base→highlight→base sweep.
/// base/highlight는 둘 다 opaque solid color라야 해서 base 위에 white 살짝
/// 섞어 highlight를 도출 — 양 테마 공통으로 약간 더 밝은 톤이 흐르듯 sweep.
class _GhostTile extends StatelessWidget {
  const _GhostTile({required this.aspect});

  final double aspect;

  @override
  Widget build(BuildContext context) {
    final base = context.colors.clickableArea;
    // highlight를 base와 거의 같은 톤으로 — 카드 색에서 살짝만 대비되는 정도.
    // foreground는 테마에 따라 cream(dark) ↔ near-black(light)으로 뒤집히므로
    // 2% blend면 양 테마 모두 base 위에 자연스럽게 미묘한 sweep이 흐름. white
    // 고정으로 쓰면 light 테마에선 invisible.
    final highlight = Color.alphaBlend(
      context.colors.foreground.withValues(alpha: 0.02),
      base,
    );
    return AspectRatio(
      aspectRatio: aspect,
      child: ClipRRect(
        borderRadius: AppRadii.mdBorder,
        child: Shimmer.fromColors(
          baseColor: base,
          highlightColor: highlight,
          period: const Duration(milliseconds: 1800),
          child: const SizedBox.expand(child: ColoredBox(color: Colors.white)),
        ),
      ),
    );
  }
}

class _DetailActionRow extends StatelessWidget {
  const _DetailActionRow({
    required this.onAddMedia,
    required this.onPlay,
    required this.showPlay,
  });

  final VoidCallback onAddMedia;
  final VoidCallback onPlay;

  /// 콘텐츠가 하나라도 있을 때만 재생 버튼 표시.
  final bool showPlay;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final screenWidth = MediaQuery.sizeOf(context).width;
    final buttonSize = screenWidth >= 420 ? 54.0 : 48.0;
    final gap = screenWidth >= 420 ? 28.0 : 22.0;
    final iconSize = buttonSize * 0.36;
    final iconColor = context.colors.foreground.withValues(alpha: 0.9);

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        GlassCircleButton(
          size: buttonSize,
          onTap: onAddMedia,
          semanticLabel: l10n.sceneDetailAddMedia,
          child: FaIcon(
            FontAwesomeIcons.plus,
            size: iconSize,
            color: iconColor,
          ),
        ),
        if (showPlay) ...[
          SizedBox(width: gap),
          GlassCircleButton(
            size: buttonSize,
            onTap: onPlay,
            semanticLabel: l10n.sceneDetailPlay,
            child: FaIcon(
              FontAwesomeIcons.play,
              size: iconSize,
              color: iconColor,
            ),
          ),
        ],
      ],
    );
  }
}

/// Scene 내 모든 Moment의 날짜를 일괄 변경하는 시트 본문. MomentDatePicker
/// Sheet와 같은 패턴 + 상단 안내 텍스트가 다른 점.
class _SceneDateBulkSheet extends StatefulWidget {
  const _SceneDateBulkSheet({
    required this.initialDate,
    required this.infoText,
    required this.title,
    required this.onConfirm,
  });

  final DateTime initialDate;
  final String infoText;
  final String title;
  final ValueChanged<DateTime> onConfirm;

  @override
  State<_SceneDateBulkSheet> createState() => _SceneDateBulkSheetState();
}

class _SceneDateBulkSheetState extends State<_SceneDateBulkSheet> {
  late DateTime _selected;
  late final DateTime _max;
  static final DateTime _min = DateTime(2000);

  @override
  void initState() {
    super.initState();
    _max = DateTime.now();
    final initialLocal = widget.initialDate.toLocal();
    _selected = initialLocal.isAfter(_max) ? _max : initialLocal;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context).toLanguageTag();
    final dateStr = DateFormat.yMMMMd(locale).format(_selected);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(height: 8),
        Text(
          widget.title,
          style: AppTypography.display(20).copyWith(
            color: context.colors.foreground,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Text(
            widget.infoText,
            textAlign: TextAlign.center,
            style: AppTypography.body(12).copyWith(
              color: context.colors.foregroundMuted,
              height: 1.4,
            ),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          dateStr,
          style: AppTypography.body(14).copyWith(
            color: context.colors.foreground,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 200,
          child: CupertinoTheme(
            data: CupertinoThemeData(
              brightness: Theme.of(context).brightness,
              textTheme: CupertinoTextThemeData(
                dateTimePickerTextStyle: AppTypography.body(16).copyWith(
                  color: context.colors.foreground,
                ),
              ),
            ),
            child: CupertinoDatePicker(
              mode: CupertinoDatePickerMode.date,
              initialDateTime: _selected,
              maximumDate: _max,
              minimumDate: _min,
              onDateTimeChanged: (date) {
                setState(() => _selected = date);
              },
            ),
          ),
        ),
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: SizedBox(
            width: double.infinity,
            child: GestureDetector(
              onTap: () => widget.onConfirm(_selected),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  borderRadius: AppRadii.sheetInnerBorder,
                  color: context.colors.foreground,
                ),
                child: Center(
                  child: Text(
                    l10n.datePickerConfirm,
                    style: AppTypography.body(15, weight: FontWeight.w600)
                        .copyWith(color: context.colors.background),
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
