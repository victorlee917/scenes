import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_typography.dart';
import '../../home/widgets/scene_title_fallback.dart';

/// 공유 영상 frame의 logical 사이즈. 시트 미리보기와 off-screen 렌더러가
/// 동일 비율을 쓰도록 한 곳에서 관리. 9:16 비율 유지.
const double kShareFrameLogicalWidth = 220;
const double kShareFrameLogicalHeight = 391;

/// 실제 영상 output 가로 픽셀. 1080×1920 유지를 위해 렌더러는
/// pixelRatio = kShareFrameOutputWidth / kShareFrameLogicalWidth 로 캡처.
const double kShareFrameOutputWidth = 1080;

/// 공유 템플릿(컨택트 시트, 스택, 슬라이드쇼 등)에서 사진 카드 뒤 배경으로
/// 공통 사용하는 어두운 세로 그라데이션. 한 곳에서 정의해 템플릿 간 톤 통일.
class ShareTemplateBackdrop extends StatelessWidget {
  const ShareTemplateBackdrop({super.key});

  @override
  Widget build(BuildContext context) {
    return const DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFF161618),
            Color(0xFF0E0E10),
          ],
        ),
      ),
    );
  }
}

/// 공유 영상의 한 frame을 구성하는 데이터.
///
/// 두 URL 변형을 보관해 출력 경로별로 적절한 화질을 선택한다:
/// - `url`: 시트 미리보기 + contact sheet 렌더가 사용. tier에 따라 호출자가
///   다른 화질을 넣는다.
///   · 무료 회원: full URL — play 메인이 이미 캐시한 URL과 같아 ImageCache
///     hit으로 추가 egress 없이 재사용. 30장 cap이라 메모리 부담은 LRU가
///     자연 회전으로 흡수.
///   · HD 회원: thumb URL — 100장 × 2560 RGBA가 ImageCache cap을 초과해
///     decode thrashing 위험. 별도 thumb으로 받아 메모리 보호.
/// - `renderUrl` (full, photo는 1920/2560 long-edge WebP): 슬라이드쇼 video
///   pipeline에서 한 장씩 1080×1920에 fit하는 hero 이미지로 사용 — 풀 화질이
///   1:1 매칭. 슬라이드쇼 자체는 HD 전용. null 입력 시 url로 fallback.
class ShareFrame {
  const ShareFrame({
    required this.url,
    required String? renderUrl,
    required this.sceneName,
    required this.sceneNumber,
    required this.occurredAt,
    required this.mediaType,
    this.aspect,
  }) : renderUrl = renderUrl ?? url;

  /// 시트 미리보기 + contact sheet 렌더용. ContactSheetView 내부의
  /// `NetworkImage(frame.url)` 키와 정확히 일치해야 ImageCache hit 가능.
  final String url;

  /// 슬라이드쇼 video pipeline용 풀 화질 URL. 1080×1920 출력에 hero 이미지
  /// 한 장으로 들어가므로 풀로 받아야 화질 손실 없음.
  final String renderUrl;

  final String sceneName;
  final int sceneNumber;
  final DateTime occurredAt;

  /// 'photo' | 'film' | 'music' | 'place'.
  final String mediaType;

  /// 사진 원본의 가로/세로 비율(width/height). 알 수 없으면 null — view는
  /// fallback 적용. Stack 템플릿이 각 카드의 높이를 결정할 때 사용.
  final double? aspect;
}

/// 공유 영상의 한 frame을 그리는 위젯.
///
/// 같은 위젯 트리를 두 곳에서 재사용:
/// - 공유 시트 안의 미리보기(180×320, NetworkImage)
/// - 영상 렌더러가 off-screen에서 캡처(180×320 + pixelRatio 6.0 → 1080×1920,
///   MemoryImage)
///
/// 부모가 SizedBox 등으로 사이즈를 정하는 것을 전제 — 이 위젯 자체는 부모를
/// 가득 채운다(StackFit.expand). 9:16 기준 디자인이라 부모도 그 비율로 줘야 함.
///
/// [colorFilter]는 사진 필터(`PhotoFilter`)를 그대로 적용 — 미디어 레이어 전체
/// (bg/blur backdrop/dim/card)에 한 번에 걸려 톤이 통일됨. 텍스트와 그라데이션
/// 오버레이는 필터 영향을 안 받게 바깥 Stack에 둠.
class ShareFrameView extends StatelessWidget {
  const ShareFrameView({
    super.key,
    required this.frame,
    required this.image,
    required this.colorFilter,
  });

