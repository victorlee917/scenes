import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_colors_ext.dart';
import '../../../core/theme/app_radii.dart';
import '../../../core/widgets/floating_action_sheet.dart';
import 'add_media_sheet.dart';
// import 'content_detail_sheet.dart' show ContentViewer;
import 'content_viewer_v2.dart';
import 'create_scene_sheet.dart';
import 'play_scene_screen.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../../../core/widgets/glass_circle_button.dart';
import '../../../l10n/app_localizations.dart';
import '../home_view_model.dart';
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
      transitionDuration: const Duration(milliseconds: 420),
      reverseTransitionDuration: const Duration(milliseconds: 360),
      pageBuilder: (context, animation, secondaryAnimation) {
        return SceneDetailScreen(scene: scene, canisterSize: canisterSize);
      },
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        return child;
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

    return Scaffold(
      // backgroundColor handled by theme
      body: Stack(
        children: [
          RefreshIndicator(
            onRefresh: _handleRefresh,
            color: context.colors.foreground,
            backgroundColor: context.colors.nonClickableArea,
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
                      tag: SceneDetailScreen.canisterHeroTag(widget.scene.id),
                      child: Material(
                        type: MaterialType.transparency,
                        child: SizedBox(
                          width: widget.canisterSize,
                          height: widget.canisterSize,
                          child: SceneCard(scene: widget.scene),
                        ),
                      ),
                    ),
                    const SizedBox(height: 40),
                    Hero(
                      tag: SceneDetailScreen.infoHeroTag(widget.scene.id),
                      child: Material(
                        type: MaterialType.transparency,
                        child: FocusedSceneInfo(scene: widget.scene),
                      ),
                    ),
                    const SizedBox(height: 36),
                    FadeTransition(
                      opacity: routeAnim,
                      child: _DetailActionRow(
                        onShare: () {},
                        onAddMedia: () {
                          AddMediaSheet.show(
                            context: context,
                            scene: widget.scene,
                            showSceneHeader: false,
                          );
                        },
                        onPlay: () {
                          Navigator.of(context).push(
                            PlaySceneScreen.route(
                              scenes: [widget.scene],
                            ),
                          );
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
                sliver: _buildMediaSliver(widget.scene),
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
                title: widget.scene.title,
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
    // TODO: Supabase에서 scene 데이터 다시 로드.
    await Future<void>.delayed(const Duration(milliseconds: 600));
  }

  void _handleMoreActions() {
    final l10n = AppLocalizations.of(context);
    FloatingActionSheet.show(
      context: context,
      items: [
        FloatingActionItem(
          label: l10n.sceneDetailEdit,
          onTap: () {
            CreateSceneSheet.show(
              context: context,
              editScene: widget.scene,
            );
          },
        ),
        FloatingActionItem(
          label: l10n.sceneDetailDelete,
          isDestructive: true,
          onTap: () {
            // 삭제 확인. UI는 추후.
          },
        ),
      ],
    );
  }

  Widget _buildMediaSliver(Scene scene) {
    final total = scene.media.total;
    if (total == 0) {
      return SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Text(
            'no media yet',
            textAlign: TextAlign.center,
            style: TextStyle(color: context.colors.foregroundMuted),
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
        childCount: total,
        itemBuilder: (context, index) {
          final height = _mockTileHeights[index % _mockTileHeights.length];
          return GestureDetector(
            onTap: () {
              final couple = ref.read(homeViewModelProvider).couple;
              // mock: 전체 콘텐츠의 매체 타입 리스트
              const mockTypes = [
                'photo', 'photo', 'film', 'photo', 'music',
                'photo', 'place', 'photo', 'film', 'music',
                'photo', 'place',
              ];
              final allTypes = List.generate(
                total,
                (i) => mockTypes[i % mockTypes.length],
              );
              ContentViewerV2.show(
                context: context,
                totalCount: total,
                initialIndex: index,
                sceneImageUrl: widget.scene.coverImageUrl,
                sceneName: widget.scene.title,
                uploaderName: couple.partnerAName,
                mediaTypes: allTypes,
                uploadedAt: DateTime.now(),
              );
            },
            child: Container(
              height: height,
              decoration: BoxDecoration(
                color: context.colors.clickableArea,
                borderRadius: AppRadii.mdBorder,
                border: Border.all(
                  color: context.colors.foreground.withValues(alpha: 0.06),
                  width: 1,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _DetailActionRow extends StatelessWidget {
  const _DetailActionRow({
    required this.onShare,
    required this.onAddMedia,
    required this.onPlay,
  });

  final VoidCallback onShare;
  final VoidCallback onAddMedia;
  final VoidCallback onPlay;

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
        // GlassCircleButton(
        //   size: buttonSize,
        //   onTap: onShare,
        //   semanticLabel: l10n.sceneDetailShare,
        //   child: FaIcon(FontAwesomeIcons.shareFromSquare,
        //       size: iconSize, color: iconColor),
        // ),
        // SizedBox(width: gap),
        GlassCircleButton(
          size: buttonSize,
          onTap: onAddMedia,
          semanticLabel: l10n.sceneDetailAddMedia,
          child: FaIcon(FontAwesomeIcons.plus,
              size: iconSize, color: iconColor),
        ),
        SizedBox(width: gap),
        GlassCircleButton(
          size: buttonSize,
          onTap: onPlay,
          semanticLabel: l10n.sceneDetailPlay,
          child: FaIcon(FontAwesomeIcons.play,
              size: iconSize, color: iconColor),
        ),
      ],
    );
  }
}

const List<double> _mockTileHeights = [
  200,
  140,
  260,
  180,
  220,
  150,
  240,
  170,
  200,
  130,
  280,
  190,
];
