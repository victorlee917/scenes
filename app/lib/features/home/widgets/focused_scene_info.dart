import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../../../core/theme/app_colors_ext.dart';
import '../../../core/theme/app_typography.dart';
import '../formatters.dart';
import '../models/scene.dart';

/// 현재 "표시할" Scene의 메타를 캐니스터 아래 별도 블록으로 렌더.
///
/// VM을 직접 구독하지 않고, 부모가 넘겨주는 [scene]만 그린다. 이렇게 하면
/// 스크롤 중에는 부모가 내용을 일부러 고정시켜 fade-out 도중 목표 씬이
/// 깜빡이는 문제를 피할 수 있다. [scene]이 `null`이면 아무것도 그리지 않음.
class FocusedSceneInfo extends StatelessWidget {
  const FocusedSceneInfo({super.key, this.scene});

  final Scene? scene;

  @override
  Widget build(BuildContext context) {
    final scene = this.scene;
    if (scene == null) return const SizedBox.shrink();

    final locale = Localizations.localeOf(context);
    final localeTag = locale.toLanguageTag();
    final isKo = locale.languageCode == 'ko';

    // 날짜 표시는 콘텐츠가 있을 때만. (콘텐츠가 걸쳐 있는 날짜를 보여주는 게
    // 의도라서, 콘텐츠 없으면 날짜 자체가 의미 없음.)
    // TODO: contents wiring 이후 scene.dates 대신 contents의 min/max occurred_at으로 교체.
    final hasContents = scene.media.total > 0;
    final dateLine = formatSceneDateRange(scene.dates, localeTag);
    final screenWidth = MediaQuery.sizeOf(context).width;
    final titleSize = screenWidth >= 420 ? 30.0 : 26.0;

    final mediaColor = context.colors.foreground.withValues(alpha: 0.52);
    final mediaItems = <(FaIconData, int)>[
      if (scene.media.photos > 0)
        (FontAwesomeIcons.solidImage, scene.media.photos),
      if (scene.media.films > 0) (FontAwesomeIcons.film, scene.media.films),
      if (scene.media.music > 0) (FontAwesomeIcons.music, scene.media.music),
      if (scene.media.places > 0) (FontAwesomeIcons.locationDot, scene.media.places),
    ];

    final dateStyle = AppTypography.body(isKo ? 10 : 9).copyWith(
      color: context.colors.foreground.withValues(alpha: 0.42),
      letterSpacing: isKo ? 0.4 : 2.4,
    );
    final dateText = isKo ? dateLine : dateLine.toUpperCase();

    // 부모가 top-anchor로 # title 위치를 고정. 안의 column은 자연 높이.
    // → # title은 항상 같은 Y에 표시되고, media/date는 그 아래로 흘러내림.
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            '#${scene.number}',
            textAlign: TextAlign.center,
            style: AppTypography.display(14).copyWith(
              color: context.colors.foregroundMuted,
              letterSpacing: 2.0,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            scene.title,
            textAlign: TextAlign.center,
            style: AppTypography.display(titleSize, text: scene.title).copyWith(
              color: context.colors.foreground,
              height: 1.05,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          if (mediaItems.isNotEmpty) ...[
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (int i = 0; i < mediaItems.length; i++) ...[
                  if (i > 0)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: Text(
                        '·',
                        style: TextStyle(
                          color: mediaColor,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  FaIcon(
                    mediaItems[i].$1,
                    size: 10,
                    color: mediaColor,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '${mediaItems[i].$2}',
                    style: AppTypography.body(12).copyWith(
                      color: mediaColor,
                    ),
                  ),
                ],
              ],
            ),
          ],
          if (hasContents) ...[
            const SizedBox(height: 12),
            Text(
              dateText,
              textAlign: TextAlign.center,
              style: dateStyle,
            ),
          ],
        ],
      ),
    );
  }
}

