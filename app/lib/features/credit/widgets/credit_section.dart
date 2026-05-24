import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/data/signed_url_cache.dart';
import '../../../core/theme/app_colors_ext.dart';
import '../../../core/theme/app_typography.dart';
import '../../../l10n/app_localizations.dart';
import '../../couple/couple_view_model.dart';
import '../../home/home_view_model.dart';
import '../../home/models/scene.dart';
import '../../home/widgets/scene_detail_screen.dart';
import '../../home/widgets/scene_title_fallback.dart';
import '../../profile/models/profile.dart';
import '../../profile/profile_view_model.dart';
import '../credit_feed_view_model.dart';
import '../models/credit_event.dart';

/// 프로필 화면의 'Credits' 섹션 — 페어의 활동 히스토리를 영화 엔딩 크레딧
/// 톤으로 표시.
///
/// - 최신순, 항목 교차 배치(이미지 좌/우 번갈아).
/// - 10개씩 로드. 더 있으면 하단에 `MORE` 버튼, 탭하면 다음 10개 append.
/// - 섹션 끝에는 작은 boundary divider — 아래 구독 배너와의 경계 역할.
/// - 활동이 0건이면 통째로 미표시.
class CreditSection extends ConsumerWidget {
  const CreditSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stateAsync = ref.watch(creditFeedProvider);
    final state = stateAsync.valueOrNull;
    final events = state?.events ?? const <CreditEvent>[];
    // 첫 로딩이거나 활동이 0건이면 섹션 자체를 미표시.
    if (events.isEmpty) return const SizedBox.shrink();

    final hasMore = state?.hasMore ?? false;
    final isLoadingMore = state?.isLoadingMore ?? false;

    final me = ref.watch(myProfileProvider).valueOrNull;
    final partner = ref.watch(activeCoupleProvider).valueOrNull?.partner;

    return Padding(
      // 위/아래 경계와의 마진을 profile_screen에서 일관되게 36으로 통제하기
      // 위해 vertical padding은 0. horizontal은 기존 24 유지.
      // bottom 36은 bottom divider와 banner 사이 간격.
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 36),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          for (var i = 0; i < events.length; i++) ...[
            if (i > 0) const SizedBox(height: 48),
            _CreditRow(
              event: events[i],
              imageOnLeft: i.isEven,
              me: me,
              partner: partner,
            ),
          ],
          if (hasMore) ...[
            const SizedBox(height: 24),
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: isLoadingMore
                  ? null
                  : () =>
                      ref.read(creditFeedProvider.notifier).loadMore(),
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                child: isLoadingMore
                    ? SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 1.5,
                          color: context.colors.foregroundMuted,
                        ),
                      )
                    : Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            AppLocalizations.of(context).creditMoreButton,
                            style: AppTypography.body(13).copyWith(
                              color: context.colors.foregroundMuted,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Icon(
                            Icons.keyboard_arrow_down,
                            size: 16,
                            color: context.colors.foregroundMuted,
                          ),
                        ],
                      ),
              ),
            ),
          ],
          // 위 경계 양쪽 마진(36)과 동일하게 맞춤.
          const SizedBox(height: 36),
          // 영화 크레딧 끝을 알리는 작은 boundary — 프로필 _divider와 동일 톤.
          Container(
            width: 30,
            height: 0.5,
            color: context.colors.foreground.withValues(alpha: 0.06),
          ),
        ],
      ),
    );
  }
}

/// Credit 한 행 — 이미지 + 정보. [imageOnLeft]에 따라 좌/우 배치를 뒤집어
/// 엔딩 크레딧처럼 교차 배치. batch는 서버가 이미 합쳐서 보내므로 클라는
/// event 한 개만 받음.
class _CreditRow extends ConsumerWidget {
  const _CreditRow({
    required this.event,
    required this.imageOnLeft,
    required this.me,
    required this.partner,
  });

  final CreditEvent event;

  final bool imageOnLeft;
  final Profile? me;
  final Profile? partner;

  /// 이미지 칼럼 폭(고정). 비율은 콘텐츠별 aspect, 높이는 width/aspect.
  static const double _imageWidth = 110;

  String _actorName() {
    final m = me;
    final p = partner;
    if (m != null && event.actorId == m.id) return m.displayName;
    if (p != null && event.actorId == p.id) return p.displayName;
    return '';
  }

  String _kindLabel() {
    switch (event.kind) {
      case CreditEventKind.sceneAdded:
        return 'Scene';
      case CreditEventKind.momentAdded:
        return event.batchCount > 1 ? '${event.batchCount} Moments' : 'Moment';
      case CreditEventKind.reactionAdded:
        final emoji = event.reactionEmoji ?? '';
        return emoji.isEmpty ? 'Reaction' : 'Reaction $emoji';
    }
  }

