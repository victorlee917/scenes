import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../../../core/theme/app_colors_ext.dart';
import '../../../core/theme/app_radii.dart';
import '../../../core/theme/app_typography.dart';
import '../../content/contents_view_model.dart';
import '../home_view_model.dart';
import 'detail_app_bar.dart';

/// Playback 시트의 "Select Moments" 버튼이 띄우는 풀스크린 모달.
///
/// 아래에서 위로 슬라이드해 등장. scope에 들어간 scene들의 콘텐츠(=moment)를
/// 실제 DB에서 읽어 3열 2:3 그리드로 보여주고, 사용자가 토글해서 재생할
/// 항목을 고른다. id는 contents.id, 썸네일은 thumb_signed_url.
class MomentSelectionScreen extends ConsumerStatefulWidget {
  const MomentSelectionScreen({
    super.key,
    this.initiallySelected = const <String>{},
    this.sceneIdFilter,
    this.selectAllWhenEmpty = true,
  });

  final Set<String> initiallySelected;

  /// 표시할 scene을 제한. null이면 모든 scene의 콘텐츠를 보여주고,
  /// 값이 있으면 해당 scene id에 속한 콘텐츠만 그리드에 노출.
  final Set<String>? sceneIdFilter;

  /// initiallySelected가 비었을 때 동작. 재생 선택은 true(빈=전체 재생 의도라
  /// 모두 선택으로 보임), 공유 대상 선택은 false(빈=아무것도 공유 안 함).
  final bool selectAllWhenEmpty;

  static Route<Set<String>> route({
    Set<String> initiallySelected = const <String>{},
    Set<String>? sceneIdFilter,
    bool selectAllWhenEmpty = true,
  }) {
    return PageRouteBuilder<Set<String>>(
      opaque: false,
      transitionDuration: const Duration(milliseconds: 300),
      reverseTransitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (context, animation, secondaryAnimation) =>
          MomentSelectionScreen(
        initiallySelected: initiallySelected,
        sceneIdFilter: sceneIdFilter,
        selectAllWhenEmpty: selectAllWhenEmpty,
      ),
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        final curved = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOut,
        );
        return SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 1),
            end: Offset.zero,
          ).animate(curved),
          child: child,
        );
      },
    );
  }

  @override
  ConsumerState<MomentSelectionScreen> createState() =>
      _MomentSelectionScreenState();
}

