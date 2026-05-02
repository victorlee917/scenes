import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';

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
    this.capturedAt,
    this.capturedLocation,
    this.photoWidth,
    this.photoHeight,
    this.filmTitle,
    this.filmReleaseDate,
    this.filmDirector,
    this.filmKind,
    this.filmGenres,
    this.filmRuntimeMinutes,
    this.musicKind,
    this.musicTitle,
    this.musicArtist,
    this.musicAlbum,
    this.musicReleaseDate,
    this.placeName,
    this.placeAddress,
    this.placeCategory,
    this.placeRegion,
    this.placeLat,
    this.placeLng,
  });

  final int totalCount;
  final int initialIndex;
  final String? sceneImageUrl;
  final String? sceneName;
  final String? uploaderName;
  final List<String> mediaTypes;
  final DateTime? uploadedAt;

  /// Photo-only meta (current index): EXIF capture timestamp.
  final DateTime? capturedAt;

  /// Photo-only meta (current index): human-readable location.
  final String? capturedLocation;

  /// Photo-only meta (current index): pixel dimensions.
  final int? photoWidth;
  final int? photoHeight;

  /// Film-only meta (current index).
  final String? filmTitle;
  final DateTime? filmReleaseDate;
  final String? filmDirector;

  /// `'movie'` or `'series'`. Defaults to a mock value when null.
  final String? filmKind;

  /// Film genre tags, displayed as `Drama / Romance / ...` in the metadata.
  final List<String>? filmGenres;

  /// Runtime in minutes (e.g., 132 → "132 min").
  final int? filmRuntimeMinutes;

  /// `'track'` or `'album'`. Track shows parent album in metadata; album
  /// skips the album line.
  final String? musicKind;

  /// Track or album title — whichever fits the [musicKind].
  final String? musicTitle;

  final String? musicArtist;

  /// Parent album for a track. Ignored when [musicKind] is `'album'`.
  final String? musicAlbum;

  final DateTime? musicReleaseDate;

  /// MapBox 기반 장소 메타.
  final String? placeName;

  /// 풀 주소 (예: "Tokyo Tower, 4-2-8 Shibakoen, Minato City").
  final String? placeAddress;

  /// POI 카테고리 (예: "Cafe", "Park", "Restaurant"). MapBox `category`.
  final String? placeCategory;

  /// 도시·국가 같은 상위 지역 컨텍스트 (예: "Seoul, Korea").
  final String? placeRegion;

  /// 위·경도 (메타에 표시할지 결정 필요).
  final double? placeLat;
  final double? placeLng;

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
    DateTime? capturedAt,
    String? capturedLocation,
    int? photoWidth,
    int? photoHeight,
    String? filmTitle,
    DateTime? filmReleaseDate,
    String? filmDirector,
    String? filmKind,
    List<String>? filmGenres,
    int? filmRuntimeMinutes,
    String? musicKind,
    String? musicTitle,
    String? musicArtist,
    String? musicAlbum,
    DateTime? musicReleaseDate,
    String? placeName,
    String? placeAddress,
    String? placeCategory,
    String? placeRegion,
    double? placeLat,
    double? placeLng,
  }) {
    return Navigator.of(context).push(
      PageRouteBuilder<void>(
        opaque: false,
        transitionDuration: const Duration(milliseconds: 300),
        reverseTransitionDuration: const Duration(milliseconds: 300),
        pageBuilder: (context, animation, secondaryAnimation) =>
            ContentViewerV2(
          totalCount: totalCount,
          initialIndex: initialIndex,
          sceneImageUrl: sceneImageUrl,
          sceneName: sceneName,
          uploaderName: uploaderName,
          mediaTypes: mediaTypes,
          uploadedAt: uploadedAt,
          capturedAt: capturedAt,
          capturedLocation: capturedLocation,
          photoWidth: photoWidth,
          photoHeight: photoHeight,
          filmTitle: filmTitle,
          filmReleaseDate: filmReleaseDate,
          filmDirector: filmDirector,
          filmKind: filmKind,
          filmGenres: filmGenres,
          filmRuntimeMinutes: filmRuntimeMinutes,
          musicKind: musicKind,
          musicTitle: musicTitle,
          musicArtist: musicArtist,
          musicAlbum: musicAlbum,
          musicReleaseDate: musicReleaseDate,
          placeName: placeName,
          placeAddress: placeAddress,
          placeCategory: placeCategory,
          placeRegion: placeRegion,
          placeLat: placeLat,
          placeLng: placeLng,
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

  /// Downloads the current content's image and opens the OS share sheet,
  /// which on iOS/Android includes "Save to Photos" / "Save to Files" along
  /// with sharing to other apps. Currently scoped to photo content; other
  /// types fall back to a no-op until we wire up film/music/place sharing.
  Future<void> _shareCurrent() async {
    if (_currentMediaType != 'photo') {
      // TODO: support film / music / place share via metadata or external URL.
      return;
    }
    final url = _contentImageUrl();
    Directory? tempDir;
    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode != 200) return;
      tempDir = await Directory.systemTemp.createTemp('scene_share_');
      final file = File('${tempDir.path}/photo_$_currentIndex.jpg');
      await file.writeAsBytes(response.bodyBytes);
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(file.path, mimeType: 'image/jpeg')],
          subject: widget.sceneName,
        ),
      );
    } catch (_) {
      // Silently swallow for now; could surface a snackbar.
    } finally {
      // Clean up the temp directory after the share sheet flow.
      if (tempDir != null && tempDir.existsSync()) {
        try {
          tempDir.deleteSync(recursive: true);
        } catch (_) {}
      }
    }
  }

  String _contentImageUrl() {
    switch (_currentMediaType) {
      case 'film':
        return 'https://picsum.photos/seed/film-$_currentIndex/300/450';
      case 'music':
        return 'https://picsum.photos/seed/music-$_currentIndex/300/300';
      case 'place':
        // 실제 데이터 연결 전 dev placeholder. 운영에선 mapbox-static-cache
        // Edge Function이 생성·캐싱한 정적 지도 이미지(scene_media 버킷의
        // signed URL)로 교체된다.
        return 'https://picsum.photos/seed/place-$_currentIndex/800/600';
      default:
        return _currentIndex.isEven
            ? 'https://picsum.photos/seed/content-$_currentIndex/1200/800'
            : 'https://picsum.photos/seed/content-$_currentIndex/800/1200';
    }
  }

  Widget _buildContent(BuildContext context) {
    final infoOverlay = _showInfo
        ? _ContentInfo(
            mediaType: _currentMediaType,
            index: _currentIndex,
            capturedAt: widget.capturedAt,
            capturedLocation: widget.capturedLocation,
            photoWidth: widget.photoWidth,
            photoHeight: widget.photoHeight,
            filmTitle: widget.filmTitle,
            filmReleaseDate: widget.filmReleaseDate,
            filmDirector: widget.filmDirector,
            filmKind: widget.filmKind,
            filmGenres: widget.filmGenres,
            filmRuntimeMinutes: widget.filmRuntimeMinutes,
            musicKind: widget.musicKind,
            musicTitle: widget.musicTitle,
            musicArtist: widget.musicArtist,
            musicAlbum: widget.musicAlbum,
            musicReleaseDate: widget.musicReleaseDate,
            placeName: widget.placeName,
            placeAddress: widget.placeAddress,
            placeCategory: widget.placeCategory,
            placeRegion: widget.placeRegion,
            placeLat: widget.placeLat,
            placeLng: widget.placeLng,
          )
        : null;

    if (_currentMediaType == 'film') {
      return _FilmContentCard(
        index: _currentIndex,
        posterUrl: _contentImageUrl(),
        title: widget.filmTitle,
        director: widget.filmDirector,
        imageOverlay: infoOverlay,
      );
    }
    if (_currentMediaType == 'music') {
      return _MusicContentCard(
        index: _currentIndex,
        albumArtUrl: _contentImageUrl(),
        title: widget.musicTitle,
        artist: widget.musicArtist,
        imageOverlay: infoOverlay,
      );
    }
    if (_currentMediaType == 'place') {
      return _PlaceContentCard(
        index: _currentIndex,
        mapImageUrl: _contentImageUrl(),
        name: widget.placeName,
        address: widget.placeAddress,
        imageOverlay: infoOverlay,
      );
    }
    return _ContentImage(
      url: _contentImageUrl(),
      index: _currentIndex,
      overlay: infoOverlay,
    );
  }

  /// 이미지 위에 깔리는 dim + meta 컨테이너. 각 콘텐츠 위젯이 이미지 영역
  /// 안에서 공통 형태로 렌더하기 위해 사용.
  static Widget _imageInfoOverlay(BuildContext context, Widget meta) {
    return Container(
      color: context.colors.background.withValues(alpha: 0.8),
      padding: const EdgeInsets.all(24),
      child: Center(child: meta),
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
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 500),
                    child: _buildContent(context),
                  ),
                ),
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
                const SizedBox(width: 16),
                GestureDetector(
                  onTap: _shareCurrent,
                  child: SizedBox(
                    width: 24,
                    height: 24,
                    child: Center(
                      child: FaIcon(
                        FontAwesomeIcons.arrowUpFromBracket,
                        size: 18,
                        color: context.colors.foregroundMuted,
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
                      if (i == _currentIndex) {
                        // 같은 인덱스 다시 탭 → 메타 정보 토글.
                        _showInfo = !_showInfo;
                      } else {
                        _currentIndex = i;
                        _showInfo = false;
                      }
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
    this.capturedAt,
    this.capturedLocation,
    this.photoWidth,
    this.photoHeight,
    this.filmTitle,
    this.filmReleaseDate,
    this.filmDirector,
    this.filmKind,
    this.filmGenres,
    this.filmRuntimeMinutes,
    this.musicKind,
    this.musicTitle,
    this.musicArtist,
    this.musicAlbum,
    this.musicReleaseDate,
    this.placeName,
    this.placeAddress,
    this.placeCategory,
    this.placeRegion,
    this.placeLat,
    this.placeLng,
  });

  final String mediaType;
  final int index;
  final DateTime? capturedAt;
  final String? capturedLocation;
  final int? photoWidth;
  final int? photoHeight;
  final String? filmTitle;
  final DateTime? filmReleaseDate;
  final String? filmDirector;
  final String? filmKind;
  final List<String>? filmGenres;
  final int? filmRuntimeMinutes;
  final String? musicKind;
  final String? musicTitle;
  final String? musicArtist;
  final String? musicAlbum;
  final DateTime? musicReleaseDate;
  final String? placeName;
  final String? placeAddress;
  final String? placeCategory;
  final String? placeRegion;
  final double? placeLat;
  final double? placeLng;

  @override
  Widget build(BuildContext context) {
    switch (mediaType) {
      case 'film':
        // 호출부가 실제 메타를 안 넘기면 미리보기용 mock으로 대체.
        final kind = filmKind ?? (index.isEven ? 'movie' : 'series');
        final release = filmReleaseDate ??
            DateTime(2020 + index % 6, 1 + index % 12, 1 + index % 28);
        final genres = filmGenres ?? _mockFilmGenres[index % _mockFilmGenres.length];
        final runtime = filmRuntimeMinutes ?? (90 + (index * 7) % 60);
        final kindLabel =
            kind.toLowerCase() == 'series' ? 'TV Series' : 'Movie';

        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(4),
                color: context.colors.foreground.withValues(alpha: 0.1),
              ),
              child: Text(
                kindLabel,
                style: AppTypography.body(11)
                    .copyWith(color: context.colors.foreground),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              genres.join(' / '),
              textAlign: TextAlign.center,
              style: AppTypography.body(13).copyWith(
                color: context.colors.foregroundMuted,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '${DateFormat.yMMMd('en').format(release)}  ·  $runtime min',
              style: AppTypography.body(13).copyWith(
                color: context.colors.foregroundMuted,
              ),
            ),
          ],
        );
      case 'music':
        // 호출부가 실제 메타를 안 넘기면 미리보기용 mock으로 대체.
        final musicKindResolved =
            musicKind ?? (index.isEven ? 'track' : 'album');
        final isTrack = musicKindResolved.toLowerCase() == 'track';
        final albumName =
            musicAlbum ?? _mockMusicAlbums[index % _mockMusicAlbums.length];
        final musicRelease = musicReleaseDate ??
            DateTime(2018 + index % 7, 1 + index % 12, 1 + index % 28);
        final musicKindLabel = isTrack ? 'Track' : 'Album';

        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(4),
                color: context.colors.foreground.withValues(alpha: 0.1),
              ),
              child: Text(
                musicKindLabel,
                style: AppTypography.body(11)
                    .copyWith(color: context.colors.foreground),
              ),
            ),
            if (isTrack) ...[
              const SizedBox(height: 8),
              Text(
                albumName,
                textAlign: TextAlign.center,
                style: AppTypography.body(13)
                    .copyWith(color: context.colors.foregroundMuted),
              ),
            ],
            const SizedBox(height: 8),
            Text(
              DateFormat.yMMMd('en').format(musicRelease),
              style: AppTypography.body(13)
                  .copyWith(color: context.colors.foregroundMuted),
            ),
          ],
        );
      case 'place':
        // 호출부가 실제 메타를 안 넘기면 미리보기용 mock으로 대체.
        final categoryResolved = placeCategory ??
            _mockPlaceCategories[index % _mockPlaceCategories.length];
        final regionResolved = placeRegion ??
            _mockPlaceRegions[index % _mockPlaceRegions.length];
        final latResolved = placeLat ?? (37.5512 + index * 0.03);
        final lngResolved = placeLng ?? (126.9882 + index * 0.03);

        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(4),
                color: context.colors.foreground.withValues(alpha: 0.1),
              ),
              child: Text(
                categoryResolved,
                style: AppTypography.body(11)
                    .copyWith(color: context.colors.foreground),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              regionResolved,
              textAlign: TextAlign.center,
              style: AppTypography.body(13)
                  .copyWith(color: context.colors.foregroundMuted),
            ),
            const SizedBox(height: 8),
            Text(
              '${latResolved.toStringAsFixed(4)}°, ${lngResolved.toStringAsFixed(4)}°',
              style: AppTypography.body(13)
                  .copyWith(color: context.colors.foregroundMuted),
            ),
          ],
        );
      default:
        // photo — EXIF 기반 메타 (장소 / 촬영 시간 / 크기). 호출부가 실제
        // 값을 안 넘기면 미리보기용 mock으로 대체.
        final location = capturedLocation ?? 'Seoul, Korea';
        final captured = capturedAt ??
            DateTime.now().subtract(Duration(days: index, hours: 3));
        final width = photoWidth ?? (index.isEven ? 1200 : 800);
        final height = photoHeight ?? (index.isEven ? 800 : 1200);

        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              location,
              textAlign: TextAlign.center,
              style: AppTypography.body(13)
                  .copyWith(color: context.colors.foregroundMuted),
            ),
            const SizedBox(height: 8),
            Text(
              DateFormat.yMMMd('en').add_jm().format(captured),
              textAlign: TextAlign.center,
              style: AppTypography.body(13)
                  .copyWith(color: context.colors.foregroundMuted),
            ),
            const SizedBox(height: 8),
            Text(
              '$width × $height',
              textAlign: TextAlign.center,
              style: AppTypography.body(13)
                  .copyWith(color: context.colors.foregroundMuted),
            ),
          ],
        );
    }
  }
}

