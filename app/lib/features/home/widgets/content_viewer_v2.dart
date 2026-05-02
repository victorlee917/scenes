import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_colors_ext.dart';
import '../../../core/theme/app_radii.dart';
import '../../../core/theme/app_typography.dart';

// TODO: project rule says no external API keys in client — migrate map
// previews to an Edge Function (e.g., `mapbox-static-cache`). For dev, pass
// the token via `flutter run --dart-define=MAPBOX_TOKEN=...`.
const _mapboxToken = String.fromEnvironment('MAPBOX_TOKEN');

/// 콘텐츠 뷰어 v2.
///
/// 레이아웃: 앱바 → 콘텐츠 박스 → 정보+좋아요 → 가로 dial.
class ContentViewerV2 extends StatefulWidget {
  const ContentViewerV2({
    super.key,
    required this.totalCount,
    required this.initialIndex,
    this.sceneImageUrl,
    this.sceneName,
    this.uploaderName,
    this.mediaTypes = const [],
    this.uploadedAt,
  });

  final int totalCount;
  final int initialIndex;
  final String? sceneImageUrl;
  final String? sceneName;
  final String? uploaderName;
  final List<String> mediaTypes;
  final DateTime? uploadedAt;

  String mediaTypeAt(int index) =>
      index < mediaTypes.length ? mediaTypes[index] : 'photo';

  static Future<void> show({
    required BuildContext context,
    required int totalCount,
    required int initialIndex,
    String? sceneImageUrl,
    String? sceneName,
    String? uploaderName,
    List<String> mediaTypes = const [],
    DateTime? uploadedAt,
  }) {
    return Navigator.of(context).push(
      PageRouteBuilder<void>(
        opaque: false,
        transitionDuration: const Duration(milliseconds: 300),
        reverseTransitionDuration: Duration.zero,
        pageBuilder: (context, animation, secondaryAnimation) =>
            ContentViewerV2(
          totalCount: totalCount,
          initialIndex: initialIndex,
          sceneImageUrl: sceneImageUrl,
          sceneName: sceneName,
          uploaderName: uploaderName,
          mediaTypes: mediaTypes,
          uploadedAt: uploadedAt,
        ),
        transitionsBuilder:
            (context, animation, secondaryAnimation, child) {
          final curved = CurvedAnimation(
            parent: animation,
            curve: Curves.easeOut,
          );
          return SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, 1),
              end: Offset.zero,
            ).animate(curved),
            child: child,
          );
        },
      ),
    );
  }

  @override
  State<ContentViewerV2> createState() => _ContentViewerV2State();
}

