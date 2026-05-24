import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_typography.dart';
import '../../home/widgets/scene_title_fallback.dart';
import 'share_frame_view.dart' show ShareFrame, ShareTemplateBackdrop;

/// 공유 템플릿 — "Snake" (HD 전용).
///
/// 화면 중심을 둘러싼 원형 궤도 위에 N+1개의 spawn(사진 N + 캐니스터 1)이
/// 균등 각도로 배치된다. 위치는 spawn index 기반이라 N과 무관하게 항상 원
/// 전체를 채움 (1장이어도 캐니스터와 반대쪽으로, 5장이면 6 spawn이 정육각형).
/// 각 spawn마다 작은 angle/radius jitter를 더해 완벽한 원이 아닌 "랜덤하게
/// 도는" 인상.
///
/// 사진은 spawn 후 [_lifetimeMs] 동안 표시되고 자연 페이드아웃. 캐니스터도
/// 같은 pop-in으로 등장한 뒤 더 오래 hold하고 마지막에 페이드아웃 — 영상의
/// 마지막은 캐니스터가 페이드아웃하며 끝나는 깔끔한 ending.
class SnakeShareView extends StatefulWidget {
  const SnakeShareView({
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
  final bool isPlaying;
  final double? overrideProgress;

  /// 사진 segment의 총 생존 시간(ms) — pop-in + 본 visible + fadeOut.
  static const int _lifetimeMs = 1300;
  static const int _popInMs = 100;
  static const int _segFadeOutMs = 240;

  /// spawn 간격(ms) — 짧고 거의 일정, 약간의 jitter로 불규칙 감.
  static const int _intervalMinMs = 130;
  static const int _intervalMaxMs = 180;

  /// 캐니스터 자체의 생애 — pop-in + hold + fadeOut. 사진보다 길게 holding
  /// 해 마지막의 강조를 둠.
  static const int _canisterHoldMs = 1500;
  static const int _canisterFadeOutMs = 500;

  /// 영상 캡처가 영상 길이 결정에 사용. 정확한 값은 _recompute에서 결정.
  static int totalCycleMs(int photoCount) {
    final n = math.max(photoCount, 1);
    const avgInterval = (_intervalMinMs + _intervalMaxMs) ~/ 2;
    final estCanisterSpawn = n * avgInterval;
    return estCanisterSpawn +
        _popInMs +
        _canisterHoldMs +
        _canisterFadeOutMs;
  }

  @override
  State<SnakeShareView> createState() => _SnakeShareViewState();
}

class _SnakeShareViewState extends State<SnakeShareView>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  int _seqForN = -1;
  late List<int> _spawnTimes;
  late List<int> _spawnPhotoIndex;
  late List<bool> _spawnIsCanister;
  // 각 spawn의 (angle, radiusFactor). 각도는 spawn index 기반 균등 분포 +
  // 작은 jitter. radiusFactor는 width 대비 0.20±jitter.
  late List<double> _spawnAngle;
  late List<double> _spawnRadiusFactor;
  int _totalMs = 0;

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
  void didUpdateWidget(covariant SnakeShareView old) {
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
          _controller.stop();
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
    final n = math.max(widget.frames.length, 1);
    _seqForN = widget.frames.length;
    final seed = widget.sceneNumber * 31 + widget.sceneTitle.hashCode;
    final rng = math.Random(seed);
    final total = n + 1; // n photos + 1 canister
    _spawnTimes = List.filled(total, 0);
    _spawnPhotoIndex = List.filled(total, 0);
    _spawnIsCanister = List.filled(total, false);
    _spawnAngle = List.filled(total, 0);
    _spawnRadiusFactor = List.filled(total, 0);
    // 각도 step — 사진 폭 대비 arc 거리가 ~50% 폭이 되도록 0.5 rad 기본.
    // (arc = r * step, r ≈ 0.22w, step 0.5 → arc ≈ 0.11w ≈ photoW/2 → 50% overlap)
    // ±20% step jitter로 spawn 간 거리에 변동 — 사진 수가 많아지면 자연스럽게
    // 여러 바퀴 winding, 적어도 무리 없이 wedge 형태.
    const baseAngleStep = 0.5;
    double theta = -math.pi / 2; // 12시에서 시작
    int t = 0;
    for (int i = 0; i < total; i++) {
      _spawnTimes[i] = t;
      _spawnPhotoIndex[i] = i < n ? i : 0;
      _spawnIsCanister[i] = (i == n);
      _spawnAngle[i] = theta;
      // 다음 angle — ±20% jitter 후 누적.
      final stepJitter = 1.0 + (rng.nextDouble() - 0.5) * 0.4;
      theta += baseAngleStep * stepJitter;
      // 반경 ±15% jitter — 매끈한 원 아닌 들쭉날쭉.
      final rJitter = (rng.nextDouble() - 0.5) * 0.30;
      _spawnRadiusFactor[i] = 0.22 * (1.0 + rJitter);
      final interval = SnakeShareView._intervalMinMs +
          rng.nextInt(SnakeShareView._intervalMaxMs -
              SnakeShareView._intervalMinMs +
              1);
      t += interval;
    }
    final canisterSpawn = _spawnTimes[total - 1];
    _totalMs = canisterSpawn +
        SnakeShareView._popInMs +
        SnakeShareView._canisterHoldMs +
        SnakeShareView._canisterFadeOutMs;
  }

  Widget _filtered(Widget child) {
    final cf = widget.colorFilter;
    return cf == null ? child : ColorFiltered(colorFilter: cf, child: child);
  }

  /// spawn index 기반 위치 — 시간 무관, 처음 결정된 angle/radius로 고정.
  /// frame 높이/너비 비율에 맞춰 y만 살짝 stretch.
  Offset _positionFor(int spawnIndex, double cx, double cy, double w, double h) {
    final theta = _spawnAngle[spawnIndex];
    final r = w * _spawnRadiusFactor[spawnIndex];
    // 세로가 긴 frame이라 sin*y를 살짝 더 늘려 원이 frame 비율에 맞게 보이도록.
    final yStretch = (h / w * 0.55).clamp(1.0, 1.5);
    final x = cx + r * math.cos(theta);
    final y = cy + r * math.sin(theta) * yStretch;
    return Offset(x, y);
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

  Widget _build(Size canvas, double tMs) {
    if (widget.frames.length != _seqForN) _recompute();
    final n = widget.frames.length;
    if (n == 0) {
      return const Stack(
        fit: StackFit.expand,
        children: [ShareTemplateBackdrop()],
      );
    }
    final w = canvas.width;
    final h = canvas.height;
    final cx = w / 2;
    final cy = h * 0.46;

    final photoW = w * 0.22;

    // 활성 segment 수집. 사진은 lifetime 후 dead, 캐니스터는 자체 envelope.
    final visible = <_SnakeSegment>[];
    for (int i = _spawnTimes.length - 1; i >= 0; i--) {
      final spawnTime = _spawnTimes[i];
      if (spawnTime > tMs) continue;
      final age = tMs - spawnTime;
      final isCanister = _spawnIsCanister[i];
      if (!isCanister && age > SnakeShareView._lifetimeMs) break;
      visible.add(_SnakeSegment(
        spawnIndex: i,
        spawnTime: spawnTime,
        photoIndex: _spawnPhotoIndex[i],
        isCanister: isCanister,
        age: age,
      ));
    }

    // z-order: 오래된 게 뒤.
    final segWidgets = <Widget>[];
    for (int i = visible.length - 1; i >= 0; i--) {
      final seg = visible[i];
      final age = seg.age;
      double opacity;
      double scale = 1.0;

      if (seg.isCanister) {
        // 캐니스터 envelope: pop-in → hold → fadeOut.
        if (age < SnakeShareView._popInMs) {
          final p = age / SnakeShareView._popInMs;
          opacity = p.clamp(0.0, 1.0);
          scale = 0.7 + 0.3 * p;
        } else if (age <
            SnakeShareView._popInMs + SnakeShareView._canisterHoldMs) {
          opacity = 1.0;
          scale = 1.0;
        } else {
          final fadeStart = SnakeShareView._popInMs +
              SnakeShareView._canisterHoldMs;
          final p =
              (age - fadeStart) / SnakeShareView._canisterFadeOutMs;
          opacity = (1.0 - p).clamp(0.0, 1.0);
          scale = 0.86 + 0.14 * opacity;
        }
      } else {
        // 사진 envelope: pop-in → full → fadeOut.
        if (age < SnakeShareView._popInMs) {
          final p = age / SnakeShareView._popInMs;
          opacity = p.clamp(0.0, 1.0);
          scale *= 0.7 + 0.3 * p;
        } else if (age <
            SnakeShareView._lifetimeMs - SnakeShareView._segFadeOutMs) {
          opacity = 1.0;
        } else {
          final fadeStart =
              SnakeShareView._lifetimeMs - SnakeShareView._segFadeOutMs;
          final p = (age - fadeStart) / SnakeShareView._segFadeOutMs;
          opacity = (1.0 - p).clamp(0.0, 1.0);
          scale = 0.78 + 0.22 * opacity;
        }
        // 꼬리로 갈수록 살짝 가늘게.
        final ageFrac = (age / SnakeShareView._lifetimeMs).clamp(0.0, 1.0);
        scale *= 1.0 - ageFrac * 0.18;
      }
      if (opacity <= 0.001) continue;

      final pos = _positionFor(seg.spawnIndex, cx, cy, w, h);
      // 사진은 각자 aspect 존중. 캐니스터(scene cover)는 정사각형으로 그림.
      // 기본 aspect(metadata 누락 시)는 가벼운 portrait 톤 0.8(=1/1.25).
      final aspect = seg.isCanister
          ? 1.0
          : (widget.frames[seg.photoIndex].aspect ?? 0.8);
      final photoH = photoW / aspect;
      segWidgets.add(_buildPhotoCard(
        center: pos,
        width: photoW,
        height: photoH,
        opacity: opacity,
        scale: scale,
        imageProvider: seg.isCanister
            ? (widget.sceneCoverUrl.isEmpty
                ? null
                : NetworkImage(widget.sceneCoverUrl))
            : NetworkImage(widget.frames[seg.photoIndex].url),
        fallbackTitle: seg.isCanister ? widget.sceneTitle : '',
      ));
    }

    return Stack(
      fit: StackFit.expand,
      clipBehavior: Clip.hardEdge,
      children: [
        const ShareTemplateBackdrop(),
        _filtered(
          Stack(
            fit: StackFit.expand,
            children: segWidgets,
          ),
        ),
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
  }

  Widget _buildPhotoCard({
    required Offset center,
    required double width,
    required double height,
    required double opacity,
    required double scale,
    required ImageProvider? imageProvider,
    required String fallbackTitle,
  }) {
    final inner = imageProvider == null
        ? SceneTitleFallback(title: fallbackTitle)
        : Image(
            image: imageProvider,
            fit: BoxFit.cover,
            gaplessPlayback: true,
            errorBuilder: (_, _, _) => fallbackTitle.isEmpty
                ? const ColoredBox(color: Colors.black)
                : SceneTitleFallback(title: fallbackTitle),
          );
    return Positioned(
      left: center.dx - width / 2,
      top: center.dy - height / 2,
      width: width,
      height: height,
      child: Opacity(
        opacity: opacity,
        child: Transform.scale(
          scale: scale,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: Colors.black,
              borderRadius: BorderRadius.circular(3),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.35),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: inner,
            ),
          ),
        ),
      ),
    );
  }

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
}

class _SnakeSegment {
  const _SnakeSegment({
    required this.spawnIndex,
    required this.spawnTime,
    required this.photoIndex,
    required this.isCanister,
    required this.age,
  });
  final int spawnIndex;
  final int spawnTime;
  final int photoIndex;
  final bool isCanister;
  final double age;
}
