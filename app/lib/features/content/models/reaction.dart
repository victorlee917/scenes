/// 한 사용자가 한 콘텐츠에 단 리액션. PK = (user_id, content_id) — 사용자당
/// 하나만 가능, 재선택 시 emoji/comment 갱신.
///
/// [comment]는 HD pair에서만 비어있지 않은 값을 저장 가능 (DB 트리거 enforce).
/// free pair는 emoji만.
class Reaction {
  const Reaction({
    required this.userId,
    required this.contentId,
    required this.emoji,
    this.comment,
    required this.createdAt,
    required this.updatedAt,
  });

  final String userId;
  final String contentId;
  final String emoji;
  final String? comment;
  final DateTime createdAt;
  final DateTime updatedAt;

  factory Reaction.fromJson(Map<String, dynamic> json) {
    return Reaction(
      userId: json['user_id'] as String,
      contentId: json['content_id'] as String,
      emoji: json['emoji'] as String,
      comment: json['comment'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }
}

/// 허용된 이모지 셋. DB CHECK 제약과 1:1 일치 — 값 추가 시 마이그레이션 동반.
class ReactionEmojis {
  ReactionEmojis._();

  static const List<String> all = ['❤️', '🥰', '😂', '😮', '🔥', '🥹'];

  /// 코멘트 최대 글자 수. DB CHECK 제약과 일치.
  static const int maxCommentLength = 200;
}
