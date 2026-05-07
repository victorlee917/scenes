import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../../../core/theme/app_colors_ext.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/confirm_dialog.dart';
import '../../upload/upload_queue_view_model.dart';
import '../../upload/upload_task.dart';
import '../models/scene.dart';
import 'scene_title_fallback.dart';

/// Scene 한 장을 **필름 릴 캐니스터(원형 통)** 형태로 표시하는 카드.
///
/// - 외곽: `Container.shape = circle` + 얇은 metallic 림 + drop shadow
/// - 내부: `ClipOval`로 커버 이미지 원형 크롭
/// - 진행 중인 업로드 task가 이 scene에 있으면 dim + 진행/상태 오버레이를
///   캐니스터 안에 표시. 홈/scene detail에서 모두 동일하게 작동.
/// - **텍스트는 여기 없음** — #번호·타이틀·날짜는 [FocusedSceneInfo]가
///   캐니스터 아래 별도 영역에 표시한다.
class SceneCard extends ConsumerWidget {
  const SceneCard({
    super.key,
    required this.scene,
  });

  final Scene scene;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tasks = ref.watch(uploadQueueProvider);
    UploadTask? activeTask;
    for (final t in tasks) {
      if (t.sceneId == scene.id) {
        activeTask = t;
        break;
      }
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        // 지름: 슬롯의 짧은 변에서 16dp 여백 둠.
        // 가로 캐러셀에서는 슬롯 폭이 좁아지므로 여백도 작게.
        final diameter = math.min(
          constraints.maxWidth - 16,
          constraints.maxHeight - 16,
        );
        return Center(
          child: SizedBox.square(
            dimension: diameter,
            child: _FilmCanister(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  _CanisterImage(scene: scene),
                  if (activeTask != null)
                    _UploadOverlay(
                      task: activeTask,
                      onCancel: () =>
                          _confirmCancel(context, ref, activeTask!.id),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

/// 진행 중 photo 업로드 task에 cancel 요청. 공용 confirm 바텀시트로 한 번
/// 더 확인. 이미 commit된 사진은 유지되고 큐의 남은 잡만 버려진다는 카피.
Future<void> _confirmCancel(
  BuildContext context,
  WidgetRef ref,
  String taskId,
) async {
  final confirmed = await ConfirmDialog.show(
    context: context,
    title: 'Cancel upload?',
    message: 'Photos already uploaded will stay.',
    confirmLabel: 'Stop',
    cancelLabel: 'Keep uploading',
    isDestructive: true,
  );
  if (!confirmed) return;
  ref.read(uploadQueueProvider.notifier).cancel(taskId);
}

/// 원형 캐니스터 셸: 색·테두리·그림자만 담당. 내용은 자식으로 주입.
class _FilmCanister extends StatelessWidget {
  const _FilmCanister({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: context.colors.filmStock,
        border: Border.all(
          color: context.colors.hairline,
          width: 1,
        ),
        // shadow color는 full opacity, spread/blur가 자연스러운 gradient를 만듦.
        // alpha를 낮추면 가우시안 falloff 거리가 짧아져 끝나는 지점이 visible
        // boundary로 보이는 "층진" 인상이 됨.
        boxShadow: [
          BoxShadow(
            color: context.colors.shadow,
            blurRadius: 40,
            spreadRadius: -20,
            offset: const Offset(0, 24),
          ),
        ],
      ),
      child: ClipOval(child: child),
    );
  }
}

class _CanisterImage extends StatelessWidget {
  const _CanisterImage({required this.scene});

  final Scene scene;

  @override
  Widget build(BuildContext context) {
    final url = scene.coverImageUrl;
    final fallback = SceneTitleFallback(title: scene.title);

    // cover URL 없고 콘텐츠도 없으면 → 타이틀 첫 글자로 표시.
    // (cover는 있는데 fail로딩되는 경우는 errorBuilder에서 같은 fallback.)
    if (url.isEmpty) return fallback;

    return ColoredBox(
      color: context.colors.nonClickableArea,
      child: Image.network(
        url,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => fallback,
        // precache cache hit이면 wasSynchronouslyLoaded=true → 즉시 child.
        frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
          if (wasSynchronouslyLoaded || frame != null) return child;
          return ColoredBox(color: context.colors.nonClickableArea);
        },
      ),
    );
  }
}

/// 업로드 진행/상태 오버레이. ClipOval 안에 들어가 원형으로 자동 클립됨.
///
/// active/cancelling 상태에서는 spinner + counter는 캐니스터 정중앙에 두고,
/// Cancel 버튼은 그 아래(원의 70% 지점)에 분리 배치 — 위로 치우쳐 보이지
/// 않도록.
class _UploadOverlay extends StatelessWidget {
  const _UploadOverlay({
    required this.task,
    required this.onCancel,
  });

  final UploadTask task;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final isActive = task.status == UploadStatus.active;
    final isCancelling = task.status == UploadStatus.cancelling;
    final showCount = isActive &&
        task.kind == UploadKind.photo &&
        task.totalCount > 1;
    final showCancel = isActive && task.kind == UploadKind.photo;
    final current = (task.completedCount + 1).clamp(1, task.totalCount);

    Widget? centerContent;
    if (isActive || isCancelling) {
      centerContent = Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(
            width: 26,
            height: 26,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
            ),
          ),
          if (showCount) ...[
            const SizedBox(height: 10),
            Text(
              '$current / ${task.totalCount}',
              style: AppTypography.body(13, weight: FontWeight.w600)
                  .copyWith(color: Colors.white),
            ),
          ],
        ],
      );
    } else if (task.status == UploadStatus.done) {
      centerContent = const FaIcon(
        FontAwesomeIcons.check,
        color: Colors.white,
        size: 26,
      );
    } else if (task.status == UploadStatus.failed) {
      centerContent = const FaIcon(
        FontAwesomeIcons.circleExclamation,
        color: Color(0xFFE06C75),
        size: 26,
      );
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        ColoredBox(color: Colors.black.withValues(alpha: 0.5)),
        if (centerContent != null) Center(child: centerContent),
        if (showCancel)
          // 캐니스터 중심에서 약 70% 아래 — spinner와 분리되어 가독.
          Align(
            alignment: const Alignment(0, 0.55),
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onCancel,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 6,
                ),
                child: Text(
                  'Cancel',
                  style: AppTypography.body(13, weight: FontWeight.w600)
                      .copyWith(
                    color: Colors.white.withValues(alpha: 0.85),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
