import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors_ext.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/splash_view.dart';
import '../../l10n/app_localizations.dart';
import '../couple/couple_view_model.dart';
import '../scene/scenes_view_model.dart';
import 'home_view_model.dart';
import 'widgets/add_scene_card.dart';
import 'widgets/arc_dial.dart';
import 'widgets/add_media_sheet.dart';
import 'widgets/couple_strip.dart';
import 'widgets/create_scene_sheet.dart';
import 'widgets/play_scene_sheet.dart';
import 'widgets/profile_screen.dart';
import 'widgets/focused_scene_info.dart';
import 'widgets/scene_card.dart';
import 'widgets/scene_detail_screen.dart';
import 'widgets/scene_list_screen.dart';
import 'widgets/transport_controls.dart';

/// 홈 화면.
///
/// 가로 원호(arc) 캐러셀:
/// - 카드들이 좌→우로 배치되고, 스크롤하면 원호를 따라 회전하는 듯한 감각.
/// - 포커스 카드는 원호의 정점(상단 가운데)에 서 있고, 양옆으로 갈수록
///   아래로 가라앉고 작아지고 opacity가 떨어짐.
/// - `PageView.builder`(horizontal) + `AnimatedBuilder` + `Transform`으로 구현.
/// - Snap·fling 물리는 PageView가 기본 제공.
class HomeView extends ConsumerStatefulWidget {
  const HomeView({super.key});

  @override
  ConsumerState<HomeView> createState() => _HomeViewState();
}

class _HomeViewState extends ConsumerState<HomeView> {
  /// 가로 슬롯 폭을 viewport 대비 얼마로 할지.
  /// 작을수록 한 화면에 더 많은 카드가 보이고, 원호가 조밀해짐.
  static const double _viewportFraction = 0.5;

  /// 원호의 step 각도(rad). 인접 카드 사이의 각 간격.
  static const double _angleStep = 0.55;

  /// 가상의 원호 반지름(dp). 클수록 arc가 완만하고 Y 하강이 작음.
  static const double _arcRadius = 320;

  /// 포커스 카드를 viewport 세로 중심에서 위로 얼마나 올릴지.
  static const double _canisterUpwardOffset = 80;

  static const double _minScale = 0.5;
  static const double _minOpacity = 0.0;

  PageController? _pageController;

  /// scenes가 처음 로드되고 cover 이미지들도 모두 precache된 시점부터 true.
  /// 그 전엔 스피너만 보여줌 — PageView 안의 Image.network 로딩으로 한 프레임
  /// 비는 듯한 인상을 주는 걸 방지.
  bool _firstLoadComplete = false;
  bool _precacheKickedOff = false;

  /// 사용자 스크롤 중 여부. true인 동안 Info를 fade out.
  bool _isScrolling = false;

  /// onPageChanged로 실시간 업데이트되는 "포커스 중인" 인덱스.
  int _lastFocusedIndex = 0;

  /// FocusedSceneInfo에 실제로 표시되는 인덱스. fade-out 도중 내용이
  /// 깜빡이는 것을 막기 위해, 스크롤이 완전히 끝난 뒤에만 _lastFocusedIndex
  /// 값을 복사한다.
  int _displayedIndex = 0;

  @override
  void initState() {
    super.initState();
  }

  /// scenes 로드 완료 시점에 PageController를 한 번만 만든다.
  /// 가장 최신(=마지막 인덱스)을 initialPage로.
  void _ensurePagerInit(int sceneCount) {
    if (_pageController != null) return;
    final initialIndex = sceneCount == 0 ? 0 : sceneCount - 1;
    _pageController = PageController(
      viewportFraction: _viewportFraction,
      initialPage: initialIndex,
    );
    _lastFocusedIndex = initialIndex;
    _displayedIndex = initialIndex;
  }

