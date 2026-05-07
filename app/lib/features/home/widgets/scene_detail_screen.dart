import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:shimmer/shimmer.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_colors_ext.dart';
import '../../../core/theme/app_radii.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/app_toast.dart';
import '../../../core/widgets/confirm_dialog.dart';
import '../../../core/widgets/floating_action_sheet.dart';
import '../../content/contents_view_model.dart';
import '../../content/models/content.dart';
import '../../content/widgets/progressive_photo.dart';
import '../../content/widgets/source_badge.dart';
import '../../profile/profile_view_model.dart';
import '../../scene/scenes_view_model.dart';
import '../../subscription/subscription_view_model.dart';
import 'add_media_sheet.dart';
// import 'content_detail_sheet.dart' show ContentViewer;
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
  });

  final Scene scene;

  /// 홈 carousel의 slot width와 동일한 값. SceneCard의 LayoutBuilder가
  /// `size - 16`을 지름으로 잡으므로 여기에도 같은 값을 넘겨 Hero가 두
  /// 위치의 크기를 원활히 보간하도록 한다.
  final double canisterSize;

  static String canisterHeroTag(String sceneId) =>
      'scene-canister-$sceneId';
  static String infoHeroTag(String sceneId) => 'scene-info-$sceneId';

  /// 홈에서 detail로 push하는 라우트. 페이지 자체는 전환 애니메이션을 쓰지
  /// 않고, Hero가 canister/info를 플라이트 시키고 나머지(앱바·그리드)만
  /// FadeTransition으로 올라온다.
  /// Hero 플라이트를 사용하는 라우트. 홈 캐러셀에서 진입할 때 사용.
  static Route<void> route({
    required Scene scene,
    required double canisterSize,
  }) {
    return PageRouteBuilder<void>(
      opaque: true,
      transitionDuration: const Duration(milliseconds: 480),
      reverseTransitionDuration: const Duration(milliseconds: 480),
      pageBuilder: (context, animation, secondaryAnimation) {
        return SceneDetailScreen(scene: scene, canisterSize: canisterSize);
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
  }) {
    return PageRouteBuilder<void>(
      opaque: true,
      transitionDuration: const Duration(milliseconds: 340),
      reverseTransitionDuration: const Duration(milliseconds: 280),
      pageBuilder: (context, animation, secondaryAnimation) {
        return HeroMode(
          enabled: false,
          child: SceneDetailScreen(scene: scene, canisterSize: canisterSize),
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

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
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

    final routeAnim = ModalRoute.of(context)?.animation ??
        const AlwaysStoppedAnimation<double>(1);

    // scenesProvider에서 최신 scene을 watch — Edit으로 title/cover 바뀌면
    // 시트 닫힌 직후 자동 반영. 리스트에서 사라졌으면(=삭제) widget.scene을
    // 최후의 fallback으로 써서 pop 애니메이션 도중 깨지지 않게 함.
    final scenesAsync = ref.watch(scenesProvider);
    final scene = scenesAsync.valueOrNull?.firstWhere(
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
                          child: FocusedSceneInfo(scene: scene),
                        ),
                      ),
                    ),
                    const SizedBox(height: 36),
                    FadeTransition(
                      opacity: routeAnim,
                      child: _DetailActionRow(
                        showPlay: scene.media.total > 0,
                        onShare: () {},
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
                          final isSubscribed =
                              ref.read(isSubscribedProvider);
                          if (isSubscribed) {
                            PlaySceneSheet.show(
                              context: context,
                              defaultSceneId: scene.id,
                              lockedSceneIds: {scene.id},
                            );
                          } else {
                            Navigator.of(context).push(
                              PlaySceneScreen.route(
                                scenes: [scene],
                              ),
                            );
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
          // 앱바. route 애니메이션으로 fade-in.
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: FadeTransition(
              opacity: routeAnim,
              child: DetailAppBar(
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
      ref
          .read(contentsForSceneProvider(widget.scene.id).notifier)
          .refresh(),
    ]);
  }

  /// scenes는 공동 편집이라 누구나 edit. 헤더(커버/타이틀) 탭 + ellipsis의
  /// Edit 항목 모두 이 시트를 띄움. provider에서 latest를 다시 읽어 stale
  /// prefill 방지.
  void _openEditSheet() {
    final latest = ref.read(scenesProvider).valueOrNull?.firstWhere(
              (s) => s.id == widget.scene.id,
              orElse: () => widget.scene,
            ) ??
        widget.scene;
    CreateSceneSheet.show(
      context: context,
      editScene: latest,
    );
  }

  void _handleMoreActions() {
    final l10n = AppLocalizations.of(context);
    final latest = ref.read(scenesProvider).valueOrNull?.firstWhere(
              (s) => s.id == widget.scene.id,
              orElse: () => widget.scene,
            ) ??
        widget.scene;
    // scenes는 공동 편집(edit)은 가능하지만 삭제는 owner만. 본인 id가
    // scene.created_by와 같을 때만 delete 항목 노출.
    final myId = ref.read(myProfileProvider).valueOrNull?.id;
    final canDelete = myId != null && myId == latest.createdBy;
    FloatingActionSheet.show(
      context: context,
      items: [
        FloatingActionItem(
          label: l10n.sceneDetailEdit,
          onTap: _openEditSheet,
        ),
        if (canDelete)
          FloatingActionItem(
            label: l10n.sceneDetailDelete,
            isDestructive: true,
            onTap: () async {
              final confirmed = await ConfirmDialog.show(
                context: context,
                title: 'Delete this scene?',
                message:
                    'All moments in this scene will also be removed.',
                confirmLabel: 'Delete',
                isDestructive: true,
              );
              if (!confirmed || !mounted) return;
              try {
                await ref
                    .read(scenesProvider.notifier)
                    .delete(widget.scene.id);
                if (mounted) Navigator.of(context).pop();
              } catch (_) {
                if (mounted) AppToast.show(context, 'Failed to delete scene.');
              }
            },
          ),
      ],
    );
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
            style: AppTypography.body(14).copyWith(
              color: context.colors.foregroundMuted,
            ),
          ),
        ),
      ),
      data: (contents) {
        if (contents.isEmpty) {
          return SliverToBoxAdapter(
            child: Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 32, vertical: 48),
              child: Text(
                l10n.sceneDetailEmptyMedia,
                textAlign: TextAlign.center,
                style: AppTypography.body(14).copyWith(
                  color: context.colors.foregroundMuted,
                  height: 1.5,
                ),
              ),
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
}

/// masonry grid의 한 칸. photo는 실 이미지, 그 외 type은 임시 placeholder
/// (다음 단계에서 type별 카드로 교체).
class _ContentTile extends StatelessWidget {
  const _ContentTile({required this.content, required this.onTap});

  final Content content;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
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
      child: ProgressivePhoto(
        thumbUrl: content.thumbSignedUrl,
        fullUrl: content.fullSignedUrl,
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
          const Positioned(
            top: 6,
            right: 6,
            child: TmdbBadge(),
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
          const Positioned(
            top: 6,
            right: 6,
            child: SpotifyBadge(),
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
          const Positioned(
            top: 6,
            right: 6,
            child: MapboxBadge(),
          ),
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
                  style: AppTypography.body(11, weight: FontWeight.w600)
                      .copyWith(color: Colors.white, height: 1.2),
                ),
              ),
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
          style: AppTypography.body(11).copyWith(
            color: context.colors.foregroundMuted,
          ),
        ),
      ),
    );
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
          child: const SizedBox.expand(
            child: ColoredBox(color: Colors.white),
          ),
        ),
      ),
    );
  }
}

class _DetailActionRow extends StatelessWidget {
  const _DetailActionRow({
    required this.onShare,
    required this.onAddMedia,
    required this.onPlay,
    required this.showPlay,
  });

  final VoidCallback onShare;
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
        // TODO: Share 버튼. 오픈 스펙에서 제외.
        GlassCircleButton(
          size: buttonSize,
          onTap: onAddMedia,
          semanticLabel: l10n.sceneDetailAddMedia,
          child: FaIcon(FontAwesomeIcons.plus,
              size: iconSize, color: iconColor),
        ),
        if (showPlay) ...[
          SizedBox(width: gap),
          GlassCircleButton(
            size: buttonSize,
            onTap: onPlay,
            semanticLabel: l10n.sceneDetailPlay,
            child: FaIcon(FontAwesomeIcons.play,
                size: iconSize, color: iconColor),
          ),
        ],
      ],
    );
  }
}