// ── 영화 콘텐츠 카드 (포스터 + 제목 + 감독, 단순 레이아웃) ─────

class _FilmContentCard extends StatelessWidget {
  const _FilmContentCard({
    required this.index,
    required this.posterUrl,
    this.title,
    this.director,
    this.imageOverlay,
  });

  final int index;
  final String posterUrl;
  final String? title;
  final String? director;

  /// 포스터 위에만 덮이는 dim + 메타 오버레이. null이면 미적용.
  final Widget? imageOverlay;

  @override
  Widget build(BuildContext context) {
    final resolvedTitle = title ?? 'Film Title #${index + 1}';
    final resolvedDirector =
        director ?? _mockFilmDirectors[index % _mockFilmDirectors.length];

    return Column(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        ClipRRect(
          borderRadius: AppRadii.smBorder,
          child: SizedBox(
            width: 280,
            height: 420,
            child: Stack(
              fit: StackFit.expand,
              children: [
                Image.network(
                  posterUrl,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => Container(
                    color: context.colors.nonClickableArea,
                    child: Center(
                      child: FaIcon(
                        FontAwesomeIcons.film,
                        size: 40,
                        color: context.colors.foregroundMuted,
                      ),
                    ),
                  ),
                ),
                if (imageOverlay != null)
                  _ContentViewerV2State._imageInfoOverlay(
                      context, imageOverlay!),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),
        Text(
          resolvedTitle,
          textAlign: TextAlign.center,
          style: AppTypography.body(17, weight: FontWeight.w600)
              .copyWith(color: context.colors.foreground),
        ),
        const SizedBox(height: 6),
        Text(
          resolvedDirector,
          textAlign: TextAlign.center,
          style: AppTypography.body(13)
              .copyWith(color: context.colors.foregroundMuted),
        ),
      ],
    );
  }
}

const _mockFilmDirectors = [
  'Christopher Nolan',
  'Greta Gerwig',
  'Bong Joon-ho',
  'Sofia Coppola',
  'Wes Anderson',
  'Park Chan-wook',
];

const _mockFilmGenres = [
  ['Drama', 'Romance'],
  ['Drama', 'Coming-of-age'],
  ['Thriller', 'Mystery'],
  ['Comedy', 'Drama'],
  ['Sci-Fi', 'Adventure'],
  ['Romance', 'Comedy'],
];

const _mockMusicTitles = [
  'Mr. Brightside',
  'Karma Police',
  'Let It Happen',
  'Through the Night',
  'Kyoto',
  'Super Shy',
];

const _mockMusicArtists = [
  'The Killers',
  'Radiohead',
  'Tame Impala',
  'IU',
  'Phoebe Bridgers',
  'NewJeans',
];

const _mockMusicAlbums = [
  'Hot Fuss',
  'OK Computer',
  'Currents',
  'Palette',
  'Punisher',
  'Get Up',
];

const _mockPlaceNames = [
  'Tokyo Tower',
  'Yeonnam-dong Cafe',
  'Hongik Park',
  'Namsan Lookout',
  'Hanok Village',
  'Gwangjang Market',
];

const _mockPlaceAddresses = [
  '4-2-8 Shibakoen, Minato City, Tokyo',
  '252-1 Yeonnam-dong, Mapo-gu, Seoul',
  '188 Wausan-ro, Mapo-gu, Seoul',
  '105 Sopa-ro, Yongsan-gu, Seoul',
  '99-2 Bukchon-ro 11-gil, Jongno-gu',
  '88 Changgyeonggung-ro, Jongno-gu',
];

const _mockPlaceCategories = [
  'Landmark',
  'Cafe',
  'Park',
  'Lookout',
  'Heritage',
  'Market',
];

const _mockPlaceRegions = [
  'Tokyo, Japan',
  'Seoul, Korea',
  'Seoul, Korea',
  'Seoul, Korea',
  'Seoul, Korea',
  'Seoul, Korea',
];

// ── 음악 콘텐츠 카드 (앨범아트 + 제목 + 아티스트, 단순 레이아웃) ─

class _MusicContentCard extends StatelessWidget {
  const _MusicContentCard({
    required this.index,
    required this.albumArtUrl,
    this.title,
    this.artist,
    this.imageOverlay,
  });

  final int index;
  final String albumArtUrl;
  final String? title;
  final String? artist;

  /// 앨범아트 위에만 덮이는 dim + 메타 오버레이. null이면 미적용.
  final Widget? imageOverlay;

  @override
  Widget build(BuildContext context) {
    final resolvedTitle =
        title ?? _mockMusicTitles[index % _mockMusicTitles.length];
    final resolvedArtist =
        artist ?? _mockMusicArtists[index % _mockMusicArtists.length];

    return Column(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        ClipRRect(
          borderRadius: AppRadii.smBorder,
          child: SizedBox(
            width: 300,
            height: 300,
            child: Stack(
              fit: StackFit.expand,
              children: [
                Image.network(
                  albumArtUrl,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => Container(
                    color: context.colors.nonClickableArea,
                    child: Center(
                      child: FaIcon(
                        FontAwesomeIcons.music,
                        size: 40,
                        color: context.colors.foregroundMuted,
                      ),
                    ),
                  ),
                ),
                if (imageOverlay != null)
                  _ContentViewerV2State._imageInfoOverlay(
                      context, imageOverlay!),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),
        Text(
          resolvedTitle,
          textAlign: TextAlign.center,
          style: AppTypography.body(17, weight: FontWeight.w600)
              .copyWith(color: context.colors.foreground),
        ),
        const SizedBox(height: 6),
        Text(
          resolvedArtist,
          textAlign: TextAlign.center,
          style: AppTypography.body(13)
              .copyWith(color: context.colors.foregroundMuted),
        ),
      ],
    );
  }
}

// ── 장소 콘텐츠 카드 (지도 + 장소명 + 주소, 단순 레이아웃) ─────

class _PlaceContentCard extends StatelessWidget {
  const _PlaceContentCard({
    required this.index,
    required this.mapImageUrl,
    this.name,
    this.address,
    this.imageOverlay,
  });

  final int index;
  final String mapImageUrl;
  final String? name;
  final String? address;

  /// 지도 이미지 위에만 덮이는 dim + 메타 오버레이.
  final Widget? imageOverlay;

  @override
  Widget build(BuildContext context) {
    final resolvedName =
        name ?? _mockPlaceNames[index % _mockPlaceNames.length];
    final resolvedAddress =
        address ?? _mockPlaceAddresses[index % _mockPlaceAddresses.length];

    return Column(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        ClipRRect(
          borderRadius: AppRadii.smBorder,
          child: SizedBox(
            width: 320,
            height: 220,
            child: Stack(
              fit: StackFit.expand,
              children: [
                Image.network(
                  mapImageUrl,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => Container(
                    color: context.colors.nonClickableArea,
                    child: Center(
                      child: FaIcon(
                        FontAwesomeIcons.locationDot,
                        size: 40,
                        color: context.colors.foregroundMuted,
                      ),
                    ),
                  ),
                ),
                if (imageOverlay != null)
                  _ContentViewerV2State._imageInfoOverlay(
                      context, imageOverlay!),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),
        Text(
          resolvedName,
          textAlign: TextAlign.center,
          style: AppTypography.body(17, weight: FontWeight.w600)
              .copyWith(color: context.colors.foreground),
        ),
        const SizedBox(height: 6),
        Text(
          resolvedAddress,
          textAlign: TextAlign.center,
          style: AppTypography.body(13)
              .copyWith(color: context.colors.foregroundMuted),
        ),
      ],
    );
  }
}

// ── 음악 카드 (구버전, 미사용 보관) ──────────────────────────

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
  const _ContentImage({
    required this.url,
    required this.index,
    this.overlay,
  });

  final String url;
  final int index;

  /// 이미지 위에 덮이는 dim + 메타. null이면 미적용.
  final Widget? overlay;

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
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.network(
              widget.url,
              fit: BoxFit.cover,
              width: double.infinity,
              height: double.infinity,
            ),
            if (widget.overlay != null)
              _ContentViewerV2State._imageInfoOverlay(
                  context, widget.overlay!),
          ],
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
        // 미리보기용 placeholder. 실제 데이터 연결 시엔
        // mapbox-static-cache Edge Function의 결과 URL을 사용.
        return 'https://picsum.photos/seed/place-$index/200/200';
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
    // 최초 레이아웃 후엔 ScrollController.position.haveDimensions가 true가
    // 되지만 컨트롤러는 그 사실을 따로 notify하지 않는다. 초기 곡률
    // transform이 계산되도록 첫 프레임 후 한 번 강제로 rebuild.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() {});
    });
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