  /// 첫 렌더 직전에 보여야 할 모든 네트워크 이미지를 동시 precache.
  /// scene cover + couple 양쪽 avatar. 끝나야 _firstLoadComplete=true.
  Future<void> _precacheImages({
    required List<dynamic> scenesList,
    required List<String> avatarUrls,
  }) async {
    final urls = <String>{
      for (final s in scenesList)
        if ((s.coverImageUrl as String).isNotEmpty) s.coverImageUrl as String,
      for (final a in avatarUrls)
        if (a.isNotEmpty) a,
    };
    if (urls.isEmpty) return;
    await Future.wait(
      urls.map(
        (u) => precacheImage(NetworkImage(u), context).catchError((_) {}),
      ),
    );
  }

  @override
  void dispose() {
    _pageController?.dispose();
    super.dispose();
  }

  void _handlePageChanged(int index) {
    if (index != _lastFocusedIndex) {
      _lastFocusedIndex = index;
      HapticFeedback.selectionClick();
      ref.read(homeViewModelProvider.notifier).setPageIndex(index);
    }
  }

  bool _onScrollNotification(ScrollNotification notification) {
    if (notification is ScrollStartNotification) {
      if (!_isScrolling) {
        setState(() => _isScrolling = true);
      }
    } else if (notification is ScrollEndNotification) {
      if (_isScrolling) {
        setState(() {
          _isScrolling = false;
          _displayedIndex = _lastFocusedIndex;
        });
      }
    }
    return false;
  }

  // ── tap handlers ────────────────────────────────────────────

  void _handleCoupleTap() {
    Navigator.of(context).push(ProfileScreen.route());
  }

  void _handleSceneTap(String sceneId) {
    final scenes = ref.read(homeViewModelProvider).scenes;
    final scene = scenes.firstWhere(
      (s) => s.id == sceneId,
      orElse: () => scenes[_displayedIndex],
    );
    final viewport = MediaQuery.sizeOf(context);
    final canisterSlotSize = viewport.width * _viewportFraction;
    Navigator.of(context).push(
      SceneDetailScreen.route(
        scene: scene,
        canisterSize: canisterSlotSize,
      ),
    );
  }

  void _handleSort() {
    final scenes = ref.read(homeViewModelProvider).scenes;
    if (scenes.isEmpty) return;
    Navigator.of(context).push(
      SceneListScreen.route(
        scenes: scenes,
        onSceneTap: _handleSceneTap,
      ),
    );
  }

  void _handleAdd() {
    final scenes = ref.read(homeViewModelProvider).scenes;
    if (scenes.isEmpty) return;
    final scene = (_displayedIndex >= 0 && _displayedIndex < scenes.length)
        ? scenes[_displayedIndex]
        : scenes.last;
    AddMediaSheet.show(context: context, scene: scene);

  }

  void _handlePlay() {
    final scenes = ref.read(homeViewModelProvider).scenes;
    if (scenes.isEmpty) return;
    final defaultScene =
        (_displayedIndex >= 0 && _displayedIndex < scenes.length)
            ? scenes[_displayedIndex]
            : scenes.last;
    PlaySceneSheet.show(
      context: context,
      defaultSceneId: defaultScene.id,
    );
  }

  // ── build ───────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final coupleAsync = ref.watch(activeCoupleProvider);
    final scenesAsync = ref.watch(scenesProvider);
    final scenes = ref.watch(homeViewModelProvider.select((s) => s.scenes));
    final l10n = AppLocalizations.of(context);
    final padding = MediaQuery.paddingOf(context);
    final viewport = MediaQuery.sizeOf(context);

    // 첫 로드 끝나기 전엔 PageController도 안 만들고 spinner만. 미리 만들면
    // 빈 scenes 기준 initialPage=0이라 Add 슬롯이 잠깐 깜빡이며 노출됨.
    //
    // 모든 조건 만족해야 진짜 ready:
    //  - coupleAsync.hasValue + 값 non-null: pair_id가 결정됨
    //  - scenesAsync.hasValue: 어쨌든 한 번 데이터가 emit됨
    //  - !scenesAsync.isLoading: 현재 fetch 진행 중이 아님 (re-fetch 포함).
    //    pair_id가 null→non-null로 바뀌면 build 재실행되며 loading.copyWithPrevious
    //    상태를 거침. 그 동안 hasValue=true지만 새 데이터 아직 안 옴 → 기다려야 함.
    final ready = coupleAsync.hasValue &&
        coupleAsync.value != null &&
        scenesAsync.hasValue &&
        !scenesAsync.isLoading;

