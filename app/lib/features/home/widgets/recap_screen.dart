import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:palette_generator/palette_generator.dart';

import '../../../core/theme/app_colors_ext.dart';
import '../../../core/theme/app_radii.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/app_toast.dart';
import '../../../core/widgets/floating_bottom_sheet.dart';
import '../../../core/widgets/glass_circle_button.dart';
import '../../../l10n/app_localizations.dart';
import '../../content/contents_view_model.dart';
import '../../content/models/content.dart';
import '../../content/models/reaction.dart';
import '../../content/reactions_view_model.dart';
import '../../content/widgets/reaction_picker_sheet.dart';
import '../../profile/profile_view_model.dart';
import '../../subscription/subscription_view_model.dart';
import '../home_view_model.dart';
import '../models/scene.dart';
import 'content_viewer_v2.dart';
import 'detail_app_bar.dart';
import 'filter_scenes_sheet.dart';
import 'place_recap_view.dart';
import 'rewind_pill_button.dart';

/// 모든 scene 합산 콘텐츠를 매체별로 돌아보는 화면. SceneListScreen과 동일한
/// FadeTransition + DetailAppBar 톤. 타이틀은 앱바에, 본문엔 매체 토글 + 매체별
/// recap 블록(예정).
class RecapScreen extends ConsumerStatefulWidget {
  const RecapScreen({super.key, this.initialMedia});

  /// 진입 시 처음 선택할 매체. null이면 'photo'.
  final String? initialMedia;

  static Route<void> route({String? initialMedia}) {
    return PageRouteBuilder<void>(
      opaque: true,
      transitionDuration: const Duration(milliseconds: 340),
      reverseTransitionDuration: const Duration(milliseconds: 280),
      pageBuilder: (_, _, _) => RecapScreen(initialMedia: initialMedia),
      transitionsBuilder: (_, anim, _, child) {
        return FadeTransition(opacity: anim, child: child);
      },
    );
  }

  @override
  ConsumerState<RecapScreen> createState() => _RecapScreenState();
}

class _RecapScreenState extends ConsumerState<RecapScreen> {
  static const _mediaTypes = ['photo', 'film', 'music', 'place'];
  static const _mediaIcons = {
    'photo': FontAwesomeIcons.solidImage,
    'film': FontAwesomeIcons.film,
    'music': FontAwesomeIcons.music,
    'place': FontAwesomeIcons.locationDot,
  };

  String _mediaLabel(AppLocalizations l10n, String type) {
    switch (type) {
      case 'photo':
        return l10n.mediaLabelPhoto;
      case 'film':
        return l10n.mediaLabelFilm;
      case 'music':
        return l10n.mediaLabelMusic;
      case 'place':
        return l10n.mediaLabelPlace;
    }
    return type;
  }

  // 현재 선택된 매체 — 한 번에 하나. 기본은 widget.initialMedia (없으면 photo).
  // 유효하지 않은 값은 photo로 fallback.
  late String _selectedMedia =
      _mediaTypes.contains(widget.initialMedia) ? widget.initialMedia! : 'photo';

  // scene 필터 — null이면 전체. set이면 그 id에 속한 scene만 recap에 포함.
  Set<String>? _filteredSceneIds;

  void _selectMedia(String type) {
    if (_selectedMedia == type) return;
    HapticFeedback.selectionClick();
    setState(() => _selectedMedia = type);
  }

  Widget _buildMediaBlock(
    List<Scene> scenes, {
    required String media,
    required bool filterActive,
  }) {
    // 매체별 고유 Key — Flutter가 다른 매체의 swiper를 별도 element로 취급해
    // mediaType 변경 시 이전 state 완전 dispose + 새 state fresh mount.
    // 결과: chip 탭 즉시 새 swiper가 마운트되며 loading 상태로 그려짐.
    switch (media) {
      case 'photo':
        return _RecapSwiper(
          key: const ValueKey('photo'),
          scenes: scenes,
          mediaType: 'photo',
          filterActive: filterActive,
          cardBuilder: (item, width, provider) =>
              _PhotoStripCard(item: item, width: width, provider: provider),
        );
      case 'film':
        return _RecapSwiper(
          key: const ValueKey('film'),
          scenes: scenes,
          mediaType: 'film',
          filterActive: filterActive,
          cardBuilder: (item, width, provider) =>
              _FilmTicketCard(item: item, width: width, provider: provider),
        );
      case 'music':
        return _RecapSwiper(
          key: const ValueKey('music'),
          scenes: scenes,
          mediaType: 'music',
          filterActive: filterActive,
          cardBuilder: (item, width, provider) =>
              _MusicLpCard(item: item, width: width, provider: provider),
        );
      // place는 _buildMediaBlock을 거치지 않고 build()에서 별도 layout 분기.
      default:
        return const SizedBox.shrink();
    }
  }

