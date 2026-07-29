import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_typography.dart';
import '../../home/widgets/scene_title_fallback.dart';
import 'share_frame_view.dart' show ShareFrame, ShareTemplateBackdrop;

/// 공유 템플릿 3 — "Lens". 사진을 눈동자 모양 실루엣으로 펼쳐 보여준다.
///
/// 레이아웃: 컬럼 수 M = 2k-1 (k = ceil(sqrt(N)))의 좌우 대칭. 각 컬럼의
/// stack height는 가장자리 1장, 중앙 k장으로 단조 증가/감소 (`[1, 2, …, k, …,
/// 2, 1]`). N이 k²와 다르면 가운데 컬럼이 약간 더 두꺼워지거나 양 끝에서 차감.
/// 같은 컬럼 안의 사진은 위로 stagger되며 새 사진이 z-order 위에 옴.
///
/// 애니메이션 흐름 (photo hard pop, accelerating stagger):
///   1. Reveal — 좌측 컬럼부터 차례로 photo 등장 (instant). 사진 간 간격은
///      가속도 곡선 (slow → fast, x^p with p<1) — 처음엔 천천히, 뒤로 갈수록
///      빠르게.
///   2. Hold all — 모든 사진이 lens 실루엣을 채운 상태로 잠깐 정지.
///   3. Canister appear (instant) — 중앙에 정사각 캐니스터 카드가 위에 즉시.
///   4. Hold final — 캐니스터까지 보이는 상태 holding.
///   5. Disappear — 등장한 순서 그대로 photo 0부터 차례로 instant 제거. 같은
///      가속도 곡선 적용 (처음엔 천천히, 끝엔 빠르게).
///   6. Canister fade out — photos 다 사라진 뒤 캐니스터만 fade-out (유일하게
///      페이드 적용되는 요소).
///   7. Hold blank — 짧은 공백 후 사이클 재시작.
///
/// 사진 자체는 회전/테두리 없이 그대로 BoxFit.cover 직사각형. drop shadow는
/// 살짝 두어 겹친 카드들이 분리감 있게 보이게.
class StackShareView extends StatefulWidget {
  const StackShareView({
    super.key,
    required this.frames,
    required this.colorFilter,
    required this.sceneCoverUrl,
    required this.sceneNumber,
    required this.sceneTitle,
    this.isPlaying = true,
    this.overrideProgress,
  });

  final List<ShareFrame> frames;
  final ColorFilter? colorFilter;
  final String sceneCoverUrl;
  final int sceneNumber;
  final String sceneTitle;

  /// false면 애니메이션이 현재 progress에서 정지.
  final bool isPlaying;

  /// null이면 내부 controller가 progress 주도. not null이면 외부 0..1 값
  /// 주입 — 영상 캡처 시 매 프레임 직접 제어.
  final double? overrideProgress;

  // 사이클 phase 길이(ms). 외부 캡처 로직이 영상 길이를 결정할 때도 동일
  // 공식 사용.
  static const int _holdAllMs = 500;
  static const int _holdFinalMs = 1100;
  // 마지막 사진이 사라진 뒤 캐니스터만 보이는 hold — fade out 시작 전 텀.
  static const int _canisterAloneHoldMs = 1000;
  static const int _canisterFadeOutMs = 500;
  static const int _holdBlankMs = 200;

  /// 가속도 곡선의 지수. p < 1이면 t(x) = T * x^p이 처음엔 가파르게 변하고
  /// (시간 축 기준 → 사진 간격 큼) 끝엔 완만하게 변함 (간격 작음) → 사진이
  /// "천천히 시작해 점점 빨라지는" 가속 효과.
  static const double _easePower = 0.6;

  /// "마지막 사진 간 간격"이 linear stagger와 같도록 reveal 총 시간을 산정한다.
  /// T_curved * p = stagger * (N-1)이 되도록 풀면 T = stagger*(N-1)/p.
  /// 하한 80ms = 가속 곡선의 peak 속도(끝 부분) 슬로우다운. N이 커도 사진 간
  /// 최소 간격이 너무 짧지 않도록 함.
  static int _staggerMsFor(int n) {
    if (n <= 0) return 0;
    final byCount = (1500 / n).round();
    return byCount.clamp(80, 220);
  }

  static int _revealDurationMsFor(int n) {
    if (n <= 1) return 0;
    return (_staggerMsFor(n) * (n - 1) / _easePower).round();
  }

