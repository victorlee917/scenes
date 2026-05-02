import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../../../core/theme/app_colors_ext.dart';
import '../../../core/theme/app_radii.dart';
import '../../../core/theme/app_typography.dart';
import '../home_view_model.dart';
import '../models/scene.dart';
import 'detail_app_bar.dart';

/// Playback 시트의 "Select Moments" 버튼이 띄우는 풀스크린 모달.
///
/// 아래에서 위로 슬라이드해 등장. 모든 scene의 콘텐츠(=moment)를 3열
/// 2:3 그리드로 보여주고, 사용자가 토글해서 재생할 항목을 고른다.
class MomentSelectionScreen extends ConsumerStatefulWidget {
  const MomentSelectionScreen({
    super.key,
    this.initiallySelected = const <String>{},
  });

  final Set<String> initiallySelected;

  static Route<Set<String>> route({
    Set<String> initiallySelected = const <String>{},
  }) {
    return PageRouteBuilder<Set<String>>(
      opaque: false,
      transitionDuration: const Duration(milliseconds: 300),
      reverseTransitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (context, animation, secondaryAnimation) =>
          MomentSelectionScreen(initiallySelected: initiallySelected),
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

  @override
  void initState() {
    super.initState();
    if (widget.initiallySelected.isNotEmpty) {
      // 호출부가 명시적으로 선택 집합을 넘겼으면 그대로 유지.
      _selected = Set<String>.from(widget.initiallySelected);
    } else {
      // 빈 집합 = "전체 재생"이라는 시트 측 의미를 그대로 옮겨와,
      // 첫 진입 시 모든 moment가 선택된 상태로 보인다.
      final scenes = ref.read(homeViewModelProvider).scenes;
      _selected = _buildMoments(scenes).map((m) => m.id).toSet();
    }
  }

  void _close() {
    Navigator.of(context).pop();
  }

  void _apply() {
    Navigator.of(context).pop(_selected);
  }

  void _toggle(String id) {
    setState(() {
      if (_selected.contains(id)) {
        _selected.remove(id);
      } else {
        _selected.add(id);
      }
    });
  }

  /// scene의 콘텐츠 개수만큼 mock moment 항목을 생성. 실제 데이터 연결
  /// 시 contents 테이블의 row id로 대체된다.
  List<_MomentItem> _buildMoments(List<Scene> scenes) {
    final items = <_MomentItem>[];
    for (var s = 0; s < scenes.length; s++) {
      final scene = scenes[s];
      for (var c = 0; c < scene.media.total; c++) {
        items.add(_MomentItem(
          id: '${scene.id}_$c',
          imageUrl: 'https://picsum.photos/seed/moment-$s-$c/400/600',
        ));
      }
    }
    return items;
  }

  @override
  Widget build(BuildContext context) {
    final padding = MediaQuery.paddingOf(context);
    final scenes = ref.watch(homeViewModelProvider.select((s) => s.scenes));
    final moments = _buildMoments(scenes);

    return Scaffold(
      backgroundColor: context.colors.background,
      body: Stack(
        children: [
          // 그리드는 풀스크린, 상단은 앱바 높이만큼 패딩.
          Positioned.fill(
            child: moments.isEmpty
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
                      padding.bottom + 24,
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
                      final selected = _selected.contains(m.id);
                      return _MomentTile(
                        imageUrl: m.imageUrl,
                        selected: selected,
                        onTap: () => _toggle(m.id),
                      );
                    },
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
                onTap: _apply,
                // Padding만으로 intrinsic 너비 + barHeight 높이를 만들어
                // 부모의 Align(centerRight)이 자연스럽게 우측 정렬되도록.
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
        ],
      ),
    );
  }
}

class _MomentItem {
  const _MomentItem({required this.id, required this.imageUrl});
  final String id;
  final String imageUrl;
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