class _ContentViewerV2State extends State<ContentViewerV2> {
  late int _currentIndex;
  bool _liked = false;
  bool _showInfo = false;
  double _dragOffset = 0;
  bool _dragging = false;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
  }

  String get _currentMediaType => widget.mediaTypeAt(_currentIndex);

  String _contentImageUrl() {
    switch (_currentMediaType) {
      case 'film':
        return 'https://picsum.photos/seed/film-$_currentIndex/300/450';
      case 'music':
        return 'https://picsum.photos/seed/music-$_currentIndex/300/300';
      case 'place':
        final isDark = Theme.of(context).brightness == Brightness.dark;
        final style = isDark ? 'dark-v11' : 'light-v11';
        final lat = 37.5512 + _currentIndex * 0.03;
        final lng = 126.9882 + _currentIndex * 0.03;
        return 'https://api.mapbox.com/styles/v1/mapbox/$style/static/'
            'pin-s+888888($lng,$lat)/$lng,$lat,14,0/800x600@2x'
            '?access_token=$_mapboxToken'
            '&attribution=false&logo=false';
      default:
        return _currentIndex.isEven
            ? 'https://picsum.photos/seed/content-$_currentIndex/1200/800'
            : 'https://picsum.photos/seed/content-$_currentIndex/800/1200';
    }
  }

  Widget _buildContent(BuildContext context) {
    return _ContentImage(
      url: _contentImageUrl(),
      index: _currentIndex,
    );
  }

  void _onVerticalDragUpdate(DragUpdateDetails details) {
    if (details.delta.dy > 0 || _dragOffset > 0) {
      setState(() {
        _dragging = true;
        _dragOffset = (_dragOffset + details.delta.dy).clamp(0.0, 400.0);
      });
    }
  }

  void _onVerticalDragEnd(DragEndDetails details) {
    if (_dragOffset > 120 ||
        (details.primaryVelocity != null && details.primaryVelocity! > 800)) {
      Navigator.of(context).pop();
    } else {
      setState(() {
        _dragging = false;
        _dragOffset = 0;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final padding = MediaQuery.paddingOf(context);
    final progress = (_dragOffset / 300).clamp(0.0, 1.0);
    final scale = 1.0 - progress * 0.1;
    final radius = progress * AppRadii.lg;

    return GestureDetector(
      onVerticalDragUpdate: _onVerticalDragUpdate,
      onVerticalDragEnd: _onVerticalDragEnd,
      child: AnimatedContainer(
        duration: _dragging ? Duration.zero : const Duration(milliseconds: 250),
        curve: Curves.easeOut,
        transformAlignment: Alignment.topCenter,
        transform: Matrix4.identity()
          // ignore: deprecated_member_use
          ..translate(0.0, _dragOffset)
          // ignore: deprecated_member_use
          ..scale(scale),
        child: Opacity(
          opacity: (1.0 - progress).clamp(0.0, 1.0),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(radius),
            child: Scaffold(
      body: Column(
        children: [
          // ── 앱바 영역 ──────────────────────────────────────
          SizedBox(height: padding.top + 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                // 좌: 캐니스터 사진 + 제목 + 매체
                if (widget.sceneImageUrl != null)
                  ClipOval(
                    child: SizedBox(
                      width: 28,
                      height: 28,
                      child: Image.network(
                        widget.sceneImageUrl!,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => Container(
                          color: context.colors.nonClickableArea,
                        ),
                      ),
                    ),
                  ),
                if (widget.sceneImageUrl != null)
                  const SizedBox(width: 10),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (widget.sceneName != null)
                      Text(
                        widget.sceneName!,
                        style: AppTypography.body(13, weight: FontWeight.w600)
                            .copyWith(color: context.colors.foreground),
                      ),
                    Text(
                      _currentMediaType,
                      style: AppTypography.body(11).copyWith(
                        color: context.colors.foregroundMuted,
                      ),
                    ),
                  ],
                ),
                const Spacer(),
                // 우: 인덱스 · X pill
                GestureDetector(
                  onTap: () => Navigator.of(context).pop(),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: BackdropFilter(
                      filter:
                          ui.ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: context.colors.foreground
                              .withValues(alpha: 0.06),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              '${_currentIndex + 1}/${widget.totalCount}',
                              style: AppTypography.body(11).copyWith(
                                color: context.colors.foreground
                                    .withValues(alpha: 0.9),
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8),
                              child: Container(
                                width: 3,
                                height: 3,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: context.colors.foreground
                                      .withValues(alpha: 0.3),
                                ),
                              ),
                            ),
                            FaIcon(
                              FontAwesomeIcons.xmark,
                              size: 11,
                              color: context.colors.foreground
                                  .withValues(alpha: 0.6),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // ── 콘텐츠 박스 ────────────────────────────────────
          Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => setState(() => _showInfo = !_showInfo),
              onHorizontalDragEnd: (details) {
                final velocity = details.primaryVelocity ?? 0;
                if (velocity < -300 && _currentIndex < widget.totalCount - 1) {
                  setState(() {
                    _currentIndex++;
                    _showInfo = false;
                  });
                  HapticFeedback.selectionClick();
                } else if (velocity > 300 && _currentIndex > 0) {
                  setState(() {
                    _currentIndex--;
                    _showInfo = false;
                  });
                  HapticFeedback.selectionClick();
                }
              },
              child: Stack(
                children: [
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxHeight: 500),
                        child: _buildContent(context),
                      ),
                    ),
                  ),
                  if (_showInfo)
                    Positioned.fill(
                      child: Container(
                        color: context.colors.background
                            .withValues(alpha: 0.8),
                        padding: const EdgeInsets.all(24),
                        child: Center(
                          child: _ContentInfo(
                            mediaType: _currentMediaType,
                            index: _currentIndex,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // ── 정보 + 좋아요 ──────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (widget.uploaderName != null)
                        Text(
                          widget.uploaderName!,
                          style: AppTypography.body(14,
                                  weight: FontWeight.w500)
                              .copyWith(
                                  color: context.colors.foreground),
                        ),
                      const SizedBox(height: 2),
                      Text(
                        widget.uploadedAt != null
                            ? DateFormat.yMMMMd('en')
                                .format(widget.uploadedAt!)
                            : '',
                        style: AppTypography.body(12).copyWith(
                          color: context.colors.foregroundMuted,
                        ),
                      ),
                    ],
                  ),
                ),
                GestureDetector(
                  onTap: () => setState(() => _liked = !_liked),
                  child: SizedBox(
                    width: 24,
                    height: 24,
                    child: Center(
                      child: FaIcon(
                        _liked
                            ? FontAwesomeIcons.solidHeart
                            : FontAwesomeIcons.heart,
                        size: 20,
                        color: _liked
                            ? const Color(0xFFE06C75)
                            : context.colors.foregroundMuted,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // ── 썸네일 dial ──────────────────────────────────────
          SizedBox(
            height: 64,
            child: _ThumbnailDial(
              totalCount: widget.totalCount,
              currentIndex: _currentIndex,
              mediaTypes: widget.mediaTypes,
              onIndexChanged: (i) {
                    setState(() {
                      _currentIndex = i;
                      _showInfo = false;
                    });
                    HapticFeedback.selectionClick();
                  },
            ),
          ),

          SizedBox(height: padding.bottom + 16),
        ],
      ),
    ),
    ),
    ),
    ),
    );
  }
}

// ── 콘텐츠 정보 오버레이 (dimmed 위 center) ──────────────────

class _ContentInfo extends StatelessWidget {
  const _ContentInfo({
    required this.mediaType,
    required this.index,
  });

  final String mediaType;
  final int index;

  @override
  Widget build(BuildContext context) {
    switch (mediaType) {
      case 'film':
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Film Title #${index + 1}',
              textAlign: TextAlign.center,
              style: AppTypography.body(18, weight: FontWeight.w600)
                  .copyWith(color: context.colors.foreground),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(4),
                    color: context.colors.foreground.withValues(alpha: 0.1),
                  ),
                  child: Text(
                    index.isEven ? 'Movie' : 'TV Series',
                    style: AppTypography.body(10)
                        .copyWith(color: context.colors.foregroundMuted),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '${2020 + index % 6}',
                  style: AppTypography.body(13)
                      .copyWith(color: context.colors.foregroundMuted),
                ),
              ],
            ),
          ],
        );
      case 'music':
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Track Title #${index + 1}',
              textAlign: TextAlign.center,
              style: AppTypography.body(18, weight: FontWeight.w600)
                  .copyWith(color: context.colors.foreground),
            ),
            const SizedBox(height: 6),
            Text(
              'Artist Name',
              style: AppTypography.body(13)
                  .copyWith(color: context.colors.foregroundMuted),
            ),
            const SizedBox(height: 2),
            Text(
              'Album Name',
              style: AppTypography.body(12)
                  .copyWith(color: context.colors.foregroundMuted.withValues(alpha: 0.7)),
            ),
          ],
        );
      case 'place':
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            FaIcon(
              FontAwesomeIcons.locationDot,
              size: 20,
              color: context.colors.foregroundMuted,
            ),
            const SizedBox(height: 12),
            Text(
              'Place Name #${index + 1}',
              textAlign: TextAlign.center,
              style: AppTypography.body(18, weight: FontWeight.w600)
                  .copyWith(color: context.colors.foreground),
            ),
            const SizedBox(height: 6),
            Text(
              '123 Example Street, City',
              textAlign: TextAlign.center,
              style: AppTypography.body(13)
                  .copyWith(color: context.colors.foregroundMuted),
            ),
          ],
        );
      default:
        // photo
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Photo #${index + 1}',
              textAlign: TextAlign.center,
              style: AppTypography.body(18, weight: FontWeight.w600)
                  .copyWith(color: context.colors.foreground),
            ),
            const SizedBox(height: 6),
            Text(
              '${index.isEven ? '1200 × 800' : '800 × 1200'}',
              style: AppTypography.body(13)
                  .copyWith(color: context.colors.foregroundMuted),
            ),
          ],
        );
    }
  }
}

