import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors_ext.dart';
import '../../l10n/app_localizations.dart';
import 'home_view_model.dart';
import 'widgets/add_scene_card.dart';
import 'widgets/arc_dial.dart';
import 'widgets/add_media_sheet.dart';
import 'widgets/couple_strip.dart';
import 'widgets/create_scene_sheet.dart';
import 'widgets/device_tilt_controller.dart';
import 'widgets/play_scene_sheet.dart';
import 'widgets/profile_screen.dart';
import 'widgets/focused_scene_info.dart';
import 'widgets/scene_card.dart';
import 'widgets/scene_detail_screen.dart';
import 'widgets/scene_list_screen.dart';
import 'widgets/tilt_container.dart';
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

  late final PageController _pageController;
  late final DeviceTiltController _deviceTilt;

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
    // 최초 진입 시 가장 최신(마지막) Scene에 포커스를 맞춤.
    final initialScenes = ref.read(homeViewModelProvider).scenes;
    final initialIndex =
        initialScenes.isEmpty ? 0 : initialScenes.length - 1;
    _pageController = PageController(
      viewportFraction: _viewportFraction,
      initialPage: initialIndex,
    );
    _lastFocusedIndex = initialIndex;
    _displayedIndex = initialIndex;
    _deviceTilt = DeviceTiltController();
  }

  @override
  void dispose() {
    _pageController.dispose();
    _deviceTilt.dispose();
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
    AddMediaSheet.show(context: context, scene: scene, isSubscribed: false);

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
      isSubscribed: false,
    );
  }

  // ── build ───────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final scenes = ref.watch(homeViewModelProvider.select((s) => s.scenes));
    final l10n = AppLocalizations.of(context);
    final padding = MediaQuery.paddingOf(context);
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
          // Layer 1 — 가로 원호 캐러셀.
          Positioned.fill(
            child: NotificationListener<ScrollNotification>(
              onNotification: _onScrollNotification,
              child: Semantics(
                label: l10n.sceneListA11yLabel,
                child: PageView.builder(
                  controller: _pageController,
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
                            child: Material(
                              type: MaterialType.transparency,
                              child: SceneCard(scene: scenes[index]),
                            ),
                          );
                    final Widget card = TiltContainer(
                      deviceTilt: _deviceTilt,
                      onTap: isAddSlot
                          ? () => CreateSceneSheet.show(context: context)
                          : () => _handleSceneTap(scenes[index].id),
                      child: inner,
                    );

                    return AnimatedBuilder(
                      animation: _pageController,
                      builder: (context, child) {
                        double signed;
                        if (_pageController.hasClients &&
                            _pageController.position.haveDimensions) {
                          final page = _pageController.page ??
                              _pageController.initialPage.toDouble();
                          signed = page - index;
                        } else {
                          signed = (_pageController.initialPage - index)
                              .toDouble();
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

          // Layer 5 — 포커스된 Scene의 메타 텍스트. Hero source.
          if (!isEmpty)
            Positioned(
              bottom: padding.bottom + 256,
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
                            child: Material(
                              type: MaterialType.transparency,
                              child: FocusedSceneInfo(scene: displayedScene),
                            ),
                          ),
                  ),
                ),
              ),
            ),

          // Layer 6 — Arc dial.
          if (!isEmpty)
            Positioned(
              bottom: padding.bottom + 84,
              left: 0,
              right: 0,
              child: ArcDial(
                pageController: _pageController,
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
}

