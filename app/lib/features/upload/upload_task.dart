import 'package:flutter/foundation.dart';

/// 업로드 매체 종류 — chip 라벨/아이콘 분기, 그리고 enqueue 메서드 구분.
enum UploadKind { photo, film, music, place }

/// 업로드 task 상태머신.
/// active → done(autodismiss) | failed(persists until dismissed) | cancelling → done.
enum UploadStatus { active, cancelling, done, failed }

/// 백그라운드 업로드 큐의 한 항목. ContentRepository 호출 1회 또는 N회를 묶음.
/// 표시 책임은 [UploadProgressChip], 실행 책임은 [UploadQueueNotifier].
@immutable
class UploadTask {
  const UploadTask({
    required this.id,
    required this.sceneId,
    required this.sceneTitle,
    required this.kind,
    required this.totalCount,
    required this.completedCount,
    required this.status,
    this.errorMessage,
  });

  final String id;
  final String sceneId;

  /// chip 라벨에 노출 후보(현재는 미사용 — 추후 "Scene X에 업로드 중" 같은
  /// 표현으로 확장 시 사용). totalCount와 함께 보존만 해둠.
  final String sceneTitle;

  final UploadKind kind;
  final int totalCount;
  final int completedCount;
  final UploadStatus status;
  final String? errorMessage;

  UploadTask copyWith({
    int? totalCount,
    int? completedCount,
    UploadStatus? status,
    String? errorMessage,
  }) =>
      UploadTask(
        id: id,
        sceneId: sceneId,
        sceneTitle: sceneTitle,
        kind: kind,
        totalCount: totalCount ?? this.totalCount,
        completedCount: completedCount ?? this.completedCount,
        status: status ?? this.status,
        errorMessage: errorMessage ?? this.errorMessage,
      );
}