  final ShareFrame frame;
  final ImageProvider image;
  final ColorFilter? colorFilter;

  String _typeLabel(String type) {
    switch (type) {
      case 'photo':
        return 'Photo';
      case 'film':
        return 'Film';
      case 'music':
        return 'Music';
      case 'place':
        return 'Place';
      default:
        return type;
    }
  }

  Widget _wrapFilter(Widget child) =>
      colorFilter == null ? child : ColorFiltered(colorFilter: colorFilter!, child: child);

  Widget _baseImage({required BoxFit fit, FilterQuality? quality}) {
    return Image(
      image: image,
      fit: fit,
      // gaplessPlayback: cycle/렌더 시 새 프레임 도착 전까지 이전 프레임 유지 →
      // 한 박자 검정 깜빡임 방지.
      gaplessPlayback: true,
      filterQuality: quality ?? FilterQuality.medium,
      errorBuilder: (_, _, _) => const ColoredBox(color: Color(0xFF1C1C1E)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final mediaLayer = Stack(
      fit: StackFit.expand,
      children: [
        // 베이스 bg — 로딩/빈 상태 가림용.
        const ColoredBox(color: Color(0xFF1C1C1E)),
        if (frame.mediaType == 'photo')
          _baseImage(fit: BoxFit.cover)
        else ...[
          // 매체별 대표 이미지를 강하게 blur한 배경 — 카드 주변 빈 영역을
          // 이미지의 대표 색감으로 채워줌.
          Positioned.fill(
            child: ImageFiltered(
              imageFilter: ui.ImageFilter.blur(sigmaX: 30, sigmaY: 30),
              child: _baseImage(
                fit: BoxFit.cover,
                quality: FilterQuality.low,
              ),
            ),
          ),
          // 가벼운 다크 dim — 카드와 backdrop 대비 보강.
          Positioned.fill(
            child: ColoredBox(
              color: Colors.black.withValues(alpha: 0.25),
            ),
          ),
          // 카드는 텍스트 영역 위쪽 공간에서 중앙 정렬. 하단 padding 60은
          // 텍스트 영역만큼 비워놓아 그 위 영역의 가운데에 카드가 오게.
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 60),
            child: Center(
              child: AspectRatio(
                aspectRatio: frame.mediaType == 'film' ? 2 / 3 : 1.0,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: _baseImage(fit: BoxFit.cover),
                ),
              ),
            ),
          ),
        ],
      ],
    );

