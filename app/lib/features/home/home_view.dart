import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../l10n/app_localizations.dart';
import 'home_view_model.dart';
import 'widgets/add_scene_card.dart';
import 'widgets/couple_strip.dart';
import 'widgets/scene_card.dart';
import 'widgets/transport_controls.dart';

/// 홈 화면.
///
/// 레이아웃:
/// ```
/// Stack
///  ├── ListView (세로 자유 스크롤 + 멈추면 가장 가까운 카드에 snap)
///  ├── 상단 shadow gradient
///  ├── 하단 shadow gradient (비어있지 않을 때만)
///  ├── CoupleStrip (상단 floating)
///  └── TransportControls (하단 floating, 비어있지 않을 때만)
/// ```
///
/// - `ListView.builder` + 고정 `itemExtent`로 카드를 배치. `ScrollController`의
///   scroll offset을 fractional "page"로 환산해 각 카드의 3D flip 트랜스폼을
///   계산.
/// - 스크롤이 멈추면 (`ScrollEndNotification`) 가장 가까운 카드 중앙으로
///   애니메이션 snap.
/// - 첫·마지막 카드도 정중앙에 올 수 있도록 위·아래 padding을 viewport 기준
///   으로 계산해 넣는다.
/// - 카루셀 끝에는 항상 `AddSceneCard`가 한 장 더 붙고, 빈 상태면 Add만 단독.
class HomeView extends ConsumerStatefulWidget {
  const HomeView({super.key});

  @override
  ConsumerState<HomeView> createState() => _HomeViewState();
}

class _HomeViewState extends ConsumerState<HomeView> {
  /// Viewport 대비 한 카드가 차지하는 세로 비율. 작을수록 스택이 타이트해짐.
  static const double _itemExtentRatio = 0.42;

  static const double _minScale = 0.86;
  static const double _minOpacity = 0.6;

  /// Flip rotation 최댓값(rad). 0.6 ≈ 34°.
  static const double _maxFlipAngle = 0.6;

  /// 3D 투영 강도.
  static const double _perspective = 0.0016;

  /// Long-press scrub 감도. 값이 작을수록 한 번의 drag으로 더 많은 index 이동.
  static const double _scrubPixelsPerIndex = 6;

  late final ScrollController _scrollController;

  double _itemExtent = 0;
  double _topPadding = 0;
  int _currentItemCount = 1;
  int _lastFocusedIndex = 0;

  /// snap 애니메이션 중에는 ScrollEndNotification이 다시 들어와도 무시.
  bool _isSnapping = false;

  /// Long press 시작 시점의 인덱스. scrub offset 계산 기준.
  int _scrubStartIndex = 0;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  // ── helpers ─────────────────────────────────────────────────

  /// 현재 scroll offset을 fractional page 값으로 환산.
  /// page 0 = item 0 centered, page 1 = item 1 centered, ...
  double _currentPage() {
    if (!_scrollController.hasClients || _itemExtent == 0) return 0;
    return _scrollController.position.pixels / _itemExtent;
  }

  /// 특정 item이 viewport 중앙에서 얼마나 떨어져 있는지 (단위: items).
  /// 양수 = 위로 빠져나간 상태, 음수 = 아래에서 올라오는 중.
  double _signedDistance(int index) {
    return _currentPage() - index;
  }

  // ── scroll snapping ─────────────────────────────────────────

  bool _onScrollNotification(ScrollNotification notification) {
    if (notification is ScrollEndNotification && !_isSnapping) {
      _snapToNearest();
    }
    return false;
  }

  Future<void> _snapToNearest() async {
    if (!_scrollController.hasClients || _itemExtent == 0) return;
    final pixels = _scrollController.position.pixels;
    final nearestIndex = (pixels / _itemExtent)
        .round()
        .clamp(0, _currentItemCount - 1);
    final target = nearestIndex * _itemExtent;

    if ((pixels - target).abs() > 0.5) {
      _isSnapping = true;
      try {
        await _scrollController.animateTo(
          target,
          duration: const Duration(milliseconds: 280),
          curve: Curves.easeOutCubic,
        );
      } finally {
        _isSnapping = false;
      }
    }

    if (nearestIndex != _lastFocusedIndex) {
      _lastFocusedIndex = nearestIndex;
      HapticFeedback.selectionClick();
      ref.read(homeViewModelProvider.notifier).setPageIndex(nearestIndex);
    }
  }

  // ── long-press scrub ────────────────────────────────────────

  void _handleLongPressStart(LongPressStartDetails details) {
    _scrubStartIndex = _currentPage().round();
    HapticFeedback.mediumImpact();
  }

