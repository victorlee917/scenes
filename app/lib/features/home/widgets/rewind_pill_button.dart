import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_colors_ext.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/floating_bottom_sheet.dart';
import '../../content/models/content.dart';
import '../../content/models/reaction.dart';
import '../../content/reactions_view_model.dart';
import '../../content/widgets/reaction_bar.dart';
import '../../content/widgets/reaction_display_sheet.dart';
import '../../couple/couple_view_model.dart';
import '../../profile/profile_view_model.dart';
import '../models/scene.dart';
import 'scene_title_fallback.dart';

/// Rewind 화면 하단 액션 바의 가운데 pill 버튼. 좌측부엔 scene 캐니스터 +
/// scene title / occurredAt, 우측부엔 (있을 때) 파트너 리액션 뱃지 + 내
/// 리액션 버튼. 좌측부 탭은 contents detail, 우측 두 영역은 각각 reaction
/// display sheet / picker sheet. GlassCircleButton과 같은 glass 톤.
class RewindPillButton extends ConsumerWidget {
  const RewindPillButton({
    super.key,
    required this.content,
    required this.scene,
    required this.height,
    required this.onTapInfo,
    required this.onTapMyReaction,
  });

  final Content content;
  final Scene scene;
  final double height;
  final VoidCallback onTapInfo;
  final VoidCallback onTapMyReaction;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final myProfile = ref.watch(myProfileProvider).valueOrNull;
    final partner = ref.watch(activeCoupleProvider).valueOrNull?.partner;
    final reactions = ref
            .watch(reactionsForSceneProvider(scene.id))
            .valueOrNull?[content.id] ??
        const <Reaction>[];

    Reaction? mine;
    Reaction? theirs;
    for (final r in reactions) {
      if (myProfile != null && r.userId == myProfile.id) mine = r;
      if (partner != null && r.userId == partner.id) theirs = r;
    }

    final occurredAt = content.occurredAt ?? content.createdAt;
    final locale = Localizations.localeOf(context).toLanguageTag();
    final dateStr = DateFormat.yMMMd(locale).format(occurredAt);

    final canisterSize = height - 12;
    final radius = height / 2;

    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 28, sigmaY: 28),
        child: Container(
          height: height,
          decoration: BoxDecoration(
            color: context.colors.foreground.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(radius),
            border: Border.all(
              color: context.colors.foreground.withValues(alpha: 0.10),
              width: 0.6,
            ),
          ),
          child: Row(
            children: [
              // 좌측부 — 캐니스터 + scene 이름 / occurredAt. 탭 = info.
              Expanded(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: onTapInfo,
                  child: Padding(
                    padding: const EdgeInsets.only(left: 6, right: 8),
                    child: Row(
                      children: [
                        SizedBox(
                          width: canisterSize,
                          height: canisterSize,
                          child: ClipOval(
                            child: scene.coverImageUrl.isNotEmpty
                                ? Image.network(
                                    scene.coverImageUrl,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, _, _) =>
                                        SceneTitleFallback(title: scene.title),
                                  )
                                : SceneTitleFallback(title: scene.title),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                scene.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: AppTypography.body(
                                  13,
                                  weight: FontWeight.w600,
                                ).copyWith(color: context.colors.foreground),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                dateStr,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: AppTypography.body(11).copyWith(
                                  color: context.colors.foregroundMuted,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              // 우측부 — 파트너 reaction (있을 때) + 내 reaction.
              if (theirs != null && partner != null)
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
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
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: ReactionAvatarBadge(
                      avatarUrl: partner.displayAvatarUrl,
                      fallbackName: partner.displayName,
                      emoji: theirs.emoji,
                    ),
                  ),
                ),
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: onTapMyReaction,
                child: Padding(
                  padding: const EdgeInsets.only(left: 4, right: 12),
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
              ),
            ],
          ),
        ),
      ),
    );
  }
}

