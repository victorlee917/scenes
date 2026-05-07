import 'package:flutter/material.dart';

import '../../../core/theme/app_colors_ext.dart';

/// thumb → full 점진 swap 이미지.
///
/// 두 장이 stack으로 깔리고, full이 첫 프레임 이후 cross-fade로 올라온다.
/// thumb은 이미 picker/grid 시점에 캐시될 가능성이 높아 즉시 출력 → 화면이
/// 빈 회색 박스로 비어 있는 시간을 0에 가깝게 줄임. HD 회원 full(2~3MB)도
/// 셀룰러에서 매끄럽게 등장.
class ProgressivePhoto extends StatelessWidget {
  const ProgressivePhoto({
    super.key,
    required this.thumbUrl,
    required this.fullUrl,
    this.fit = BoxFit.cover,
    this.swapDuration = const Duration(milliseconds: 220),
  });

  /// 썸네일 URL. null/빈문자열이면 fallback color box.
  final String? thumbUrl;

  /// 풀해상도 URL. null/빈문자열이면 thumb만 사용.
  final String? fullUrl;

  final BoxFit fit;
  final Duration swapDuration;

  @override
  Widget build(BuildContext context) {
    final hasThumb = thumbUrl != null && thumbUrl!.isNotEmpty;
    final hasFull = fullUrl != null && fullUrl!.isNotEmpty;

    // load 중·error 모두 같은 톤 placeholder. 시각적으로 shimmer ghost와
    // 동일한 base 색이라 shimmer → real grid 전환 시 빈 검정 갭이 안 생김.
    Widget placeholder() => ColoredBox(color: context.colors.clickableArea);

    if (!hasThumb && !hasFull) {
      return placeholder();
    }

    // single-variant type(예: film poster — thumb=full)이면 두 Image를 stack
    // 하면 본인 위에 본인 fade-in 이 돌아 시각적 결함. 한 장만 그림.
    if (hasFull && (!hasThumb || thumbUrl == fullUrl)) {
      return Image.network(
        fullUrl!,
        fit: fit,
        frameBuilder: (ctx, child, frame, wasSync) {
          if (wasSync || frame != null) return child;
          return placeholder();
        },
        errorBuilder: (_, _, _) => placeholder(),
      );
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        if (hasThumb)
          Image.network(
            thumbUrl!,
            fit: fit,
            frameBuilder: (ctx, child, frame, wasSync) {
              if (wasSync || frame != null) return child;
              return placeholder();
            },
            errorBuilder: (_, _, _) => placeholder(),
          )
        else
          placeholder(),
        if (hasFull)
          Image.network(
            fullUrl!,
            fit: fit,
            // wasSync=true면 캐시 hit이라 즉시 보여 cross-fade 불필요.
            // frame=null은 아직 첫 프레임 미도착 → opacity 0으로 숨김.
            frameBuilder: (ctx, child, frame, wasSync) {
              if (wasSync) return child;
              return AnimatedOpacity(
                opacity: frame == null ? 0 : 1,
                duration: swapDuration,
                curve: Curves.easeOut,
                child: child,
              );
            },
            errorBuilder: (_, _, _) => const SizedBox.shrink(),
          ),
      ],
    );
  }
}