  @override
  Widget build(BuildContext context) {
    final padding = MediaQuery.paddingOf(context);
    final l10n = AppLocalizations.of(context);
    final allScenes = ref.watch(homeViewModelProvider.select((s) => s.scenes));
    final filter = _filteredSceneIds;
    final scenes = filter == null
        ? allScenes
        : allScenes.where((s) => filter.contains(s.id)).toList();
    // 매체 노출 규칙:
    //  - HD: 4개(photo/film/music/place) 모두.
    //  - 무료: photo + 이미 페어에 콘텐츠가 1개 이상 등록된 매체. HD에서 무료로
    //    내려와도 기존에 올린 film/music/place는 그대로 볼 수 있어야 하기 때문.
    // 구독 상태 로딩 중엔 chips를 잠깐 invisible 상태로 두고 ready 시 fade-in
    // — '무료 회원 버전 → 유료 회원 버전' 깜빡임을 방지.
    final subAsync = ref.watch(subscriptionViewModelProvider);
    final subReady = subAsync.hasValue;
    final isHd = subAsync.valueOrNull?.isSubscribed ?? false;
    final hasFilms = scenes.any((s) => s.media.films > 0);
    final hasMusic = scenes.any((s) => s.media.music > 0);
    final hasPlaces = scenes.any((s) => s.media.places > 0);
    final visibleMediaTypes = <String>[
      'photo',
      if (isHd || hasFilms) 'film',
      if (isHd || hasMusic) 'music',
      if (isHd || hasPlaces) 'place',
    ];
    // 사용자가 다른 매체에 머문 상태에서 구독 만료 등으로 visible set이 줄어
    // 들면 'photo'로 자동 fallback.
    final effectiveMedia = visibleMediaTypes.contains(_selectedMedia)
        ? _selectedMedia
        : 'photo';
    final isPlace = effectiveMedia == 'place';
    final bg = context.colors.background;
    final filterActive = filter != null;
    // chip 자체의 자연 높이를 그대로 — SizedBox로 fixed height를 박으면 chip
    // 실제 height와 1~2px 어긋나 overflow가 난다. invisible 상태에서도 chip
    // 자연 layout이 자리를 유지하므로 jump 없음.
    final chipsRow = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: AnimatedOpacity(
        opacity: subReady ? 1.0 : 0.0,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
        child: Row(
          children: [
            for (final type in visibleMediaTypes) ...[
              if (type != visibleMediaTypes.first) const SizedBox(width: 6),
              Expanded(
                child: _MediaToggleChip(
                  icon: FaIcon(
                    _mediaIcons[type]!,
                    size: 14,
                    color: effectiveMedia == type
                        ? context.colors.foreground
                        : context.colors.foregroundMuted
                            .withValues(alpha: 0.4),
                  ),
                  label: _mediaLabel(l10n, type),
                  selected: effectiveMedia == type,
                  onTap: () => _selectMedia(type),
                ),
              ),
            ],
          ],
        ),
      ),
    );

