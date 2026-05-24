import 'package:flutter/material.dart';

import '../../../core/theme/app_colors_ext.dart';
import '../../../core/theme/app_typography.dart';
import '../../home/widgets/scene_title_fallback.dart';

/// 파트너의 리액션을 read-only로 보여주는 시트.
///
/// 큰 아바타(우상단 emoji 뱃지) + 이름 + 코멘트(있으면). 본인 picker와 달리
/// 편집 버튼 없음. 그냥 보여주고 닫기.
class ReactionDisplaySheet extends StatelessWidget {
  const ReactionDisplaySheet({
    super.key,
    required this.avatarUrl,
    required this.name,
    required this.emoji,
    this.comment,
  });

  final String? avatarUrl;
  final String name;
  final String emoji;
  final String? comment;

  static const double _avatarSize = 64;
  // 인라인 뱃지(16:9 비율) 그대로 확대 — breathing room 유지.
  static const double _badgeSize = 32;
  static const double _emojiSize = 18;

  @override
  Widget build(BuildContext context) {
    final fallback = SceneTitleFallback(title: name);
    final hasComment = comment != null && comment!.isNotEmpty;

    // 시트가 콘텐츠 폭에 맞춰 좁아지지 않게 width 명시 — FloatingBottomSheet
    // 안의 Column이 children intrinsic width를 따르기 때문.
    // 상단 마진 8px — 다른 시트들(AddMediaSheet, ReactionPickerSheet 등)이
    // grab handle 아래 8px 두는 패턴과 일관.
    return SizedBox(
      width: double.infinity,
      child: Padding(
        padding: const EdgeInsets.only(
          left: 24,
          right: 24,
          top: 8,
          bottom: 24,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // 큰 아바타 + 우상단 emoji 뱃지. 인라인 _ReactionAvatarBadge와 동일
            // 패턴이지만 디스플레이용 크기로 확대.
            SizedBox(
              width: _avatarSize + 4,
              height: _avatarSize + 4,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Positioned(
                    left: 0,
                    top: 4,
                    child: Container(
                      width: _avatarSize,
                      height: _avatarSize,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: context.colors.nonClickableArea,
                      ),
                      child: ClipOval(
                        child: (avatarUrl != null && avatarUrl!.isNotEmpty)
                            ? Image.network(
                                avatarUrl!,
                                width: _avatarSize,
                                height: _avatarSize,
                                fit: BoxFit.cover,
                                gaplessPlayback: true,
                                errorBuilder: (_, _, _) => fallback,
                              )
                            : fallback,
                      ),
                    ),
                  ),
                  Positioned(
                    right: 0,
                    top: 0,
                    child: Container(
                      width: _badgeSize,
                      height: _badgeSize,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: context.colors.clickableArea,
                        border: Border.all(
                          color: context.colors.foreground.withValues(
                            alpha: 0.1,
                          ),
                          width: 0.5,
                        ),
                      ),
                      // 인라인과 동일한 baseline-shift 보정 (Center +
                      // Transform). emoji가 fontSize 18px이라 nudge도 비례하게
                      // 더 큼.
                      child: Center(
                        child: Transform.translate(
                          offset: const Offset(1, -1),
                          child: Text(
                            emoji,
                            style: const TextStyle(
                              fontSize: _emojiSize,
                              height: 1.0,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            Text(
              name,
              style: AppTypography.body(
                15,
                weight: FontWeight.w600,
              ).copyWith(color: context.colors.foreground),
            ),
            if (hasComment) ...[
              const SizedBox(height: 12),
              Text(
                comment!,
                textAlign: TextAlign.center,
                style: AppTypography.body(
                  14,
                ).copyWith(color: context.colors.foregroundMuted, height: 1.5),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
