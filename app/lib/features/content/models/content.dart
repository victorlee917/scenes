import 'package:flutter/foundation.dart';

/// Scene 안에 들어가는 미디어 한 항목. `contents` 테이블 row 1:1.
///
/// `type`이 discriminator고, [payload]는 type마다 다른 스키마. photo의 경우
/// `external_media_caching_policy` 메모리 + `PhotoMetadata.toPayloadJson()`
/// 참고. 클라이언트는 변형(thumb/full)을 알기 위해 `storage_path`/`thumb_path`만
/// payload에서 직접 읽고, 나머지는 type별 파서가 해석한다.
@immutable
class Content {
  const Content({
    required this.id,
    required this.sceneId,
    required this.type,
    required this.position,
    required this.payload,
    required this.createdBy,
    required this.createdAt,
    this.occurredAt,
    this.fullSignedUrl,
    this.thumbSignedUrl,
  });

  final String id;
  final String sceneId;

  /// 'photo' | 'film' | 'music' | 'place'.
  final String type;

  final int position;

  /// type별 스키마. photo의 경우 storage_path/thumb_path/width/height/exif 등.
  final Map<String, dynamic> payload;

  /// `auth.users.id`. 본인만 update/delete 가능.
  final String? createdBy;

  final DateTime createdAt;

  /// 사진 촬영 시각 등 "콘텐츠 자체의 발생 시각". null 가능.
  final DateTime? occurredAt;

  /// scene_media full variant 1h signed URL. listing 시 함께 받아둠.
  final String? fullSignedUrl;

  /// scene_media thumb variant 1h signed URL.
  final String? thumbSignedUrl;

  /// payload에서 안전하게 storage_path 꺼내기. photo type 한정.
  String? get storagePath => payload['storage_path'] as String?;

  /// payload에서 thumb_path. photo type 한정.
  String? get thumbPath => payload['thumb_path'] as String?;

  Content copyWith({
    String? fullSignedUrl,
    String? thumbSignedUrl,
    DateTime? occurredAt,
  }) =>
      Content(
        id: id,
        sceneId: sceneId,
        type: type,
        position: position,
        payload: payload,
        createdBy: createdBy,
        createdAt: createdAt,
        occurredAt: occurredAt ?? this.occurredAt,
        fullSignedUrl: fullSignedUrl ?? this.fullSignedUrl,
        thumbSignedUrl: thumbSignedUrl ?? this.thumbSignedUrl,
      );

  factory Content.fromJson(Map<String, dynamic> json) {
    return Content(
      id: json['id'] as String,
      sceneId: json['scene_id'] as String,
      type: json['type'] as String,
      position: (json['position'] as num).toInt(),
      payload: Map<String, dynamic>.from(json['payload'] as Map),
      createdBy: json['created_by'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      occurredAt: json['occurred_at'] == null
          ? null
          : DateTime.parse(json['occurred_at'] as String),
    );
  }
}