    return Stack(
      fit: StackFit.expand,
      children: [
        // 미디어 레이어에만 필터 적용 — 그라데이션/텍스트는 영향 X.
        _wrapFilter(mediaLayer),

        // 하단 검정 그라데이션 — 약 40% 높이를 덮어 텍스트 가독성만 확보하고
        // 위쪽 콘텐츠는 살림.
        const Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          height: 130,
          child: IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color(0x00000000),
                    Color(0xCC000000),
                  ],
                ),
              ),
            ),
          ),
        ),
        Positioned(
          left: 12,
          right: 12,
          bottom: 12,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                frame.sceneName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: AppTypography.display(9, text: frame.sceneName)
                    .copyWith(color: Colors.white),
              ),
              const SizedBox(height: 5),
              Text(
                '${DateFormat.yMMMd('en').format(frame.occurredAt)} · '
                '${_typeLabel(frame.mediaType)}',
                textAlign: TextAlign.center,
                style: AppTypography.body(5).copyWith(
                  color: Colors.white.withValues(alpha: 0.4),
                  letterSpacing: 0.3,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// 컨택트 시트 템플릿 — thumb URL(600px)을 그대로 사용하므로 storage
/// egress 60배 절감 + 화질 저하 0. 3 cols × N rows 그리드(N=ceil(count/3),
/// 3..5 clamp), 사진 수가 부족하면 끝쪽 셀은 검정.
///
/// 애니메이션: 비어있는 상태에서 시작 → 랜덤 순서로 한 장씩 fade-in → 모두
/// 찬 상태로 잠깐 hold → 또 다른 랜덤 순서로 fade-out → 다시 비어있는 상태.
/// 한 사이클이 끝나면 reveal/hide 순서를 새 셔플로 다시 시작.
class ContactSheetView extends StatefulWidget {
  const ContactSheetView({
    super.key,
    required this.frames,
    required this.colorFilter,
    required this.sceneCoverUrl,
    required this.sceneNumber,
    required this.sceneTitle,
    this.isPlaying = true,
    this.staticFull = false,
    this.overrideProgress,
  });

  final List<ShareFrame> frames;
  final ColorFilter? colorFilter;

  /// 중앙 셀에 표시할 scene 캐니스터 정보. 빈 URL이면 타이틀 첫 글자 fallback.
  final String sceneCoverUrl;
  final int sceneNumber;
  final String sceneTitle;

  /// false면 reveal/hide 애니메이션이 현재 프레임에서 정지. carousel에서
  /// 포커싱 안 된 페이지가 백그라운드로 도는 걸 막기 위한 용도.
  final bool isPlaying;

  /// 공유용 capture 모드 — animation 무시하고 모든 셀이 채워진 상태로
  /// 즉시 그림. RepaintBoundary로 한 장 PNG 추출할 때 사용.
  final bool staticFull;

  /// null이면 내부 [_controller.value]를 progress로 사용. not null이면 외부
  /// 0..1 progress 값을 주입해 매 frame을 직접 제어 — 영상 캡처용.
  final double? overrideProgress;

  // 한 cycle(reveal → hold-on → hide → hold-off) 길이. 사진 수에 따라 동적.
  // 외부 캡처 로직이 video 총 길이를 결정할 때 사용.
  static const int _staggerMs = 180;
  static const int _fadeMs = 350;
  static const int _holdOnMs = 1200;
  static const int _holdOffMs = 600;
  static int totalCycleMs(int photoCount) {
    final n = math.min(photoCount, maxPhotos);
    final phaseMs = n == 0 ? 300 : _staggerMs * n + _fadeMs;
    return phaseMs * 2 + _holdOnMs + _holdOffMs;
  }

  // 한 scene에 들어올 수 있는 사진 한도. 그리드는 N에 맞춰 가장 작은 홀수
  // 정사각형(3×3, 5×5, …, 11×11)으로 동적 결정. 11×11 = 121 cell이라
  // canister(중앙) + 사진 120장까지 수용.
  static const int maxPhotos = 120;

  @override
  State<ContactSheetView> createState() => _ContactSheetViewState();
}

class _ContactSheetViewState extends State<ContactSheetView>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late List<int> _revealStep;
  late List<int> _hideStep;
  late int _filledCount;
  // 그리드는 정사각(_cols == _rows)이고 홀수 — 중앙 셀이 항상 존재하도록.
  late int _cols;
  late int _rows;
  // 그리드 인덱스(r*cols+c) → filled rank(0..N-1). 채워지지 않는 셀은 -1.
  // 중앙에서 방사형 거리 순으로 rank가 매겨져 사진 수가 적을수록 중앙에 몰림.
  late List<int> _gridToFilled;
  // 캐니스터가 표시되는 중앙 셀의 grid index. 항상 reserve됨.
  late int _centerCellIndex;
  late int _totalMs;
  late int _lightUpEndMs;
  late int _holdOnEndMs;
  late int _lightOffEndMs;

  static const Duration _perCellStagger = Duration(milliseconds: 180);
  static const Duration _fadeDuration = Duration(milliseconds: 350);
  static const Duration _holdOn = Duration(milliseconds: 1200);
  static const Duration _holdOff = Duration(milliseconds: 600);

  @override
  void initState() {
    super.initState();
    _computeLayout();
    _shuffleOrders();
    _computePhases();
    _controller = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: _totalMs),
    )..addStatusListener((s) {
        if (s == AnimationStatus.completed && mounted && widget.isPlaying) {
          _shuffleOrders();
          _controller.forward(from: 0);
        }
      });
    if (widget.isPlaying) _controller.forward();
  }

  @override
  void didUpdateWidget(covariant ContactSheetView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isPlaying != widget.isPlaying) {
      if (widget.isPlaying) {
        // 완료된 상태에서 멈춰 있었다면 새 사이클 시작.
        if (_controller.status == AnimationStatus.completed) {
          _shuffleOrders();
          _controller.forward(from: 0);
        } else {
          _controller.forward();
        }
      } else {
        _controller.stop();
      }
    }
  }

  /// 현재 사진 수에 맞춰 행 수와 셀→프레임 매핑을 결정. 중앙 셀은 항상
  /// canister 전용으로 reserve되고 사진들은 그 주변에 방사형 대칭으로 깔림.
  ///
  /// 1. 행 수는 3(≤8장) 또는 5(≥9장). 4행은 행 수가 짝수라 mirror-pair가
  ///    깨져 N=홀수일 때 대칭 채움이 불가능 → 8↔9에서 점프.
  /// 2. 셀들을 (중심 거리² → 행거리 |dr| → mirror-pair 그룹) 순으로 정렬.
  /// 3. 중앙 셀(rank 0)은 항상 canister용으로 reserve. 사진은 ordered[1..]
  ///    에 mirror-pair 순으로 채워짐 → N이 짝수면 완전 대칭, 홀수면 마지막
  ///    한 장만 비대칭(불가피).
  ///
  /// 결과 패턴 예시 (3×3, 중앙=canister):
  ///   N=0 → canister만.       N=2 → 수평 페어 + canister.
  ///   N=4 → 십자(중앙 canister). N=6 → 십자 + 대각 페어.
  ///   N=8 → 가득(중앙 canister).
  void _computeLayout() {
    final n = math.min(widget.frames.length, ContactSheetView.maxPhotos);
    _filledCount = n;
    // N+1(canister 포함)을 담을 가장 작은 홀수 정사각형 side. 홀수여야 중심
    // 셀이 존재해 mirror-pair 대칭 + canister reserve가 모두 성립.
    var side = math.max(3, math.sqrt(n + 1).ceil());
    if (side.isEven) side += 1;
    _cols = side;
    _rows = side;
    final cols = _cols;

    final centerR = (_rows - 1) / 2.0;
    final centerC = (cols - 1) / 2.0;
    final total = _rows * cols;

    // (1) shell(중앙거리²) 그룹화. (2) shell 내에서 mirror-pair로 묶고
    // pair끼리 정렬해 partial-fill 시에도 항상 대칭이 떨어지도록 한다.
    final byShell = <num, List<int>>{};
    for (var i = 0; i < total; i++) {
      final r = i ~/ cols, c = i % cols;
      final dr = r - centerR;
      final dc = c - centerC;
      byShell.putIfAbsent(dr * dr + dc * dc, () => []).add(i);
    }
    final shellKeys = byShell.keys.toList()..sort();

    final ordered = <int>[];
    for (final key in shellKeys) {
      final cells = byShell[key]!;
      // mirror(i): 중심 기준 점대칭 셀. (cell, mirror) 한 쌍을 pairId로 묶음.
      final byPair = <int, List<int>>{};
      for (final cell in cells) {
        final r = cell ~/ cols, c = cell % cols;
        final mr = (2 * centerR - r).round();
        final mc = (2 * centerC - c).round();
        final mirror = mr * cols + mc;
        final pairId = math.min(cell, mirror);
        byPair.putIfAbsent(pairId, () => []).add(cell);
      }
      // pair 그룹 정렬 — 수평축에 가까운 페어(|dr|=0)를 먼저 채워
      // 적은 N에서 가로 한 줄 느낌이 나도록.
      final pairKeys = byPair.keys.toList()
        ..sort((a, b) {
          final ra = a ~/ cols;
          final rb = b ~/ cols;
          final hra = (ra - centerR).abs();
          final hrb = (rb - centerR).abs();
          if (hra != hrb) return hra.compareTo(hrb);
          return a.compareTo(b);
        });
      for (final pk in pairKeys) {
        (byPair[pk]!..sort()).forEach(ordered.add);
      }
    }

    // 중앙 셀은 canister 전용이라 사진 채움에서 항상 skip. 사진은 ordered[1..]
    // 에 mirror-pair 순으로 채워져, N=짝수면 완전 대칭, N=홀수면 마지막 1장만
    // 비대칭(불가피).
    _centerCellIndex = ordered.isNotEmpty ? ordered[0] : -1;
    _gridToFilled = List<int>.filled(total, -1);
    var filledIdx = 0;
    for (var i = 1; i < ordered.length && filledIdx < n; i++) {
      _gridToFilled[ordered[i]] = filledIdx++;
    }
  }

  void _shuffleOrders() {
    final reveal = List<int>.generate(_filledCount, (i) => i)..shuffle();
    final hide = List<int>.generate(_filledCount, (i) => i)..shuffle();
    _revealStep = List<int>.filled(_filledCount, 0);
    _hideStep = List<int>.filled(_filledCount, 0);
    for (var step = 0; step < _filledCount; step++) {
      _revealStep[reveal[step]] = step;
      _hideStep[hide[step]] = step;
    }
  }

  void _computePhases() {
    final phaseMs = _filledCount == 0
        ? 300
        : _perCellStagger.inMilliseconds * _filledCount +
            _fadeDuration.inMilliseconds;
    _lightUpEndMs = phaseMs;
    _holdOnEndMs = _lightUpEndMs + _holdOn.inMilliseconds;
    _lightOffEndMs = _holdOnEndMs + phaseMs;
    _totalMs = _lightOffEndMs + _holdOff.inMilliseconds;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// 셀의 현재 opacity. 4단계 phase: light-up → hold-on → light-off → hold-off.
  double _opacityFor(int cellIndex) {
    if (cellIndex >= _filledCount) return 0.0;
    // static capture 모드 — animation 건너뛰고 항상 fully visible.
    if (widget.staticFull) return 1.0;
    final progress = widget.overrideProgress ?? _controller.value;
    final nowMs = (progress * _totalMs).round();

    if (nowMs <= _lightUpEndMs) {
      final step = _revealStep[cellIndex];
      final start = step * _perCellStagger.inMilliseconds;
      final end = start + _fadeDuration.inMilliseconds;
      if (nowMs <= start) return 0.0;
      if (nowMs >= end) return 1.0;
      return Curves.easeOut.transform(
        (nowMs - start) / _fadeDuration.inMilliseconds,
      );
    }
    if (nowMs <= _holdOnEndMs) return 1.0;
    if (nowMs <= _lightOffEndMs) {
      final phaseMs = nowMs - _holdOnEndMs;
      final step = _hideStep[cellIndex];
      final start = step * _perCellStagger.inMilliseconds;
      final end = start + _fadeDuration.inMilliseconds;
      if (phaseMs <= start) return 1.0;
      if (phaseMs >= end) return 0.0;
      return 1.0 -
          Curves.easeOut.transform(
            (phaseMs - start) / _fadeDuration.inMilliseconds,
          );
    }
    return 0.0;
  }

  /// colorFilter가 있으면 [child]를 ColorFiltered로 감싸 반환 — 사진 셀
  /// 레이어에만 필름 룩 필터를 적용하는 데 사용. backdrop 배경은 제외.
  Widget _filtered(Widget child) {
    final cf = widget.colorFilter;
    return cf == null ? child : ColorFiltered(colorFilter: cf, child: child);
  }

  /// stack/snake와 동일 — 같은 날이면 단일 날짜, 아니면 범위.
  String _dateRangeLabel(List<ShareFrame> frames) {
    if (frames.isEmpty) return '';
    DateTime first = frames.first.occurredAt;
    DateTime last = frames.first.occurredAt;
    for (final f in frames) {
      if (f.occurredAt.isBefore(first)) first = f.occurredAt;
      if (f.occurredAt.isAfter(last)) last = f.occurredAt;
    }
    final fmt = DateFormat.yMMMd('en');
    final sameDay = first.year == last.year &&
        first.month == last.month &&
        first.day == last.day;
    if (sameDay) return fmt.format(first);
    return '${fmt.format(first)} — ${fmt.format(last)}';
  }

  @override
  Widget build(BuildContext context) {
    final cells =
        widget.frames.take(_cols * _rows).toList();

    final grid = AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        return Stack(
          fit: StackFit.expand,
          children: [
            // 다른 공유 템플릿과 동일한 그라데이션 배경 사용 — 톤 통일.
            const ShareTemplateBackdrop(),
            // 사진 셀에만 필름 룩 필터 — backdrop 배경엔 적용되지 않도록.
            // bottom padding을 60으로 키워 그리드 아래에 title/date 푸터 영역
            // (~48) 확보. 다른 템플릿(스택/스네이크/슬라이드쇼)과 톤 통일.
            _filtered(Padding(
              padding: const EdgeInsets.fromLTRB(8, 26, 8, 60),
              child: Column(
                children: [
                  for (var r = 0; r < _rows; r++) ...[
                    if (r > 0) const SizedBox(height: 4),
                    Expanded(
                      child: Row(
                        children: [
                          for (var c = 0; c < _cols; c++) ...[
                            if (c > 0) const SizedBox(width: 4),
                            Expanded(
                              child: () {
                                final gridIdx = r * _cols + c;
                                if (gridIdx == _centerCellIndex) {
                                  return _CanisterCenterCell(
                                    coverUrl: widget.sceneCoverUrl,
                                    title: widget.sceneTitle,
                                  );
                                }
                                final filledIdx = _gridToFilled[gridIdx];
                                if (filledIdx < 0) {
                                  // 빈 셀은 backdrop이 비치도록 투명.
                                  return const SizedBox.shrink();
                                }
                                return Opacity(
                                  opacity:
                                      _opacityFor(filledIdx).clamp(0.0, 1.0),
                                  child: Image(
                                    image: NetworkImage(cells[filledIdx].url),
                                    fit: BoxFit.cover,
                                    gaplessPlayback: true,
                                    errorBuilder: (_, _, _) =>
                                        const ColoredBox(
                                            color: Color(0xFF1C1C1E)),
                                  ),
                                );
                              }(),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            )),
            // 푸터 — title + date range. 다른 템플릿과 동일 위치·스타일.
            Positioned(
              left: 12,
              right: 12,
              bottom: 12,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    widget.sceneTitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: AppTypography.display(9, text: widget.sceneTitle)
                        .copyWith(color: Colors.white),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    _dateRangeLabel(widget.frames),
                    textAlign: TextAlign.center,
                    style: AppTypography.body(5).copyWith(
                      color: Colors.white.withValues(alpha: 0.4),
                      letterSpacing: 0.3,
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );

    return grid;
  }
}

/// 컨택트 시트 중앙 셀 — 다른 사진 셀과 같은 사각 프레임에 scene 캐니스터
/// 이미지를 cover로 채워 넣는다. 텍스트 오버레이는 없고 이미지만 표시.
class _CanisterCenterCell extends StatelessWidget {
  const _CanisterCenterCell({
    required this.coverUrl,
    required this.title,
  });

  final String coverUrl;
  // SceneTitleFallback에만 사용 — coverUrl이 비거나 로드 실패 시 fallback.
  final String title;

  @override
  Widget build(BuildContext context) {
    final hasUrl = coverUrl.isNotEmpty;
    if (!hasUrl) {
      return SceneTitleFallback(title: title);
    }
    return Image(
      image: NetworkImage(coverUrl),
      fit: BoxFit.cover,
      gaplessPlayback: true,
      errorBuilder: (_, _, _) => SceneTitleFallback(title: title),
    );
  }
}