    return Scaffold(
      backgroundColor: bg,
      body: Stack(
        children: [
          if (isPlace) ...[
            // 풀스크린 Mapbox + 자체 하단 그라데이션/메타/액션바. 상단 그라
            // 데이션과 chips는 그 위에 별도 오버레이.
            Positioned.fill(
              child: PlaceRecapView(
                key: const ValueKey('place'),
                scenes: scenes,
                filterActive: filterActive,
              ),
            ),
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [bg, bg.withValues(alpha: 0.85), bg.withValues(alpha: 0.0)],
                    stops: const [0.0, 0.6, 1.0],
                  ),
                ),
                padding: EdgeInsets.only(
                  top: padding.top + DetailAppBar.barHeight + 16,
                  bottom: 40,
                ),
                child: chipsRow,
              ),
            ),
          ] else
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(height: padding.top + DetailAppBar.barHeight + 16),
                // 매체 선택 chips는 노출할 매체가 2개 이상일 때만 표시. 무료
                // 회원이 photo만 있는 경우엔 chip이 의미 없어서 숨기고 그만큼의
                // 세로 공간을 페이징 박스가 가져간다. 무료라도 film/music/place
                // 콘텐츠가 있으면 (HD → 무료 다운그레이드 케이스) 그 매체의
                // chip도 함께 노출.
                if (visibleMediaTypes.length > 1) ...[
                  chipsRow,
                  const SizedBox(height: 8),
                ],
                Expanded(
                  child: _buildMediaBlock(
                    scenes,
                    media: effectiveMedia,
                    filterActive: filterActive,
                  ),
                ),
              ],
            ),
          // 상단 앱바 — X close + 'Recap' 타이틀. place layout에서도 그라데
          // 이션 위에 떠 있는 형태. 우측 액션에는 scene 필터 버튼.
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: DetailAppBar(
              topInset: padding.top,
              title: 'Rewind',
              titleOpacity: 1.0,
              onClose: () => Navigator.of(context).pop(),
              trailing: _FilterButton(
                active: filterActive,
                onTap: () {
                  HapticFeedback.selectionClick();
                  FilterScenesSheet.show(
                    context: context,
                    scenes: allScenes,
                    initialSelected: _filteredSceneIds,
                    onApply: (sel) => setState(() => _filteredSceneIds = sel),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// PlaySceneSheet의 매체 토글과 동일 톤. 헤더 위에서도 동일 패턴으로 재사용.
class _MediaToggleChip extends StatelessWidget {
  const _MediaToggleChip({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final Widget icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          borderRadius: AppRadii.sheetInnerBorder,
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [context.colors.surface, context.colors.surfaceElevated],
          ),
          border: Border.all(
            color: context.colors.foreground.withValues(alpha: 0.06),
            width: 0.5,
          ),
        ),
        child: Column(
          children: [
            icon,
            const SizedBox(height: 5),
            Text(
              label,
              style: AppTypography.body(11, weight: FontWeight.w500).copyWith(
                color: selected
                    ? context.colors.foreground
                    : context.colors.foregroundMuted.withValues(alpha: 0.4),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

typedef _RecapCardBuilder =
    Widget Function(_RecapItem item, double width, ImageProvider provider);

/// 매체별 recap의 공통 스와이퍼 — 좌우 슬라이드, 메타 정보, 액션 버튼, 파트너
/// 리액션 스티커 등 공통 로직. 카드 비주얼은 [cardBuilder]가 매체별로 그림.
class _RecapSwiper extends ConsumerStatefulWidget {
  const _RecapSwiper({
    super.key,
    required this.scenes,
    required this.mediaType,
    required this.cardBuilder,
    required this.filterActive,
  });

  final List<Scene> scenes;
  final String mediaType;
  final _RecapCardBuilder cardBuilder;
  // 사용자가 scene 필터를 걸어둔 상태인지 — 빈 상태일 때 메시지를 'no X yet'
  // vs 'no X in selected scenes'로 분기.
  final bool filterActive;

  @override
  ConsumerState<_RecapSwiper> createState() => _RecapSwiperState();
}

class _RecapSwiperState extends ConsumerState<_RecapSwiper> {
  // lazy 모델 — _items는 scene+content 참조만 보관(_ItemRef). 실제 Content row
  // 는 페이지 진입 시 contentsForSceneProvider에서 처음 fetch.
  List<_ItemRef>? _items;
  Map<String, Scene> _sceneById = {};

  // PageView 기반 페이징. drag follow + snap을 PageView가 자체 처리.
  late final PageController _pageController;
  int _currentIndex = 0;

  final Map<String, ImageProvider> _providers = {};

  // 매체 토글 빠르게 누를 때 이전 _loadContents가 늦게 완료돼 새 매체 위에
  // 옛 매체의 items로 setState하는 race 방지.
  int _loadToken = 0;

  // 결정적 셔플 seed — session 동안 같은 순서. 새 widget(매체 토글)이면 새
  // state라 새 seed가 됨.
  late final int _shuffleSeed;

  ImageProvider _providerFor(String url) =>
      _providers.putIfAbsent(url, () => NetworkImage(url));

  @override
  void initState() {
    super.initState();
    _shuffleSeed = math.Random().nextInt(0x7fffffff);
    _pageController = PageController();
    _sceneById = {for (final s in widget.scenes) s.id: s};
    _loadContents();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant _RecapSwiper oldWidget) {
    super.didUpdateWidget(oldWidget);
    final mediaChanged = oldWidget.mediaType != widget.mediaType;
    // scenes ref 변경만으로 reload하면 부모가 같은 내용으로 rebuild할 때도
    // _loadContents가 돌면서 advance 도중 인덱스를 reset한다. scene id list로
    // 실제 내용이 바뀌었을 때만 reload.
    final scenesChanged = !mediaChanged &&
        !_sameSceneIds(oldWidget.scenes, widget.scenes);
    if (!mediaChanged && !scenesChanged) return;
    if (mediaChanged) {
      _items = null;
    }
    _sceneById = {for (final s in widget.scenes) s.id: s};
    _loadContents();
  }

  bool _sameSceneIds(List<Scene> a, List<Scene> b) {
    if (identical(a, b)) return true;
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i].id != b[i].id) return false;
    }
    return true;
  }

  Future<void> _loadContents() async {
    final token = ++_loadToken;
    final mediaType = widget.mediaType;
    // 1. scene.media count를 이용해 페이지 ref 리스트만 미리 만든다. 실제
    //    Content row는 페이지 진입 시 lazy fetch.
    final raw = <_ItemRef>[];
    for (final scene in widget.scenes) {
      final count = _mediaCountFor(scene.media, mediaType);
      for (var i = 0; i < count; i++) {
        raw.add(_ItemRef(sceneId: scene.id, indexWithinScene: i));
      }
    }
    // 2. seed 기반 결정적 shuffle — 같은 session 안에서 순서 일관.
    final rng = math.Random(_shuffleSeed ^ mediaType.hashCode);
    for (var i = raw.length - 1; i > 0; i--) {
      final j = rng.nextInt(i + 1);
      final tmp = raw[i];
      raw[i] = raw[j];
      raw[j] = tmp;
    }
    // 3. 첫 카드만 미리 fetch + 이미지/팔레트 warm — 첫 진입 깜빡임 방지.
    if (raw.isNotEmpty) {
      final firstRef = raw[0];
      try {
        final contents = await ref.read(
          contentsForSceneProvider(firstRef.sceneId).future,
        );
        if (token != _loadToken || !mounted) return;
        try {
          await ref.read(
            reactionsForSceneProvider(firstRef.sceneId).future,
          );
        } catch (_) {}
        if (token != _loadToken || !mounted) return;
        final firstContent = _resolveContent(
          contents,
          mediaType,
          firstRef.indexWithinScene,
        );
        if (firstContent != null) {
          final url = firstContent.thumbSignedUrl ??
              firstContent.fullSignedUrl;
          if (url != null && url.isNotEmpty) {
            final provider = _providerFor(url);
            try {
              await precacheImage(provider, context);
            } catch (_) {}
            if (token != _loadToken || !mounted) return;
            if (mediaType == 'film') {
              await _FilmTicketCardState.warmPalette(provider);
              if (token != _loadToken || !mounted) return;
            }
          }
        }
      } catch (_) {}
    }
    if (!mounted || token != _loadToken) return;
    setState(() {
      _items = raw;
      _currentIndex = 0;
    });
    if (_pageController.hasClients) {
      _pageController.jumpToPage(0);
    }
    // 첫 진입 직후 이웃 페이지도 미리 fetch.
    _prefetchAround(0);
  }

  int _mediaCountFor(SceneMediaCounts m, String mediaType) {
    switch (mediaType) {
      case 'photo':
        return m.photos;
      case 'film':
        return m.films;
      case 'music':
        return m.music;
      case 'place':
        return m.places;
    }
    return 0;
  }

  Content? _resolveContent(
    List<Content> contents,
    String mediaType,
    int indexWithinScene,
  ) {
    var seen = 0;
    for (final c in contents) {
      if (c.type != mediaType) continue;
      if (seen == indexWithinScene) return c;
      seen++;
    }
    return null;
  }

  _RecapItem? get _currentItem {
    final refs = _items;
    if (refs == null || refs.isEmpty) return null;
    final i = _currentIndex.clamp(0, refs.length - 1);
    final r = refs[i];
    final scene = _sceneById[r.sceneId];
    if (scene == null) return null;
    final contents =
        ref.read(contentsForSceneProvider(r.sceneId)).valueOrNull;
    if (contents == null) return null;
    final content = _resolveContent(
      contents,
      widget.mediaType,
      r.indexWithinScene,
    );
    if (content == null) return null;
    return _RecapItem(content: content, scene: scene);
  }

  Future<void> _openReactionPicker() async {
    final item = _currentItem;
    if (item == null) return;
    HapticFeedback.selectionClick();
    final myId = ref.read(myProfileProvider).valueOrNull?.id;
    if (myId == null) return;
    final sceneId = item.scene.id;
    final contentId = item.content.id;
    final reactions =
        ref.read(reactionsForSceneProvider(sceneId)).valueOrNull?[contentId] ??
        const <Reaction>[];
    Reaction? mine;
    for (final r in reactions) {
      if (r.userId == myId) {
        mine = r;
        break;
      }
    }
    if (!mounted) return;
    await FloatingBottomSheet.show<void>(
      context: context,
      builder: (_) => ReactionPickerSheet(
        initialEmoji: mine?.emoji,
        initialComment: mine?.comment,
        onSubmit: (emoji, comment) async {
          try {
            await ref
                .read(reactionsForSceneProvider(sceneId).notifier)
                .setMyReaction(
                  userId: myId,
                  contentId: contentId,
                  emoji: emoji,
                  comment: comment,
                );
          } catch (_) {
            if (mounted) {
              AppToast.show(
                context,
                AppLocalizations.of(context).reactionSaveFailed,
              );
            }
          }
        },
        onRemove: () async {
          try {
            await ref
                .read(reactionsForSceneProvider(sceneId).notifier)
                .removeMyReaction(userId: myId, contentId: contentId);
          } catch (_) {
            if (mounted) {
              AppToast.show(
                context,
                AppLocalizations.of(context).reactionRemoveFailed,
              );
            }
          }
        },
      ),
    );
  }

  /// 사진 또는 메타 영역 탭 → 해당 사진의 contents detail 열기.
  /// scene의 전체 contents 리스트에서 현재 photo id 위치에 anchoring.
  void _openContentDetail() {
    final item = _currentItem;
    if (item == null) return;
    final contents = ref
        .read(contentsForSceneProvider(item.scene.id))
        .valueOrNull;
    if (contents == null || contents.isEmpty) return;
    final idx = contents.indexWhere((c) => c.id == item.content.id);
    if (idx < 0) return;
    HapticFeedback.selectionClick();
    ContentViewerV2.show(
      context: context,
      contents: contents,
      initialIndex: idx,
      sceneImageUrl: item.scene.coverImageUrl,
      sceneName: item.scene.title,
    );
  }

  /// 현재 페이지에서 [delta]만큼 이동(+1 = 다음, -1 = 이전). PageView가
  /// snap/animation을 직접 처리하므로 여기서는 animateToPage만 호출.
  void _advance(int delta) {
    final items = _items;
    if (items == null || items.isEmpty) return;
    final target = (_currentIndex + delta).clamp(0, items.length - 1);
    if (target == _currentIndex) return;
    HapticFeedback.selectionClick();
    _pageController.animateToPage(
      target,
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
    );
  }

  /// 현재 page에서 ±_prefetchRadius 안의 페이지 scene contents/reactions/
  /// 이미지를 미리 fetch — 빠른 swipe도 buffer되도록.
  static const int _prefetchRadius = 2;

  void _onPageChanged(int page) {
    setState(() => _currentIndex = page);
    _prefetchAround(page);
  }

  String _emptyMessage(AppLocalizations l10n, String mediaType) {
    switch (mediaType) {
      case 'photo':
        return l10n.recapEmptyPhotos;
      case 'film':
        return l10n.recapEmptyFilms;
      case 'music':
        return l10n.recapEmptyMusic;
      case 'place':
        return l10n.recapEmptyPlaces;
    }
    return l10n.recapEmptyPhotos;
  }

  String _filteredEmptyMessage(AppLocalizations l10n, String mediaType) {
    switch (mediaType) {
      case 'photo':
        return l10n.recapFilteredEmptyPhotos;
      case 'film':
        return l10n.recapFilteredEmptyFilms;
      case 'music':
        return l10n.recapFilteredEmptyMusic;
      case 'place':
        return l10n.recapFilteredEmptyPlaces;
    }
    return l10n.recapFilteredEmptyPhotos;
  }

  void _prefetchAround(int page) {
    final refs = _items;
    if (refs == null) return;
    for (var delta = -_prefetchRadius; delta <= _prefetchRadius; delta++) {
      if (delta == 0) continue;
      final neighbor = page + delta;
      if (neighbor < 0 || neighbor >= refs.length) continue;
      final r = refs[neighbor];
      // ignore: discarded_futures
      ref
          .read(contentsForSceneProvider(r.sceneId).future)
          .then((contents) {
        if (!mounted) return;
        final content = _resolveContent(
          contents,
          widget.mediaType,
          r.indexWithinScene,
        );
        if (content == null) return;
        final url =
            content.thumbSignedUrl ?? content.fullSignedUrl;
        if (url == null || url.isEmpty) return;
        final provider = _providerFor(url);
        // ignore: discarded_futures
        precacheImage(provider, context).catchError((_) {});
        if (widget.mediaType == 'film') {
          // PaletteGenerator의 histogram clustering이 main isolate에서
          // 동기로 돌면 스와이프 중 한 프레임을 블로킹해 페이지 전환이
          // 툭 끊긴다. idle priority로 예약해 스크롤 애니메이션이
          // 끝난 뒤에만 돌도록.
          // ignore: discarded_futures
          SchedulerBinding.instance
              .scheduleTask<void>(
                () => _FilmTicketCardState.warmPalette(provider),
                Priority.idle,
              )
              .catchError((_) {});
        }
      }).catchError((_) {});
      // reactions도 미리 — 이웃 페이지의 pill button reaction badge 즉시
      // 결정되도록.
      // ignore: discarded_futures
      ref
          .read(reactionsForSceneProvider(r.sceneId).future)
          .catchError((Object _) => const <String, List<Reaction>>{});
    }
  }

  @override
  Widget build(BuildContext context) {
    final items = _items;
    if (items == null) {
      return const Center(
        child: SizedBox(
          width: 28,
          height: 28,
          child: CircularProgressIndicator(strokeWidth: 1.5),
        ),
      );
    }
    if (items.isEmpty) {
      final l10n = AppLocalizations.of(context);
      final msg = widget.filterActive
          ? _filteredEmptyMessage(l10n, widget.mediaType)
          : _emptyMessage(l10n, widget.mediaType);
      return Center(
        child: Text(
          msg,
          style: AppTypography.body(
            13,
          ).copyWith(color: context.colors.foregroundMuted),
        ),
      );
    }

    // Column으로 영역 분리 — 카드는 Expanded 안에서 상단(chips)과 하단(action
    // bar) 사이의 가용 공간에만 잡힘. action bar는 자체 height만 차지.
    final screenWidth = MediaQuery.sizeOf(context).width;
    final buttonSize = screenWidth >= 420 ? 54.0 : 48.0;
    final iconSize = buttonSize * 0.28;
    final iconColor = context.colors.foreground.withValues(alpha: 0.9);

    return Column(
      children: [
        Expanded(
          child: LayoutBuilder(
              builder: (context, constraints) {
                final cardWidth = (constraints.maxWidth * 0.72).clamp(
                  220.0,
                  360.0,
                );
                return PageView.builder(
                  controller: _pageController,
                  itemCount: items.length,
                  physics: const BouncingScrollPhysics(),
                  // 인접 페이지 itemBuilder가 미리 호출되도록 cacheExtent를
                  // 한 화면 폭만큼 잡음 — Consumer 안 ref.watch가 자동으로
                  // scene contents fetch trigger.
                  allowImplicitScrolling: true,
                  // 카드 boxShadow가 page bounds 밖으로 살짝 흘러도 자르지
                  // 않도록. 인접 페이지 시각 침범은 미미.
                  clipBehavior: Clip.none,
                  onPageChanged: _onPageChanged,
                  itemBuilder: (context, index) {
                    final r = items[index];
                    final scene = _sceneById[r.sceneId];
                    if (scene == null) return const SizedBox.shrink();
                    // 페이지 진입 시점에 그 scene의 contents를 lazy fetch.
                    // 이미 cached면 즉시 data.
                    return Consumer(
                      builder: (context, ref, _) {
                        final contentsAsync =
                            ref.watch(contentsForSceneProvider(r.sceneId));
                        return contentsAsync.when(
                          loading: () => const Center(
                            child: SizedBox(
                              width: 28,
                              height: 28,
                              child: CircularProgressIndicator(
                                strokeWidth: 1.5,
                              ),
                            ),
                          ),
                          error: (_, _) => const SizedBox.shrink(),
                          data: (contents) {
                            final content = _resolveContent(
                              contents,
                              widget.mediaType,
                              r.indexWithinScene,
                            );
                            if (content == null) {
                              return const SizedBox.shrink();
                            }
                            return GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onTap: _openContentDetail,
                              child: Center(
                                child: FittedBox(
                                  fit: BoxFit.scaleDown,
                                  alignment: Alignment.center,
                                  child: KeyedSubtree(
                                    key: ValueKey(content.id),
                                    // 카드 BoxShadow는 painted bounds 밖에
                                    // 그려져 FittedBox 자연 크기에 포함이
                                    // 안 된다. Padding으로 외곽 여유 공간을
                                    // 만들어줘야 scaleDown 후 그림자가
                                    // 잘리지 않는다.
                                    child: Padding(
                                      padding: const EdgeInsets.all(28),
                                      child: widget.cardBuilder(
                                        _RecapItem(
                                          content: content,
                                          scene: scene,
                                        ),
                                        cardWidth,
                                        _providerFor(
                                          content.thumbSignedUrl ??
                                              content.fullSignedUrl ??
                                              '',
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            );
                          },
                        );
                      },
                    );
                  },
                );
              },
            ),
          ),
        // 카드와 액션바 사이 약간의 breathing room (메타 strip은 pill에 통합).
        const SizedBox(height: 12),
        // 하단 액션 바 — [이전] [pill (콘텐츠 메타 + 리액션)] [다음].
        // 첫/마지막 페이지에서는 해당 방향 버튼을 숨기지만 같은 크기의
        // 빈 슬롯을 남겨서 pill의 가로 위치가 흔들리지 않도록 한다.
        if (_currentItem != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                if (_currentIndex > 0)
                  GlassCircleButton(
                    size: buttonSize,
                    onTap: () => _advance(-1),
                    semanticLabel: AppLocalizations.of(context).recapNavPrevious,
                    child: FaIcon(
                      FontAwesomeIcons.backwardStep,
                      size: iconSize,
                      color: iconColor,
                    ),
                  )
                else
                  SizedBox(width: buttonSize, height: buttonSize),
                const SizedBox(width: 10),
                Expanded(
                  child: RewindPillButton(
                    content: _currentItem!.content,
                    scene: _currentItem!.scene,
                    height: buttonSize,
                    onTapInfo: _openContentDetail,
                    onTapMyReaction: _openReactionPicker,
                  ),
                ),
                const SizedBox(width: 10),
                if (_currentIndex < items.length - 1)
                  GlassCircleButton(
                    size: buttonSize,
                    onTap: () => _advance(1),
                    semanticLabel: AppLocalizations.of(context).recapNavNext,
                    child: FaIcon(
                      FontAwesomeIcons.forwardStep,
                      size: iconSize,
                      color: iconColor,
                    ),
                  )
                else
                  SizedBox(width: buttonSize, height: buttonSize),
              ],
            ),
          ),
        SizedBox(height: MediaQuery.paddingOf(context).bottom + 18),
      ],
    );
  }
}

/// 페이지 → (scene, scene 안 mediaType 필터 후 N번째) 매핑. _items에는 ref만
/// 보관해서 모든 scene contents를 미리 fetch하지 않고도 페이지 수 결정 가능.
class _ItemRef {
  const _ItemRef({required this.sceneId, required this.indexWithinScene});
  final String sceneId;
  final int indexWithinScene;
}

class _RecapItem {
  const _RecapItem({required this.content, required this.scene});
  final Content content;
  final Scene scene;

  /// payload의 width/height에서 산출한 사진 비율. 없으면 null (호출자가 fallback).
  double? get aspect {
    final w = content.payload['width'];
    final h = content.payload['height'];
    if (w is int && h is int && w > 0 && h > 0) return w / h;
    return null;
  }
}

/// 35mm 필름 프레임 — 검정 필름 body + 위/아래 sprocket hole 줄 + 사진(실제
/// 비율 유지) + 가장자리에 frame number / scene 타이틀 annotation.
class _PhotoStripCard extends StatelessWidget {
  const _PhotoStripCard({
    required this.item,
    required this.width,
    required this.provider,
  });

  final _RecapItem item;
  final double width;
  final ImageProvider provider;

  // 필름 베이스 — Kodak Portra 120 medium-format 톤. 거의 순수 검정.
  static const Color _filmBody = Color(0xFF050505);
  // 에지 코드 잉크 — 살짝 톤다운된 오프 화이트. 실제 Portra edge print가
  // 빛 자국 + 톤다운된 흰색으로 찍히는 인상.
  static const Color _edgeInk = Color(0xFFD8D5CF);

  @override
  Widget build(BuildContext context) {
    final aspect = item.aspect ?? 1.0;
    final mono9 = GoogleFonts.robotoMono(
      textStyle: const TextStyle(
        color: _edgeInk,
        fontSize: 8.5,
        fontWeight: FontWeight.w500,
        letterSpacing: 1.2,
        height: 1.0,
      ),
    );
    // Portra 120 스타일 edge code — 상단은 barcode/얼룩 패턴, 하단은 ▶+번호 +
    // scene 이름. partner reaction sticker는 _RecapSwiper level에서 native
    // size로 별도 overlay (FittedBox 영향 안 받음).
    return _buildBody(mono9, aspect);
  }

  Widget _buildBody(TextStyle mono9, double aspect) {
    return Container(
      width: width,
      decoration: BoxDecoration(
        color: _filmBody,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.6),
            blurRadius: 30,
            offset: const Offset(0, 10),
            spreadRadius: -8,
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 사진 — payload 비율 그대로.
            AspectRatio(
              aspectRatio: aspect,
              child: ColoredBox(
                color: const Color(0xFF1C1C1E),
                child: Image(
                  image: provider,
                  fit: BoxFit.cover,
                  gaplessPlayback: true,
                  errorBuilder: (_, _, _) =>
                      const ColoredBox(color: Color(0xFF1C1C1E)),
                ),
              ),
            ),
            const SizedBox(height: 10),
            // 하단 edge — 좌: ▶ #n, 우: scene 이름.
            Row(
              children: [
                const Icon(Icons.play_arrow_rounded, size: 12, color: _edgeInk),
                const SizedBox(width: 3),
                Text('#${item.scene.number}', style: mono9),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    item.scene.title.toUpperCase(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.end,
                    style: mono9,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Film 매체 recap — 영화 티켓 카드. 상단 포스터(+ 개봉연도 뱃지), 하단은 포스터
/// 에서 추출한 muted 색조의 배경 위에 영화 정보 + TMDB QR.
class _FilmTicketCard extends StatefulWidget {
  const _FilmTicketCard({
    required this.item,
    required this.width,
    required this.provider,
  });

  final _RecapItem item;
  final double width;
  final ImageProvider provider;

  @override
  State<_FilmTicketCard> createState() => _FilmTicketCardState();
}

class _FilmTicketCardState extends State<_FilmTicketCard> {
  // 기본 cream — palette 추출 전/실패 시 fallback.
  static const Color _defaultBg = Color(0xFFEAE3D4);
  // URL별 추출된 palette 색상 정적 캐시 — _RecapSwiper가 진입 시 첫 카드의
  // palette를 미리 워밍해두면 카드 첫 빌드에 default→extracted 깜빡임 없음.
  static final Map<String, Color> _paletteCache = {};

  late Color _bgColor;

  static String? _urlOf(ImageProvider p) => p is NetworkImage ? p.url : null;

  /// 외부에서 미리 palette 추출해 캐시에 저장. _RecapSwiper가 로딩 단계에서
  /// 호출 — 카드가 처음 빌드될 때 cache hit → bg가 처음부터 정확한 색.
  static Future<void> warmPalette(ImageProvider provider) async {
    final url = _urlOf(provider);
    if (url == null || _paletteCache.containsKey(url)) return;
    try {
      final palette = await PaletteGenerator.fromImageProvider(
        provider,
        size: const Size(80, 80),
      );
      _paletteCache[url] =
          palette.lightMutedColor?.color ??
          palette.mutedColor?.color ??
          _defaultBg;
    } catch (_) {
      _paletteCache[url] = _defaultBg;
    }
  }

  @override
  void initState() {
    super.initState();
    final url = _urlOf(widget.provider);
    _bgColor = (url != null ? _paletteCache[url] : null) ?? _defaultBg;
    if (url != null && !_paletteCache.containsKey(url)) {
      _resolvePalette(url);
    }
  }

  @override
  void didUpdateWidget(covariant _FilmTicketCard old) {
    super.didUpdateWidget(old);
    if (old.provider != widget.provider) {
      final url = _urlOf(widget.provider);
      final cached = url != null ? _paletteCache[url] : null;
      setState(() => _bgColor = cached ?? _defaultBg);
      if (url != null && cached == null) {
        _resolvePalette(url);
      }
    }
  }

  Future<void> _resolvePalette(String url) async {
    // histogram clustering이 main isolate에서 돌면서 스와이프 도중
    // 발화되면 프레임을 통째로 먹는다. idle priority로 예약하면
    // PageView snap 애니메이션이 끝난 뒤에만 돌아서 jank가 없다.
    // 결과적으로 background 색은 cream → muted로 살짝 늦게 전환되지만
    // 페이지 전환 자체는 매끄럽다.
    await SchedulerBinding.instance.scheduleTask(
      () => warmPalette(widget.provider),
      Priority.idle,
    );
    if (!mounted) return;
    setState(() => _bgColor = _paletteCache[url] ?? _defaultBg);
  }

  @override
  Widget build(BuildContext context) {
    final payload = widget.item.content.payload;
    final title = (payload['title'] as String?)?.trim().isNotEmpty == true
        ? payload['title'] as String
        : widget.item.scene.title;
    final director = payload['director'] as String?;
    final genres = (payload['genres'] is List)
        ? (payload['genres'] as List).whereType<String>().toList()
        : <String>[];
    final releaseYear = payload['release_year'] is int
        ? payload['release_year'] as int
        : null;
    final runtime = payload['runtime'] is int
        ? payload['runtime'] as int
        : null;
    final watchedAt =
        widget.item.content.occurredAt ?? widget.item.content.createdAt;

    // 포스터(2:3) 높이 — 펀치 path를 그 경계 정확히에 자리 잡는 데 사용.
    final posterHeight = widget.width * 3 / 2;
    const punchRadius = 9.0;

    // 카드 외곽 path 자체에서 좌우 두 원을 빼내 진짜 perforation. shadow는
    // PhysicalShape이 path 따라 그리고, child의 painting도 ClipPath로 한 번
    // 더 명시적으로 잘라서 포스터/정보 영역 양쪽 모두 노치 안으로 fill이
    // 흘러들어가지 않도록.
    final clipper = _PerforationClipper(
      perfRadius: punchRadius,
      perfY: posterHeight,
      borderRadius: 4,
    );
    return PhysicalShape(
      clipper: clipper,
      color: _bgColor,
      shadowColor: Colors.black.withValues(alpha: 0.55),
      elevation: 8,
      child: ClipPath(
        clipper: clipper,
        child: SizedBox(
        width: widget.width,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
                // 상단 포스터 + 개봉연도 뱃지.
                Stack(
                  children: [
                    AspectRatio(
                      aspectRatio: 2 / 3,
                      child: ColoredBox(
                        color: const Color(0xFF1C1C1E),
                        child: Image(
                          image: widget.provider,
                          fit: BoxFit.cover,
                          gaplessPlayback: true,
                          errorBuilder: (_, _, _) =>
                              const ColoredBox(color: Color(0xFF1C1C1E)),
                        ),
                      ),
                    ),
                  ],
                ),
                // 하단 정보 영역.
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.display(18).copyWith(
                          color: Colors.black87,
                          fontWeight: FontWeight.w700,
                          height: 1.2,
                        ),
                      ),
                      if (director != null && director.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Text(
                          director,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.body(
                            12,
                          ).copyWith(color: Colors.black54),
                        ),
                      ],
                      if (genres.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          genres.join(' / '),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.body(
                            11,
                          ).copyWith(color: Colors.black54),
                        ),
                      ],
                      const SizedBox(height: 14),
                      Container(
                        height: 0.6,
                        color: Colors.black.withValues(alpha: 0.15),
                      ),
                      const SizedBox(height: 12),
                      // 3-cell meta — Released / Runtime / Watched.
                      Builder(builder: (context) {
                        final l10n = AppLocalizations.of(context);
                        return Row(
                          children: [
                            Expanded(
                              child: _TicketLabeled(
                                label: l10n.recapTicketReleased,
                                value: releaseYear?.toString() ?? '—',
                              ),
                            ),
                            Expanded(
                              child: _TicketLabeled(
                                label: l10n.recapTicketRuntime,
                                value: runtime != null
                                    ? l10n.runtimeMinutesValue(runtime)
                                    : '—',
                              ),
                            ),
                            Expanded(
                              child: _TicketLabeled(
                                label: l10n.recapTicketWatched,
                                value:
                                    DateFormat('yyyy.MM.dd').format(watchedAt),
                              ),
                            ),
                          ],
                        );
                      }),
                    ],
                  ),
                ),
              ],
            ),
          ),
      ),
    );
  }
}

/// 영화 티켓 카드의 외곽 path — 모서리는 rounded rect, 포스터/정보 영역 이음새
/// 좌우에 두 원만큼 빼냄. PhysicalShape이 이 path 따라 shape + shadow를 그려서
/// 진짜 perforation 효과(카드 자체에 구멍이 뚫린 것처럼 scaffold 배경이 비침).
class _PerforationClipper extends CustomClipper<Path> {
  _PerforationClipper({
    required this.perfRadius,
    required this.perfY,
    required this.borderRadius,
  });

  final double perfRadius;
  final double perfY;
  final double borderRadius;

  @override
  Path getClip(Size size) {
    final cardPath = Path()
      ..addRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(0, 0, size.width, size.height),
          Radius.circular(borderRadius),
        ),
      );
    final leftHole = Path()
      ..addOval(
        Rect.fromCircle(
          center: Offset(0, perfY),
          radius: perfRadius,
        ),
      );
    final rightHole = Path()
      ..addOval(
        Rect.fromCircle(
          center: Offset(size.width, perfY),
          radius: perfRadius,
        ),
      );
    final withLeft = Path.combine(
      PathOperation.difference,
      cardPath,
      leftHole,
    );
    return Path.combine(PathOperation.difference, withLeft, rightHole);
  }

  @override
  bool shouldReclip(covariant _PerforationClipper old) =>
      old.perfRadius != perfRadius ||
      old.perfY != perfY ||
      old.borderRadius != borderRadius;
}

/// 티켓 하단 meta cell — 작은 label + 굵은 value 1줄.
class _TicketLabeled extends StatelessWidget {
  const _TicketLabeled({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label.toUpperCase(),
          style: AppTypography.body(
            9,
            weight: FontWeight.w500,
          ).copyWith(color: Colors.black54, letterSpacing: 0.6),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AppTypography.body(
            12,
            weight: FontWeight.w600,
          ).copyWith(color: Colors.black87),
        ),
      ],
    );
  }
}

/// 음악 매체 recap — 앨범 아트를 CD 디스크 형태로 표시(원형 + 가운데 hole)
/// 하고 그 아래 곡명/아티스트 노출. 다른 카드와 달리 정사각 비율, 가운데 hole은
/// 카드 뒤로 비치는 Scaffold 배경색.
/// Music 매체 recap — 12인치 LP 레코드. 검은 vinyl + 동심원 groove + 가운데
/// 라벨에 앨범 아트. 파트너가 리액션을 남긴 경우 라벨 한가운데에 sticker가
/// 박힌 형태로 표시 (다른 매체와 사이즈는 같지만 회전은 없음).
class _MusicLpCard extends ConsumerWidget {
  const _MusicLpCard({
    required this.item,
    required this.width,
    required this.provider,
  });

  final _RecapItem item;
  final double width;
  final ImageProvider provider;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final payload = item.content.payload;
    final title = (payload['title'] as String?)?.trim().isNotEmpty == true
        ? payload['title'] as String
        : item.scene.title;
    final artist = (payload['artist'] as String?)?.trim() ?? '';
    final holeColor = Theme.of(context).scaffoldBackgroundColor;

    // 실제 12인치 LP는 라벨 지름이 약 4인치 → 디스크의 ~33%. 살짝 키워서 40%
    // (앨범 아트 가독성). spindle 구멍은 정말 작게.
    final labelSize = width * 0.40;
    final spindleSize = width * 0.035;

    return SizedBox(
      width: width,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(
            width: width,
            height: width,
            child: Stack(
              alignment: Alignment.center,
              // sticker가 LP 외곽 경계에 걸쳐 overhang하므로 클립 해제.
              clipBehavior: Clip.none,
              children: [
                // 디스크 그림자.
                Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.55),
                        blurRadius: 26,
                        offset: const Offset(0, 10),
                        spreadRadius: -6,
                      ),
                    ],
                  ),
                ),
                // Vinyl — 검은 디스크. RadialGradient으로 라벨 주변은 살짝
                // 밝게, 가장자리로 갈수록 깊은 검정.
                Container(
                  width: width,
                  height: width,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [Color(0xFF1A1A1C), Color(0xFF0A0A0C)],
                      stops: [0.35, 1.0],
                    ),
                  ),
                ),
                // 동심원 groove — 라벨 외곽부터 vinyl edge 직전까지 옅게.
                SizedBox(
                  width: width,
                  height: width,
                  child: CustomPaint(
                    painter: _LpGroovesPainter(labelRadius: labelSize / 2),
                  ),
                ),
                // 라벨 외곽 highlight ring — vinyl과 라벨 경계.
                Container(
                  width: labelSize + 1,
                  height: labelSize + 1,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.10),
                      width: 0.5,
                    ),
                  ),
                ),
                // 라벨 = 앨범 아트를 원형으로 클립.
                ClipOval(
                  child: SizedBox(
                    width: labelSize,
                    height: labelSize,
                    child: Image(
                      image: provider,
                      fit: BoxFit.cover,
                      gaplessPlayback: true,
                      errorBuilder: (_, _, _) =>
                          const ColoredBox(color: Color(0xFF1C1C1E)),
                    ),
                  ),
                ),
                // Spindle 구멍 — LP의 핵심 시각 요소라 sticker 유무와 상관
                // 없이 항상 그림.
                Container(
                  width: spindleSize,
                  height: spindleSize,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: holeColor,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.6),
                        blurRadius: 2,
                        spreadRadius: 0.3,
                      ),
                    ],
                  ),
                ),
                // 파트너 reaction은 메타 strip(_PhotoInfoStrip)에 통합 표시.
              ],
            ),
          ),
          const SizedBox(height: 20),
          // 곡 제목 + 아티스트.
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: AppTypography.body(
                15,
                weight: FontWeight.w600,
              ).copyWith(color: context.colors.foreground),
            ),
          ),
          if (artist.isNotEmpty) ...[
            const SizedBox(height: 3),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Text(
                artist,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: AppTypography.body(
                  12,
                ).copyWith(color: context.colors.foregroundMuted),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// LP vinyl 동심원 groove. 라벨 외곽 약간 바깥부터 vinyl edge 직전까지 옅은
/// 백색 ring을 일정 간격으로 그려서 진짜 LP의 spiraled groove 인상을 흉내낸다.
class _LpGroovesPainter extends CustomPainter {
  _LpGroovesPainter({required this.labelRadius});

  final double labelRadius;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final outerR = size.width / 2;
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.5
      ..color = Colors.white.withValues(alpha: 0.045);
    for (double r = labelRadius + 6; r < outerR - 3; r += 2.4) {
      canvas.drawCircle(center, r, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _LpGroovesPainter old) =>
      old.labelRadius != labelRadius;
}

/// 앱바 우측의 scene 필터 버튼. 36×36 hit area, 활성 상태일 때 작은 dot으로
/// 필터가 걸려있다는 단서를 줌.
class _FilterButton extends StatelessWidget {
  const _FilterButton({required this.active, required this.onTap});

  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: SizedBox(
        width: 36,
        height: 36,
        child: Stack(
          alignment: Alignment.center,
          clipBehavior: Clip.none,
          children: [
            FaIcon(
              FontAwesomeIcons.layerGroup,
              size: 16,
              color: context.colors.foreground,
            ),
            if (active)
              Positioned(
                right: 8,
                top: 8,
                child: Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: context.colors.foreground,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

