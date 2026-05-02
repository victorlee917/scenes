import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:grain/grain.dart';

import '../../../core/theme/app_colors_ext.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/theme/app_radii.dart';
import '../../../core/widgets/confirm_dialog.dart';
import '../../../core/widgets/floating_bottom_sheet.dart';
import '../../subscription/subscription_screen.dart';
import '../models/scene.dart';
import 'moment_selection_screen.dart';

/// Scene 재생 화면.
///
/// 진입 시 선택된 Scene들의 콘텐츠를 로딩한 뒤 재생 모드로 전환.
class PlaySceneScreen extends StatefulWidget {
  const PlaySceneScreen({
    super.key,
    required this.scenes,
  });

  final List<Scene> scenes;

  static Route<void> route({required List<Scene> scenes}) {
    return PageRouteBuilder<void>(
      opaque: true,
      transitionDuration: const Duration(milliseconds: 400),
      reverseTransitionDuration: Duration.zero,
      pageBuilder: (context, animation, secondaryAnimation) =>
          PlaySceneScreen(scenes: scenes),
      transitionsBuilder:
          (context, animation, secondaryAnimation, child) {
        return FadeTransition(opacity: animation, child: child);
      },
    );
  }

  @override
  State<PlaySceneScreen> createState() => _PlaySceneScreenState();
}

enum PhotoFilter { normal, vintage, cinema, mono }