    // 첫 로드: ready되면 cover + avatar 이미지들 precache 시작.
    if (ready && !_precacheKickedOff) {
      _precacheKickedOff = true;
      final couple = ref.read(homeViewModelProvider).couple;
      final avatarUrls = <String>[
        couple.partnerAImageUrl,
        couple.partnerBImageUrl,
      ];
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        await _precacheImages(scenesList: scenes, avatarUrls: avatarUrls);
        // precacheImage 완료 후에도 image cache 최종 commit까지 한 프레임이
        // 더 필요한 케이스가 있어 한 frame 대기 후 완료 표시 → wasSync=true 보장.
        await SchedulerBinding.instance.endOfFrame;
        if (mounted) setState(() => _firstLoadComplete = true);
      });
    }

    if (!ready || !_firstLoadComplete) {
      // 네이티브 splash와 시각적으로 동일한 위젯으로 채워, native splash가
      // 제거된 직후 깜빡이는 spinner 없이 같은 화면이 이어지는 인상을 줌.
      return const Scaffold(body: SplashView());
    }

    // 로드 완료 시점에 한 번만 PageController 생성 — initialPage = 마지막 인덱스.
    _ensurePagerInit(scenes.length);

    final isEmpty = scenes.isEmpty;

    final gradientBase = context.colors.gradientBase;
    final topShadowHeight = padding.top + 130;
    final bottomShadowHeight = padding.bottom + 150;

    final pagerItemCount = isEmpty ? 1 : scenes.length + 1;

    final displayedScene =
        (_displayedIndex >= 0 && _displayedIndex < scenes.length)
            ? scenes[_displayedIndex]
            : null;

    return Scaffold(
      resizeToAvoidBottomInset: false,
      // backgroundColor handled by theme
      body: Stack(
        children: [
          // ── Refreshable 영역: 캐니스터 캐러셀 + 메타 정보만 ─────
          // CoupleStrip / ArcDial / TransportControls / shadow는 outer
          // Stack에 직접 배치되므로 pull-to-refresh 시 같이 따라 내려가지
          // 않고 고정된 위치를 유지한다.
          Positioned.fill(
            child: RefreshIndicator(
              onRefresh: _handleRefresh,
              // edgeOffset이 indicator의 출발 지점을 CoupleStrip 아래로
              // 내리고, displacement는 default(40)로 둬 트리거 거리를 짧게.
              edgeOffset: 80,
              displacement: 40,
              // Material 기본 elevation(2.0)이 진한 drop shadow를 만들어
              // 테마 톤과 부딪힘. 0으로 두고 배경색은 테마 토큰 사용.
              elevation: 0,
              backgroundColor: context.colors.clickableArea,
              color: context.colors.foreground,
              child: CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: Stack(
                      children: [
                        Positioned.fill(
                          child: NotificationListener<ScrollNotification>(
                            onNotification: _onScrollNotification,
                            child: Semantics(
                label: l10n.sceneListA11yLabel,
                child: PageView.builder(
                  controller: _pageController!,
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  clipBehavior: Clip.none,
                  itemCount: pagerItemCount,
                  onPageChanged: _handlePageChanged,
                  itemBuilder: (context, index) {
                    final isAddSlot = index >= scenes.length;
                    final Widget inner = isAddSlot
                        ? const AddSceneCard()
                        : Hero(
                            tag: SceneDetailScreen.canisterHeroTag(
                              scenes[index].id,
                            ),
                            // iOS swipe-back 제스처에서도 Hero 비행 발사.
                            transitionOnUserGestures: true,
                            // 비행 중 source/destination 트리가 rebuild되어도
                            // 영향 안 받도록 fresh SceneCard로 grow/shrink만.
                            flightShuttleBuilder: (
                              _,
                              _,
                              _,
                              _,
                              _,
                            ) =>
                                Material(
                              type: MaterialType.transparency,
                              child: SceneCard(scene: scenes[index]),
                            ),
                            child: Material(
                              type: MaterialType.transparency,
                              child: SceneCard(scene: scenes[index]),
                            ),
                          );
                    final Widget card = GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () {
                        // 포커스(=carousel 중앙)된 캐니스터만 본 액션을 트리거.
                        // 옆에서 일부 보이는 카드는 탭 시 그 인덱스로 carousel
                        // 만 스냅(액션은 다음 탭에서). controller.page를 round
                        // 해서 현재 snap 대상 인덱스와 비교 — 스크롤 중 tap도
                        // 자연스럽게 처리.
                        final controller = _pageController;
                        if (controller == null || !controller.hasClients) {
                          return;
                        }
                        final page = controller.page ??
                            controller.initialPage.toDouble();
                        if (page.round() != index) {
                          controller.animateToPage(
                            index,
                            duration: const Duration(milliseconds: 320),
                            curve: Curves.easeOut,
                          );
                          return;
                        }
                        if (isAddSlot) {
                          CreateSceneSheet.show(context: context);
                        } else {
                          _handleSceneTap(scenes[index].id);
                        }
                      },
                      child: inner,
                    );

                    return AnimatedBuilder(
                      animation: _pageController!,
                      builder: (context, child) {
                        final controller = _pageController!;
                        double signed;
                        if (controller.hasClients &&
                            controller.position.haveDimensions) {
                          final page = controller.page ??
                              controller.initialPage.toDouble();
                          signed = page - index;
                        } else {
                          signed =
                              (controller.initialPage - index).toDouble();
                        }
                        final absSigned = signed.abs().clamp(0.0, 3.0);

                        final angle = absSigned * _angleStep;
                        final yArc = _arcRadius * (1 - math.cos(angle));
                        final yOffset = yArc - _canisterUpwardOffset;

                        final scale =
                            math.max(_minScale, 1 - absSigned * 0.18);
                        final opacity = (1 - absSigned * 0.45)
                            .clamp(_minOpacity, 1.0);

                        // 원통 회전: 중심에서 벗어날수록 X축 기준 회전해
                        // 마치 드럼 표면에 붙어 굴러가는 느낌.
                        final rotX = signed.clamp(-2.0, 2.0) * 0.18;
                        final matrix = Matrix4.identity()
                          ..setEntry(3, 2, 0.0012)
                          ..rotateX(rotX);

                        return Transform.translate(
                          offset: Offset(0, yOffset),
                          child: Transform(
                            transform: matrix,
                            alignment: Alignment.center,
                            child: Transform.scale(
                              scale: scale,
                              child: Opacity(
                                opacity: opacity,
                                child: child,
                              ),
                            ),
                          ),
                        );
                      },
                      child: card,
                    );
                  },
                ),
              ),
            ),
          ),

                        // 등록된 scene이 0개일 땐 AddSceneCard 아래에 display
                        // font 태그라인. FocusedSceneInfo와 동일한 Y anchor라
                        // 빈 상태 → 첫 scene 추가 후의 텍스트 등장 위치가
                        // 거의 같은 곳. 한/영 폰트는 display(text:)가 자동.
                        if (isEmpty)
                          Positioned(
                            top: viewport.height - padding.bottom - 362,
                            left: 24,
                            right: 24,
                            child: IgnorePointer(
                              child: Builder(
                                builder: (context) {
                                  final prefix = l10n.homeEmptyTaglinePrefix;
                                  final brand = l10n.homeEmptyTaglineBrand;
                                  final suffix = l10n.homeEmptyTaglineSuffix;
                                  // 한/영 폰트 분기는 합본 문자열로 판정.
                                  final fullText = '$prefix$brand$suffix';
                                  final baseStyle = AppTypography.display(
                                    30,
                                    text: fullText,
                                  ).copyWith(
                                    color: context.colors.foregroundMuted,
                                    height: 1.45,
                                  );
                                  // 프로필 narrative와 동일한 하이라이트 톤.
                                  final hlStyle = TextStyle(
                                    color: context.colors.foreground,
                                    fontWeight: FontWeight.w700,
                                  );
                                  return Text.rich(
                                    TextSpan(
                                      children: [
                                        TextSpan(text: prefix),
                                        TextSpan(text: brand, style: hlStyle),
                                        TextSpan(text: suffix),
                                      ],
                                    ),
                                    textAlign: TextAlign.center,
                                    style: baseStyle,
                                  );
                                },
                              ),
                            ),
                          ),
                        // Layer 5 — 포커스된 Scene의 메타 텍스트. Hero source.
                        // top-anchor로 # title의 절대 Y 고정. 콘텐츠(media/date)
                        // 가 있든 없든 # title은 같은 자리. media/date는 그
                        // 아래로 자연 흘러내림. 362 ≈ 캐니스터 바닥과 50px 마진.
                        if (!isEmpty)
                          Positioned(
                            top: viewport.height - padding.bottom - 362,
                            left: 0,
                            right: 0,
                            child: IgnorePointer(
                              ignoring: _isScrolling,
                              child: AnimatedOpacity(
                                opacity: _isScrolling ? 0 : 1,
                                duration: const Duration(milliseconds: 220),
                                curve: Curves.easeOut,
                                child: GestureDetector(
                                  behavior: HitTestBehavior.translucent,
                                  onTap: () {
                                    if (displayedScene != null) {
                                      _handleSceneTap(displayedScene.id);
                                    }
                                  },
                                  child: displayedScene == null
                                      ? const SizedBox.shrink()
                                      : Hero(
                                          tag: SceneDetailScreen.infoHeroTag(
                                            displayedScene.id,
                                          ),
                                          transitionOnUserGestures: true,
                                          child: Material(
                                            type: MaterialType.transparency,
                                            child: FocusedSceneInfo(
                                                scene: displayedScene),
                                          ),
                                        ),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Layer 2 — 상단 shadow
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: topShadowHeight,
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      gradientBase.withValues(alpha: 1.0),
                      gradientBase.withValues(alpha: 0.9),
                      gradientBase.withValues(alpha: 0.58),
                      gradientBase.withValues(alpha: 0.22),
                      gradientBase.withValues(alpha: 0.0),
                    ],
                    stops: const [0.0, 0.3, 0.55, 0.8, 1.0],
                  ),
                ),
              ),
            ),
          ),

          // Layer 3 — 하단 shadow
          if (!isEmpty)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              height: bottomShadowHeight,
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                      colors: [
                        gradientBase.withValues(alpha: 1.0),
                        gradientBase.withValues(alpha: 0.9),
                        gradientBase.withValues(alpha: 0.58),
                        gradientBase.withValues(alpha: 0.22),
                        gradientBase.withValues(alpha: 0.0),
                      ],
                      stops: const [0.0, 0.3, 0.55, 0.8, 1.0],
                    ),
                  ),
                ),
              ),
            ),

          // Layer 4 — 상단 couple strip. 양옆 빈 영역 터치가
          // 아래 PageView로 전달되지 않도록 GestureDetector로 차단.
          Positioned(
            top: padding.top,
            left: 0,
            right: 0,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () {},
              child: CoupleStrip(onTap: _handleCoupleTap),
            ),
          ),

          // Layer 6 — Arc dial.
          if (!isEmpty)
            Positioned(
              bottom: padding.bottom + 84,
              left: 0,
              right: 0,
              child: ArcDial(
                pageController: _pageController!,
                itemCount: pagerItemCount,
              ),
            ),

          // Layer 7 — 하단 glass 버튼.
          if (!isEmpty)
            Positioned(
              bottom: padding.bottom,
              left: 0,
              right: 0,
              child: TransportControls(
                onSort: _handleSort,
                onAdd: _handleAdd,
                onPlay: _handlePlay,
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _handleRefresh() async {
    // scenesProvider는 scene_summary 뷰를 읽으므로 photo upload 후 type별
    // count도 같이 갱신. softRefresh가 loading state로 안 가서 카드들이
    // pull-to-refresh 동안 그대로 보임.
    await ref.read(scenesProvider.notifier).softRefresh();
  }
}

