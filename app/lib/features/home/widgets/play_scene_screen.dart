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
import '../../../l10n/app_localizations.dart';
import '../../../core/widgets/floating_bottom_sheet.dart';
import '../../content/contents_view_model.dart';
import '../../content/models/content.dart';
import '../../share/data/share_frame_renderer.dart';
import '../../share/data/video_composer.dart';
import '../../share/widgets/share_frame_view.dart';
import '../../share/widgets/snake_share_view.dart';
import '../../share/widgets/stack_share_view.dart';
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
    required this.scene,
    this.initialMediaTypes = const {'photo', 'film', 'music', 'place'},
  });

  final Scene scene;
  // PlaySceneSheet가 토글한 매체 선택을 그대로 받아 초기 필터로 적용.
  // 화면 안의 _PlayFilterSheet에서 추후 변경 가능.
  final Set<String> initialMediaTypes;

  static Route<void> route({
    required Scene scene,
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
        scene: scene,
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
  // Shuffle 모드. on이면 _shuffledOrder의 다음 인덱스를 따라 진행하고 한
  // 사이클 끝나면 재셔플. _applyFilter로 _playUrls 길이가 바뀌면 재생성.
  bool _shuffle = false;
  List<int> _shuffledOrder = const [];
  int _shufflePos = 0;
  // Pause 중 좌우 tilt로 cover-fit된 사진의 가려진 영역을 들춰보는 parallax.
  // ValueNotifier로 두면 stream 업데이트가 ValueListenableBuilder만 리빌드하고
  // 화면 전체 setState 없이 alignment만 갱신할 수 있다.
  final ValueNotifier<double> _tiltX = ValueNotifier(0.0);
  StreamSubscription<AccelerometerEvent>? _accelSub;
  // Filter/Share 등 바텀시트가 떠 있는 동안에는 tilt도 멈춰야 한다(시트 안의
  // 미리보기·콘텐츠가 흔들리지 않도록). _paused만 보면 시트 표시 시에도
  // tilt가 활성화돼서 의도와 어긋남.
  bool _sheetOpen = false;
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

    _selectedSceneIds = {widget.scene.id};
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

  /// 로딩 중 디코드 완료된 인덱스를 누적하는 큐. 디코드가 750ms보다 빨리
  /// 끝나도 사진이 휙 지나가지 않게 [_drainDisplayQueue]가 통일 간격으로
  /// 1장씩 표시.
  final List<int> _decodedQueue = [];
  Timer? _displayTimer;

  /// 디코드된 사진을 [_autoCycleInterval] 간격으로 1장씩 binocular에 표시.
  /// 첫 호출은 즉시 첫 사진을 그리고, 이후는 timer로 dripfeed.
  void _drainDisplayQueue() {
    if (!mounted || _playing) {
      _displayTimer?.cancel();
      _displayTimer = null;
      return;
    }
    if (_decodedQueue.isEmpty) {
      _displayTimer?.cancel();
      _displayTimer = null;
      return;
    }
    final nextIdx = _decodedQueue.removeAt(0);
    setState(() => _playIndex = nextIdx);
    _displayTimer?.cancel();
    _displayTimer = Timer(_autoCycleInterval, _drainDisplayQueue);
  }

  void _enqueueDecoded(int index) {
    if (!mounted || _playing) return;
    _decodedQueue.add(index);
    // 첫 사진은 즉시 표시(빈 화면 시간 최소화), 이후 timer로 750ms 간격.
    if (_displayTimer == null) _drainDisplayQueue();
  }

  void _startAutoCycle() {
    _autoCycleTimer?.cancel();
    // 디코드 큐 처리는 auto-cycle이 인계받음 — display timer 정리.
    _displayTimer?.cancel();
    _displayTimer = null;
    _decodedQueue.clear();
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
    // cover 없는 scene이면 빈 string → NetworkImage('')가 file:/// URI로
    // 파싱돼 "No host specified" 예외. 비어있으면 skip.
    final url = widget.scene.coverImageUrl;
    if (url.isEmpty) return;
    precacheImage(NetworkImage(url), context);
  }

  /// 선택된 Scene들의 contents를 순차로 로드. scene_summary가 알려주는
  /// type별 count는 무시 — 각 scene의 contentsForSceneProvider로 실제 row를
  /// 받아 fullSignedUrl로 재생, thumbSignedUrl로 로딩 미리보기.
  ///
  /// 사용자가 방금 scene_detail에서 진입했다면 그 scene은 이미 cache hot이라
  /// 즉시 반환. 다른 scene들은 fresh fetch. cache가 핫해서 너무 빨리 끝나면
  /// 로딩 시퀀스가 휙 지나가 어색하니 [_minLoadingDuration] 보장.
  static const _minLoadingDuration = Duration(seconds: 3);

  /// precacheImage 완료가 하나라도 무한히 늘어지면 사용자 대기시간이 폭주
  /// 하므로 cap을 둠. 12장 초기 batch는 보통 2–4초면 충분.
  static const _maxPrecacheWait = Duration(seconds: 15);

  /// 진입 시 즉시 디코드해놓을 사진 수. 한 세션에서 사용자가 실제로 보는
  /// 평균이 5~10장이라 12장이면 첫 cycle 동안 충분. 나머지는 재생 진행에
  /// 따라 [_ensureLookAheadPrecache]가 점진 디코드 → 한 세션 egress 80%↓.
  static const _initialPrefetchCount = 12;

  /// 현재 _playIndex 기준 미리 디코드해둘 향후 사진 수. 재생 속도(750ms/장)
  /// 와 디코드 시간(보통 200~500ms)을 고려해 10장이면 셔플 첫 사이클에서도
  /// 충분히 한 발 앞서 디코드가 끝남.
  static const _lookAheadCount = 10;

  /// 다음 frame이 decode될 때까지 750ms 후 advance를 늦출 수 있는 최대 시간.
  /// 이걸 넘어가면 디코드를 포기하고 advance — 사용자가 영원히 멈춘 상태로
  /// 두지는 않음.
  static const _maxAdvanceWaitForDecode = Duration(seconds: 2);

  /// 이미 precache 호출이 들어간 URL 집합. 중복 호출 방지.
  final Set<String> _precachedUrls = {};

  /// 디코드(precache)가 끝난 URL — `_scheduleNextContent`가 다음 frame이
  /// 준비됐는지 빠르게 체크할 때 사용.
  final Set<String> _decodedUrls = {};

  /// URL별 디코드 완료 신호. waiter가 `await`해서 디코드가 끝났을 때 깨어남.
  /// 실패 케이스도 complete()로 풀어 무한 대기 방지.
  final Map<String, Completer<void>> _decodeCompleters = {};

  /// 단일 URL의 precache 트리거 — 중복은 무시. 실패는 silently catch.
  /// 디코드 완료/실패를 [_decodedUrls] / [_decodeCompleters]에 반영해
  /// `_waitForDecode`가 깨어날 수 있게.
  void _kickOffPrecache(String url) {
    if (_precachedUrls.contains(url)) return;
    final provider = _imageProviders[url];
    if (provider == null) return;
    _precachedUrls.add(url);
    final completer =
        _decodeCompleters.putIfAbsent(url, () => Completer<void>());
    // ignore: discarded_futures
    precacheImage(provider, context).then((_) {
      _decodedUrls.add(url);
      if (!completer.isCompleted) completer.complete();
    }).catchError((_) {
      // 실패해도 waiter는 깨워 줘야 advance가 무한히 지연되지 않음.
      if (!completer.isCompleted) completer.complete();
    });
  }

  /// 다음에 보여줄 URL — `_scheduleNextContent`가 advance 직전에 호출.
  /// shuffle on이면 _shuffledOrder의 다음 항목, 아니면 sequential.
  String? _peekNextUrl() {
    if (_playUrls.isEmpty) return null;
    final len = _playUrls.length;
    final int nextIdx;
    if (_shuffle && _shuffledOrder.length == len) {
      nextIdx = _shuffledOrder[(_shufflePos + 1) % len];
    } else {
      nextIdx = (_playIndex + 1) % len;
    }
    if (nextIdx < 0 || nextIdx >= len) return null;
    return _playUrls[nextIdx];
  }

  /// [url] 디코드가 끝날 때까지 최대 [timeout] 대기. 이미 끝났으면 즉시
  /// 반환. 시간 초과면 그냥 통과(advance가 stale 이미지 위로 진행되지만
  /// 무한 멈춤은 아님).
  Future<void> _waitForDecode(String url, Duration timeout) async {
    if (_decodedUrls.contains(url)) return;
    final completer = _decodeCompleters[url];
    if (completer == null || completer.isCompleted) return;
    try {
      await completer.future.timeout(timeout, onTimeout: () {});
    } catch (_) {}
  }

  /// 현재 재생 위치 기준 향후 [_lookAheadCount]장의 사진을 미리 디코드.
  /// shuffle이면 [_shuffledOrder]의 다음 항목들을 따라가고, 아니면 sequential.
  void _ensureLookAheadPrecache() {
    if (_playUrls.isEmpty) return;
    final len = _playUrls.length;
    for (var k = 1; k <= _lookAheadCount; k++) {
      final int next;
      if (_shuffle && _shuffledOrder.length == len) {
        next = _shuffledOrder[(_shufflePos + k) % len];
      } else {
        next = (_playIndex + k) % len;
      }
      if (next < 0 || next >= _playUrls.length) continue;
      _kickOffPrecache(_playUrls[next]);
    }
  }

  Future<void> _loadContent() async {
    final startedAt = DateTime.now();
    final repo = ref.read;
    // 초기 진입용 precache Future만 수집. 나머지는 _ensureLookAheadPrecache가
    // 재생 진행에 따라 점진 디코드 — 한 번에 100장 다 받지 않아 egress
    // 80%↓. 12장이면 첫 cycle 충분 + min duration 안에 끝남.
    final initialPrecaches = <Future<void>>[];

    if (!mounted) return;
    setState(() => _currentLoadingIndex = 0);

    final scene = widget.scene;
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
      // 단일 scene 재생이라 scene index는 항상 0 — 호환 유지를 위해 리스트는 둠.
      _allPlaySceneIndex.add(0);
      // photo는 EXIF taken_at이 occurredAt에 들어감, 그 외는 createdAt fallback.
      _allPlayDates.add(content.occurredAt ?? content.createdAt);
      _allMediaTypes.add(content.type);
      _allContents.add(content);

      // 초기 _initialPrefetchCount장만 즉시 precache. 디코드 완료된 인덱스
      // 는 _decodedQueue에 적재 → display timer가 750ms 간격으로 1장씩
      // binocular에 표시. 디코드가 빨라도 사진이 휙 지나가지 않음. 그 외
      // 사진은 metadata만 저장 — 실제 디코드는 재생 진행에 따라
      // _ensureLookAheadPrecache가 호출.
      if (initialPrecaches.length < _initialPrefetchCount) {
        final addedAtIndex = _allPlayUrls.length - 1;
        _precachedUrls.add(fullUrl);
        final completer = _decodeCompleters
            .putIfAbsent(fullUrl, () => Completer<void>());
        initialPrecaches.add(
          precacheImage(provider, context).then((_) {
            _decodedUrls.add(fullUrl);
            if (!completer.isCompleted) completer.complete();
            _enqueueDecoded(addedAtIndex);
          }).catchError((_) {
            // 실패해도 waiter는 깨움.
            if (!completer.isCompleted) completer.complete();
          }),
        );
      }

      if (mounted) {
        setState(() {
          _loadedThumbs.add(thumbUrl);
        });
      }
    }

    if (!mounted) return;
    setState(() {
      _completedScenes.add(0);
      _loadProgress = 1.0;
    });

    if (!mounted) return;
    _applyFilter();
    if (_playUrls.isEmpty) {
      // 콘텐츠가 아예 없거나, 필터로 다 걸러져서 재생할 게 없는 경우 토스트
      // 띄우고 화면 pop.
      AppToast.show(
        context,
        AppLocalizations.of(context).playSceneNoMomentsToast,
      );
      Navigator.of(context).pop();
      return;
    }
    {
      // 모든 사진 로드 완료 → play와 동일 속도로 자동 cycle 시작. min duration
      // 대기 동안에도, expansion 도중에도, 재생 진입 직후에도 같은 cycle이
      // 흘러가다 _scheduleNextContent로 매끈하게 인계 (전환 끊김 없음).
      _startAutoCycle();

      // (1) 모든 사진 디코드 완료 + (2) _minLoadingDuration 보장. 둘 다 만족
      // 해야 진행. (1)이 너무 늦어지면 _maxPrecacheWait로 cap해서 강제 진행.
      final elapsed = DateTime.now().difference(startedAt);
      final minRemaining = _minLoadingDuration - elapsed;
      final precacheAll = Future.wait(initialPrecaches).timeout(
        _maxPrecacheWait,
        onTimeout: () => const [],
      );
      await Future.wait<void>([
        precacheAll,
        if (minRemaining > Duration.zero)
          Future<void>.delayed(minRemaining),
      ]);
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
    // 재생 진입 직후 look-ahead 시작 — _advancePlayIndex가 발화되기 전에도
    // 첫 cycle 직후 표시될 사진들이 미리 디코드되어 있도록.
    _ensureLookAheadPrecache();
  }

  void _togglePause() {
    setState(() => _paused = !_paused);
    if (!_paused) _scheduleNextContent();
  }

  void _scheduleNextContent() {
    if (!mounted || !_playing || _paused || _autoPlayScheduled) return;
    _autoPlayScheduled = true;
    Future<void>.delayed(const Duration(milliseconds: 750), () async {
      if (!mounted || !_playing || _paused) {
        _autoPlayScheduled = false;
        return;
      }
      // 750ms 경과했더라도 다음 이미지가 decode 안 됐으면 잠시 더 대기 —
      // 안 그러면 gaplessPlayback이 옛 이미지를 그대로 두다가 새 이미지가
      // 늦게 들어와 짧게만 보이고 다음 tick에 다시 넘어가는 "씹힘" 발생.
      final nextUrl = _peekNextUrl();
      if (nextUrl != null && !_decodedUrls.contains(nextUrl)) {
        _kickOffPrecache(nextUrl);
        await _waitForDecode(nextUrl, _maxAdvanceWaitForDecode);
      }
      _autoPlayScheduled = false;
      if (!mounted || !_playing || _paused) return;
      setState(_advancePlayIndex);
      HapticFeedback.selectionClick();
      // 인덱스 진행에 따라 향후 N장 미리 디코드.
      _ensureLookAheadPrecache();
      _scheduleNextContent();
    });
  }

  /// 다음 인덱스 결정 — shuffle on이면 _shuffledOrder의 다음 값,
  /// off이면 순차. 한 사이클(= 한 바퀴, 모든 사진 1회씩)을 다 돌면 새
  /// permutation으로 재셔플하되, 새 순서의 첫 장이 직전 장과 겹치지 않게 해
  /// 사이클 경계에서 같은 사진이 연속으로 나오는 일이 없게 한다.
  void _advancePlayIndex() {
    if (_playUrls.isEmpty) return;
    if (_shuffle && _shuffledOrder.length == _playUrls.length) {
      _shufflePos = (_shufflePos + 1) % _shuffledOrder.length;
      if (_shufflePos == 0) {
        _shuffledOrder = _reshuffledAvoiding(_shuffledOrder, _playIndex);
      }
      _playIndex = _shuffledOrder[_shufflePos];
    } else {
      _playIndex = (_playIndex + 1) % _playUrls.length;
    }
  }

  /// 현재 _playUrls 길이로 새 permutation 생성 + 첫 항목으로 _playIndex 정렬.
  /// shuffle ON 진입 시점이나 _applyFilter로 길이가 바뀐 직후에 호출.
  void _regenerateShuffleOrder() {
    if (_playUrls.isEmpty) {
      _shuffledOrder = const [];
      _shufflePos = 0;
      return;
    }
    final base = List<int>.generate(_playUrls.length, (i) => i);
    // 현재 보이던 사진(_playIndex)이 셔플 첫 장으로 또 나오지 않게.
    _shuffledOrder = _reshuffledAvoiding(base, _playIndex);
    _shufflePos = 0;
    _playIndex = _shuffledOrder[0];
  }

  /// [source]의 원소를 새 permutation으로 섞되 첫 항목이 [avoidFirst]가
  /// 되지 않도록 보정 — 셔플 진입·사이클 경계에서 같은 사진이 연속으로
  /// 나오는 걸 막는다. 첫 항목이 겹치면 마지막 항목과 swap(permutation 유지).
  List<int> _reshuffledAvoiding(List<int> source, int avoidFirst) {
    final next = List<int>.of(source)..shuffle();
    if (next.length > 1 && next.first == avoidFirst) {
      final last = next.length - 1;
      next[0] = next[last];
      next[last] = avoidFirst;
    }
    return next;
  }

  void _applyFilter() {
    _playUrls = [];
    _playSceneIndex = [];
    _playDates = [];
    _filteredMediaTypes = [];
    _filteredContents = [];

    for (int i = 0; i < _allPlayUrls.length; i++) {
      final sceneId = widget.scene.id;
      final mediaType = _allMediaTypes[i];
      final contentId = _allContents[i].id;
      // moment 필터 의미론: 빈 set = "전체 재생"(필터 미적용),
      // non-empty = 그 안의 content_id만 통과.
      final passesMomentFilter = _selectedMomentIds.isEmpty ||
          _selectedMomentIds.contains(contentId);
      if (_selectedSceneIds.contains(sceneId) &&
          _selectedMediaTypes.contains(mediaType) &&
          passesMomentFilter) {
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
  /// Content.payload의 width/height에서 사진 원본 가로/세로 비율 산출. 없거나
  /// 잘못된 값이면 null — view가 fallback 적용.
  double? _aspectOf(Content c) {
    final w = c.payload['width'];
    final h = c.payload['height'];
    if (w is int && h is int && w > 0 && h > 0) return w / h;
    return null;
  }

  Future<void> _showShareSheet() async {
    if (_playUrls.isEmpty) return;
    final wasPaused = _paused;
    setState(() {
      _paused = true;
      _sheetOpen = true;
    });

    // 미리보기에 넘길 frame들 — 필터 적용 후 재생 대상에서 그대로 추출.
    // 영상 길이/렌더 시간 폭주 방지를 위해 최대 100장까지만 cap.
    //   - url(미리보기): tier별 다름.
    //     · 무료: full(1920) — play 메인이 이미 캐시한 URL과 같아 ImageCache
    //       hit, 추가 egress 0. 30장 cap이라 RGBA RAM 부담은 ImageCache LRU
    //       (100MB)가 자연 회전으로 흡수.
    //     · HD: thumb(600) — 100장 × 2560 RGBA가 ImageCache cap을 크게
    //       초과해 evict ↔ re-decode thrashing 위험. 별도 thumb으로 받아
    //       메모리 보호. 어차피 HD는 slideshow가 메인 출력.
    //   - renderUrl(영상 캡처): full(free 1920 / HD 2560 long-edge WebP) —
    //     슬라이드쇼 1080×1920에 1:1 매칭. 단, 슬라이드쇼는 HD 전용이라
    //     무료 회원은 contact sheet만 렌더링됨 → contact sheet 렌더러는
    //     frame.url(=full for 무료)을 사용.
    final isHdViewer = ref.read(isSubscribedProvider);
    // shuffle ON이면 _shuffledOrder의 순서대로 영상에 들어가도록. 길이
    // 불일치 시(예외) sequential로 fallback. shuffle OFF면 그대로 인덱스 순서.
    final useShuffled =
        _shuffle && _shuffledOrder.length == _playUrls.length;
    final order = useShuffled
        ? _shuffledOrder
        : List<int>.generate(_playUrls.length, (i) => i);
    final maxFrames = math.min(order.length, 100);
    final frames = <ShareFrame>[
      for (var k = 0; k < maxFrames; k++)
        () {
          final i = order[k];
          return ShareFrame(
            url: isHdViewer
                ? (_filteredContents[i].thumbSignedUrl ?? _playUrls[i])
                : (_filteredContents[i].fullSignedUrl ??
                    _filteredContents[i].thumbSignedUrl ??
                    _playUrls[i]),
            renderUrl: _filteredContents[i].fullSignedUrl,
            sceneName: widget.scene.title,
            sceneNumber: widget.scene.number,
            occurredAt: _playDates[i],
            mediaType: _filteredMediaTypes[i],
            aspect: _aspectOf(_filteredContents[i]),
          );
        }(),
    ];
    // 현재 보고 있는 frame의 frames[] 내 위치. shuffle ON이면 _shufflePos가
    // _shuffledOrder에서의 위치 = frames[] 내 위치와 동일. 아니면 _playIndex.
    final initialIndex =
        (useShuffled ? _shufflePos : _playIndex) % (maxFrames > 0 ? maxFrames : 1);

    await FloatingBottomSheet.show<void>(
      context: context,
      builder: (_) => _ShareSheet(
        frames: frames,
        initialIndex: initialIndex,
        photoFilter: _photoFilter,
        sceneCoverUrl: widget.scene.coverImageUrl,
        sceneNumber: widget.scene.number,
        sceneTitle: widget.scene.title,
      ),
    );

    if (!mounted) return;
    setState(() => _sheetOpen = false);
    if (!wasPaused && _playUrls.isNotEmpty) {
      setState(() => _paused = false);
      _scheduleNextContent();
    }
  }

  void _showFilterSheet() {
    final wasPaused = _paused;
    setState(() {
      _paused = true;
      _sheetOpen = true;
    });

    FloatingBottomSheet.show(
      context: context,
      builder: (_) => _PlayFilterSheet(
        scene: widget.scene,
        selectedMediaTypes: Set.of(_selectedMediaTypes),
        selectedMomentIds: Set.of(_selectedMomentIds),
        photoFilter: _photoFilter,
        shuffle: _shuffle,
        onApply: (mediaTypes, momentIds, filter, shuffle) {
          setState(() {
            _selectedMediaTypes
              ..clear()
              ..addAll(mediaTypes);
            _selectedMomentIds
              ..clear()
              ..addAll(momentIds);
            _photoFilter = filter;
            _shuffle = shuffle;
            _applyFilter();
            if (_shuffle && _playUrls.isNotEmpty) {
              _regenerateShuffleOrder();
            } else {
              _shuffledOrder = const [];
              _shufflePos = 0;
              _playIndex = 0;
            }
            _infoIndex = 0;
            // 필터/셔플 적용으로 다음 재생 인덱스들이 바뀜 — 현재 + 향후
            // 사진을 미리 디코드해 전환 시 사진이 늦게 뜨지 않게.
            if (_playUrls.isNotEmpty) {
              _kickOffPrecache(_playUrls[_playIndex % _playUrls.length]);
              _ensureLookAheadPrecache();
            }
            if (!wasPaused && _playUrls.isNotEmpty) {
              _paused = false;
              _scheduleNextContent();
            }
          });
          // 필터 결과가 0이면 재생할 콘텐츠가 없음 — 안내 후 화면 pop.
          if (_playUrls.isEmpty) {
            AppToast.show(
        context,
        AppLocalizations.of(context).playSceneNoMomentsToast,
      );
            Navigator.of(context).pop();
          }
        },
      ),
    ).then((_) {
      if (!mounted) return;
      setState(() => _sheetOpen = false);
      if (!wasPaused && _playUrls.isNotEmpty) {
        setState(() => _paused = false);
        _scheduleNextContent();
      }
    });
  }

  Scene get _currentScene => widget.scene;

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

  /// 재생 일시정지 + 시트가 떠있지 않을 때만 accelerometer stream 활성화.
  /// 매 setState 호출자가 직접 켜고 끌 필요 없이 build 시작 시 한 번 동기화.
  void _syncTiltSubscription() {
    final shouldListen = _paused && !_sheetOpen;
    if (shouldListen && _accelSub == null) {
      _accelSub = accelerometerEventStream(
        samplingPeriod: const Duration(milliseconds: 33),
      ).listen((event) {
        // event.x: iOS portrait 기준 디바이스가 오른쪽으로 기울면 양수.
        // ±2.5를 풀스윙(약 15°)으로 매핑 — 가벼운 손목 회전으로도 풀 팬에
        // 도달하면서 정지 상태의 미세 흔들림은 비교적 적게 반응.
        final target = (event.x / 2.5).clamp(-1.0, 1.0);
        // EMA 스무딩 — 손떨림 노이즈 억제. factor 0.12 → 약 250ms 응답.
        _tiltX.value = _tiltX.value + (target - _tiltX.value) * 0.12;
      });
    } else if (!shouldListen && _accelSub != null) {
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
                          // _sheetOpen 토글 — confirm dialog 떠있는 동안엔
                          // tilt parallax도 함께 정지(시트류와 같은 취급).
                          setState(() {
                            _paused = true;
                            _sheetOpen = true;
                          });
                          final confirmed = await ConfirmDialog.show(
                            context: context,
                            title: 'Stop playing?',
                            confirmLabel:
                                AppLocalizations.of(context).playSceneStop,
                            isDestructive: true,
                          );
                          if (!mounted) return;
                          if (confirmed) {
                            _restoreSystemUI();
                            Navigator.of(this.context).pop();
                          } else {
                            setState(() {
                              _sheetOpen = false;
                              if (!wasPaused) _paused = false;
                            });
                            if (!wasPaused) _scheduleNextContent();
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
                                    // right 12로 텍스트와 우측 divider(=경계)
                                    // 사이 breathing room 확보.
                                    padding: const EdgeInsets.only(
                                        left: 10, right: 12),
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
                        AppLocalizations.of(context).playSceneLoadingPreparing,
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
                                SizedBox(
                                  height: 22,
                                  child: AnimatedOpacity(
                                    opacity: _completedScenes.contains(0)
                                        ? 0.0
                                        : 1.0,
                                    duration: const Duration(
                                        milliseconds: 300),
                                    child: _ShimmerText(
                                      text: widget.scene.title,
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
    _displayTimer?.cancel();
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
    required this.scene,
    required this.selectedMediaTypes,
    required this.selectedMomentIds,
    required this.photoFilter,
    required this.shuffle,
    required this.onApply,
  });

  final Scene scene;
  final Set<String> selectedMediaTypes;
  final Set<String> selectedMomentIds;
  final PhotoFilter photoFilter;
  final bool shuffle;
  final void Function(
    Set<String> mediaTypes,
    Set<String> momentIds,
    PhotoFilter filter,
    bool shuffle,
  ) onApply;

  @override
  ConsumerState<_PlayFilterSheet> createState() => _PlayFilterSheetState();
}

class _PlayFilterSheetState extends ConsumerState<_PlayFilterSheet> {
  late final Set<String> _mediaTypes;
  late PhotoFilter _photoFilter;
  late bool _shuffle;

  /// MomentSelectionScreen에서 선택한 콘텐츠 ID. Apply를 누르기 전까지는
  /// 시트 내부 pending 상태이고, Apply 시 부모로 commit된다.
  /// 비어 있으면 "전체" 의미.
  late final Set<String> _selectedMomentIds;

  /// 선택된 moment 수가 있으면 그 수, 없으면 단일 scene의 콘텐츠 합계.
  int _momentsCount(Scene scene) {
    if (_selectedMomentIds.isNotEmpty) return _selectedMomentIds.length;
    return scene.media.total;
  }

  String _filterLabel(AppLocalizations l10n, PhotoFilter filter) {
    switch (filter) {
      case PhotoFilter.normal:
        return l10n.playSceneFilterNormal;
      case PhotoFilter.vintage:
        return l10n.playSceneFilterVintage;
      case PhotoFilter.cinema:
        return l10n.playSceneFilterCinema;
      case PhotoFilter.mono:
        return l10n.playSceneFilterMono;
    }
  }

  @override
  void initState() {
    super.initState();
    _mediaTypes = Set.of(widget.selectedMediaTypes);
    _selectedMomentIds = Set.of(widget.selectedMomentIds);
    _photoFilter = widget.photoFilter;
    _shuffle = widget.shuffle;
  }

  bool get _canApply => _mediaTypes.isNotEmpty;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
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
                  // 단일 scene 재생이므로 그 scene id로 필터.
                  sceneIdFilter: {widget.scene.id},
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
                          l10n.playSceneSelectMoments,
                          style: AppTypography.body(15,
                                  weight: FontWeight.w600)
                              .copyWith(
                            color: context.colors.foreground,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          l10n.playSceneMomentsCount(_momentsCount(widget.scene)),
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
        // Shuffle 토글 — on이면 _playUrls를 랜덤 순서로 재생.
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
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
                FaIcon(
                  FontAwesomeIcons.shuffle,
                  size: 14,
                  color: context.colors.foreground.withValues(alpha: 0.7),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    l10n.playSceneShuffle,
                    style: AppTypography.body(
                      15,
                      weight: FontWeight.w600,
                    ).copyWith(color: context.colors.foreground),
                  ),
                ),
                Transform.translate(
                  offset: const Offset(8, 0),
                  child: Switch.adaptive(
                    value: _shuffle,
                    onChanged: (v) => setState(() => _shuffle = v),
                  ),
                ),
              ],
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
                            _filterLabel(l10n, filter),
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
                            l10n.playSceneHdUpsellSubtitle,
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
                        _mediaTypes,
                        _selectedMomentIds,
                        _photoFilter,
                        _shuffle,
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
                      l10n.actionApply,
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

/// 공유 영상 준비 단계 가중치. 0..1 progress 안에서 각 단계가 차지하는 구간.
///   - render: 0.00 → 0.60 (PNG frame 생성, 보통 가장 오래 걸림)
///   - encode: 0.60 → 0.95 (PNG 시퀀스 → MP4 인코딩)
///   - dispatch: 0.95 → 1.00 (저장/공유 시트 호출, 거의 즉시)
const double _renderProgressEnd = 0.60;
const double _encodeProgressEnd = 0.95;

/// 공유 바텀시트 본문. 9:16 미리보기는 자체 타이머로 cycle하고, 채널 탭 시
/// 직접 frame 렌더 → AVAssetWriter 합성 → 채널별 dispatch까지 수행.
class _ShareSheet extends ConsumerStatefulWidget {
  const _ShareSheet({
    required this.frames,
    required this.initialIndex,
    required this.photoFilter,
    required this.sceneCoverUrl,
    required this.sceneNumber,
    required this.sceneTitle,
  });

  final List<ShareFrame> frames;
  final int initialIndex;
  final PhotoFilter photoFilter;
  // 컨택트 시트 중앙 캐니스터에 표시되는 scene 정보. multi-scene play일 때는
  // 첫 scene을 대표로.
  final String sceneCoverUrl;
  final int sceneNumber;
  final String sceneTitle;

  @override
  ConsumerState<_ShareSheet> createState() => _ShareSheetState();
}

class _ShareSheetState extends ConsumerState<_ShareSheet> {
  /// 메인 재생과 동일한 인터벌. 같은 페이스로 보여줘야 "공유될 영상" 감각 일치.
  static const _cyclePeriod = Duration(milliseconds: 750);
  static const _frameDuration = Duration(milliseconds: 750);

  late int _index;
  Timer? _timer;

  // 미리보기 템플릿 carousel — 0: 컨택트 시트(무료 회원용/썸네일 기반),
  // 1: 슬라이드쇼(풀사이즈 영상). 좌우 peek을 위해 viewportFraction이
  // 시트 가용 폭에 따라 달라지므로 LayoutBuilder가 fraction을 알려주면
  // 그때 controller 생성.
  PageController? _previewController;
  double? _previewFraction;
  int _previewPage = 0;

  PageController _controllerFor(double fraction) {
    if (_previewController == null || _previewFraction != fraction) {
      _previewController?.dispose();
      _previewController = PageController(
        initialPage: _previewPage,
        viewportFraction: fraction,
      );
      _previewFraction = fraction;
    }
    return _previewController!;
  }

  // 영상 준비 통합 진행률. render → encode → dispatch 모두 합쳐 0..1.
  bool _busy = false;
  double _overallProgress = 0.0;

  void _setProgress(double v) {
    if (!mounted) return;
    setState(() => _overallProgress = v.clamp(0.0, 1.0));
  }

  @override
  void initState() {
    super.initState();
    _index = widget.frames.isEmpty
        ? 0
        : widget.initialIndex.clamp(0, widget.frames.length - 1);
    _timer = Timer.periodic(_cyclePeriod, (_) {
      if (!mounted || widget.frames.length <= 1) return;
      // 슬라이드쇼 페이지(page 3)가 보일 때만 인덱스 진행 — 포커싱 안 된
      // 템플릿은 백그라운드로 돌지 않게. (0=ContactSheet, 1=Snake, 2=Stack,
      // 3=Slideshow 순서. 옛 코드는 page 2였는데 Stack이 끼면서 한 칸 밀림.)
      if (_previewPage != 3) return;
      setState(() {
        _index = (_index + 1) % widget.frames.length;
      });
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _previewController?.dispose();
    super.dispose();
  }

  Future<void> _handleChannel(_ShareChannel channel) async {
    if (_busy || widget.frames.isEmpty) return;
    // page 0(컨택트 시트)만 무료 사용 가능. page 1(스네이크), page 2(스택),
    // page 3(슬라이드쇼)은 Scenes HD 전용. UI상으로도 미리보기 위에 HD 뱃지
    // 가려져 있어 일반적으로는 도달하기 어렵지만 안전 게이트.
    if (_previewPage > 0 && !ref.read(isSubscribedProvider)) {
      Navigator.of(context).pop();
      Navigator.of(context).push(SubscriptionScreen.route());
      return;
    }
    setState(() {
      _busy = true;
      _overallProgress = 0;
    });

    // 단계별 onProgress 콜백을 통합 0..1 progress로 변환하는 헬퍼.
    // 스트리밍(iOS/Android)에선 render 루프가 인코딩까지 포함하므로 render
    // 진행을 거의 전체 바(0..renderProgressEnd)에 매핑해 실제 소요시간에
    // 비례하게 한다. 배치(fallback)에선 0..0.60만 쓰고 이후 encodeTick이 이어감.
    var renderProgressEnd = _renderProgressEnd;
    void renderTick(int current, int total) {
      if (total <= 0) return;
      _setProgress(renderProgressEnd * (current / total));
    }

    void encodeTick(int current, int total) {
      if (total <= 0) return;
      final span = _encodeProgressEnd - _renderProgressEnd;
      _setProgress(_renderProgressEnd + span * (current / total));
    }

    Directory? tempDir;
    // Android 스트리밍 인코딩 세션이 열려 있는지 — 예외/조기 return 시 finally에서
    // endCompose로 native encoder를 반드시 닫아 자원 누수를 막는다.
    var streamingSessionOpen = false;
    try {
      tempDir = await Directory.systemTemp.createTemp('scenes_share_');
      if (!mounted) return;

      // 1) 렌더 파라미터 결정. 애니메이션은 24fps로 통일(12fps 이하는 끊겨 보임),
      //    슬라이드쇼(page 3)는 _frameDuration의 역수.
      const animationFps = 24;
      final int fps = _previewPage == 3
          ? (1000 / _frameDuration.inMilliseconds).round()
          : animationFps;
      final Duration frameDuration = _previewPage == 3
          ? _frameDuration
          : Duration(milliseconds: (1000 / fps).round());
      final outputName = switch (_previewPage) {
        0 => 'scenes_contact_sheet.mp4',
        1 => 'scenes_snake.mp4',
        2 => 'scenes_stack.mp4',
        _ => 'scenes_share.mp4',
      };
      final outputPath = '${tempDir.path}/$outputName';

      // 2) frame 소비 sink. iOS/Android 모두 native encoder로 직접 스트리밍 —
      //    render한 frame을 raw RGBA로 바로 인코딩해 PNG 압축/디스크 적재를
      //    생략(render 병목 제거). PngFileSink+composeVideo 배치 경로는 미지원
      //    플랫폼용 fallback으로만 남겨둔다.
      final bool streaming = Platform.isAndroid || Platform.isIOS;
      final ShareFrameSink sink;
      if (streaming) {
        // 인코딩이 render 루프에 인라인되므로 render 진행을 거의 전체 바에
        // 매핑 — 남은 구간(endCompose finalize)은 짧아 98%에서 마감.
        renderProgressEnd = 0.98;
        await VideoComposer.instance.beginCompose(
          frameDuration: frameDuration,
          outputPath: outputPath,
        );
        streamingSessionOpen = true;
        sink = NativeStreamSink();
      } else {
        sink = PngFileSink(tempDir);
      }

      // 3) 페이지별 렌더 — sink로 frame 방출(스트리밍 시 인코딩까지 인라인).
      if (!mounted) return;
      final colorFilter = _colorFilterFor(widget.photoFilter);
      switch (_previewPage) {
        case 0:
          await ShareFrameRenderer.instance.renderContactSheetAnimation(
            context: context,
            frames: widget.frames,
            colorFilter: colorFilter,
            sink: sink,
            sceneCoverUrl: widget.sceneCoverUrl,
            sceneNumber: widget.sceneNumber,
            sceneTitle: widget.sceneTitle,
            fps: animationFps,
            onProgress: renderTick,
          );
        case 1:
          await ShareFrameRenderer.instance.renderSnakeAnimation(
            context: context,
            frames: widget.frames,
            colorFilter: colorFilter,
            sink: sink,
            sceneCoverUrl: widget.sceneCoverUrl,
            sceneNumber: widget.sceneNumber,
            sceneTitle: widget.sceneTitle,
            fps: animationFps,
            onProgress: renderTick,
          );
        case 2:
          await ShareFrameRenderer.instance.renderStackAnimation(
            context: context,
            frames: widget.frames,
            colorFilter: colorFilter,
            sink: sink,
            sceneCoverUrl: widget.sceneCoverUrl,
            sceneNumber: widget.sceneNumber,
            sceneTitle: widget.sceneTitle,
            fps: animationFps,
            onProgress: renderTick,
          );
        default:
          await ShareFrameRenderer.instance.renderFrames(
            context: context,
            frames: widget.frames,
            colorFilter: colorFilter,
            sink: sink,
            onProgress: renderTick,
          );
      }
      // 파이프라인에 걸린 마지막 frame append 완료 대기 후 finalize.
      await sink.finish();
      if (!mounted) return;
      _setProgress(renderProgressEnd);

      // 4) 인코딩 마무리 → 완성 영상 path.
      final String videoPath;
      if (streaming) {
        videoPath = await VideoComposer.instance.endCompose();
        streamingSessionOpen = false;
      } else {
        videoPath = await VideoComposer.instance.composeVideo(
          framePaths: (sink as PngFileSink).paths,
          frameDuration: frameDuration,
          outputPath: outputPath,
          onProgress: encodeTick,
        );
      }
      if (!mounted) return;
      _setProgress(_encodeProgressEnd);

      // 3) 채널별 dispatch.
      switch (channel) {
        case _ShareChannel.save:
          await _saveToGallery(videoPath);
        case _ShareChannel.story:
          await _shareToStory(videoPath);
        case _ShareChannel.more:
          await _shareGeneral(videoPath);
      }
      _setProgress(1.0);
      if (!mounted) return;
      Navigator.of(context).pop();
    } catch (e) {
      debugPrint('share render/dispatch failed: $e');
      if (!mounted) return;
      AppToast.show(
        context,
        AppLocalizations.of(context).playSceneShareFailedToast,
      );
      setState(() {
        _busy = false;
        _overallProgress = 0;
      });
    } finally {
      // 예외/조기 return으로 스트리밍 세션이 열린 채 남았으면 native encoder를
      // 닫아 자원 누수 방지(best-effort — 결과는 버림).
      if (streamingSessionOpen) {
        try {
          await VideoComposer.instance.endCompose();
        } catch (_) {}
      }
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
    // iOS: 사진 라이브러리 add-only 권한이 반드시 필요 — 게이트로 막는다.
    // Android: scoped storage(API 29+)라 자기 앱이 만든 미디어는 READ_MEDIA_*
    // read 권한 없이도 MediaStore에 insert할 수 있다. 오히려 read 권한을
    // 게이트로 걸면(동영상인데 READ_MEDIA_IMAGES만 선언돼 있어) 저장이
    // "권한 필요"로 잘못 막힌다. 그래서 Android는 권한 게이트를 건너뛰고
    // photo_manager 내부 권한 체크도 우회한 뒤 바로 저장한다.
    if (Platform.isIOS) {
      final permission = await PhotoManager.requestPermissionExtend(
        requestOption: const PermissionRequestOption(
          iosAccessLevel: IosAccessLevel.addOnly,
        ),
      );
      // hasAccess = authorized || limited. limited(일부 사진만 허용)여도 add는
      // 가능하므로 authorized만 요구하지 않는다.
      if (!permission.hasAccess) {
        if (mounted) {
          AppToast.show(
            context,
            AppLocalizations.of(context).playScenePhotoPermissionToast,
          );
        }
        return;
      }
      await PhotoManager.editor.saveVideo(
        File(videoPath),
        title: 'scenes_share_${DateTime.now().millisecondsSinceEpoch}.mp4',
      );
    } else {
      // Android: 내부 read-permission 체크를 저장 구간에만 껐다 되돌린다.
      // 전역 true로 두면 이후 사진 선택(picker) 읽기가 권한 없이 빈 결과를
      // 반환할 수 있어 반드시 finally에서 원복.
      try {
        await PhotoManager.setIgnorePermissionCheck(true);
        // relativePath로 DCIM/Scenes에 저장 — photo_manager 기본값은 Movies/
        // 인데, Google Photos 등은 Movies/를 메인 타임라인에 안 띄우고 "기기
        // 폴더"에만 숨겨 "저장했는데 앨범에 안 보임" 문제가 난다. DCIM 아래로
        // 넣으면 카메라 롤 타임라인에 바로 뜨고 Scenes 앨범으로도 묶인다.
        await PhotoManager.editor.saveVideo(
          File(videoPath),
          title: 'scenes_share_${DateTime.now().millisecondsSinceEpoch}.mp4',
          relativePath: 'DCIM/Scenes',
        );
      } finally {
        await PhotoManager.setIgnorePermissionCheck(false);
      }
    }
    if (mounted) {
      AppToast.show(
        context,
        AppLocalizations.of(context).playSceneSavedToPhotosToast,
      );
    }
  }

  Future<void> _shareToStory(String videoPath) async {
    try {
      await VideoComposer.instance.shareToInstagramStory(videoPath: videoPath);
    } on PlatformException catch (e) {
      // IG 미설치 등으로 직접 attach 안 되면 일반 공유 시트로 fallback.
      if (e.code == 'unavailable') {
        if (mounted) {
          AppToast.show(
            context,
            AppLocalizations.of(context).playSceneInstagramMissingToast,
          );
        }
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
    final isHd = ref.watch(isSubscribedProvider);

    return Padding(
      // carousel이 시트 가용 폭을 다 써서 좌우 peek을 확보하도록 horizontal
      // padding은 각 children이 개별로 들고 있고, 시트 자체엔 bottom만.
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Text(
              'Share',
              style: AppTypography.display(20).copyWith(
                color: context.colors.foreground,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(height: 16),
          // 미리보기 carousel — page 0: 컨택트 시트(default, free),
          // page 1: 스택(lens, HD), page 2: 슬라이드쇼(HD). viewportFraction을
          // 시트 폭 기준으로 계산해 포커싱된 페이지는 정확히 logical width로,
          // 좌우 인접 페이지는 가장자리에 peek.
          SizedBox(
            height: kShareFrameLogicalHeight,
            child: widget.frames.isEmpty
                ? Center(
                    child: ClipRRect(
                      borderRadius: AppRadii.smBorder,
                      child: SizedBox(
                        width: kShareFrameLogicalWidth,
                        height: kShareFrameLogicalHeight,
                        child: const ColoredBox(color: Color(0xFF1C1C1E)),
                      ),
                    ),
                  )
                : LayoutBuilder(
                    builder: (context, constraints) {
                      // slot = logical width + gap. fraction = slot / available.
                      // 시트가 좁아 fraction이 1 근접하면 peek이 거의 안 보임 —
                      // 그건 사용자 화면이 정말 좁을 때 자연스러운 fallback.
                      const slotWidth = kShareFrameLogicalWidth + 12;
                      final fraction =
                          (slotWidth / constraints.maxWidth).clamp(0.4, 0.98);
                      final controller = _controllerFor(fraction);
                      final slideshow = ShareFrameView(
                        frame: frame!,
                        image: NetworkImage(frame.url),
                        colorFilter: colorFilter,
                      );
                      final snake = SnakeShareView(
                        frames: widget.frames,
                        colorFilter: colorFilter,
                        sceneCoverUrl: widget.sceneCoverUrl,
                        sceneNumber: widget.sceneNumber,
                        sceneTitle: widget.sceneTitle,
                        isPlaying: _previewPage == 1,
                      );
                      final stack = StackShareView(
                        frames: widget.frames,
                        colorFilter: colorFilter,
                        sceneCoverUrl: widget.sceneCoverUrl,
                        sceneNumber: widget.sceneNumber,
                        sceneTitle: widget.sceneTitle,
                        isPlaying: _previewPage == 2,
                      );
                      // page 0(컨택트 시트)만 무료. page 1(스네이크), page 2
                      // (스택), page 3(슬라이드쇼)은 Scenes HD 전용. 무료
                      // 회원에겐 HD 페이지 위에 dim + HD 뱃지 오버레이. 탭하면
                      // 시트를 닫고 SubscriptionScreen으로.
                      final pages = <Widget>[
                        ContactSheetView(
                          frames: widget.frames,
                          colorFilter: colorFilter,
                          isPlaying: _previewPage == 0,
                          sceneCoverUrl: widget.sceneCoverUrl,
                          sceneNumber: widget.sceneNumber,
                          sceneTitle: widget.sceneTitle,
                        ),
                        isHd ? snake : _SlideshowHdLock(child: snake),
                        isHd ? stack : _SlideshowHdLock(child: stack),
                        isHd
                            ? slideshow
                            : _SlideshowHdLock(child: slideshow),
                      ];
                      return PageView.builder(
                        controller: controller,
                        itemCount: pages.length,
                        onPageChanged: (i) =>
                            setState(() => _previewPage = i),
                        itemBuilder: (context, i) {
                          return AnimatedBuilder(
                            animation: controller,
                            builder: (context, _) {
                              // 포커싱된 페이지는 1.0, 인접 페이지는 0.86까지
                              // 줄어드는 linear taper. controller.page는 layout
                              // 이전엔 null이라 _previewPage로 fallback.
                              double page = _previewPage.toDouble();
                              if (controller.position.haveDimensions) {
                                page = controller.page ?? page;
                              }
                              final t =
                                  (i - page).abs().clamp(0.0, 1.0);
                              final scale = 1.0 - 0.14 * t;
                              return Center(
                                child: Transform.scale(
                                  scale: scale,
                                  child: ClipRRect(
                                    borderRadius: AppRadii.smBorder,
                                    child: SizedBox(
                                      width: kShareFrameLogicalWidth,
                                      height: kShareFrameLogicalHeight,
                                      child: pages[i],
                                    ),
                                  ),
                                ),
                              );
                            },
                          );
                        },
                      );
                    },
                  ),
          ),
          const SizedBox(height: 10),
          // 페이지 인디케이터.
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(4, (i) {
              final active = i == _previewPage;
              return AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                margin: const EdgeInsets.symmetric(horizontal: 3),
                width: active ? 16 : 6,
                height: 6,
                decoration: BoxDecoration(
                  color: active
                      ? context.colors.foreground
                      : context.colors.foreground.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(3),
                ),
              );
            }),
          ),
          const SizedBox(height: 14),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: _busy
                ? _ProgressFooter(progress: _overallProgress)
                : Builder(builder: (context) {
                    final l10n = AppLocalizations.of(context);
                    // page 1(스택), page 2(슬라이드쇼)는 HD 전용. 무료 회원
                    // 에겐 채널 셀을 dim 처리 — 시각적으로 잠긴 상태를 알리고,
                    // 탭하면 _handleChannel이 SubscriptionScreen으로 라우팅.
                    final lockedHd = _previewPage > 0 &&
                        !ref.watch(isSubscribedProvider);
                    return Row(
                      children: [
                        Expanded(
                          child: _ChannelCell(
                            icon: FontAwesomeIcons.download,
                            label: l10n.actionSave,
                            dimmed: lockedHd,
                            onTap: () =>
                                _handleChannel(_ShareChannel.save),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _ChannelCell(
                            icon: FontAwesomeIcons.instagram,
                            label: l10n.playSceneShareStory,
                            dimmed: lockedHd,
                            onTap: () =>
                                _handleChannel(_ShareChannel.story),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _ChannelCell(
                            icon: FontAwesomeIcons.ellipsis,
                            label: l10n.playSceneShareMore,
                            dimmed: lockedHd,
                            onTap: () =>
                                _handleChannel(_ShareChannel.more),
                          ),
                        ),
                      ],
                    );
                  }),
          ),
        ],
      ),
    );
  }

}

/// 슬라이드쇼 미리보기를 가리는 Scenes HD 락 레이어. 무료 회원이 share 시트
/// 에서 슬라이드쇼 페이지로 넘기면 보이며, 탭하면 시트를 닫고 SubscriptionScreen
/// 으로 보낸다. 슬라이드쇼는 풀 화질 egress가 크고 HD 전용 기능이라 게이트.
class _SlideshowHdLock extends StatelessWidget {
  const _SlideshowHdLock({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        // 슬라이드쇼 미리보기는 살짝 보이게 — 무엇이 잠겼는지 teaser 역할.
        ColorFiltered(
          colorFilter: ColorFilter.mode(
            Colors.black.withValues(alpha: 0.35),
            BlendMode.srcATop,
          ),
          child: child,
        ),
        // 추가 dim — 가운데 뱃지 가독성 확보.
        const ColoredBox(color: Color(0x66000000)),
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () {
              Navigator.of(context).pop();
              Navigator.of(context).push(SubscriptionScreen.route());
            },
            child: Center(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.25),
                        width: 0.6,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Scenes HD',
                          style: AppTypography.body(
                            13,
                            weight: FontWeight.w600,
                          ).copyWith(color: Colors.white),
                        ),
                        const SizedBox(width: 6),
                        const FaIcon(
                          FontAwesomeIcons.chevronRight,
                          size: 10,
                          color: Colors.white,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// 진행률 footer. 라벨 + linear progress + "X / N" 카운터.
/// 공유 영상 준비 진행률 footer. 렌더링·인코딩·디스패치 모든 단계를 합쳐
/// 하나의 0..1 progress로 표시 — 단계 라벨/n-of-N 카운트 없이 % 만.
class _ProgressFooter extends StatelessWidget {
  const _ProgressFooter({required this.progress});

  /// 전체 작업 대비 완료 비율(0..1).
  final double progress;

  @override
  Widget build(BuildContext context) {
    final clamped = progress.clamp(0.0, 1.0);
    final percent = (clamped * 100).round();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ClipRRect(
            borderRadius: AppRadii.xsBorder,
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: clamped),
              duration: const Duration(milliseconds: 220),
              curve: Curves.linear,
              builder: (context, v, _) => LinearProgressIndicator(
                value: v,
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
            '$percent%',
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
    this.dimmed = false,
  });

  final FaIconData icon;
  final String label;
  final VoidCallback onTap;
  // 무료 회원이 HD 전용 채널(슬라이드쇼 page에서의 share)을 인지하도록 표시.
  // 탭은 그대로 허용하지만 GestureDetector handler가 SubscriptionScreen으로
  // 라우팅한다.
  final bool dimmed;

  @override
  Widget build(BuildContext context) {
    final cell = Container(
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
    );
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Opacity(
        opacity: dimmed ? 0.4 : 1.0,
        child: cell,
      ),
    );
  }
}
