import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors_ext.dart';
import '../../../core/theme/app_typography.dart';
import '../home_view_model.dart';
import 'profile_screen.dart';

/// 홈 상단 — 두 아바타 + since/D-Day 메타. 영역 전체가 tap target.
///
/// 크기는 반응형: 기본 avatarSize=32, 화면 폭 >= 420일 땐 38로 살짝 커짐.
class CoupleStrip extends ConsumerWidget {
  const CoupleStrip({super.key, required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final couple = ref.watch(homeViewModelProvider.select((s) => s.couple));
    final screenWidth = MediaQuery.sizeOf(context).width;
    final avatarSize = screenWidth >= 420 ? 38.0 : 32.0;
    final overlap = avatarSize * 0.35;

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 12),
      child: Center(
        child: GestureDetector(
          onTap: onTap,
          behavior: HitTestBehavior.opaque,
          child: SizedBox(
            width: avatarSize + (avatarSize - overlap),
            height: avatarSize,
            child: Stack(
              children: [
                Positioned(
                  left: 0,
                  child: Hero(
                    tag: ProfileScreen.partnerAHeroTag,
                    createRectTween: ProfileScreen.straightRectTween,
                    child: _Avatar(
                      url: couple.partnerAImageUrl,
                      name: couple.partnerAName,
                      size: avatarSize,
                    ),
                  ),
                ),
                Positioned(
                  left: avatarSize - overlap,
                  child: Hero(
                    tag: ProfileScreen.partnerBHeroTag,
                    createRectTween: ProfileScreen.straightRectTween,
                    child: _Avatar(
                      url: couple.partnerBImageUrl,
                      name: couple.partnerBName,
                      size: avatarSize,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.url, required this.name, required this.size});

  final String url;
  final String name;
  final double size;

  @override
  Widget build(BuildContext context) {
    final fallback = _initialFallback(context);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: context.colors.nonClickableArea,
        border: Border.all(color: context.colors.background, width: 2),
      ),
      child: ClipOval(
        child: url.isEmpty
            ? fallback
            : Image.network(
                url,
                width: size,
                height: size,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => fallback,
                frameBuilder: (context, child, frame, wasSync) {
                  if (wasSync || frame != null) return child;
                  return fallback;
                },
              ),
      ),
    );
  }

  Widget _initialFallback(BuildContext context) {
    final trimmed = name.trim();
    final initial = trimmed.isEmpty
        ? ''
        : String.fromCharCodes(trimmed.runes.take(1)).toUpperCase();
    // FittedBox로 100 reference를 visual scale — Hero flight 중 re-layout
    // 없이 매끄럽게 크기만 변함.
    return ColoredBox(
      color: context.colors.nonClickableArea,
      child: FittedBox(
        fit: BoxFit.contain,
        child: SizedBox(
          width: 100,
          height: 100,
          // 시각적 중심을 위해 글자를 살짝 위로.
          child: Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Center(
              child: Text(
                initial,
                textAlign: TextAlign.center,
                textHeightBehavior: const TextHeightBehavior(
                  applyHeightToFirstAscent: false,
                  applyHeightToLastDescent: false,
                ),
                style: AppTypography.display(42).copyWith(
                  color: context.colors.foregroundMuted,
                  fontWeight: FontWeight.w500,
                  height: 1.0,
                  decoration: TextDecoration.none,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
