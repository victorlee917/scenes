import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../../../core/theme/app_colors_ext.dart';
import '../../../core/widgets/floating_bottom_sheet.dart';
import '../../couple/couple_view_model.dart';
import '../../home/widgets/scene_title_fallback.dart';
import '../../profile/profile_view_model.dart';
import '../models/reaction.dart';
import '../reactions_view_model.dart';
import 'reaction_display_sheet.dart';

/// 콘텐츠 한 건의 리액션 슬롯. 좌측에 파트너 리액션(있을 때만, 탭 → display 시트),
/// 우측에 본인 리액션 또는 아직 안 했을 때 smiley face 아이콘(탭 → picker 시트).
/// content_viewer와 recap 양쪽에서 동일 톤으로 재사용.
class ReactionBar extends ConsumerWidget {
  const ReactionBar({
    super.key,
    required this.contentId,
    required this.sceneId,
    required this.onTapMyReaction,
  });

  final String contentId;
  final String sceneId;
  final VoidCallback onTapMyReaction;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final myProfile = ref.watch(myProfileProvider).valueOrNull;
    final partner = ref.watch(activeCoupleProvider).valueOrNull?.partner;
    final reactionsByContent =
        ref.watch(reactionsForSceneProvider(sceneId)).valueOrNull ?? const {};
    final reactions = reactionsByContent[contentId] ?? const <Reaction>[];

    Reaction? mine;
    Reaction? theirs;
    for (final r in reactions) {
      if (myProfile != null && r.userId == myProfile.id) {
        mine = r;
      } else if (partner != null && r.userId == partner.id) {
        theirs = r;
      }
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // 파트너 슬롯 — reacted일 때만 avatar+badge. 탭 → read-only 시트.
        if (theirs != null && partner != null) ...[
          GestureDetector(
            onTap: () {
              FloatingBottomSheet.show<void>(
                context: context,
                builder: (_) => ReactionDisplaySheet(
                  avatarUrl: partner.displayAvatarUrl,
                  name: partner.displayName,
                  emoji: theirs!.emoji,
                  comment: theirs.comment,
                ),
              );
            },
            behavior: HitTestBehavior.opaque,
            child: ReactionAvatarBadge(
              avatarUrl: partner.displayAvatarUrl,
              fallbackName: partner.displayName,
              emoji: theirs.emoji,
            ),
          ),
          const SizedBox(width: 12),
        ],
        // 본인 슬롯 — reacted면 내 avatar+badge, 아니면 추가 버튼.
        GestureDetector(
          onTap: onTapMyReaction,
          behavior: HitTestBehavior.opaque,
          child: (mine != null && myProfile != null)
              ? ReactionAvatarBadge(
                  avatarUrl: myProfile.displayAvatarUrl,
                  fallbackName: myProfile.displayName,
                  emoji: mine.emoji,
                )
              : SizedBox(
                  width: 28,
                  height: 28,
                  child: Center(
                    child: FaIcon(
                      FontAwesomeIcons.faceSmile,
                      size: 20,
                      color: context.colors.foregroundMuted,
                    ),
                  ),
                ),
        ),
      ],
    );
  }
}

/// 원형 아바타 + 우상단 emoji 뱃지 오버레이. 단일 레이어 뱃지 톤. 기본
/// 28x28(content viewer ReactionBar 기준). 그리드 등 다른 위치에선 size
/// 파라미터로 축소해 사용.
class ReactionAvatarBadge extends StatelessWidget {
  const ReactionAvatarBadge({
    super.key,
    required this.avatarUrl,
    required this.fallbackName,
    required this.emoji,
    this.avatarSize = 28,
    this.badgeSize = 16,
    this.emojiSize = 9,
    this.emojiOffset = const Offset(0.8, -0.8),
  });

  final String? avatarUrl;
  final String fallbackName;
  final String emoji;

  /// 아바타 원형 지름. 기본 28.
  final double avatarSize;

  /// 우상단 emoji 뱃지의 원형 지름. 기본 16.
  final double badgeSize;

  /// 뱃지 안 emoji 폰트 크기. 기본 9.
  final double emojiSize;

  /// emoji baseline-shift 보정용 추가 오프셋. iOS Apple Color Emoji가
  /// 메트릭상 정중앙 아닌 살짝 위/오른쪽이라 사이즈마다 미세 보정 필요.
  /// 기본값(0.8, -0.8)은 emojiSize=9 기준. 다른 사이즈에선 호출자가
  /// 별도 calibrate 권장.
  final Offset emojiOffset;

  @override
  Widget build(BuildContext context) {
    final fallback = SceneTitleFallback(title: fallbackName);
    // bounding box를 정확히 아바타 크기(28)로 잡아 부모 Row가 아바타를 기준
    // 으로 vertical center할 수 있게. emoji 뱃지는 Stack의 clipBehavior:none
    // 으로 아바타 영역 밖 우상단으로 overflow.
    return SizedBox(
      width: avatarSize,
      height: avatarSize,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: avatarSize,
            height: avatarSize,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: context.colors.nonClickableArea,
            ),
            child: ClipOval(
              child: (avatarUrl != null && avatarUrl!.isNotEmpty)
                  ? Image.network(
                      avatarUrl!,
                      width: avatarSize,
                      height: avatarSize,
                      fit: BoxFit.cover,
                      gaplessPlayback: true,
                      errorBuilder: (_, _, _) => fallback,
                    )
                  : fallback,
            ),
          ),
          // emoji 뱃지 — 아바타 영역 밖 우상단으로 살짝 튀어나옴 (Stack overflow).
          // Center + Transform.translate로 iOS Apple Color Emoji 폰트의
          // baseline-shift 보정 (메트릭상 중앙 아니라 살짝 위/오른쪽).
          Positioned(
            right: -2,
            top: -4,
            child: Container(
              width: badgeSize,
              height: badgeSize,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: context.colors.clickableArea,
                border: Border.all(
                  color: context.colors.foreground.withValues(alpha: 0.1),
                  width: 0.5,
                ),
              ),
              child: Center(
                child: Transform.translate(
                  offset: emojiOffset,
                  child: Text(
                    emoji,
                    style: TextStyle(fontSize: emojiSize, height: 1.0),
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
