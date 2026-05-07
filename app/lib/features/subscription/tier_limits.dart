/// Tier-별 콘텐츠 한도. 서버(`pair_has_active_hd` + 0022 마이그레이션 트리거)
/// 와 1:1 매칭. DB가 진짜 source of truth고, 클라는 pre-flight UX 용도.
class TierLimits {
  TierLimits._();

  /// 한 scene당 업로드 가능한 콘텐츠(photo+film+music+place) 총 개수.
  static const int freeContentsPerScene = 30;
  static const int hdContentsPerScene = 100;

  /// 현재 페어의 tier에 맞는 scene별 콘텐츠 한도.
  static int contentsPerScene({required bool isHd}) =>
      isHd ? hdContentsPerScene : freeContentsPerScene;
}