class _MomentSelectionScreenState
    extends ConsumerState<MomentSelectionScreen> {
  late Set<String> _selected;
  // initiallySelected가 비어 있으면 "전체 재생" 의도. 첫 토글 전까진 모든
  // moment가 선택된 상태로 보이도록 _autoSelectAll로 표현.
  late bool _autoSelectAll;
  // 사용자가 한 번이라도 토글했는지. true가 되면 _selected가 source of truth.
  bool _seeded = false;

  @override
  void initState() {
    super.initState();
    _selected = Set<String>.from(widget.initiallySelected);
    _autoSelectAll =
        widget.selectAllWhenEmpty && widget.initiallySelected.isEmpty;
  }

  void _close() => Navigator.of(context).pop();

  void _apply() => Navigator.of(context).pop(_selected);

  void _toggle(String id, List<_MomentItem> moments) {
    setState(() {
      if (_autoSelectAll && !_seeded) {
        // 첫 토글: 시각상 "전체 선택"이었으므로 _selected를 그대로 흡수.
        _selected = moments.map((m) => m.id).toSet();
        _seeded = true;
        _autoSelectAll = false;
      }
      if (_selected.contains(id)) {
        _selected.remove(id);
      } else {
        _selected.add(id);
      }
    });
  }

  bool _isTileSelected(String id) {
    if (_autoSelectAll && !_seeded) return true;
    return _selected.contains(id);
  }

  bool _isAllSelected(List<_MomentItem> moments) {
    if (_autoSelectAll && !_seeded) return true;
    return moments.isNotEmpty && moments.every((m) => _selected.contains(m.id));
  }

  void _toggleSelectAll(List<_MomentItem> moments) {
    final selectAll = !_isAllSelected(moments);
    setState(() {
      _seeded = true;
      _autoSelectAll = false;
      _selected = selectAll ? moments.map((m) => m.id).toSet() : <String>{};
    });
  }

  /// scope 안의 scene들에 대해 contentsForSceneProvider를 watch해 실제 DB
  /// row를 모은 결과. 한 scene이라도 loading이면 anyLoading=true.
  ({List<_MomentItem> items, bool loading}) _loadMoments() {
    final scenes = ref.watch(homeViewModelProvider.select((s) => s.scenes));
    final filter = widget.sceneIdFilter;
    final inScope = filter == null
        ? scenes
        : scenes.where((s) => filter.contains(s.id)).toList();

    final items = <_MomentItem>[];
    bool anyLoading = false;
    for (final scene in inScope) {
      final asyncRes = ref.watch(contentsForSceneProvider(scene.id));
      asyncRes.when(
        data: (list) {
          for (final c in list) {
            // 썸네일 우선, 없으면 full URL fallback. 둘 다 없으면 스킵.
            final url = c.thumbSignedUrl ?? c.fullSignedUrl;
            if (url == null || url.isEmpty) continue;
            items.add(_MomentItem(
              id: c.id,
              imageUrl: url,
              type: c.type,
            ));
          }
        },
        loading: () => anyLoading = true,
        error: (_, _) {
          // 한 scene 실패는 그 scene만 누락 — 전체 화면은 계속 진행.
        },
      );
    }
    return (items: items, loading: anyLoading);
  }

  @override
  Widget build(BuildContext context) {
    final padding = MediaQuery.paddingOf(context);
    final result = _loadMoments();
    final moments = result.items;
    final isLoading = result.loading && moments.isEmpty;
    // Done 활성화 조건 — 선택된 moment가 1개 이상이면 enable.
    // _autoSelectAll && !_seeded 상태는 시각상 모두 선택이라 enable로 간주.
    final hasSelection = (_autoSelectAll && !_seeded)
        ? moments.isNotEmpty
        : _selected.isNotEmpty;
    // 공유 대상 선택(selectAllWhenEmpty=false)은 "아무것도 공유 안 함"도 유효한
    // 결과이므로 빈 선택이어도 Done 가능. 재생 선택은 1개 이상 필요.
    final canDone = widget.selectAllWhenEmpty ? hasSelection : true;

    return Scaffold(
      backgroundColor: context.colors.background,
      body: Stack(
        children: [
          // 그리드는 풀스크린, 상단은 앱바 높이만큼 패딩. 하단은 플로팅
          // Select all pill에 가리지 않도록 여유 패딩.
          Positioned.fill(
            child: isLoading
                ? Padding(
                    padding: EdgeInsets.only(
                      top: padding.top + DetailAppBar.barHeight + 16,
                    ),
                    child: Center(
                      child: CircularProgressIndicator(
                        color: context.colors.foreground,
                        strokeWidth: 1.5,
                      ),
                    ),
                  )
                : moments.isEmpty
                    ? Padding(
                        padding: EdgeInsets.only(
                          top: padding.top + DetailAppBar.barHeight + 16,
                        ),
                        child: Center(
                          child: Text(
                            'No moments yet.',
                            style: AppTypography.body(13).copyWith(
                              color: context.colors.foregroundMuted,
                            ),
                          ),
                        ),
                      )
                    : GridView.builder(
                        padding: EdgeInsets.fromLTRB(
                          16,
                          padding.top + DetailAppBar.barHeight + 16,
                          16,
                          padding.bottom + 80,
                        ),
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 3,
                          crossAxisSpacing: 8,
                          mainAxisSpacing: 8,
                          childAspectRatio: 2 / 3,
                        ),
                        itemCount: moments.length,
                        itemBuilder: (context, index) {
                          final m = moments[index];
                          return _MomentTile(
                            imageUrl: m.imageUrl,
                            selected: _isTileSelected(m.id),
                            onTap: () => _toggle(m.id, moments),
                          );
                        },
                      ),
          ),
          // 하단 중앙 플로팅 Select all/Deselect all pill (앨범 선택 버튼과 동일
          // 한 glass 스타일).
          if (!isLoading && moments.isNotEmpty)
            Positioned(
              bottom: padding.bottom + 16,
              left: 0,
              right: 0,
              child: Center(
                child: _FloatingSelectAll(
                  allSelected: _isAllSelected(moments),
                  onToggle: () => _toggleSelectAll(moments),
                ),
              ),
            ),
          // 상단 그라데이션 + 앱바 (콘텐츠가 그 아래로 비치며 fade out).
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: DetailAppBar(
              topInset: padding.top,
              title: 'Select Moments',
              titleOpacity: 1,
              onClose: _close,
              borderOpacity: 0,
              trailing: GestureDetector(
                behavior: HitTestBehavior.opaque,
                // 확정 불가 상태면 onTap=null로 비활성. AnimatedOpacity로 dim
                // 처리해 시각적으로 비활성을 알림.
                onTap: canDone ? _apply : null,
                child: AnimatedOpacity(
                  opacity: canDone ? 1.0 : 0.4,
                  duration: const Duration(milliseconds: 200),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(8, 14, 8, 14),
                    child: Text(
                      'Done',
                      style: AppTypography.body(15, weight: FontWeight.w600)
                          .copyWith(color: context.colors.foreground),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 하단 중앙에 떠 있는 전체 선택/해제 토글 pill. add photo 화면의 앨범 선택
/// 버튼과 동일한 glass 스타일(blur + clickableArea 틴트 + xl radius).
class _FloatingSelectAll extends StatelessWidget {
  const _FloatingSelectAll({required this.allSelected, required this.onToggle});

  final bool allSelected;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onToggle,
      child: ClipRRect(
        borderRadius: AppRadii.xlBorder,
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 28, sigmaY: 28),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
            decoration: BoxDecoration(
              color: context.colors.clickableArea.withValues(alpha: 0.82),
              borderRadius: AppRadii.xlBorder,
              border: Border.all(
                color: context.colors.foreground.withValues(alpha: 0.08),
                width: 0.5,
              ),
            ),
            child: Text(
              allSelected ? 'Deselect all' : 'Select all',
              style: AppTypography.body(14, weight: FontWeight.w500)
                  .copyWith(color: context.colors.foreground),
            ),
          ),
        ),
      ),
    );
  }
}

class _MomentItem {
  const _MomentItem({
    required this.id,
    required this.imageUrl,
    required this.type,
  });
  final String id;
  final String imageUrl;
  final String type;
}

class _MomentTile extends StatelessWidget {
  const _MomentTile({
    required this.imageUrl,
    required this.selected,
    required this.onTap,
  });

  final String imageUrl;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: AppRadii.smBorder,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.network(
              imageUrl,
              fit: BoxFit.cover,
              gaplessPlayback: true,
              errorBuilder: (_, _, _) => Container(
                color: context.colors.nonClickableArea,
              ),
            ),
            // 선택 안 된 항목은 살짝 어둡게.
            if (!selected)
              Positioned.fill(
                child: Container(
                  color: Colors.black.withValues(alpha: 0.35),
                ),
              ),
            // 체크 표시 (우상단).
            if (selected)
              Positioned(
                top: 6,
                right: 6,
                child: Container(
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: context.colors.foreground,
                  ),
                  child: Center(
                    child: FaIcon(
                      FontAwesomeIcons.check,
                      size: 11,
                      color: context.colors.background,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
