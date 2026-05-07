import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:grain/grain.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/theme/app_colors_ext.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/theme/app_radii.dart';
import '../../../core/widgets/app_toast.dart';
import '../../../core/widgets/confirm_dialog.dart';
import '../../../core/widgets/floating_bottom_sheet.dart';
import '../../content/contents_view_model.dart';
import '../../content/models/content.dart';
import '../../share/data/share_frame_renderer.dart';
import '../../share/data/video_composer.dart';
import '../../share/widgets/share_frame_view.dart';
import '../../subscription/subscription_screen.dart';
import '../../subscription/subscription_view_model.dart';
import '../models/scene.dart';
import 'moment_selection_screen.dart';
import 'scene_title_fallback.dart';

/// Scene 재생 화면.
///
/// 진입 시 선택된 Scene들의 콘텐츠를 로딩한 뒤 재생 모드로 전환.
class PlaySceneScreen extends ConsumerStatefulWidget {
  const PlaySceneScreen({
    super.key,
    required this.scenes,
    this.initialMediaTypes = const {'photo', 'film', 'music', 'place'},
  });

  final List<Scene> scenes;
  // PlaySceneSheet가 토글한 매체 선택을 그대로 받아 초기 필터로 적용.
  // 화면 안의 _PlayFilterSheet에서 추후 변경 가능.
  final Set<String> initialMediaTypes;

  static Route<void> route({
    required List<Scene> scenes,
    Set<String> initialMediaTypes = const {
      'photo',
      'film',
      'music',
      'place',
    },
  }) {
    return PageRouteBuilder<void>(
      opaque: true,
      transitionDuration: const Duration(milliseconds: 400),
      reverseTransitionDuration: Duration.zero,
      pageBuilder: (context, animation, secondaryAnimation) =>
          PlaySceneScreen(
        scenes: scenes,
        initialMediaTypes: initialMediaTypes,
      ),
      transitionsBuilder:
          (context, animation, secondaryAnimation, child) {
        return FadeTransition(opacity: animation, child: child);
      },
    );
  }

  @override
  ConsumerState<PlaySceneScreen> createState() => _PlaySceneScreenState();
}

enum PhotoFilter { normal, vintage, cinema, mono }

/// PhotoFilter → ColorFilter 매핑. 메인 재생 화면(`_PlaySceneScreenState`)과
/// 공유 시트의 정지 미리보기가 같은 톤을 보여주도록 공유. matrix 값 변경 시
/// 한 곳에서만 수정하면 됨.
ColorFilter? _colorFilterFor(PhotoFilter f) {
  switch (f) {
    case PhotoFilter.normal:
      return null;
    case PhotoFilter.vintage:
      // 레트로 필름: 따뜻한 앰버 톤, 높은 콘트라스트, 틸 쉐도우, faded blacks
      return const ColorFilter.matrix(<double>[
        0.90, 0.12, 0.02, 0, 20,
        0.06, 0.75, 0.10, 0, 10,
        0.02, 0.08, 0.58, 0, 12,
        0,    0,    0,    1, 0,
      ]);
    case PhotoFilter.cinema:
      // 틸-오렌지 컬러 그레이딩: 스킨톤 따뜻하게, 쉐도우 틸/시안, 높은 콘트라스트
      return const ColorFilter.matrix(<double>[
        0.85, 0.12, 0.02, 0, 12,
        0.05, 0.80, 0.08, 0, 5,
        0.0,  0.10, 0.82, 0, 18,
        0,    0,    0,    1, 0,
      ]);
    case PhotoFilter.mono:
      return const ColorFilter.matrix(<double>[
        0.2126, 0.7152, 0.0722, 0, 0,
        0.2126, 0.7152, 0.0722, 0, 0,
        0.2126, 0.7152, 0.0722, 0, 0,
        0,      0,      0,      1, 0,
      ]);
  }
}

