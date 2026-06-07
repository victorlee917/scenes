import 'package:flutter/material.dart';

import '../../../core/theme/app_colors_ext.dart';
import '../../../core/theme/app_typography.dart';
import '../formatters.dart';
import '../models/scene.dart';
import 'scene_title_fallback.dart';

/// Scene 리스트의 단일 행. 원형 썸네일(#번호 오버레이) + 제목 + 날짜.
///
/// 전체 Scene 목록([SceneListScreen])과 공유 관리 화면 등 여러 곳에서 동일한
/// 행 디자인을 공유하기 위해 공개 위젯으로 분리. reorder 모드(드래그 핸들)도
/// 지원한다.
class SceneRowTile extends StatelessWidget {
  const SceneRowTile({
    super.key,
    required this.scene,
    required this.onTap,
    this.onLongPress,
    this.showDragHandle = false,
    this.reorderIndex,
    this.horizontalPadding = 20,
    this.trailingLabel,
  });

  final Scene scene;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final bool showDragHandle;

  /// 행 우측에 표시할 짧은 라벨. 예: 공유 화면의 `{공유}/{전체}`. null이면
  /// 기본 개수 표시로 대체.
  final String? trailingLabel;
  // edit 모드 진입 시 ReorderableListView의 index. 좌측 영역은 long-press →
  // reorder, 우측 grip 핸들은 즉시 reorder로 분리해 vertical scroll이 가능.
  final int? reorderIndex;

  /// 행의 좌우 여백. 화면별 page margin에 맞춰 호출 측에서 조정.
  final double horizontalPadding;

  static const double _thumbSize = 56;

  @override
  Widget build(BuildContext context) {
    final locale = Localizations.localeOf(context);
    final localeTag = locale.toLanguageTag();
    // 날짜는 콘텐츠 있을 때만 노출.
    final dateLine = scene.media.total > 0
        ? formatSceneDateRange(scene.dates, localeTag)
        : '';

    final thumb = ClipOval(
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
            Container(color: Colors.black.withValues(alpha: 0.4)),
            Align(
              alignment: const Alignment(0, -0.12),
              child: Text(
                '#${scene.number}',
                style: AppTypography.display(16).copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1.0,
                  height: 1.0,
                  leadingDistribution: TextLeadingDistribution.even,
                ),
              ),
            ),
          ],
        ),
      ),
    );

    final titleColumn = Column(
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
    );

    if (reorderIndex != null) {
      // edit 모드: 좌측 영역(thumb+title)은 long-press로만 드래그 시작. 그래야
      // 좌측에서 손가락을 위/아래로 끌면 ReorderableListView가 vertical scroll
      // 한다. 우측 grip 아이콘은 즉시 드래그 — 빠른 reorder용.
      return Padding(
        padding:
            EdgeInsets.symmetric(horizontal: horizontalPadding, vertical: 10),
        child: Row(
          children: [
            Expanded(
              child: ReorderableDelayedDragStartListener(
                index: reorderIndex!,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  child: Row(
                    children: [
                      thumb,
                      const SizedBox(width: 14),
                      Expanded(child: titleColumn),
                    ],
                  ),
                ),
              ),
            ),
            ReorderableDragStartListener(
              index: reorderIndex!,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                child: SizedBox(
                  width: 56,
                  height: 56,
                  child: Center(
                    child: Icon(
                      Icons.drag_handle,
                      size: 20,
                      color: context.colors.foregroundMuted,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      onLongPress: onLongPress,
      child: Padding(
        padding:
            EdgeInsets.symmetric(horizontal: horizontalPadding, vertical: 10),
        child: Row(
          children: [
            thumb,
            const SizedBox(width: 14),
            Expanded(child: titleColumn),
            if (showDragHandle)
              Padding(
                padding: const EdgeInsets.only(left: 12),
                child: Icon(
                  Icons.drag_handle,
                  size: 20,
                  color: context.colors.foregroundMuted,
                ),
              )
            else if (trailingLabel != null)
              Padding(
                padding: const EdgeInsets.only(left: 12),
                child: Text(
                  trailingLabel!,
                  style: AppTypography.body(12).copyWith(
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
