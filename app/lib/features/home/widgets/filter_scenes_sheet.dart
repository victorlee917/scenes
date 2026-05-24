import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../../../core/theme/app_colors_ext.dart';
import '../../../core/theme/app_radii.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/floating_bottom_sheet.dart';
import '../../../l10n/app_localizations.dart';
import '../models/scene.dart';
import 'scene_cover_image.dart';

/// Recap 화면 scene 필터 시트. 홈의 add_media_sheet `_ScenePickerDialog`와
/// 같은 톤 — 박스 카드 없이 단순한 row(캐니스터 + `#N Title`) + 우측 체크
/// 아이콘. 스크롤 영역 안에 scene list 전체가 들어가고, 하단 Apply 버튼으로
/// 변경 확정.
class FilterScenesSheet extends StatefulWidget {
  const FilterScenesSheet({
    super.key,
    required this.scenes,
    required this.initialSelected,
    required this.onApply,
  });

  final List<Scene> scenes;
  // null이면 전체. set이면 그 id만 포함.
  final Set<String>? initialSelected;
  final ValueChanged<Set<String>?> onApply;

  static Future<void> show({
    required BuildContext context,
    required List<Scene> scenes,
    required Set<String>? initialSelected,
    required ValueChanged<Set<String>?> onApply,
  }) {
    return FloatingBottomSheet.show(
      context: context,
      builder: (_) => FilterScenesSheet(
        scenes: scenes,
        initialSelected: initialSelected,
        onApply: onApply,
      ),
    );
  }

  @override
  State<FilterScenesSheet> createState() => _FilterScenesSheetState();
}

class _FilterScenesSheetState extends State<FilterScenesSheet> {
  late Set<String> _selected;
  bool get _isAll => _selected.length == widget.scenes.length;

  @override
  void initState() {
    super.initState();
    _selected = widget.initialSelected == null
        ? widget.scenes.map((s) => s.id).toSet()
        : Set<String>.of(widget.initialSelected!);
  }

  void _toggleAll() {
    setState(() {
      if (_isAll) {
        _selected.clear();
      } else {
        _selected = widget.scenes.map((s) => s.id).toSet();
      }
    });
  }

  void _toggleScene(String id) {
    setState(() {
      if (_selected.contains(id)) {
        _selected.remove(id);
      } else {
        _selected.add(id);
      }
    });
  }

  void _apply() {
    final isAll = _selected.length == widget.scenes.length;
    widget.onApply(isAll ? null : Set<String>.of(_selected));
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final l10n = AppLocalizations.of(context);
    // 시트가 화면 너무 많이 점유 안 하도록 scroll 영역 max 제한.
    final listMaxHeight = mq.size.height * 0.5;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(height: 8),
        Text(
          'Filter Scenes',
          style: AppTypography.display(20).copyWith(
            color: context.colors.foreground,
            fontWeight: FontWeight.w700,
          ),
        ),
        // 다른 시트(PlaySceneSheet 등)와 동일한 header → content 간격.
        const SizedBox(height: 24),
        // 스크롤 박스 — add_media_sheet의 _ScenePickerDialog 톤. 박스가
        // bg + border + radius를 가지고, 그 안에서 list가 스크롤.
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: ConstrainedBox(
            constraints: BoxConstraints(maxHeight: listMaxHeight),
            child: Container(
              decoration: BoxDecoration(
                color: context.colors.surface,
                borderRadius: AppRadii.sheetInnerBorder,
                border: Border.all(
                  color: context.colors.foreground.withValues(alpha: 0.06),
                  width: 0.5,
                ),
              ),
              child: ClipRRect(
                borderRadius: AppRadii.sheetInnerBorder,
                child: Material(
                  color: Colors.transparent,
                  child: ListView.builder(
                    shrinkWrap: true,
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    itemCount: widget.scenes.length + 1,
                    itemBuilder: (_, i) {
                      if (i == 0) {
                        return _PickerRow(
                          leading: _AllLeading(),
                          label: l10n.filterScenesAll,
                          selected: _isAll,
                          onTap: _toggleAll,
                        );
                      }
                      final scene = widget.scenes[i - 1];
                      return _PickerRow(
                        leading: ClipOval(
                          child: SizedBox(
                            width: 36,
                            height: 36,
                            child: SceneCoverImage(scene: scene),
                          ),
                        ),
                        label: '#${scene.number}  ${scene.title}',
                        selected: _selected.contains(scene.id),
                        onTap: () => _toggleScene(scene.id),
                      );
                    },
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: SizedBox(
            width: double.infinity,
            child: GestureDetector(
              onTap: _selected.isEmpty ? null : _apply,
              child: AnimatedOpacity(
                opacity: _selected.isEmpty ? 0.4 : 1.0,
                duration: const Duration(milliseconds: 200),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: BoxDecoration(
                    borderRadius: AppRadii.sheetInnerBorder,
                    color: context.colors.foreground,
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    l10n.actionApply,
                    style: AppTypography.body(
                      15,
                      weight: FontWeight.w600,
                    ).copyWith(color: context.colors.background),
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

/// add_media_sheet의 _ScenePickerDialog row와 동일 톤. 박스 카드 없이 단순
/// padding + leading + label + (선택 시) trailing check.
class _PickerRow extends StatelessWidget {
  const _PickerRow({
    required this.leading,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final Widget leading;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        child: Row(
          children: [
            leading,
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.body(14).copyWith(
                  color: selected
                      ? context.colors.foreground
                      : context.colors.foregroundMuted,
                ),
              ),
            ),
            if (selected)
              FaIcon(
                FontAwesomeIcons.check,
                size: 14,
                color: context.colors.foreground,
              ),
          ],
        ),
      ),
    );
  }
}

/// 'All scenes' row의 leading — 36×36 자리에 stacked layer icon. 캐니스터
/// 자리와 너비 동일하게 잡아 다른 row와 정렬.
class _AllLeading extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 36,
      height: 36,
      child: Center(
        child: FaIcon(
          FontAwesomeIcons.layerGroup,
          size: 18,
          color: context.colors.foregroundMuted,
        ),
      ),
    );
  }
}