  static int totalCycleMs(int photoCount) {
    final n = math.max(photoCount, 1);
    final phase = _revealDurationMsFor(n);
    return phase // reveal (가속도)
        + _holdAllMs
        + _holdFinalMs
        + phase // disappear (가속도, 등장 순서)
        + _canisterAloneHoldMs // 캐니스터만 보이는 텀
        + _canisterFadeOutMs
        + _holdBlankMs;
  }

  @override
  State<StackShareView> createState() => _StackShareViewState();
}

class _StackShareViewState extends State<StackShareView>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  // N 변화 시 timings 재계산 가드.
  int _timingsForN = -1;

  // Phase 경계 (cumulative ms within 한 사이클).
  int _totalMs = 0;
  int _revealEndMs = 0;
  int _holdAllEndMs = 0;
  int _holdFinalEndMs = 0;
  int _disappearEndMs = 0;
  int _canisterAloneEndMs = 0;
  int _canisterFadeEndMs = 0;
  // 한 phase의 reveal/disappear 총 길이 — 가속도 곡선 evaluation에 사용.
  int _phaseMs = 0;

  @override
  void initState() {
    super.initState();
    _recompute();
    _controller = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: math.max(_totalMs, 1)),
    )..addStatusListener((s) {
        if (s == AnimationStatus.completed && mounted && widget.isPlaying) {
          _controller.forward(from: 0);
        }
      });
    if (widget.isPlaying && widget.overrideProgress == null) {
      _controller.forward();
    }
  }

  @override
  void didUpdateWidget(covariant StackShareView old) {
    super.didUpdateWidget(old);
    if (old.frames.length != widget.frames.length) {
      _recompute();
      _controller.duration = Duration(milliseconds: math.max(_totalMs, 1));
      _controller.value = 0;
      if (widget.isPlaying && widget.overrideProgress == null) {
        _controller.forward();
      }
    }
    if (old.isPlaying != widget.isPlaying) {
      if (widget.isPlaying && widget.overrideProgress == null) {
        if (_controller.status == AnimationStatus.completed) {
          _controller.forward(from: 0);
        } else {
          _controller.forward();
        }
      } else {
        _controller.stop();
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _recompute() {
    final n = widget.frames.length;
    _timingsForN = n;

    _phaseMs = StackShareView._revealDurationMsFor(n);
    _revealEndMs = _phaseMs;
    _holdAllEndMs = _revealEndMs + StackShareView._holdAllMs;
    // 캐니스터는 _holdAllEndMs에 instant 등장. holdFinal은 photos+canister 둘
    // 다 보이는 구간.
    _holdFinalEndMs = _holdAllEndMs + StackShareView._holdFinalMs;
    // Disappear phase: 가속도 곡선 — photo i가 _holdFinalEndMs + phase*ease(i)
    // 시점에 instant 제거. 등장 순서 그대로.
    _disappearEndMs = _holdFinalEndMs + _phaseMs;
    // 캐니스터만 보이는 hold — 마지막 사진 사라진 뒤 fade out 시작 전 텀.
    _canisterAloneEndMs =
        _disappearEndMs + StackShareView._canisterAloneHoldMs;
    _canisterFadeEndMs =
        _canisterAloneEndMs + StackShareView._canisterFadeOutMs;
    _totalMs = _canisterFadeEndMs + StackShareView._holdBlankMs;
  }

  /// 가속도 곡선 평가 — index를 0..1 fraction으로 매핑한 뒤 x^p 적용. p<1이라
  /// 처음엔 천천히, 뒤로 갈수록 빠르게 증가하는 곡선.
  double _easedFraction(int index) {
    final n = widget.frames.length;
    if (n <= 1) return 0.0;
    final x = index / (n - 1);
    return math.pow(x, StackShareView._easePower).toDouble();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return AnimatedBuilder(
          animation: _controller,
          builder: (_, _) {
            final progress = widget.overrideProgress ?? _controller.value;
            final tMs = (progress * _totalMs).clamp(0, _totalMs).toDouble();
            return _build(constraints.biggest, tMs);
          },
        );
      },
    );
  }

  /// colorFilter가 있으면 [child]를 ColorFiltered로 감싸 반환 — 사진 콘텐츠
  /// 레이어에만 필름 룩 필터를 적용하는 데 사용. backdrop·텍스트는 제외.
  Widget _filtered(Widget child) {
    final cf = widget.colorFilter;
    return cf == null ? child : ColorFiltered(colorFilter: cf, child: child);
  }

  Widget _build(Size canvasSize, double tMs) {
    final n = widget.frames.length;
    if (n != _timingsForN) {
      // didUpdateWidget가 못 잡은 edge case 안전망.
      _recompute();
    }
    final w = canvasSize.width;
    final h = canvasSize.height;

    // N에 따라 layout 모드 분기:
    //   N=1: 정중앙 1장
    //   N=2,3: 좌상→우하 단일 대각선
    //   N=4: 지그재그 (위/아래 교대로 4장)
    //   N=5: S자 — 가운데 3장 대각선 + 양 끝이 반대편으로 튀어나감
    //   N ≥ 6: 가로 지그재그. photoW는 N에 따라 자동 축소하여 사진끼리
    //          겹치는 비율이 ~45%선에 머무르도록(매우 큰 N에선 floor에
    //          걸리고 그 이상은 stack 두께가 두꺼워지는 모양으로 수렴).
    final photoW = _photoWidthFor(n, w);
    final List<Offset> photoCenters;
    if (n <= 5) {
      photoCenters = _specialCenters(n, w, h, photoW);
    } else {
      photoCenters = _zigzagCenters(n, w, h, photoW);
    }

    // 캐니스터 — _holdAllEndMs에 instant 등장, photos 다 사라진 뒤
    // _canisterAloneHoldMs(1초) 동안 단독 노출, _canisterAloneEndMs에 fade out
    // 시작, _canisterFadeEndMs에 완전 사라짐.
    final double canisterAlpha;
    if (tMs < _holdAllEndMs) {
      canisterAlpha = 0;
    } else if (tMs < _canisterAloneEndMs) {
      canisterAlpha = 1;
    } else if (tMs < _canisterFadeEndMs) {
      final p = (tMs - _canisterAloneEndMs) /
          (_canisterFadeEndMs - _canisterAloneEndMs);
      canisterAlpha = (1 - p).clamp(0.0, 1.0);
    } else {
      canisterAlpha = 0;
    }
    // 캐니스터 사이즈 — N과 무관하게 고정. 사진 수가 많아도 anchor로서의
    // visual weight를 유지.
    final canisterSize = w * 0.2;

    return Stack(
      fit: StackFit.expand,
      clipBehavior: Clip.hardEdge,
      children: [
        const RepaintBoundary(child: ShareTemplateBackdrop()),
        // 사진 콘텐츠(photo 카드 + 캐니스터)에만 필름 룩 필터 — backdrop
        // 배경과 하단 텍스트엔 적용되지 않도록 별도 레이어로 감싼다.
        _filtered(
          Stack(
            fit: StackFit.expand,
            children: [
              // photo cards — index 순서로 z-order: 먼저 등록된 사진이 뒤.
              for (var i = 0; i < photoCenters.length; i++)
                _buildPhotoCardAt(
                  index: i,
                  center: photoCenters[i],
                  tMs: tMs,
                  photoW: photoW,
                ),
              if (canisterAlpha > 0.001)
                Center(
                  child: Opacity(
                    opacity: canisterAlpha,
                    child: SizedBox(
                      width: canisterSize,
                      height: canisterSize,
                      child: _CanisterCard(
                        coverUrl: widget.sceneCoverUrl,
                        title: widget.sceneTitle,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        // 하단 푸터 — scene 이름(display font) + 모먼트들이 걸쳐 있는 기간.
        // 위치·간격·폰트 크기는 ShareFrameView(슬라이드쇼)와 동일하게 맞춤.
        Positioned(
          left: 12,
          right: 12,
          bottom: 12,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
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
  }

  /// frames의 occurredAt 분포에서 기간 라벨 생성. 같은 날이면 단일 날짜만,
  /// 그렇지 않으면 "Jan 5, 2026 — Jan 15, 2026" 형태로.
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

  Widget _buildPhotoCardAt({
    required int index,
    required Offset center,
    required double tMs,
    required double photoW,
  }) {
    // 가속도 곡선: photo i의 appearAt = phase * ease(i), disappearAt =
    // _holdFinalEndMs + phase * ease(i). 두 phase에 동일 곡선 적용 — 사라질
    // 때도 처음엔 천천히, 끝엔 빠르게.
    final eased = _easedFraction(index);
    final appearAt = _phaseMs * eased;
    final disappearAt = _holdFinalEndMs + _phaseMs * eased;
    if (tMs < appearAt || tMs >= disappearAt) {
      return const SizedBox.shrink();
    }

    // 각 사진은 원본 가로/세로 비율 보존. width는 모든 카드 공통이고 height만
    // aspect에 따라 다름. aspect 정보 없으면 representative(5:4 portrait)로
    // fallback.
    final aspect = widget.frames[index].aspect ?? (1 / 1.25);
    final photoH = photoW / aspect;

    return Positioned(
      left: center.dx - photoW / 2,
      top: center.dy - photoH / 2,
      width: photoW,
      height: photoH,
      // 등장~소멸 사이 내용 불변 — RepaintBoundary로 shadow+리샘플 래스터 캐시.
      child: RepaintBoundary(child: _PhotoCard(url: widget.frames[index].url)),
    );
  }

  /// N에 따른 사진 카드 폭. N≤5는 0.35w 고정(특수 layout 기준), N≥6은
  /// 겹침 비율 ~45% (visible step = photoW * 0.55) 가정 하에 canvas 95%를
  /// 채우도록 역산. 너무 작아지지 않게 0.12w floor, 너무 커지지 않게 0.35w
  /// ceiling. floor에 걸리는 매우 큰 N은 겹침 비율이 자연히 50% 이상으로
  /// 올라가지만 그 모양 자체가 "두꺼운 stack" 느낌을 만들어줌.
  double _photoWidthFor(int n, double w) {
    if (n <= 5) return w * 0.35;
    const visibleFraction = 0.55; // 1 - 0.45 overlap
    final solvedW = 0.95 * w / (1 + (n - 1) * visibleFraction);
    return solvedW.clamp(0.12 * w, 0.35 * w);
  }

  /// 작은 N (1~5) 전용 layout.
  ///   N=1: 정중앙 1장
  ///   N=2: 중심 대칭, 좌상→우하 대각선 2장
  ///   N=3: 좌상/중앙/우하 (두 번째가 정중앙, 단일 대각선)
  ///   N=4: 지그재그 — 좌→우 진행하며 Y가 위/아래 교대 (가로 4장)
  ///   N=5: S자 — 가운데 3장(인덱스 1,2,3)이 좌상→우하 대각선, 양 끝(0, 4)이
  ///        그 대각선 반대편으로 튀어나가 전체 trace가 S 형태.
  List<Offset> _specialCenters(int n, double w, double h, double photoW) {
    final cx = w / 2;
    final cy = h / 2;
    if (n <= 1) return [Offset(cx, cy)];
    if (n == 4) {
      // 지그재그: 4장이 좌→우로 가로로 펼쳐지며 Y가 ±dy 교대. dy =
      // envelope * photoH * 0.45 * random — envelope이 sin(πt)라 양 끝은
      // y=0(중앙선)에 붙고 가운데가 최대로 돌출. photoH 기반이라 인접 사진
      // 가로폭이 달라도 항상 중앙선을 가로질러 overlap 유지.
      final dx = photoW * 0.55;
      final rng = _layoutRng(4);
      final result = <Offset>[];
      for (var i = 0; i < 4; i++) {
        final aspect = widget.frames[i].aspect ?? (1 / 1.25);
        final photoH = photoW / aspect;
        final dy = _pupilEnvelope(i, 4) *
            photoH *
            0.45 *
            (0.85 + rng.nextDouble() * 0.15);
        final xJitter = (rng.nextDouble() - 0.5) * dx * 0.15;
        result.add(Offset(
          cx + (i - 1.5) * dx + xJitter,
          cy + (i.isEven ? -1 : 1) * dy,
        ));
      }
      return result;
    }
    if (n == 5) {
      // S자: P1,P2,P3가 (-step,-step), (0,0), (+step,+step) — 대각선 위에
      // 있고, P0/P4는 X는 더 외곽이지만 Y는 반대편으로 — P0(-2s,+s) 좌하,
      // P4(+2s,-s) 우상. 전체 trace가 S처럼 굽이침.
      final maxStep = (w * 0.95 - photoW) / 4;
      final step = math.min(maxStep, photoW * 0.55);
      return [
        Offset(cx - 2 * step, cy + step),
        Offset(cx - step, cy - step),
        Offset(cx, cy),
        Offset(cx + step, cy + step),
        Offset(cx + 2 * step, cy - step),
      ];
    }
    // 단일 대각선 (N=2, 3). step은 photoW의 70% 상한 + canvas 95% fit.
    final maxStep = (w * 0.95 - photoW) / (n - 1);
    final step = math.min(maxStep, photoW * 0.7);
    final start = -((n - 1) / 2) * step;
    return [
      for (var i = 0; i < n; i++)
        Offset(cx + start + i * step, cy + start + i * step),
    ];
  }

  /// N ≥ 6 전용 가로 지그재그. X는 좌→우 균등 분포(canvas 95% 안에 모든 사진
  /// 들어오도록 dx 자동 축소). dy = envelope * photoH * 0.45 * random —
  /// envelope이 sin(πt)라 양 끝은 y=0(중앙선)에 붙고 가운데가 최대로 돌출,
  /// trace 전체가 렌즈/눈동자 모양. photoH * 0.45 cap이 formula에 내재돼 있어
  /// 인접 사진은 항상 중앙선을 교차 → vertical overlap 보장.
  List<Offset> _zigzagCenters(int n, double w, double h, double photoW) {
    final cx = w / 2;
    final cy = h / 2;
    // X step은 photoW의 55% (= 45% overlap)로 고정. 사진이 floor에 걸리는
    // 매우 큰 N에서는 maxStep이 더 작아져 자연스럽게 stack이 두꺼워짐.
    final maxStep = (w * 0.95 - photoW) / (n - 1);
    final dx = math.min(maxStep, photoW * 0.55);
    final firstX = cx - (n - 1) / 2 * dx;
    final rng = _layoutRng(n);
    final result = <Offset>[];
    for (var i = 0; i < n; i++) {
      final aspect = widget.frames[i].aspect ?? (1 / 1.25);
      final photoH = photoW / aspect;
      final dy = _pupilEnvelope(i, n) *
          photoH *
          0.45 *
          (0.85 + rng.nextDouble() * 0.15);
      final xJitter = (rng.nextDouble() - 0.5) * dx * 0.15;
      result.add(Offset(
        firstX + i * dx + xJitter,
        cy + (i.isEven ? -1 : 1) * dy,
      ));
    }
    return result;
  }

  /// 눈동자(렌즈) 형태 envelope. i=0과 i=n-1에서 0, 가운데에서 1이 되는
  /// plain sin(πt) — offset 없이 양 끝이 완전히 중앙선에 붙어 렌즈 tip을 만들고
  /// 가운데로 갈수록 dy가 자연스럽게 커지는 곡선. offset 두면 가운데 plateau가
  /// 생겨 변화감 없어짐.
  double _pupilEnvelope(int i, int n) {
    if (n <= 1) return 1.0;
    final t = i / (n - 1);
    return math.sin(math.pi * t);
  }

  /// scene-stable seed로 [math.Random] 생성 — 같은 scene을 다시 렌더해도 같은
  /// 배치가 나오도록. sceneNumber + sceneTitle.hashCode + n을 섞어 N별로도 다른
  /// 패턴이 나오게.
  math.Random _layoutRng(int n) {
    final raw = widget.sceneNumber * 1009 +
        widget.sceneTitle.hashCode +
        n * 31;
    return math.Random(raw & 0x7fffffff);
  }
}

/// Lens 템플릿용 사진 카드 — 회전·테두리 없음. drop shadow로 겹친 카드 간
/// 분리감만 살짝.
class _PhotoCard extends StatelessWidget {
  const _PhotoCard({required this.url});

  final String url;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.45),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(2),
        child: Image(
          image: NetworkImage(url),
          fit: BoxFit.cover,
          gaplessPlayback: true,
          errorBuilder: (_, _, _) => const ColoredBox(color: Color(0xFF1C1C1E)),
        ),
      ),
    );
  }
}

/// Lens 마지막에 등장하는 중앙 캐니스터 카드. 정사각형 cover 이미지. coverUrl이
/// 비면 [SceneTitleFallback]으로.
class _CanisterCard extends StatelessWidget {
  const _CanisterCard({required this.coverUrl, required this.title});

  final String coverUrl;
  final String title;

  @override
  Widget build(BuildContext context) {
    final hasUrl = coverUrl.isNotEmpty;
    final image = hasUrl
        ? Image(
            image: NetworkImage(coverUrl),
            fit: BoxFit.cover,
            gaplessPlayback: true,
            errorBuilder: (_, _, _) => SceneTitleFallback(title: title),
          )
        : SceneTitleFallback(title: title);

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(3),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.55),
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(3),
        child: image,
      ),
    );
  }
}