  void _handleLongPressMoveUpdate(LongPressMoveUpdateDetails details) {
    if (_currentItemCount <= 1 || _itemExtent == 0) return;
    final dy = details.offsetFromOrigin.dy;
    // 위로 drag(dy 음수) = 다음 씬(인덱스↑). 아래 drag = 이전 씬.
    final delta = (-dy / _scrubPixelsPerIndex).round();
    final target =
        (_scrubStartIndex + delta).clamp(0, _currentItemCount - 1);
    final targetPixels = target * _itemExtent;
    final current = _scrollController.position.pixels;
    if ((current - targetPixels).abs() > 0.5) {
      _scrollController.jumpTo(targetPixels);
      if (target != _lastFocusedIndex) {
        _lastFocusedIndex = target;
        HapticFeedback.selectionClick();
        ref.read(homeViewModelProvider.notifier).setPageIndex(target);
      }
    }
  }

  // ── tap handlers ────────────────────────────────────────────

  void _handleCoupleTap() {
    // Navigate to couple detail (pending design).
  }

  void _handleSceneTap(String sceneId) {
    // Navigate to scene detail (pending design).
  }

  void _handleSort() {
    // Navigate to Scene sort/list screen (pending design).
  }

  void _handleAdd() {
    // Navigate to Scene create flow (pending design).
  }

  void _handlePlay() {
    // Enter Rewind (dial-based playback) screen (pending design).
  }

  // ── build ───────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final scenes = ref.watch(homeViewModelProvider.select((s) => s.scenes));
    final l10n = AppLocalizations.of(context);
    final mq = MediaQuery.of(context);
    final padding = mq.padding;
    final isEmpty = scenes.isEmpty;

    _currentItemCount = isEmpty ? 1 : scenes.length + 1;
    _itemExtent = mq.size.height * _itemExtentRatio;
    // 첫·마지막 카드가 viewport 중앙에 오도록 위·아래 padding.
    _topPadding = (mq.size.height - _itemExtent) / 2;

    final topShadowHeight = padding.top + 140;
    final bottomShadowHeight = padding.bottom + 160;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          // Layer 1 — 세로 자유 스크롤 + snap
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.deferToChild,
              onLongPressStart: _handleLongPressStart,
              onLongPressMoveUpdate: _handleLongPressMoveUpdate,
              child: NotificationListener<ScrollNotification>(
                onNotification: _onScrollNotification,
                child: Semantics(
                  label: l10n.sceneListA11yLabel,
                  child: ListView.builder(
                    controller: _scrollController,
                    scrollDirection: Axis.vertical,
                    physics: const BouncingScrollPhysics(),
                    itemExtent: _itemExtent,
                    padding: EdgeInsets.only(
                      top: _topPadding,
                      bottom: _topPadding,
                    ),
                    clipBehavior: Clip.none,
                    itemCount: _currentItemCount,
                    itemBuilder: (context, index) {
                      final isAddSlot = index >= scenes.length;
                      final Widget card = isAddSlot
                          ? AddSceneCard(onTap: _handleAdd)
                          : SceneCard(
                              scene: scenes[index],
                              onTap: () =>
                                  _handleSceneTap(scenes[index].id),
                            );

                      return AnimatedBuilder(
                        animation: _scrollController,
                        builder: (context, child) {
                          final signed =
                              _signedDistance(index).clamp(-1.5, 1.5);
                          final t = signed.abs().clamp(0.0, 1.0);
                          final scale = 1.0 - (t * (1.0 - _minScale));
                          final opacity =
                              1.0 - (t * (1.0 - _minOpacity));
                          final angle =
                              signed.clamp(-1.0, 1.0) * _maxFlipAngle;

                          return Opacity(
                            opacity: opacity,
                            child: Transform(
                              alignment: Alignment.center,
                              transform: Matrix4.identity()
                                ..setEntry(3, 2, _perspective)
                                ..rotateX(angle)
                                ..scaleByDouble(scale, scale, 1.0, 1.0),
                              child: child,
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
          ),

          // Layer 2 — 상단 shadow
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: topShadowHeight,
            child: const IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      AppColors.background,
                      Color(0x00000000),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // Layer 3 — 하단 shadow (transport와 한 세트, 비어있을 땐 숨김)
          if (!isEmpty)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              height: bottomShadowHeight,
              child: const IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                      colors: [
                        AppColors.background,
                        Color(0x00000000),
                      ],
                    ),
                  ),
                ),
              ),
            ),

          // Layer 4 — 상단 couple strip (항상 표시)
          Positioned(
            top: padding.top,
            left: 0,
            right: 0,
            child: CoupleStrip(onTap: _handleCoupleTap),
          ),

          // Layer 5 — 하단 glass 버튼 (비어있지 않을 때만)
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