class _PlaySceneScreenState extends State<PlaySceneScreen>
    with SingleTickerProviderStateMixin {
  bool _expanding = false;
  bool _playing = false;
  PhotoFilter _photoFilter = PhotoFilter.normal;
  bool _paused = false;
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

  // 필터 적용 후 재생 대상
  List<String> _playUrls = [];
  List<int> _playSceneIndex = [];
  List<DateTime> _playDates = [];
  List<String> _filteredMediaTypes = [];

  // 필터 상태
  late Set<String> _selectedSceneIds;
  final Set<String> _selectedMediaTypes = {'photo', 'film', 'music', 'place'};

  final _dialKey = GlobalKey<_IndexDialState>();
  late final AnimationController _expandController;
  late final Animation<double> _expandAnimation;
  bool _autoPlayScheduled = false;

  static const List<String> _mockMediaCycle = [
    'photo', 'photo', 'film', 'photo', 'music',
    'photo', 'place', 'photo', 'film', 'music',
    'photo', 'place',
  ];

  @override
  void initState() {
    super.initState();
    _selectedSceneIds = widget.scenes.map((s) => s.id).toSet();
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
        _scheduleNextContent();
      }
    });
    _loadContent();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
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
      precacheImage(NetworkImage(scene.coverImageUrl), context);
    }
  }

  Future<void> _loadContent() async {
    final total = widget.scenes.length;

    for (int s = 0; s < total; s++) {
      if (!mounted) return;
      setState(() => _currentLoadingIndex = s);

      // mock: 각 Scene의 콘텐츠 로드 시뮬레이션
      final scene = widget.scenes[s];
      final contentCount = scene.media.total > 0 ? scene.media.total : 3;
      for (int c = 0; c < contentCount; c++) {
        await Future<void>.delayed(const Duration(milliseconds: 200));
        if (!mounted) return;
        final thumbUrl = 'https://picsum.photos/seed/play-$s-$c/400/300';
        setState(() {
          _loadedThumbs.add(thumbUrl);
        });
        final hiRes = _hiResUrl(thumbUrl);
        final mediaType = _mockMediaCycle[(s * contentCount + c) % _mockMediaCycle.length];
        final provider = NetworkImage(hiRes);
        _imageProviders[hiRes] = provider;
        _allPlayUrls.add(hiRes);
        _allPlaySceneIndex.add(s);
        _allPlayDates.add(scene.dates.first.add(Duration(days: c * 3)));
        _allMediaTypes.add(mediaType);
        precacheImage(provider, context);
      }

      if (!mounted) return;
      setState(() {
        _completedScenes.add(s);
        _loadProgress = (s + 1) / total;
      });
    }

    if (mounted) {
      _applyFilter();
      setState(() {
        _loadedThumbs.add(_playUrls.first);
      });
    }
  }

  ColorFilter? get _colorFilter {
    switch (_photoFilter) {
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

  Widget _wrapGrain({required bool enabled, required Widget child}) {
    if (!enabled) return child;
    return GrainFiltered(
      scale: 0.4,
      child: child,
    );
  }

  Widget _buildPlayerImage() {
    final image = Image(
      image: _imageProviders[_playUrls[_playIndex]]!,
      width: 220,
      height: 130,
      fit: BoxFit.cover,
      gaplessPlayback: true,
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

    final filter = _colorFilter;
    if (filter == null) return image;
    return ColorFiltered(colorFilter: filter, child: image);
  }

  bool get _loadComplete => _loadProgress >= 1.0;
  bool get _readyToPlay => _loadComplete && !_expanding;

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

  String _hiResUrl(String thumbUrl) =>
      thumbUrl.replaceAll('400/300', '1600/1200');


  void _applyFilter() {
    _playUrls = [];
    _playSceneIndex = [];
    _playDates = [];
    _filteredMediaTypes = [];

    for (int i = 0; i < _allPlayUrls.length; i++) {
      final sceneId = widget.scenes[_allPlaySceneIndex[i]].id;
      final mediaType = _allMediaTypes[i];
      if (_selectedSceneIds.contains(sceneId) &&
          _selectedMediaTypes.contains(mediaType)) {
        _playUrls.add(_allPlayUrls[i]);
        _playSceneIndex.add(_allPlaySceneIndex[i]);
        _playDates.add(_allPlayDates[i]);
        _filteredMediaTypes.add(mediaType);
      }
    }

    if (_playIndex >= _playUrls.length) {
      _playIndex = _playUrls.isEmpty ? 0 : _playIndex % _playUrls.length;
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
        photoFilter: _photoFilter,
        isSubscribed: false, // TODO: 실제 구독 상태 연결
        onApply: (sceneIds, mediaTypes, filter) {
          setState(() {
            _selectedSceneIds = sceneIds;
            _selectedMediaTypes
              ..clear()
              ..addAll(mediaTypes);
            _photoFilter = filter;
            _applyFilter();
            _playIndex = 0;
            _infoIndex = 0;
            if (!wasPaused && _playUrls.isNotEmpty) {
              _paused = false;
              _scheduleNextContent();
            }
          });
        },
      ),
    ).then((_) {
      if (!wasPaused && _playUrls.isNotEmpty && mounted) {
        setState(() => _paused = false);
        _scheduleNextContent();
      }
    });
  }

  Scene get _currentScene =>
      widget.scenes[_playSceneIndex[_infoIndex]];

  Widget _buildPlayInfo() {
    final scene = _currentScene;
    final date = _playDates[_infoIndex];
    final dateStr = '${date.year}.${date.month.toString().padLeft(2, '0')}.${date.day.toString().padLeft(2, '0')}';

    return Row(
      children: [
        ClipOval(
          child: SizedBox(
            width: 32,
            height: 32,
            child: Image.network(
              scene.coverImageUrl,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => Container(
                color: Colors.white.withValues(alpha: 0.1),
              ),
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

  @override
  Widget build(BuildContext context) {
    final expandValue = _expanding ? _expandAnimation.value : 0.0;
    final infoOpacity = (1.0 - expandValue * 3).clamp(0.0, 1.0);
    final padding = MediaQuery.paddingOf(context);

    Widget body = Stack(
          children: [
            // 쌍안경 / 플레이어 이미지
            _wrapGrain(
              enabled: _playing && _photoFilter != PhotoFilter.normal,
              child: Center(
                child: AnimatedBuilder(
                  animation: _expandAnimation,
                  builder: (context, child) {
                    final ev = _playing ? 1.0 : (_expanding ? _expandAnimation.value : 0.0);
                    final scale = 1.0 + ev * 12.0;
                    return Transform.scale(
                      scale: scale,
                      child: child,
                    );
                  },
                  child: ClipPath(
                    clipper: _BinocularClipper(),
                    child: SizedBox(
                      width: 220,
                      height: 130,
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          Container(color: Colors.black),
                          if (_playing)
                            _buildPlayerImage(),
                          if (!_playing) ...[
                            for (final url in _loadedThumbs)
                              Image.network(
                                url,
                                width: 220,
                                height: 130,
                                fit: BoxFit.cover,
                                errorBuilder: (_, _, _) =>
                                    const SizedBox.shrink(),
                              ),
                          ],
                        ],
                      ),
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
                        onTap: () {
                          // TODO: share
                        },
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

            // 하단 정보 (로딩 중, expand 시 fade out)
            if (!_playing && infoOpacity > 0)
              Positioned(
                left: 48,
                right: 48,
                bottom: padding.bottom + 80,
                child: Opacity(
                  opacity: infoOpacity,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (_readyToPlay)
                        GestureDetector(
                          onTap: _startPlay,
                          child: Container(
                            width: 56,
                            height: 56,
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.white,
                            ),
                            child: const Center(
                              child: Padding(
                                padding: EdgeInsets.only(left: 3),
                                child: Icon(
                                  Icons.play_arrow_rounded,
                                  size: 32,
                                  color: Colors.black,
                                ),
                              ),
                            ),
                          ),
                        ),
                      if (!_loadComplete) ...[
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
                      ],
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
  static final _bgColor = Colors.white.withValues(alpha: 0.15);

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
class _BinocularClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final r = size.height / 2;
    final leftCenter = Offset(r, r);
    final rightCenter = Offset(size.width - r, r);

    final path = Path()
      ..addOval(Rect.fromCircle(center: leftCenter, radius: r))
      ..addOval(Rect.fromCircle(center: rightCenter, radius: r));
    return path;
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}

/// 좌→우로 반짝이는 shimmer 텍스트.
class _PlayFilterSheet extends StatefulWidget {
  const _PlayFilterSheet({
    required this.scenes,
    required this.selectedSceneIds,
    required this.selectedMediaTypes,
    required this.photoFilter,
    required this.onApply,
    this.isSubscribed = false,
  });

  final List<Scene> scenes;
  final Set<String> selectedSceneIds;
  final Set<String> selectedMediaTypes;
  final PhotoFilter photoFilter;
  final bool isSubscribed;
  final void Function(Set<String> sceneIds, Set<String> mediaTypes, PhotoFilter filter) onApply;

  @override
  State<_PlayFilterSheet> createState() => _PlayFilterSheetState();
}

class _PlayFilterSheetState extends State<_PlayFilterSheet> {
  late final Set<String> _sceneIds;
  late final Set<String> _mediaTypes;
  late PhotoFilter _photoFilter;

  /// MomentSelectionScreen에서 선택한 콘텐츠 ID. 비어 있으면 "전체" 의미.
  final Set<String> _selectedMomentIds = {};

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
        if (widget.isSubscribed)
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
                      widget.onApply(_sceneIds, _mediaTypes, _photoFilter);
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