// ── 영화 카드 (미사용, 보관) ─────────────────────────────────

class _FilmCard extends StatelessWidget {
  const _FilmCard({required this.index});
  final int index;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: context.colors.clickableArea,
        borderRadius: AppRadii.mdBorder,
        border: Border.all(
          color: context.colors.foreground.withValues(alpha: 0.04),
          width: 0.5,
        ),
      ),
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 포스터
          ClipRRect(
            borderRadius: AppRadii.smBorder,
            child: Image.network(
              'https://picsum.photos/seed/film-$index/300/450',
              width: 140,
              height: 210,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => Container(
                width: 140,
                height: 210,
                color: context.colors.nonClickableArea,
                child: Center(
                  child: FaIcon(
                    FontAwesomeIcons.film,
                    size: 32,
                    color: context.colors.foregroundMuted,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'Film Title #${index + 1}',
            textAlign: TextAlign.center,
            style: AppTypography.body(17, weight: FontWeight.w600)
                .copyWith(color: context.colors.foreground),
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 6,
                  vertical: 2,
                ),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(4),
                  color: context.colors.foreground.withValues(alpha: 0.06),
                ),
                child: Text(
                  index.isEven ? 'Movie' : 'TV Series',
                  style: AppTypography.body(10).copyWith(
                    color: context.colors.foregroundMuted,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '${2020 + index % 6}',
                style: AppTypography.body(13).copyWith(
                  color: context.colors.foregroundMuted,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── 음악 카드 ────────────────────────────────────────────────

class _MusicCard extends StatelessWidget {
  const _MusicCard({required this.index});
  final int index;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: context.colors.clickableArea,
        borderRadius: AppRadii.mdBorder,
        border: Border.all(
          color: context.colors.foreground.withValues(alpha: 0.04),
          width: 0.5,
        ),
      ),
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 앨범 커버
          ClipRRect(
            borderRadius: AppRadii.smBorder,
            child: Image.network(
              'https://picsum.photos/seed/music-$index/300/300',
              width: 180,
              height: 180,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => Container(
                width: 180,
                height: 180,
                color: context.colors.nonClickableArea,
                child: Center(
                  child: FaIcon(
                    FontAwesomeIcons.music,
                    size: 32,
                    color: context.colors.foregroundMuted,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'Track Title #${index + 1}',
            textAlign: TextAlign.center,
            style: AppTypography.body(17, weight: FontWeight.w600)
                .copyWith(color: context.colors.foreground),
          ),
          const SizedBox(height: 6),
          Text(
            'Artist Name',
            textAlign: TextAlign.center,
            style: AppTypography.body(13).copyWith(
              color: context.colors.foregroundMuted,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            'Album Name',
            textAlign: TextAlign.center,
            style: AppTypography.body(12).copyWith(
              color: context.colors.foregroundMuted.withValues(alpha: 0.7),
            ),
          ),
        ],
      ),
    );
  }
}

// ── 장소 카드 ────────────────────────────────────────────────

class _PlaceCard extends StatelessWidget {
  const _PlaceCard({required this.index});
  final int index;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final style = isDark ? 'dark-v11' : 'light-v11';
    // mock 좌표
    final lat = 37.5512 + index * 0.01;
    final lng = 126.9882 + index * 0.01;
    final mapUrl =
        'https://api.mapbox.com/styles/v1/mapbox/$style/static/'
        'pin-s+888888($lng,$lat)/$lng,$lat,14,0/600x300@2x'
        '?access_token=$_mapboxToken'
        '&attribution=false&logo=false';

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: context.colors.clickableArea,
        borderRadius: AppRadii.mdBorder,
        border: Border.all(
          color: context.colors.foreground.withValues(alpha: 0.04),
          width: 0.5,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 지도 미리보기
          ClipRRect(
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(AppRadii.md),
            ),
            child: Image.network(
              mapUrl,
              width: double.infinity,
              height: 180,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => Container(
                width: double.infinity,
                height: 180,
                color: context.colors.nonClickableArea,
                child: Center(
                  child: FaIcon(
                    FontAwesomeIcons.locationDot,
                    size: 32,
                    color: context.colors.foregroundMuted,
                  ),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Place Name #${index + 1}',
                  style: AppTypography.body(17, weight: FontWeight.w600)
                      .copyWith(color: context.colors.foreground),
                ),
                const SizedBox(height: 4),
                Text(
                  '123 Example Street, City, Country',
                  style: AppTypography.body(13).copyWith(
                    color: context.colors.foregroundMuted,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── 콘텐츠 이미지 (비율 유지 + radius) ────────────────────────

class _ContentImage extends StatefulWidget {
  const _ContentImage({required this.url, required this.index});

  final String url;
  final int index;

  @override
  State<_ContentImage> createState() => _ContentImageState();
}

class _ContentImageState extends State<_ContentImage> {
  double? _aspectRatio;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _resolve();
  }

  @override
  void didUpdateWidget(_ContentImage old) {
    super.didUpdateWidget(old);
    if (old.url != widget.url) {
      _aspectRatio = null;
      _failed = false;
      _resolve();
    }
  }

  void _resolve() {
    final provider = NetworkImage(widget.url);
    final stream = provider.resolve(ImageConfiguration.empty);
    stream.addListener(ImageStreamListener(
      (info, _) {
        if (mounted) {
          setState(() {
            _aspectRatio =
                info.image.width.toDouble() / info.image.height.toDouble();
          });
        }
      },
      onError: (_, __) {
        if (mounted) setState(() => _failed = true);
      },
    ));
  }

  @override
  Widget build(BuildContext context) {
    if (_failed) {
      return Center(
        child: Text(
          'Content #${widget.index + 1}',
          style: AppTypography.display(24).copyWith(
            color: context.colors.foregroundMuted,
          ),
        ),
      );
    }
    if (_aspectRatio == null) {
      return Center(
        child: CircularProgressIndicator(
          color: context.colors.foreground,
          strokeWidth: 1.5,
        ),
      );
    }
    return AspectRatio(
      aspectRatio: _aspectRatio!,
      child: ClipRRect(
        borderRadius: AppRadii.mdBorder,
        child: Image.network(
          widget.url,
          fit: BoxFit.cover,
          width: double.infinity,
          height: double.infinity,
        ),
      ),
    );
  }
}

// ── 썸네일 dial (원통형 곡률 + 좌우 그라데이션) ──────────────

class _ThumbnailDial extends StatefulWidget {
  const _ThumbnailDial({
    required this.totalCount,
    required this.currentIndex,
    required this.onIndexChanged,
    this.mediaTypes = const [],
  });

  final int totalCount;
  final int currentIndex;
  final ValueChanged<int> onIndexChanged;
  final List<String> mediaTypes;

  String _thumbUrl(int index) {
    final type = index < mediaTypes.length ? mediaTypes[index] : 'photo';
    switch (type) {
      case 'film':
        return 'https://picsum.photos/seed/film-$index/200/200';
      case 'music':
        return 'https://picsum.photos/seed/music-$index/200/200';
      case 'place':
        final lat = 37.5512 + index * 0.03;
        final lng = 126.9882 + index * 0.03;
        return 'https://api.mapbox.com/styles/v1/mapbox/dark-v11/static/'
            'pin-s+888888($lng,$lat)/$lng,$lat,14,0/200x200@2x'
            '?access_token=$_mapboxToken'
            '&attribution=false&logo=false';
      default:
        return 'https://picsum.photos/seed/content-$index/200/200';
    }
  }

  @override
  State<_ThumbnailDial> createState() => _ThumbnailDialState();
}

class _ThumbnailDialState extends State<_ThumbnailDial> {
  late final ScrollController _scrollController;
  static const double _itemSize = 48;
  static const double _spacing = 8;
  static const double _itemExtent = _itemSize + _spacing;
  int _lastReportedIndex = -1;
  bool _programmaticScroll = false;
  bool _userScrolling = false;

  @override
  void initState() {
    super.initState();
    _lastReportedIndex = widget.currentIndex;
    _scrollController = ScrollController(
      initialScrollOffset: widget.currentIndex * _itemExtent,
    );
    _scrollController.addListener(_onScroll);
  }

  void _onScroll() {
    if (!_scrollController.hasClients || _programmaticScroll) return;
    final index = (_scrollController.offset / _itemExtent)
        .round()
        .clamp(0, widget.totalCount - 1);
    if (index != _lastReportedIndex) {
      _lastReportedIndex = index;
      widget.onIndexChanged(index);
    }
  }

  @override
  void didUpdateWidget(_ThumbnailDial old) {
    super.didUpdateWidget(old);
    if (old.currentIndex != widget.currentIndex && !_userScrolling) {
      _lastReportedIndex = widget.currentIndex;
      _programmaticScroll = true;
      _scrollController
          .animateTo(
            widget.currentIndex * _itemExtent,
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOut,
          )
          .then((_) => _programmaticScroll = false);
    }
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final halfWidth = constraints.maxWidth / 2;
        final sidePadding = halfWidth - _itemSize / 2;

        return ShaderMask(
          shaderCallback: (bounds) => const LinearGradient(
            colors: [
              Colors.transparent,
              Colors.white,
              Colors.white,
              Colors.transparent,
            ],
            stops: [0.0, 0.25, 0.75, 1.0],
          ).createShader(bounds),
          blendMode: BlendMode.dstIn,
          child: NotificationListener<ScrollNotification>(
            onNotification: (n) {
              if (n is ScrollStartNotification && n.dragDetails != null) {
                _userScrolling = true;
              } else if (n is ScrollEndNotification) {
                _userScrolling = false;
              }
              return false;
            },
            child: ListView.builder(
            controller: _scrollController,
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            padding: EdgeInsets.symmetric(horizontal: sidePadding),
            itemCount: widget.totalCount,
            itemBuilder: (context, index) {
              return Padding(
                padding: EdgeInsets.only(
                  right: index < widget.totalCount - 1 ? _spacing : 0,
                ),
                child: GestureDetector(
                  onTap: () => widget.onIndexChanged(index),
                  child: AnimatedBuilder(
                    animation: _scrollController,
                    builder: (context, child) {
                      double scale = 1.0;
                      double rotateY = 0.0;
                      if (_scrollController.hasClients &&
                          _scrollController.position.haveDimensions) {
                        final itemCenter =
                            index * _itemExtent + _itemSize / 2;
                        final viewCenter =
                            _scrollController.offset + halfWidth;
                        final distance =
                            (itemCenter - viewCenter) / halfWidth;
                        scale = (1.0 - distance.abs() * 0.15)
                            .clamp(0.7, 1.0);
                        rotateY = distance * 0.4;
                      }
                      return Transform(
                        alignment: Alignment.center,
                        transform: Matrix4.identity()
                          ..setEntry(3, 2, 0.002)
                          ..rotateY(rotateY)
                          // ignore: deprecated_member_use
                          ..scale(scale),
                        child: child,
                      );
                    },
                    child: ClipRRect(
                      borderRadius: AppRadii.xsBorder,
                      child: SizedBox(
                        width: _itemSize,
                        height: _itemSize,
                        child: Image.network(
                          widget._thumbUrl(index),
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) => Container(
                            color: context.colors.nonClickableArea,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
          ),
        );
      },
    );
  }
}