class _PlaySceneScreenState extends ConsumerState<PlaySceneScreen>
    with SingleTickerProviderStateMixin {
  bool _expanding = false;
  bool _playing = false;
  // 로딩 UI(progress bar + 안내 문구 + scene 이름 carousel)의 fade-out
  // 트리거. min duration 다 지나면 true로 세팅되고, AnimatedOpacity가 350ms
  // 동안 0으로 흘러감. 그 fade가 끝난 뒤 expansion 시작.
  bool _loadingDismissed = false;
  // 로딩 완료 후 재생 진입 전까지 _playIndex를 play 속도(750ms)로 cycle.
  // 재생 진입 시 cancel되고 _scheduleNextContent가 이어받는다.
  Timer? _autoCycleTimer;
  // dispose 시 원래대로 돌릴 ImageCache 한도.
  int? _imageCacheBytesBefore;
  int? _imageCacheCountBefore;
  PhotoFilter _photoFilter = PhotoFilter.normal;
  bool _paused = false;
  // Pause 중 좌우 tilt로 cover-fit된 사진의 가려진 영역을 들춰보는 parallax.
  // ValueNotifier로 두면 stream 업데이트가 ValueListenableBuilder만 리빌드하고
  // 화면 전체 setState 없이 alignment만 갱신할 수 있다.
  final ValueNotifier<double> _tiltX = ValueNotifier(0.0);
  StreamSubscription<AccelerometerEvent>? _accelSub;
  int _playIndex = 0;
  int _infoIndex = 0;
  double _loadProgress = 0;
  int _currentLoadingIndex = 0;
  final Set<int> _completedScenes = {};
  final List<String> _loadedThumbs = [];
  // 전체 콘텐츠 (필터 전)
  final List<String> _allPlayUrls = [];
  final Map<String, NetworkImage> _imageProviders = {};
  final List<int> _allPlaySceneIndex = [];
  final List<DateTime> _allPlayDates = [];
  final List<String> _allMediaTypes = [];
  // payload(title/director/artist/...) 접근용 — 카드 하단 텍스트 표시.
  final List<Content> _allContents = [];

  // 필터 적용 후 재생 대상
  List<String> _playUrls = [];
  List<int> _playSceneIndex = [];
  List<DateTime> _playDates = [];
  List<String> _filteredMediaTypes = [];
  List<Content> _filteredContents = [];

  // 필터 상태 — initState에서 초기 매체 선택을 widget.initialMediaTypes 로
  // 동기화. 화면 안 _PlayFilterSheet에서 사용자가 변경 가능.
  late Set<String> _selectedSceneIds;
  late Set<String> _selectedMediaTypes;
  /// MomentSelectionScreen → Done → Apply까지 거쳐 commit된 moment 선택.
  /// 비어 있으면 "전체 재생" 의미.
  final Set<String> _selectedMomentIds = {};

  final _dialKey = GlobalKey<_IndexDialState>();
  late final AnimationController _expandController;
  late final Animation<double> _expandAnimation;
  bool _autoPlayScheduled = false;

  @override
  void initState() {
    super.initState();
    // Flutter ImageCache 기본 한도(100MB, 1000 entries)는 사진 ~30장이 들어
    // 가면 LRU eviction 시작 → cycle wraparound(last → first) 시점에 첫 사진
    // 이 evict돼 다시 fetch하느라 한 프레임 검정 플래시. play 동안만 한도를
    // 넉넉히 잡아 모든 play URL을 hot 유지. dispose에서 원복.
    final cache = PaintingBinding.instance.imageCache;
    _imageCacheBytesBefore = cache.maximumSizeBytes;
    _imageCacheCountBefore = cache.maximumSize;
    cache.maximumSizeBytes = 500 << 20; // 500 MiB
    cache.maximumSize = 5000;

    _selectedSceneIds = widget.scenes.map((s) => s.id).toSet();
    _selectedMediaTypes = Set.of(widget.initialMediaTypes);
    _expandController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _expandAnimation = CurvedAnimation(
      parent: _expandController,
      curve: Curves.easeInOut,
    );
    _expandController.addStatusListener((status) {
      if (status == AnimationStatus.completed && mounted) {
        setState(() {
          _expanding = false;
          _playing = true;
        });
        // 재생 진입 → 자동 cycle은 _scheduleNextContent로 인계.
        _autoCycleTimer?.cancel();
        _autoCycleTimer = null;
        _scheduleNextContent();
      }
    });
    _loadContent();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    });
  }

  /// 모든 thumb 로드 완료 후 expansion 전까지 _playIndex를 play 속도(750ms)
  /// 로 자동 cycle. 같은 widget 트리·같은 cycle 속도라 expansion 도중에도
  /// 멈춤·끊김 없이 자연스럽게 재생 모드로 이어진다.
  static const _autoCycleInterval = Duration(milliseconds: 750);

  void _startAutoCycle() {
    _autoCycleTimer?.cancel();
    _autoCycleTimer = Timer.periodic(_autoCycleInterval, (_) {
      if (!mounted || _playing) return;
      // 필터 적용된 _playUrls가 있으면 그걸 기준 — 안 그러면 _playIndex가
      // 필터 길이를 넘어 RangeError + 잘못된 type lookup으로 카드/사진 분기
      // 어긋남.
      final list = _playUrls.isNotEmpty ? _playUrls : _allPlayUrls;
      if (list.isEmpty) return;
      setState(() {
        _playIndex = (_playIndex + 1) % list.length;
      });
    });
  }

  bool _coversPrecached = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_coversPrecached) {
      _coversPrecached = true;
      _precacheSceneCovers();
    }
  }

  void _precacheSceneCovers() {
    for (final scene in widget.scenes) {
      // cover 없는 scene이면 빈 string → NetworkImage('')가 file:/// URI로
      // 파싱돼 "No host specified" 예외. 비어있으면 skip.
      final url = scene.coverImageUrl;
      if (url.isEmpty) continue;
      precacheImage(NetworkImage(url), context);
    }
  }

  /// 선택된 Scene들의 contents를 순차로 로드. scene_summary가 알려주는
  /// type별 count는 무시 — 각 scene의 contentsForSceneProvider로 실제 row를
  /// 받아 fullSignedUrl로 재생, thumbSignedUrl로 로딩 미리보기.
  ///
  /// 사용자가 방금 scene_detail에서 진입했다면 그 scene은 이미 cache hot이라
  /// 즉시 반환. 다른 scene들은 fresh fetch. cache가 핫해서 너무 빨리 끝나면
  /// 로딩 시퀀스가 휙 지나가 어색하니 [_minLoadingDuration] 보장.
  static const _minLoadingDuration = Duration(seconds: 3);

  Future<void> _loadContent() async {
    final startedAt = DateTime.now();
    final total = widget.scenes.length;
    final repo = ref.read;

    for (int s = 0; s < total; s++) {
      if (!mounted) return;
      setState(() => _currentLoadingIndex = s);

      final scene = widget.scenes[s];
      List<Content> contents;
      try {
        contents = await repo(contentsForSceneProvider(scene.id).future);
      } catch (_) {
        contents = const [];
      }

      for (final content in contents) {
        if (!mounted) return;
        final fullUrl = content.fullSignedUrl;
        if (fullUrl == null || fullUrl.isEmpty) continue;
        final thumbUrl = content.thumbSignedUrl ?? fullUrl;

        final provider = NetworkImage(fullUrl);
        _imageProviders[fullUrl] = provider;
        _allPlayUrls.add(fullUrl);
        _allPlaySceneIndex.add(s);
        // photo는 EXIF taken_at이 occurredAt에 들어감, 그 외는 createdAt fallback.
        _allPlayDates.add(content.occurredAt ?? content.createdAt);
        _allMediaTypes.add(content.type);
        _allContents.add(content);
        precacheImage(provider, context);

        if (mounted) {
          setState(() {
            _loadedThumbs.add(thumbUrl);
            // 새로 들어온 사진을 즉시 화면에 — 사진 로딩 진행을 따라 표시.
            _playIndex = _allPlayUrls.length - 1;
          });
        }
      }

      if (!mounted) return;
      setState(() {
        _completedScenes.add(s);
        _loadProgress = (s + 1) / total;
      });
    }

    if (!mounted) return;
    _applyFilter();
    if (_playUrls.isEmpty) {
      // 콘텐츠가 아예 없거나, 필터로 다 걸러져서 재생할 게 없는 경우 토스트
      // 띄우고 화면 pop.
      AppToast.show(context, 'No moments to play.');
      Navigator.of(context).pop();
      return;
    }
    {
      // 모든 사진 로드 완료 → play와 동일 속도로 자동 cycle 시작. min duration
      // 대기 동안에도, expansion 도중에도, 재생 진입 직후에도 같은 cycle이
      // 흘러가다 _scheduleNextContent로 매끈하게 인계 (전환 끊김 없음).
      _startAutoCycle();

      // 빠르게 끝나도 로딩 시퀀스가 휙 지나가면 어색 — _minLoadingDuration 보장.
      final elapsed = DateTime.now().difference(startedAt);
      final remaining = _minLoadingDuration - elapsed;
      if (remaining > Duration.zero) {
        await Future<void>.delayed(remaining);
      }
      if (!mounted) return;
      // 로딩 UI fade out 먼저 → 끝나면 expansion 시작. 두 모션이 겹치지 않게.
      setState(() => _loadingDismissed = true);
      await Future<void>.delayed(const Duration(milliseconds: 350));
      if (!mounted) return;
      _startPlay();
    }
  }

  ColorFilter? get _colorFilter => _colorFilterFor(_photoFilter);

  Widget _wrapGrain({required bool enabled, required Widget child}) {
    if (!enabled) return child;
    return GrainFiltered(
      scale: 0.4,
      child: child,
    );
  }

  /// 현재 인덱스의 콘텐츠 렌더. 로딩 중·재생 중 모두 같은 widget tree.
  ///
  /// type별 레이아웃:
  /// - **photo**: 화면 전체 cover-fit (사진 자체가 주인공)
  /// - **film / music / place**: 블러된 같은 이미지를 backdrop으로 깔고
  ///   가운데에 카드 (film 2:3, music/place 1:1). 카드는 상단 safearea와
  ///   하단 utility row 사이 영역의 center.
  Widget _buildPlayerImage() {
    final list = _playUrls.isNotEmpty ? _playUrls : _allPlayUrls;
    if (list.isEmpty) return const SizedBox.shrink();
    final url = list[_playIndex % list.length];
    final provider = _imageProviders[url];
    if (provider == null) return const SizedBox.shrink();

    final typeList =
        _filteredMediaTypes.isNotEmpty ? _filteredMediaTypes : _allMediaTypes;
    // list.length로 modulo — _playIndex가 일시적으로 필터 길이 넘어가도
    // 항상 valid index가 나오게.
    final type = typeList.isEmpty
        ? 'photo'
        : typeList[_playIndex % typeList.length];
    final contentList =
        _filteredContents.isNotEmpty ? _filteredContents : _allContents;
    final content = contentList.isEmpty
        ? null
        : contentList[_playIndex % contentList.length];

    // 메인(전경) 이미지. frameBuilder가 _infoIndex 트래킹.
    // alignmentX는 paused 중 좌우 tilt parallax. type=='photo'에서만 의미가
    // 있고(전체화면 cover-fit) 카드형은 AspectRatio 안에 들어가서 alignment
    // 효과가 없다.
    Image buildPhoto(double alignmentX) => Image(
          image: provider,
          fit: BoxFit.cover,
          alignment: Alignment(alignmentX, 0.0),
          gaplessPlayback: true,
          filterQuality: FilterQuality.medium,
          frameBuilder: (context, child, frame, loaded) {
            if (frame != null && _infoIndex != _playIndex) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) setState(() => _infoIndex = _playIndex);
              });
            }
            return child;
          },
          errorBuilder: (_, _, _) => const SizedBox.shrink(),
        );

    Widget mainImage;
    if (type == 'photo') {
      // tilt notifier 변경 시 ValueListenableBuilder만 리빌드 — 다른 widget
      // tree(앱바·하단 버튼 등)는 영향 없음.
      mainImage = ValueListenableBuilder<double>(
        valueListenable: _tiltX,
        builder: (_, tilt, _) => buildPhoto(tilt),
      );
    } else {
      mainImage = buildPhoto(0.0);
    }

    final colorFilter = _colorFilter;
    if (colorFilter != null) {
      mainImage = ColorFiltered(colorFilter: colorFilter, child: mainImage);
    }

    // photo는 기존대로 화면 전체.
    if (type == 'photo') return mainImage;

    // 카드 형태 매체. 같은 이미지를 강하게 blur한 fullscreen backdrop +
    // 살짝 다크 dim → 카드 가독성. 카드는 AspectRatio로 type별 비율 유지.
    final cardAspect = type == 'film' ? 2 / 3 : 1.0;
    final padding = MediaQuery.paddingOf(context);
    // 하단 utility row 위 + 상단 safearea 아래로 카드 영역 한정.
    final topReserve = padding.top + 32;
    final bottomReserve = padding.bottom + 16 + 48 + 32;

    return Stack(
      fit: StackFit.expand,
      children: [
        // 블러 backdrop — 별도 Image 인스턴스. backdrop은 흐려서 filterQuality
        // low면 충분 + 성능.
        Positioned.fill(
          child: ImageFiltered(
            imageFilter: ImageFilter.blur(sigmaX: 60, sigmaY: 60),
            child: Image(
              image: provider,
              fit: BoxFit.cover,
              gaplessPlayback: true,
              filterQuality: FilterQuality.low,
              errorBuilder: (_, _, _) => const SizedBox.shrink(),
            ),
          ),
        ),
        // 다크 dim — 카드와 backdrop 대비 보강.
        Positioned.fill(
          child: ColoredBox(color: Colors.black.withValues(alpha: 0.25)),
        ),
        // 가운데 카드 + 하단 title/subtitle. type별 텍스트 매핑은
        // content_viewer_v2 카드들과 동일.
        Padding(
          padding: EdgeInsets.only(
            top: topReserve,
            bottom: bottomReserve,
            left: 32,
            right: 32,
          ),
          child: _CardLayout(
            aspect: cardAspect,
            card: ClipRRect(
              borderRadius: AppRadii.mdBorder,
              child: mainImage,
            ),
            title: _cardTitle(type, content),
            subtitle: _cardSubtitle(type, content),
          ),
        ),
      ],
    );
  }

  static String? _cardTitle(String type, Content? content) {
    if (content == null) return null;
    final p = content.payload;
    switch (type) {
      case 'film':
      case 'music':
        return p['title'] as String?;
      case 'place':
        return p['name'] as String?;
      default:
        return null;
    }
  }

  static String? _cardSubtitle(String type, Content? content) {
    if (content == null) return null;
    final p = content.payload;
    switch (type) {
      case 'film':
        return p['director'] as String?;
      case 'music':
        return p['artist'] as String?;
      case 'place':
        return p['address'] as String?;
      default:
        return null;
    }
  }

  void _startPlay() {
    setState(() => _expanding = true);
    _expandController.forward();
  }

  void _togglePause() {
    setState(() => _paused = !_paused);
    if (!_paused) _scheduleNextContent();
  }

  void _scheduleNextContent() {
    if (!mounted || !_playing || _paused || _autoPlayScheduled) return;
    _autoPlayScheduled = true;
    Future<void>.delayed(const Duration(milliseconds: 750), () {
      if (!mounted || !_playing || _paused) {
        _autoPlayScheduled = false;
        return;
      }
      _autoPlayScheduled = false;
      setState(() {
        _playIndex = (_playIndex + 1) % _playUrls.length;
      });
      HapticFeedback.selectionClick();
      _scheduleNextContent();
    });
  }

  void _applyFilter() {
    _playUrls = [];
    _playSceneIndex = [];
    _playDates = [];
    _filteredMediaTypes = [];
    _filteredContents = [];

    for (int i = 0; i < _allPlayUrls.length; i++) {
      final sceneId = widget.scenes[_allPlaySceneIndex[i]].id;
      final mediaType = _allMediaTypes[i];
      if (_selectedSceneIds.contains(sceneId) &&
          _selectedMediaTypes.contains(mediaType)) {
        _playUrls.add(_allPlayUrls[i]);
        _playSceneIndex.add(_allPlaySceneIndex[i]);
        _playDates.add(_allPlayDates[i]);
        _filteredMediaTypes.add(mediaType);
        _filteredContents.add(_allContents[i]);
      }
    }

    if (_playIndex >= _playUrls.length) {
      _playIndex = _playUrls.isEmpty ? 0 : _playIndex % _playUrls.length;
    }
  }

  /// 공유 바텀시트. 열리는 동안 메인 재생은 일시정지, 닫히면 원래 상태로 복귀.
  /// 시트 안의 미리보기는 자체 타이머로 같은 필터·같은 항목들을 9:16 비율로
  /// 계속 cycle. 채널 탭 시 시트가 직접 frame 렌더 → MP4 합성 → 저장/공유까지
  /// 처리하고 toast 후 닫힘.
  Future<void> _showShareSheet() async {
    if (_playUrls.isEmpty) return;
    final wasPaused = _paused;
    setState(() => _paused = true);

    // 미리보기에 넘길 frame들 — 필터 적용 후 재생 대상에서 그대로 추출.
    // 영상 길이/렌더 시간 폭주 방지를 위해 최대 100장까지만 cap.
    // renderUrl엔 thumbSignedUrl을 넣어 frame 렌더 단계의 storage egress 감소.
    // 미리보기는 url(full)로 그대로라 시트 안 화질은 영향 X.
    final maxFrames = math.min(_playUrls.length, 100);
    final frames = <ShareFrame>[
      for (var i = 0; i < maxFrames; i++)
        ShareFrame(
          url: _playUrls[i],
          renderUrl: _filteredContents[i].thumbSignedUrl,
          sceneName: widget.scenes[_playSceneIndex[i]].title,
          occurredAt: _playDates[i],
          mediaType: _filteredMediaTypes[i],
        ),
    ];
    final initialIndex = _playIndex % _playUrls.length;

    await FloatingBottomSheet.show<void>(
      context: context,
      builder: (_) => _ShareSheet(
        frames: frames,
        initialIndex: initialIndex,
        photoFilter: _photoFilter,
      ),
    );

    if (!mounted) return;
    if (!wasPaused && _playUrls.isNotEmpty) {
      setState(() => _paused = false);
      _scheduleNextContent();
    }
  }

  void _showFilterSheet() {
    final wasPaused = _paused;
    setState(() => _paused = true);

    FloatingBottomSheet.show(
      context: context,
      builder: (_) => _PlayFilterSheet(
        scenes: widget.scenes,
        selectedSceneIds: Set.of(_selectedSceneIds),
        selectedMediaTypes: Set.of(_selectedMediaTypes),
        selectedMomentIds: Set.of(_selectedMomentIds),
        photoFilter: _photoFilter,
        onApply: (sceneIds, mediaTypes, momentIds, filter) {
          setState(() {
            _selectedSceneIds = sceneIds;
            _selectedMediaTypes
              ..clear()
              ..addAll(mediaTypes);
            _selectedMomentIds
              ..clear()
              ..addAll(momentIds);
            _photoFilter = filter;
            _applyFilter();
            _playIndex = 0;
            _infoIndex = 0;
            if (!wasPaused && _playUrls.isNotEmpty) {
              _paused = false;
              _scheduleNextContent();
            }
          });
          // 필터 결과가 0이면 재생할 콘텐츠가 없음 — 안내 후 화면 pop.
          if (_playUrls.isEmpty) {
            AppToast.show(context, 'No moments to play.');
            Navigator.of(context).pop();
          }
        },
      ),
    ).then((_) {
      if (!wasPaused && _playUrls.isNotEmpty && mounted) {
        setState(() => _paused = false);
        _scheduleNextContent();
      }
    });
  }

  Scene get _currentScene {
    if (_playSceneIndex.isEmpty) return widget.scenes.first;
    final i = _infoIndex % _playSceneIndex.length;
    return widget.scenes[_playSceneIndex[i]];
  }

  Widget _buildPlayInfo() {
    final scene = _currentScene;
    if (_playDates.isEmpty) {
      return const SizedBox.shrink();
    }
    final date = _playDates[_infoIndex % _playDates.length];
    final dateStr = '${date.year}.${date.month.toString().padLeft(2, '0')}.${date.day.toString().padLeft(2, '0')}';

    return Row(
      children: [
        ClipOval(
          child: SizedBox(
            width: 32,
            height: 32,
            child: scene.coverImageUrl.isEmpty
                ? SceneTitleFallback(title: scene.title)
                : Image.network(
                    scene.coverImageUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) =>
                        SceneTitleFallback(title: scene.title),
                  ),
          ),
        ),
        const SizedBox(width: 10),
        Flexible(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                scene.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.body(13, weight: FontWeight.w600)
                    .copyWith(color: Colors.white),
              ),
              const SizedBox(height: 1),
              Text(
                dateStr,
                style: AppTypography.body(11).copyWith(
                  color: Colors.white.withValues(alpha: 0.5),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// `_paused` 상태에 따라 accelerometer stream을 자동 토글. 매 setState
  /// 호출자가 직접 켜고 끌 필요 없이 build 시작 시 한 번 동기화.
  void _syncTiltSubscription() {
    if (_paused && _accelSub == null) {
      _accelSub = accelerometerEventStream(
        samplingPeriod: const Duration(milliseconds: 33),
      ).listen((event) {
        // event.x: iOS portrait 기준 디바이스가 오른쪽으로 기울면 양수.
        // ±2를 풀스윙(약 12°)으로 매핑 — 작은 손목 회전만으로도 풀 팬.
        final target = (event.x / 2.0).clamp(-1.0, 1.0);
        // EMA 스무딩 — 손떨림 노이즈 억제. factor 0.12 → 약 250ms 응답.
        _tiltX.value = _tiltX.value + (target - _tiltX.value) * 0.12;
      });
    } else if (!_paused && _accelSub != null) {
      _accelSub!.cancel();
      _accelSub = null;
      _tiltX.value = 0.0;
    }
  }

  @override
  Widget build(BuildContext context) {
    _syncTiltSubscription();
    final padding = MediaQuery.paddingOf(context);

    Widget body = Stack(
          children: [
            // 검정 backdrop — 클립 바깥은 항상 검정.
            const Positioned.fill(child: ColoredBox(color: Colors.black)),

            // 이미지는 항상 화면 전체 크기. 쌍안경 모양의 ClipPath가
            // progress(0→1)로 확장하면서 보이는 영역이 넓어진다. 이미지 자체
            // 는 움직이지 않으므로 확장 중 zoom 인상이 없음.
            Positioned.fill(
              child: AnimatedBuilder(
                animation: _expandAnimation,
                builder: (context, child) {
                  final p = _playing
                      ? 1.0
                      : (_expanding ? _expandAnimation.value : 0.0);
                  return ClipPath(
                    clipper: _BinocularClipper(progress: p),
                    child: child,
                  );
                },
                child: _wrapGrain(
                  enabled: _playing && _photoFilter != PhotoFilter.normal,
                  child: SizedBox.expand(
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        // 쌍안경 안쪽 base 톤. 첫 사진이 도착하기 전까지만
                        // 보이고, 사진이 깔리면 그 위로 덮인다.
                        const ColoredBox(color: Color(0xFF1A1A1C)),
                        // 로딩·확장·재생 모두 같은 widget tree. _playIndex만
                        // 바뀌면 Image의 `image` 필드만 swap → gaplessPlayback
                        // 으로 끊김 없이 다음 사진. expansion 도중에도 image
                        // 자체는 같은 위치·크기에 그대로 있어 자연스럽게 이어짐.
                        _buildPlayerImage(),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            // 화면 좌우 드래그 → 일시정지 + 다이얼 조작
            if (_playing)
              Positioned.fill(
                child: GestureDetector(
                  behavior: HitTestBehavior.translucent,
                  onTap: _paused ? () {
                    setState(() => _paused = false);
                    _scheduleNextContent();
                  } : null,
                  onHorizontalDragStart: (d) {
                    if (!_paused) {
                      setState(() => _paused = true);
                    }
                    _dialKey.currentState?.onDragStart(d);
                  },
                  onHorizontalDragUpdate: (d) {
                    _dialKey.currentState?.onDragUpdate(d);
                  },
                  onHorizontalDragEnd: (d) {
                    _dialKey.currentState?.onDragEnd(d);
                  },
                ),
              ),

            // 하단 그라데이션
            if (_playing)
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: IgnorePointer(
                  child: Container(
                    height: padding.bottom + 160,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.bottomCenter,
                        end: Alignment.topCenter,
                        colors: [
                          Colors.black.withValues(alpha: 0.5),
                          Colors.black.withValues(alpha: 0.0),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

            // 인덱스 다이얼
            if (_playing && _playUrls.isNotEmpty)
              Positioned(
                left: 0,
                right: 0,
                bottom: padding.bottom + 16 + 48 + 24,
                child: AnimatedOpacity(
                  opacity: _paused ? 1.0 : 0.0,
                  duration: const Duration(milliseconds: 250),
                  child: IgnorePointer(
                    ignoring: !_paused,
                    child: _IndexDial(
                      key: _dialKey,
                      total: _playUrls.length,
                      current: _playIndex,
                      onChanged: (index) {
                        setState(() {
                          _playIndex = index;
                        });
                        HapticFeedback.selectionClick();
                      },
                    ),
                  ),
                ),
              ),

            // 하단 플레이어 바
            if (_playing)
              Positioned(
                left: 0,
                right: 0,
                bottom: padding.bottom + 16,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    children: [
                      _BlurPill(
                        onTap: () async {
                          final wasPaused = _paused;
                          if (!wasPaused) setState(() => _paused = true);
                          final confirmed = await ConfirmDialog.show(
                            context: context,
                            title: 'Stop playing?',
                            confirmLabel: 'Stop',
                            isDestructive: true,
                          );
                          if (!mounted) return;
                          if (confirmed) {
                            _restoreSystemUI();
                            Navigator.of(this.context).pop();
                          } else if (!wasPaused) {
                            setState(() => _paused = false);
                            _scheduleNextContent();
                          }
                        },
                        isCircle: true,
                        child: const FaIcon(
                          FontAwesomeIcons.xmark,
                          size: 16,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _BlurPill(
                          onTap: () {},
                          padding: EdgeInsets.zero,
                          child: Row(
                            children: [
                              Expanded(
                                child: GestureDetector(
                                  behavior: HitTestBehavior.opaque,
                                  onTap: _showFilterSheet,
                                  child: Padding(
                                    padding: const EdgeInsets.only(left: 10),
                                    child: _buildPlayInfo(),
                                  ),
                                ),
                              ),
                              Container(
                                width: 0.5,
                                height: 24,
                                color: Colors.white.withValues(alpha: 0.2),
                              ),
                              GestureDetector(
                                behavior: HitTestBehavior.opaque,
                                onTap: _togglePause,
                                child: SizedBox(
                                  width: 48,
                                  child: Center(
                                    child: FaIcon(
                                      _paused
                                          ? FontAwesomeIcons.play
                                          : FontAwesomeIcons.pause,
                                      size: 13,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      _BlurPill(
                        onTap: _showShareSheet,
                        isCircle: true,
                        child: const FaIcon(
                          FontAwesomeIcons.arrowUpFromBracket,
                          size: 14,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            // 하단 정보 (로딩 progress + scene 이름). expansion 시작 전에
            // _loadingDismissed=true가 되면 350ms 동안 fade out, 그 fade가
            // 끝난 뒤에야 expansion 애니메이션 시작.
            if (!_playing)
              Positioned(
                left: 48,
                right: 48,
                bottom: padding.bottom + 80,
                child: AnimatedOpacity(
                  opacity: _loadingDismissed ? 0 : 1,
                  duration: const Duration(milliseconds: 350),
                  curve: Curves.easeOut,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // 로딩 완료 후에도 expansion 시작 전(min duration 대기
                      // 포함)까진 progress bar 노출 유지 — 너무 휙 사라지지
                      // 않게. expansion이 시작되면 infoOpacity가 0으로 빠르게
                      // 떨어져 자연스럽게 fade out.
                      ClipRRect(
                        borderRadius: AppRadii.xsBorder,
                        child: TweenAnimationBuilder<double>(
                          tween: Tween(begin: 0, end: _loadProgress),
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.linear,
                          builder: (context, value, _) {
                            return SizedBox(
                              width: 120,
                              child: LinearProgressIndicator(
                                value: value,
                                minHeight: 3,
                                backgroundColor:
                                    Colors.white.withValues(alpha: 0.08),
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  Colors.white.withValues(alpha: 0.4),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        'Preparing scenes...',
                        style: AppTypography.body(14).copyWith(
                          color: Colors.white.withValues(alpha: 0.5),
                        ),
                      ),
                      const SizedBox(height: 16),
                      ShaderMask(
                        shaderCallback: (bounds) => const LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.transparent,
                            Colors.white,
                            Colors.white,
                            Colors.transparent,
                          ],
                          stops: [0.0, 0.02, 0.85, 1.0],
                        ).createShader(bounds),
                        blendMode: BlendMode.dstIn,
                        child: SizedBox(
                          height: 160,
                          child: AnimatedSlide(
                            offset: Offset(0,
                                -_currentLoadingIndex * 22.0 / 160),
                            duration:
                                const Duration(milliseconds: 350),
                            curve: Curves.easeOut,
                            child: Column(
                              crossAxisAlignment:
                                  CrossAxisAlignment.center,
                              children: [
                                for (int i = 0;
                                    i < widget.scenes.length;
                                    i++)
                                  SizedBox(
                                    height: 22,
                                    child: AnimatedOpacity(
                                      opacity:
                                          _completedScenes.contains(i)
                                              ? 0.0
                                              : 1.0,
                                      duration: const Duration(
                                          milliseconds: 300),
                                      child: i == _currentLoadingIndex
                                          ? _ShimmerText(
                                              text: widget
                                                  .scenes[i].title,
                                            )
                                          : Text(
                                              widget.scenes[i].title,
                                              textAlign:
                                                  TextAlign.center,
                                              style:
                                                  AppTypography.body(12)
                                                      .copyWith(
                                                color: Colors.white
                                                    .withValues(
                                                        alpha: 0.25),
                                              ),
                                            ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
      );

    return Scaffold(
      backgroundColor: Colors.black,
      body: body,
    );
  }

  void _restoreSystemUI() {
    SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.manual,
      overlays: SystemUiOverlay.values,
    );
  }

  @override
  void dispose() {
    _playing = false;
    _autoCycleTimer?.cancel();
    _accelSub?.cancel();
    _tiltX.dispose();
    // ImageCache 한도 원복.
    final cache = PaintingBinding.instance.imageCache;
    if (_imageCacheBytesBefore != null) {
      cache.maximumSizeBytes = _imageCacheBytesBefore!;
    }
    if (_imageCacheCountBefore != null) {
      cache.maximumSize = _imageCacheCountBefore!;
    }
    _restoreSystemUI();
    _expandController.dispose();
    super.dispose();
  }

}

class _IndexDial extends StatefulWidget {
  const _IndexDial({
    super.key,
    required this.total,
    required this.current,
    required this.onChanged,
  });

  final int total;
  final int current;
  final ValueChanged<int> onChanged;

  @override
  State<_IndexDial> createState() => _IndexDialState();
}

class _IndexDialState extends State<_IndexDial>
    with SingleTickerProviderStateMixin {
  double _offset = 0;
  double _dragStart = 0;
  double _dragStartOffset = 0;

  static const double _tickStep = 12.0;
  static const double _tickWidth = 1.5;
  static const double _tickHeight = 14.0;
  static const double _dialHeight = 28.0;

  double _targetOffset(int index) => index * _tickStep;

  @override
  void initState() {
    super.initState();
    _offset = _targetOffset(widget.current);
  }

  @override
  void didUpdateWidget(_IndexDial old) {
    super.didUpdateWidget(old);
    if (old.current != widget.current) {
      setState(() => _offset = _targetOffset(widget.current));
    }
  }

  void onDragStart(DragStartDetails d) {
    _dragStart = d.localPosition.dx;
    _dragStartOffset = _offset;
  }

  void onDragUpdate(DragUpdateDetails d) {
    final dx = d.localPosition.dx - _dragStart;
    final newOffset = _dragStartOffset - dx;
    final cycleLen = widget.total * _tickStep;
    final normalized = ((newOffset % cycleLen) + cycleLen) % cycleLen;
    final newIndex = (normalized / _tickStep).round() % widget.total;
    setState(() => _offset = newOffset);
    if (newIndex != widget.current) {
      widget.onChanged(newIndex);
    }
  }

  void onDragEnd(DragEndDetails _) {
    final snapped = _targetOffset(widget.current);
    setState(() => _offset = snapped);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onHorizontalDragStart: onDragStart,
      onHorizontalDragUpdate: onDragUpdate,
      onHorizontalDragEnd: onDragEnd,
      child: SizedBox(
        height: _dialHeight,
        child: ShaderMask(
          shaderCallback: (bounds) => const LinearGradient(
            colors: [
              Colors.transparent,
              Colors.white,
              Colors.white,
              Colors.transparent,
            ],
            stops: [0.0, 0.15, 0.85, 1.0],
          ).createShader(bounds),
          blendMode: BlendMode.dstIn,
          child: CustomPaint(
            size: Size.infinite,
            painter: _DialPainter(
              total: widget.total,
              offset: _offset,
              tickStep: _tickStep,
              tickWidth: _tickWidth,
              tickHeight: _tickHeight,
            ),
          ),
        ),
      ),
    );
  }
}

class _DialPainter extends CustomPainter {
  _DialPainter({
    required this.total,
    required this.offset,
    required this.tickStep,
    required this.tickWidth,
    required this.tickHeight,
  });

  final int total;
  final double offset;
  final double tickStep;
  final double tickWidth;
  final double tickHeight;

  @override
  void paint(Canvas canvas, Size size) {
    final centerX = size.width / 2;
    final halfW = size.width / 2;
    final remainder = offset - (offset / tickStep).round() * tickStep;

    final halfCount = (halfW / tickStep).ceil() + 2;
    final bottom = size.height;

    // 배경 눈금
    for (int di = -halfCount; di <= halfCount; di++) {
      final x = centerX + di * tickStep - remainder;
      final t = ((x - centerX) / halfW).clamp(-1.0, 1.0);
      final curve = 1.0 - t * t;
      final h = tickHeight * (0.4 + 0.6 * curve);
      final alpha = 0.15 + 0.2 * curve;

      canvas.drawLine(
        Offset(x, bottom - h),
        Offset(x, bottom),
        Paint()
          ..color = Colors.white.withValues(alpha: alpha)
          ..strokeWidth = tickWidth
          ..strokeCap = StrokeCap.round,
      );
    }

    // 중앙 고정 인디케이터
    final indicatorHeight = tickHeight * 1.4;
    canvas.drawLine(
      Offset(centerX, bottom - indicatorHeight),
      Offset(centerX, bottom),
      Paint()
        ..color = Colors.white
        ..strokeWidth = 2.5
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(_DialPainter old) =>
      old.offset != offset || old.total != total;
}


class _BlurPill extends StatelessWidget {
  const _BlurPill({
    required this.onTap,
    required this.child,
    this.isCircle = false,
    this.padding,
  });

  final VoidCallback onTap;
  final Widget child;
  final bool isCircle;
  final EdgeInsets? padding;

  static const double _height = 48;
  static const double _sigma = 30.0;
  static final _filter = ImageFilter.blur(sigmaX: _sigma, sigmaY: _sigma);
  // dark-mode 블러 톤 — Play 화면이 항상 다크 배경/콘텐츠 위에 떠있다는
  // 전제로 white tint(0.15)가 아닌 black tint를 깐다. iOS Control Center
  // 다크 블러와 비슷한 범위(35–45%)에서 35%로 조절.
  static final _bgColor = Colors.black.withValues(alpha: 0.35);

  @override
  Widget build(BuildContext context) {
    final borderRadius = isCircle ? null : AppRadii.xlBorder;

    Widget container = Container(
      width: isCircle ? _height : null,
      height: _height,
      padding: padding,
      color: _bgColor,
      alignment: isCircle ? Alignment.center : Alignment.centerLeft,
      child: child,
    );

    Widget clipped;
    if (isCircle) {
      clipped = ClipOval(
        child: BackdropFilter(filter: _filter, child: container),
      );
    } else {
      clipped = ClipRRect(
        borderRadius: borderRadius!,
        child: BackdropFilter(filter: _filter, child: container),
      );
    }

    return GestureDetector(
      onTap: onTap,
      child: clipped,
    );
  }
}

/// 쌍안경(두 원이 겹침) 형태의 클리퍼.
/// 카드 형태 매체(film/music/place)의 카드+텍스트 레이아웃. Flexible로
/// 카드가 사용 가능 vertical space를 최대한 차지(aspect 유지)하고, 그 아래
/// title·subtitle을 흰색 텍스트로 배치.
class _CardLayout extends StatelessWidget {
  const _CardLayout({
    required this.aspect,
    required this.card,
    this.title,
    this.subtitle,
  });

  final double aspect;
  final Widget card;
  final String? title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final hasTitle = title != null && title!.isNotEmpty;
    final hasSubtitle = subtitle != null && subtitle!.isNotEmpty;
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Flexible(
          child: AspectRatio(aspectRatio: aspect, child: card),
        ),
        if (hasTitle || hasSubtitle) const SizedBox(height: 24),
        if (hasTitle)
          Text(
            title!,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.body(17, weight: FontWeight.w600)
                .copyWith(color: Colors.white),
          ),
        if (hasSubtitle) ...[
          const SizedBox(height: 6),
          Text(
            subtitle!,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.body(13).copyWith(
              color: Colors.white.withValues(alpha: 0.7),
            ),
          ),
        ],
      ],
    );
  }
}

/// 망원경 두 원이 화면 가운데에서 [progress] 0→1로 확장하는 clipper.
/// progress=0이면 작은 두 원(쌍안경 미리보기), 1이면 화면 전체를 덮음.
/// 안쪽 image는 항상 화면 전체 크기로 깔려있어, 확장 중에도 image 자체는
/// 움직이지 않고 mask만 열리는 효과.
class _BinocularClipper extends CustomClipper<Path> {
  const _BinocularClipper({required this.progress});

  final double progress;

  @override
  Path getClip(Size size) {
    // 작은 쌍안경 한 원의 반지름 (progress=0). 두 원 사이 간격은 90px 기준
    // (각 원 중심이 화면 가운데에서 ±45px).
    const baseRadius = 65.0;
    const eyeOffset = 45.0;

    // progress=1에선 두 원이 화면 끝까지 다 덮어야 함. 어느 코너든 거리
    // 안쪽으로 들어오게 충분히 키움 — 화면 대각선 + 오프셋.
    final diag = math.sqrt(size.width * size.width + size.height * size.height);
    final maxRadius = diag / 2 + eyeOffset + 20;

    final radius = baseRadius + (maxRadius - baseRadius) * progress;
    final cx = size.width / 2;
    final cy = size.height / 2;

    final path = Path()
      ..addOval(
          Rect.fromCircle(center: Offset(cx - eyeOffset, cy), radius: radius))
      ..addOval(
          Rect.fromCircle(center: Offset(cx + eyeOffset, cy), radius: radius));
    return path;
  }

  @override
  bool shouldReclip(covariant _BinocularClipper old) =>
      old.progress != progress;
}

/// 좌→우로 반짝이는 shimmer 텍스트.
class _PlayFilterSheet extends ConsumerStatefulWidget {
  const _PlayFilterSheet({
    required this.scenes,
    required this.selectedSceneIds,
    required this.selectedMediaTypes,
    required this.selectedMomentIds,
    required this.photoFilter,
    required this.onApply,
  });

  final List<Scene> scenes;
  final Set<String> selectedSceneIds;
  final Set<String> selectedMediaTypes;
  final Set<String> selectedMomentIds;
  final PhotoFilter photoFilter;
  final void Function(
    Set<String> sceneIds,
    Set<String> mediaTypes,
    Set<String> momentIds,
    PhotoFilter filter,
  ) onApply;

  @override
  ConsumerState<_PlayFilterSheet> createState() => _PlayFilterSheetState();
}

class _PlayFilterSheetState extends ConsumerState<_PlayFilterSheet> {
  late final Set<String> _sceneIds;
  late final Set<String> _mediaTypes;
  late PhotoFilter _photoFilter;

  /// MomentSelectionScreen에서 선택한 콘텐츠 ID. Apply를 누르기 전까지는
  /// 시트 내부 pending 상태이고, Apply 시 부모로 commit된다.
  /// 비어 있으면 "전체" 의미.
  late final Set<String> _selectedMomentIds;

  /// 선택된 moment 수가 있으면 그 수, 없으면 전체 콘텐츠 합계.
  int _momentsCount(List<Scene> scenes) {
    if (_selectedMomentIds.isNotEmpty) return _selectedMomentIds.length;
    return scenes.fold<int>(0, (sum, s) => sum + s.media.total);
  }

  static const _filterLabels = {
    PhotoFilter.normal: 'Normal',
    PhotoFilter.vintage: 'Vintage',
    PhotoFilter.cinema: 'Cinema',
    PhotoFilter.mono: 'Mono',
  };

  @override
  void initState() {
    super.initState();
    _sceneIds = Set.of(widget.selectedSceneIds);
    _mediaTypes = Set.of(widget.selectedMediaTypes);
    _selectedMomentIds = Set.of(widget.selectedMomentIds);
    _photoFilter = widget.photoFilter;
  }

  void _toggleScene(String id) {
    setState(() {
      if (_sceneIds.contains(id)) {
        _sceneIds.remove(id);
      } else {
        _sceneIds.add(id);
      }
    });
  }



  bool get _canApply => _sceneIds.isNotEmpty && _mediaTypes.isNotEmpty;

  @override
  Widget build(BuildContext context) {
    final isSubscribed = ref.watch(isSubscribedProvider);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(height: 8),
        Text(
          'Playback',
          style: AppTypography.display(20).copyWith(
            color: context.colors.foreground,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 24),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: GestureDetector(
            onTap: () async {
              final result = await Navigator.of(context).push<Set<String>>(
                MomentSelectionScreen.route(
                  initiallySelected: _selectedMomentIds,
                  // 앞에서 로딩된(=현재 sheet에서 선택된) scene의 콘텐츠만
                  // 그리드에 노출.
                  sceneIdFilter: _sceneIds,
                ),
              );
              if (result != null) {
                setState(() {
                  _selectedMomentIds
                    ..clear()
                    ..addAll(result);
                });
              }
            },
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 20,
                vertical: 16,
              ),
              decoration: BoxDecoration(
                color: context.colors.clickableArea,
                borderRadius: AppRadii.sheetInnerBorder,
                border: Border.all(
                  color: context.colors.foreground.withValues(alpha: 0.04),
                  width: 0.5,
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Select Moments',
                          style: AppTypography.body(15,
                                  weight: FontWeight.w600)
                              .copyWith(
                            color: context.colors.foreground,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${_momentsCount(widget.scenes)} moments',
                          style: AppTypography.body(12).copyWith(
                            color: context.colors.foregroundMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  FaIcon(
                    FontAwesomeIcons.chevronRight,
                    size: 14,
                    color: context.colors.foregroundMuted,
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 14),
        if (isSubscribed)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                for (final filter in PhotoFilter.values) ...[
                  if (filter != PhotoFilter.values.first)
                    const SizedBox(width: 6),
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _photoFilter = filter),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                          borderRadius: AppRadii.sheetInnerBorder,
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              context.colors.surface,
                              context.colors.surfaceElevated,
                            ],
                          ),
                          border: Border.all(
                            color: context.colors.foreground
                                .withValues(alpha: 0.06),
                            width: 0.5,
                          ),
                        ),
                        child: Center(
                          child: Text(
                            _filterLabels[filter]!,
                            style: AppTypography.body(12,
                                    weight: FontWeight.w500)
                                .copyWith(
                              color: _photoFilter == filter
                                  ? context.colors.foreground
                                  : context.colors.foregroundMuted
                                      .withValues(alpha: 0.4),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          )
        else
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: GestureDetector(
              onTap: () {
                Navigator.of(context).pop();
                Navigator.of(context).push(SubscriptionScreen.route());
              },
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 18,
                ),
                decoration: BoxDecoration(
                  borderRadius: AppRadii.sheetInnerBorder,
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      context.colors.surface,
                      context.colors.surfaceElevated,
                    ],
                  ),
                  border: Border.all(
                    color: context.colors.foreground.withValues(alpha: 0.06),
                    width: 0.5,
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Scenes HD',
                            style: AppTypography.display(16).copyWith(
                              color: context.colors.foreground,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Apply film looks to your playback.',
                            style: AppTypography.body(12).copyWith(
                              color: context.colors.foregroundMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    FaIcon(
                      FontAwesomeIcons.chevronRight,
                      size: 14,
                      color: context.colors.foregroundMuted,
                    ),
                  ],
                ),
              ),
            ),
          ),
        const SizedBox(height: 14),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: SizedBox(
            width: double.infinity,
            child: GestureDetector(
              onTap: _canApply
                  ? () {
                      widget.onApply(
                        _sceneIds,
                        _mediaTypes,
                        _selectedMomentIds,
                        _photoFilter,
                      );
                      Navigator.of(context).pop();
                    }
                  : null,
              child: AnimatedOpacity(
                opacity: _canApply ? 1.0 : 0.4,
                duration: const Duration(milliseconds: 200),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: BoxDecoration(
                    borderRadius: AppRadii.sheetInnerBorder,
                    color: context.colors.foreground,
                  ),
                  child: Center(
                    child: Text(
                      'Apply',
                      style: AppTypography.body(15, weight: FontWeight.w600)
                          .copyWith(color: context.colors.background),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }
}

class _ShimmerText extends StatefulWidget {
  const _ShimmerText({required this.text});
  final String text;

  @override
  State<_ShimmerText> createState() => _ShimmerTextState();
}

class _ShimmerTextState extends State<_ShimmerText>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final dx = _controller.value * 3 - 1;
        return ShaderMask(
          shaderCallback: (bounds) => LinearGradient(
            begin: Alignment(dx, 0),
            end: Alignment(dx + 0.6, 0),
            colors: const [
              Color(0xFF888886),
              Color(0xFFFFFFFF),
              Color(0xFF888886),
            ],
            stops: const [0.0, 0.5, 1.0],
          ).createShader(bounds),
          blendMode: BlendMode.srcIn,
          child: child,
        );
      },
      child: Text(
        widget.text,
        textAlign: TextAlign.center,
        style: AppTypography.body(12, weight: FontWeight.w500).copyWith(
          color: Colors.white,
        ),
      ),
    );
  }
}

// ── Share sheet ─────────────────────────────────────────────

enum _ShareChannel { save, story, more }

enum _RenderState { idle, rendering, encoding, dispatching }

/// 공유 바텀시트 본문. 9:16 미리보기는 자체 타이머로 cycle하고, 채널 탭 시
/// 직접 frame 렌더 → AVAssetWriter 합성 → 채널별 dispatch까지 수행.
class _ShareSheet extends StatefulWidget {
  const _ShareSheet({
    required this.frames,
    required this.initialIndex,
    required this.photoFilter,
  });

  final List<ShareFrame> frames;
  final int initialIndex;
  final PhotoFilter photoFilter;

  @override
  State<_ShareSheet> createState() => _ShareSheetState();
}

class _ShareSheetState extends State<_ShareSheet> {
  /// 메인 재생과 동일한 인터벌. 같은 페이스로 보여줘야 "공유될 영상" 감각 일치.
  static const _cyclePeriod = Duration(milliseconds: 750);
  static const _frameDuration = Duration(milliseconds: 750);

  late int _index;
  Timer? _timer;

  _RenderState _renderState = _RenderState.idle;
  int _renderCurrent = 0;
  int _renderTotal = 0;

  bool get _busy => _renderState != _RenderState.idle;

  @override
  void initState() {
    super.initState();
    _index = widget.frames.isEmpty
        ? 0
        : widget.initialIndex.clamp(0, widget.frames.length - 1);
    _timer = Timer.periodic(_cyclePeriod, (_) {
      if (!mounted || widget.frames.length <= 1) return;
      setState(() {
        _index = (_index + 1) % widget.frames.length;
      });
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _handleChannel(_ShareChannel channel) async {
    if (_busy || widget.frames.isEmpty) return;
    setState(() {
      _renderState = _RenderState.rendering;
      _renderCurrent = 0;
      _renderTotal = widget.frames.length;
    });

    Directory? tempDir;
    try {
      tempDir = await Directory.systemTemp.createTemp('scenes_share_');
      if (!mounted) return;

      // Phase 1: Flutter가 각 frame을 1080×1920 PNG로 굽기.
      final framePaths =
          await ShareFrameRenderer.instance.renderFrames(
        context: context,
        frames: widget.frames,
        colorFilter: _colorFilterFor(widget.photoFilter),
        outputDir: tempDir,
        onProgress: (current, total) {
          if (!mounted) return;
          setState(() {
            _renderCurrent = current;
            _renderTotal = total;
          });
        },
      );
      if (!mounted) return;

      // Phase 2: iOS AVAssetWriter가 PNG 시퀀스를 H.264 MP4로 인코딩.
      setState(() {
        _renderState = _RenderState.encoding;
        _renderCurrent = 0;
        _renderTotal = framePaths.length;
      });
      final outputPath = '${tempDir.path}/scenes_share.mp4';
      final videoPath = await VideoComposer.instance.composeVideo(
        framePaths: framePaths,
        frameDuration: _frameDuration,
        outputPath: outputPath,
        onProgress: (current, total) {
          if (!mounted) return;
          setState(() {
            _renderCurrent = current;
            _renderTotal = total;
          });
        },
      );
      if (!mounted) return;

      // Phase 3: 채널별 dispatch.
      setState(() => _renderState = _RenderState.dispatching);
      switch (channel) {
        case _ShareChannel.save:
          await _saveToGallery(videoPath);
        case _ShareChannel.story:
          await _shareToStory(videoPath);
        case _ShareChannel.more:
          await _shareGeneral(videoPath);
      }
      if (!mounted) return;
      Navigator.of(context).pop();
    } catch (e) {
      debugPrint('share render/dispatch failed: $e');
      if (!mounted) return;
      // 디버깅 중 — 토스트에 raw 에러 메시지를 노출. 안정화 후 generic 메시지로
      // 되돌릴 것.
      AppToast.show(context, 'Share failed: $e');
      setState(() => _renderState = _RenderState.idle);
    } finally {
      // 임시 frame PNG들과 MP4 모두 정리. PhotoManager.saveVideo는 라이브러리에
      // 복사본 생성, SharePlus도 OS가 복사본 보유, IG는 pasteboard에 데이터로
      // 복사 — 따라서 source temp dir은 안전하게 통째로 지움.
      if (tempDir != null) {
        try {
          await tempDir.delete(recursive: true);
        } catch (_) {}
      }
    }
  }

  Future<void> _saveToGallery(String videoPath) async {
    final permission = await PhotoManager.requestPermissionExtend(
      requestOption: const PermissionRequestOption(
        iosAccessLevel: IosAccessLevel.addOnly,
      ),
    );
    if (!permission.isAuth) {
      if (mounted) AppToast.show(context, 'Photo permission required.');
      return;
    }
    await PhotoManager.editor.saveVideo(
      File(videoPath),
      title: 'scenes_share_${DateTime.now().millisecondsSinceEpoch}.mp4',
    );
    if (mounted) AppToast.show(context, 'Saved to Photos');
  }

  Future<void> _shareToStory(String videoPath) async {
    try {
      await VideoComposer.instance.shareToInstagramStory(videoPath: videoPath);
    } on PlatformException catch (e) {
      // IG 미설치 등으로 직접 attach 안 되면 일반 공유 시트로 fallback.
      if (e.code == 'unavailable') {
        if (mounted) AppToast.show(context, 'Instagram is not installed.');
        await _shareGeneral(videoPath);
      } else {
        rethrow;
      }
    }
  }

  Future<void> _shareGeneral(String videoPath) async {
    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(videoPath, mimeType: 'video/mp4')],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorFilter = _colorFilterFor(widget.photoFilter);
    final frame = widget.frames.isEmpty ? null : widget.frames[_index];

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Share',
            style: AppTypography.display(20).copyWith(
              color: context.colors.foreground,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: AppRadii.smBorder,
            child: SizedBox(
              width: kShareFrameLogicalWidth,
              height: kShareFrameLogicalHeight,
              child: frame == null
                  ? const ColoredBox(color: Color(0xFF1C1C1E))
                  : ShareFrameView(
                      frame: frame,
                      image: NetworkImage(frame.url),
                      colorFilter: colorFilter,
                    ),
            ),
          ),
          const SizedBox(height: 20),
          if (_busy)
            _ProgressFooter(
              label: _progressLabel(),
              current: _renderCurrent,
              total: _renderTotal,
            )
          else
            Row(
              children: [
                Expanded(
                  child: _ChannelCell(
                    icon: FontAwesomeIcons.download,
                    label: 'Save',
                    onTap: () => _handleChannel(_ShareChannel.save),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _ChannelCell(
                    icon: FontAwesomeIcons.instagram,
                    label: 'Story',
                    onTap: () => _handleChannel(_ShareChannel.story),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _ChannelCell(
                    icon: FontAwesomeIcons.ellipsis,
                    label: 'More',
                    onTap: () => _handleChannel(_ShareChannel.more),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  String _progressLabel() {
    switch (_renderState) {
      case _RenderState.rendering:
        return 'Preparing video';
      case _RenderState.encoding:
        return 'Encoding';
      case _RenderState.dispatching:
        return 'Sharing';
      case _RenderState.idle:
        return '';
    }
  }
}

/// 진행률 footer. 라벨 + linear progress + "X / N" 카운터.
class _ProgressFooter extends StatelessWidget {
  const _ProgressFooter({
    required this.label,
    required this.current,
    required this.total,
  });

  final String label;
  final int current;
  final int total;

  @override
  Widget build(BuildContext context) {
    final value = total > 0 ? (current / total).clamp(0.0, 1.0) : null;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ClipRRect(
            borderRadius: AppRadii.xsBorder,
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: value ?? 0),
              duration: const Duration(milliseconds: 220),
              curve: Curves.linear,
              builder: (context, v, _) => LinearProgressIndicator(
                value: value == null ? null : v,
                minHeight: 4,
                backgroundColor:
                    context.colors.foreground.withValues(alpha: 0.1),
                valueColor: AlwaysStoppedAnimation<Color>(
                  context.colors.foreground,
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            total > 0 ? '$label  ·  $current / $total' : '$label…',
            style: AppTypography.body(13).copyWith(
              color: context.colors.foregroundMuted,
            ),
          ),
        ],
      ),
    );
  }
}

class _ChannelCell extends StatelessWidget {
  const _ChannelCell({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final FaIconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 18),
        decoration: BoxDecoration(
          color: context.colors.clickableArea,
          borderRadius: AppRadii.sheetInnerBorder,
          border: Border.all(
            color: context.colors.foreground.withValues(alpha: 0.04),
            width: 0.5,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            FaIcon(
              icon,
              size: 22,
              color: context.colors.foreground.withValues(alpha: 0.7),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: AppTypography.body(12).copyWith(
                color: context.colors.foregroundMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