  /// 콘텐츠 타입별 가로/세로 비율. contents detail viewer와 같은 규칙.
  double _imageAspect() {
    if (event.kind == CreditEventKind.sceneAdded) return 1.0;
    final payload = event.contentPayload;
    final type = event.contentType;
    if (type == null) return 1.0;
    switch (type) {
      case 'photo':
        final w = (payload?['width'] as num?)?.toDouble();
        final h = (payload?['height'] as num?)?.toDouble();
        if (w != null && h != null && w > 0 && h > 0) return w / h;
        return 0.75; // photo 평균 portrait
      case 'film':
        return 2 / 3;
      case 'music':
      case 'place':
      default:
        return 1.0;
    }
  }

  /// 표시할 이미지의 최종 URL. photo/film/place는 storage path를 sign,
  /// music은 Spotify CDN URL 직접, film은 캐싱 실패 시 TMDB source URL fallback.
  Future<String?> _imageUrl(SignedUrlCache cache) async {
    if (event.kind == CreditEventKind.sceneAdded) {
      final path = event.sceneCoverStoragePath;
      if (path == null || path.isEmpty) return null;
      return cache.getOrSign(path);
    }
    final payload = event.contentPayload;
    final type = event.contentType;
    if (payload == null || type == null) return null;
    switch (type) {
      case 'photo':
        // credits는 작게 표시되므로 thumb 우선, 없으면 full.
        final path = (payload['thumb_path'] as String?) ??
            (payload['storage_path'] as String?);
        if (path == null || path.isEmpty) return null;
        return cache.getOrSign(path);
      case 'film':
        final cached = payload['poster_storage_path'] as String?;
        if (cached != null && cached.isNotEmpty) {
          final signed = await cache.getOrSign(cached);
          return signed ?? payload['poster_source_url'] as String?;
        }
        return payload['poster_source_url'] as String?;
      case 'music':
        // Spotify TOS상 캐싱 금지 — CDN URL 그대로.
        return payload['album_art_url'] as String?;
      case 'place':
        final path = payload['mapbox_static_storage_path'] as String?;
        if (path == null || path.isEmpty) return null;
        return cache.getOrSign(path);
    }
    return null;
  }

  void _handleTap(BuildContext context, WidgetRef ref) {
    // 푸시 딥링크와 동일 흐름 — 해당 scene의 detail로 push, content가 있으면
    // detail이 그 콘텐츠 viewer를 자동으로 연다.
    final scenes = ref.read(homeViewModelProvider).scenes;
    Scene? target;
    for (final s in scenes) {
      if (s.id == event.sceneId) {
        target = s;
        break;
      }
    }
    if (target == null) return; // 삭제됐거나 다른 페어 컨텍스트 — 무시
    final viewportWidth = MediaQuery.sizeOf(context).width;
    Navigator.of(context).push(
      SceneDetailScreen.fadeRoute(
        scene: target,
        canisterSize: viewportWidth * 0.5,
        initialContentId: event.contentId,
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cache = ref.watch(signedUrlCacheProvider);
    final locale = Localizations.localeOf(context).toLanguageTag();
    final timeLabel = DateFormat.yMMMd(locale)
        .add_Hm()
        .format(event.createdAt.toLocal());
    final actor = _actorName();
    final kindLabel = _kindLabel();

    final image = SizedBox(
      width: _imageWidth,
      child: AspectRatio(
        aspectRatio: _imageAspect(),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: FutureBuilder<String?>(
            future: _imageUrl(cache),
            builder: (context, snap) {
              // scene_added는 캐니스터 로직과 동일하게 cover 없거나 로드
              // 실패면 타이틀 첫 글자 fallback. 콘텐츠 이벤트는 그냥 회색.
              final fallback = event.kind == CreditEventKind.sceneAdded
                  ? SceneTitleFallback(title: event.sceneTitle)
                  : ColoredBox(color: context.colors.nonClickableArea);
              final url = snap.data;
              if (url == null || url.isEmpty) return fallback;
              return Image.network(
                url,
                fit: BoxFit.cover,
                gaplessPlayback: true,
                errorBuilder: (_, _, _) => fallback,
              );
            },
          ),
        ),
      ),
    );

    final info = Column(
      crossAxisAlignment:
          imageOnLeft ? CrossAxisAlignment.start : CrossAxisAlignment.end,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          kindLabel,
          textAlign: imageOnLeft ? TextAlign.start : TextAlign.end,
          style: AppTypography.display(18).copyWith(
            color: context.colors.foreground,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          actor.isEmpty ? 'by —' : 'by $actor',
          textAlign: imageOnLeft ? TextAlign.start : TextAlign.end,
          style: AppTypography.body(13).copyWith(
            color: context.colors.foregroundMuted,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          timeLabel,
          textAlign: imageOnLeft ? TextAlign.start : TextAlign.end,
          style: AppTypography.body(11).copyWith(
            color: context.colors.foregroundMuted.withValues(alpha: 0.7),
            letterSpacing: 0.2,
          ),
        ),
      ],
    );

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => _handleTap(context, ref),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: imageOnLeft
            ? [image, const SizedBox(width: 16), Expanded(child: info)]
            : [Expanded(child: info), const SizedBox(width: 16), image],
      ),
    );
  }
}
