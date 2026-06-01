import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

/// 구독자가 "구독 중" 버튼을 눌렀을 때 띄우는 하트 burst. 짧은 축하 인터랙션
/// 한 번으로 끝나고 자동 제거. Overlay에 그려 본 레이아웃 영향 없음.
class HeartBurst {
  static void show(BuildContext context, Offset origin) {
    final overlay = Overlay.of(context, rootOverlay: true);
    late OverlayEntry entry;
    entry = OverlayEntry(
      builder: (_) => _HeartBurstView(
        origin: origin,
        onComplete: () {
          if (entry.mounted) entry.remove();
        },
      ),
    );
    overlay.insert(entry);
  }
}

class _HeartBurstView extends StatefulWidget {
  const _HeartBurstView({required this.origin, required this.onComplete});

  final Offset origin;
  final VoidCallback onComplete;

  @override
  State<_HeartBurstView> createState() => _HeartBurstViewState();
}

class _HeartBurstViewState extends State<_HeartBurstView>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final List<_Particle> _particles;

  static const _heartCount = 18;
  // 위로 분산되는 부채꼴 burst. 0=오른쪽, π=왼쪽, π/2=아래(우리 기준 화면 위는 -y).
  // -π(=위쪽)을 중심으로 ±부채꼴 각도 분산.
  static const _spreadHalf = math.pi * 0.42;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    )
      ..addListener(() => setState(() {}))
      ..addStatusListener((status) {
        if (status == AnimationStatus.completed) widget.onComplete();
      });

    final rand = math.Random();
    _particles = List.generate(_heartCount, (i) {
      // 위쪽(-π/2) 중심으로 ±_spreadHalf 부채꼴.
      final angle = -math.pi / 2 + (rand.nextDouble() * 2 - 1) * _spreadHalf;
      // 거리 — burst 반경. 화면 폭과 무관하게 일정한 시각감.
      final distance = 90 + rand.nextDouble() * 90;
      // 크기 변동 — 큰 거 + 작은 거 섞임.
      final size = 14 + rand.nextDouble() * 14;
      // 회전 — 각 하트 살짝 기울어 자연스러움.
      final tilt = (rand.nextDouble() - 0.5) * 0.8;
      // 시작 delay — 다 동시에 안 튀고 살짝 시차.
      final delay = rand.nextDouble() * 0.15;
      // 색 — solid 하트 분홍/빨강 톤 두 가지.
      final color = i % 2 == 0
          ? const Color(0xFFFF4D6D)
          : const Color(0xFFFF8FA3);
      return _Particle(
        angle: angle,
        distance: distance,
        size: size,
        tilt: tilt,
        delay: delay,
        color: color,
      );
    });

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = _controller.value;
    return IgnorePointer(
      child: Stack(
        children: [
          for (final p in _particles) _buildParticle(p, t),
        ],
      ),
    );
  }

  Widget _buildParticle(_Particle p, double t) {
    // 각 입자 자체 진행도: delay 차감 + 0..1 clamp.
    final local = ((t - p.delay) / (1 - p.delay)).clamp(0.0, 1.0);
    // ease-out 위치 — 빠르게 퍼졌다가 감속.
    final eased = 1 - math.pow(1 - local, 3).toDouble();
    // 중력 약간 — 위로 튀어오른 뒤 끝물에 살짝 떨어지는 느낌.
    final gravity = 30 * local * local;
    final dx = math.cos(p.angle) * p.distance * eased;
    final dy = math.sin(p.angle) * p.distance * eased + gravity;
    // opacity — 1초까지 1.0, 마지막 30%에서 fade out.
    final opacity = local < 0.7 ? 1.0 : (1 - (local - 0.7) / 0.3);
    // scale — 초반 0→1 pop-in, 후반 약간 축소.
    final scale = local < 0.2
        ? local / 0.2
        : 1.0 - (local - 0.2) * 0.15;

    return Positioned(
      left: widget.origin.dx + dx - p.size / 2,
      top: widget.origin.dy + dy - p.size / 2,
      child: Opacity(
        opacity: opacity.clamp(0.0, 1.0),
        child: Transform.rotate(
          angle: p.tilt + local * 0.3,
          child: Transform.scale(
            scale: scale.clamp(0.0, 1.5),
            child: FaIcon(
              FontAwesomeIcons.solidHeart,
              size: p.size,
              color: p.color,
            ),
          ),
        ),
      ),
    );
  }
}

class _Particle {
  const _Particle({
    required this.angle,
    required this.distance,
    required this.size,
    required this.tilt,
    required this.delay,
    required this.color,
  });

  final double angle;
  final double distance;
  final double size;
  final double tilt;
  final double delay;
  final Color color;
}
