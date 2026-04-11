import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../l10n/app_localizations.dart';
import '../home_view_model.dart';

/// 홈 상단 — 두 아바타 + since/D-Day 메타. 영역 전체가 tap target.
///
/// 크기는 반응형: 기본 avatarSize=32, 화면 폭 >= 420일 땐 38로 살짝 커짐.
class CoupleStrip extends ConsumerWidget {
  const CoupleStrip({super.key, required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final couple = ref.watch(homeViewModelProvider.select((s) => s.couple));
    final l10n = AppLocalizations.of(context);
    final screenWidth = MediaQuery.sizeOf(context).width;
    final avatarSize = screenWidth >= 420 ? 38.0 : 32.0;
    final overlap = avatarSize * 0.35;

    final sinceDate = DateFormat('yyyy.MM.dd').format(couple.sinceDate);
    final sinceText = l10n.coupleSince(sinceDate);
    final dDayText = l10n.coupleDDay(couple.dDayFrom(DateTime.now()));

    return InkWell(
      onTap: onTap,
      splashColor: Colors.transparent,
      highlightColor: AppColors.hairline,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 12),
        child: Row(
          children: [
            SizedBox(
              width: avatarSize + (avatarSize - overlap),
              height: avatarSize,
              child: Stack(
                children: [
                  Positioned(
                    left: 0,
                    child: _Avatar(
                      url: couple.partnerAImageUrl,
                      size: avatarSize,
                    ),
                  ),
                  Positioned(
                    left: avatarSize - overlap,
                    child: _Avatar(
                      url: couple.partnerBImageUrl,
                      size: avatarSize,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    sinceText,
                    style: AppTypography.body(12, italic: FontStyle.italic)
                        .copyWith(color: AppColors.foregroundMuted),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    dDayText,
                    style: AppTypography.body(12, italic: FontStyle.italic)
                        .copyWith(color: AppColors.foregroundMuted),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.url, required this.size});

  final String url;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppColors.surface,
        border: Border.all(color: AppColors.background, width: 2),
      ),
      child: ClipOval(
        child: Image.network(
          url,
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) =>
              const ColoredBox(color: AppColors.surface),
          loadingBuilder: (context, child, progress) => progress == null
              ? child
              : const ColoredBox(color: AppColors.surface),
        ),
      ),
    );
  }
}
