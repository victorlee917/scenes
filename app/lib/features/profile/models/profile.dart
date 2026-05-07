/// `profiles` 테이블 row를 표현하는 모델.
///
/// `id`는 `auth.users.id`와 동일. 0021 trigger가 신규 user 생성 시 nickname/email
/// 로 row를 자동 만들지만 [onboardingCompletedAt]는 null로 남겨둠 — 사용자가
/// profile-setup 화면을 통과해야 채워짐. 라우터는 이 값으로 분기.
///
/// [deletedAt]은 0004 마이그레이션의 soft-delete 표시. 한 번 set되면 트리거가
/// active 커플을 'abandoned'로 자동 전환하고, 이후 immutable. 클라는 [displayName]
/// / [displayAvatarUrl] 게터로 마스킹 처리해 UI에서 "Deleted user" 같은 라벨로
/// 보여줌.
class Profile {
  const Profile({
    required this.id,
    required this.name,
    required this.avatarUrl,
    required this.locale,
    required this.onboardingCompletedAt,
    required this.createdAt,
    this.deletedAt,
    this.subscriptionTier,
    this.subscriptionStatus,
    this.subscriptionExpiresAt,
  });

  final String id;
  final String name;
  final String? avatarUrl;
  final String locale;
  final DateTime? onboardingCompletedAt;
  final DateTime createdAt;
  final DateTime? deletedAt;

  /// 'free' | 'scenes_hd' | null. 0019/0020 마이그레이션의 컬럼.
  final String? subscriptionTier;

  /// 'active' | 'expired' | null.
  final String? subscriptionStatus;

  final DateTime? subscriptionExpiresAt;

  bool get isOnboarded => onboardingCompletedAt != null;
  bool get isDeleted => deletedAt != null;

  /// App Store/Google Play 측 자동 갱신 구독이 살아있는지. 탈퇴 confirm
  /// 다이얼로그 분기에 사용 — true면 사용자에게 시스템 설정에서 따로
  /// 취소해야 함을 안내.
  bool get hasActiveSubscription =>
      subscriptionStatus == 'active' &&
      subscriptionTier != null &&
      subscriptionTier != 'free' &&
      (subscriptionExpiresAt == null ||
          subscriptionExpiresAt!.isAfter(DateTime.now()));

  /// 사용자 표시용 이름. 탈퇴된 프로필은 라벨로 마스킹.
  String get displayName => isDeleted ? 'Deleted user' : name;

  /// 표시용 아바타 URL. 탈퇴된 프로필은 null로 — 위젯이 fallback(이니셜 등) 표시.
  String? get displayAvatarUrl => isDeleted ? null : avatarUrl;

  Profile copyWith({
    String? name,
    String? avatarUrl,
    String? locale,
    DateTime? onboardingCompletedAt,
    DateTime? deletedAt,
  }) {
    return Profile(
      id: id,
      name: name ?? this.name,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      locale: locale ?? this.locale,
      onboardingCompletedAt:
          onboardingCompletedAt ?? this.onboardingCompletedAt,
      createdAt: createdAt,
      deletedAt: deletedAt ?? this.deletedAt,
    );
  }

  factory Profile.fromJson(Map<String, dynamic> json) {
    return Profile(
      id: json['id'] as String,
      name: json['name'] as String,
      avatarUrl: json['avatar_url'] as String?,
      locale: json['locale'] as String,
      onboardingCompletedAt: json['onboarding_completed_at'] == null
          ? null
          : DateTime.parse(json['onboarding_completed_at'] as String),
      createdAt: DateTime.parse(json['created_at'] as String),
      deletedAt: json['deleted_at'] == null
          ? null
          : DateTime.parse(json['deleted_at'] as String),
      subscriptionTier: json['subscription_tier'] as String?,
      subscriptionStatus: json['subscription_status'] as String?,
      subscriptionExpiresAt: json['subscription_expires_at'] == null
          ? null
          : DateTime.parse(json['subscription_expires_at'] as String),
    );
  }
}
