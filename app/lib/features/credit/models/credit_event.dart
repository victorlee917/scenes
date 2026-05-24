import 'package:flutter/foundation.dart';

/// Credit 피드 한 항목의 종류. `get_pair_activity_page` RPC의 `kind` 컬럼과
/// 매핑된다.
enum CreditEventKind { sceneAdded, momentAdded, reactionAdded }

/// 페어 활동 피드의 한 row — Credits 화면에 그릴 정보 한 묶음.
///
/// 이미지(scene cover / moment 콘텐츠)는 storage path와 payload를 그대로 보관
/// 하고, 표시 시점에 [SignedUrlCache]로 sign해 URL을 얻는다. 시간은 UTC
/// `created_at`을 그대로 보관해 로컬 포맷은 view에서 처리.
@immutable
class CreditEvent {
  const CreditEvent({
    required this.kind,
    required this.actorId,
    required this.createdAt,
    required this.minCreatedAt,
    required this.sceneId,
    required this.sceneTitle,
    required this.sceneNumber,
    required this.sceneCoverStoragePath,
    required this.batchCount,
    this.contentId,
    this.contentType,
    this.contentPayload,
    this.reactionEmoji,
  });

  final CreditEventKind kind;
  final String actorId;

  /// 그룹의 head 시각(가장 최신 raw event). 표시·정렬에 사용.
  final DateTime createdAt;

  /// 그룹의 tail 시각(가장 오래된 raw event). pagination cursor용 —
  /// 다음 페이지를 fetch할 때 이 값보다 오래된 그룹들만 받음으로써 그룹
  /// 경계를 깔끔히 넘어간다.
  final DateTime minCreatedAt;

  /// 같은 actor·scene·type의 content_added를 시간 desc 정렬에서 연속으로
  /// 합친 개수. 단일 이벤트는 1. server가 결정.
  final int batchCount;

  /// 활동이 일어난 scene — 탭 시 detail로 이동할 때 사용.
  final String sceneId;
  final String sceneTitle;
  final int sceneNumber;
  final String? sceneCoverStoragePath;

  /// 콘텐츠/리액션 이벤트에서만 채워짐. scene_added는 null.
  final String? contentId;

  /// 'photo' | 'film' | 'music' | 'place'.
  final String? contentType;

  /// 콘텐츠의 payload(storage_path/thumb_path/width/height/album_art_url 등).
  /// 이미지 URL과 aspect 결정에 사용.
  final Map<String, dynamic>? contentPayload;

  /// reaction_added일 때만 채워짐.
  final String? reactionEmoji;

  factory CreditEvent.fromJson(Map<String, dynamic> json) {
    final kindStr = json['kind'] as String;
    final createdAt = DateTime.parse(json['created_at'] as String);
    // 옛 RPC(필드 부재) 호환 — 없으면 createdAt과 동일 취급(=단일 이벤트).
    final minStr = json['min_created_at'] as String?;
    return CreditEvent(
      kind: switch (kindStr) {
        'scene_added' => CreditEventKind.sceneAdded,
        'content_added' => CreditEventKind.momentAdded,
        'reaction_added' => CreditEventKind.reactionAdded,
        _ => throw StateError('Unknown credit kind: $kindStr'),
      },
      actorId: json['actor_id'] as String,
      createdAt: createdAt,
      minCreatedAt: minStr == null ? createdAt : DateTime.parse(minStr),
      sceneId: json['scene_id'] as String,
      sceneTitle: json['scene_title'] as String? ?? '',
      sceneNumber: (json['scene_number'] as num?)?.toInt() ?? 0,
      sceneCoverStoragePath: json['scene_cover_storage_path'] as String?,
      batchCount: (json['batch_count'] as num?)?.toInt() ?? 1,
      contentId: json['content_id'] as String?,
      contentType: json['content_type'] as String?,
      contentPayload: (json['content_payload'] is Map)
          ? Map<String, dynamic>.from(json['content_payload'] as Map)
          : null,
      reactionEmoji: json['reaction_emoji'] as String?,
    );
  }
}
