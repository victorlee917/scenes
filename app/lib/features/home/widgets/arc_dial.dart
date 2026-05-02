import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/app_colors_ext.dart';

/// 하단에 떠 있는 **호형 다이얼**.
///
/// - 위 Scene 캐러셀과 **같은 방향의 arc** (∩ — 중앙 상단, 양옆 하단).
///   포커스 tick은 다이얼의 맨 위 중앙, 양옆으로 갈수록 아래로 내려감.
/// - 현재 포커스 인덱스는 **앰버로 하이라이트**된 tick으로 표시.
/// - 가로 드래그로 [pageController]의 페이지를 직접 조정. 드래그 끝나면
///   가장 가까운 인덱스로 스냅.
class ArcDial extends StatefulWidget {
  const ArcDial({
    super.key,
    required this.pageController,
    required this.itemCount,
    this.arcRadius = 140,
    this.angleStep = 0.35,
    this.height = 72,
    this.pixelsPerIndex = 40,
  });

  final PageController pageController;
  final int itemCount;

  /// 다이얼 arc의 반지름. 작을수록 호가 짧고 조밀.
  final double arcRadius;

  /// 인접 tick 사이의 각 간격(rad). 상단 캐러셀과 달리 이쪽은 조밀하게.
  final double angleStep;

  /// 다이얼 영역 전체 높이.
  final double height;

  /// 드래그 감도. 값이 작을수록 작은 움직임으로 많은 인덱스 이동.
  final double pixelsPerIndex;

  @override
  State<ArcDial> createState() => _ArcDialState();
}

class _ArcDialState extends State<ArcDial> {
  /// 드래그 중 마지막으로 haptic을 울린 정수 인덱스. 중복 haptic 방지용.
  int _lastHapticIndex = 0;

  void _onDragStart(DragStartDetails details) {
    _lastHapticIndex = (widget.pageController.page ?? 0).round();
  }

  void _onDragUpdate(DragUpdateDetails details) {
    final pc = widget.pageController;
    if (!pc.hasClients || !pc.position.haveDimensions) return;

    // 드래그 오른쪽 = 인덱스 감소 (이전 씬 쪽).
    final pageDelta = -details.delta.dx / widget.pixelsPerIndex;
    final currentPage = pc.page ?? 0;
    final newPage = (currentPage + pageDelta)
        .clamp(0.0, (widget.itemCount - 1).toDouble());
    final viewportPixelsPerPage =
        pc.position.viewportDimension * pc.viewportFraction;
    pc.jumpTo(newPage * viewportPixelsPerPage);

    // 정수 인덱스가 바뀔 때마다 미세한 selection click haptic.
    final roundedNew = newPage.round();
    if (roundedNew != _lastHapticIndex) {
      _lastHapticIndex = roundedNew;
      HapticFeedback.selectionClick();
    }
  }

  void _onDragEnd(DragEndDetails details) {
    final pc = widget.pageController;
    if (!pc.hasClients) return;
    final current = pc.page ?? 0;
    final target = current.round().clamp(0, widget.itemCount - 1);
    pc.animateToPage(
      target,
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onHorizontalDragStart: _onDragStart,
      onHorizontalDragUpdate: _onDragUpdate,
      onHorizontalDragEnd: _onDragEnd,
      child: SizedBox(
        height: widget.height,
        child: AnimatedBuilder(
          animation: widget.pageController,
          builder: (context, _) {
            final pc = widget.pageController;
            double page;
            if (pc.hasClients && pc.position.haveDimensions) {
              page = pc.page ?? pc.initialPage.toDouble();
            } else {
              page = pc.initialPage.toDouble();
            }
            final fgColor = context.colors.foreground;
            return CustomPaint(
              size: Size.infinite,
              painter: _DialPainter(
                page: page,
                itemCount: widget.itemCount,
                angleStep: widget.angleStep,
                arcRadius: widget.arcRadius,
                foregroundColor: fgColor,
              ),
            );
          },
        ),
      ),
    );
  }
}

class _DialPainter extends CustomPainter {
  _DialPainter({
    required this.page,
    required this.itemCount,
    required this.angleStep,
    required this.arcRadius,
    required this.foregroundColor,
  });

  final double page;
  final int itemCount;
  final double angleStep;
  final double arcRadius;
  final Color foregroundColor;

  static const double _maxVisibleAngle = 1.0; // ~57°

  @override
  void paint(Canvas canvas, Size size) {
    final centerX = size.width / 2;
    // arc의 정중앙 tick은 widget의 top에. 양옆은 아래로 내려간다.
    // 위의 캐러셀 arc와 같은 방향(∩).
    const double topY = 4;

    // ── Baseline arc — 아주 옅은 곡선을 먼저 그려서 "다이얼" 질감 ──
    final baselinePaint = Paint()
      ..color = foregroundColor.withValues(alpha: 0.08)
      ..strokeWidth = 0.6
      ..style = PaintingStyle.stroke;
    final baseline = Path();
    const int segments = 48;
    for (int i = 0; i <= segments; i++) {
      final t = i / segments;
      final angle = (t - 0.5) * 2 * _maxVisibleAngle;
      final x = centerX + arcRadius * math.sin(angle);
      final y = topY + arcRadius * (1 - math.cos(angle));
      if (i == 0) {
        baseline.moveTo(x, y);
      } else {
        baseline.lineTo(x, y);
      }
    }
    canvas.drawPath(baseline, baselinePaint);

    // ── Tick marks ───────────────────────────────────────────
    final tickPaint = Paint()..style = PaintingStyle.fill;

    for (int i = 0; i < itemCount; i++) {
      final signed = i - page;
      final angle = signed * angleStep;
      if (angle.abs() > _maxVisibleAngle) continue;

      final x = centerX + arcRadius * math.sin(angle);
      final y = topY + arcRadius * (1 - math.cos(angle));

      final absSigned = signed.abs();
      final isFocused = absSigned < 0.5;

      if (isFocused) {
        tickPaint.color = foregroundColor;
        canvas.drawCircle(Offset(x, y), 4, tickPaint);
      } else {
        final alpha =
            (1.0 - absSigned * 0.28).clamp(0.0, 1.0) * 0.55;
        tickPaint.color =
            foregroundColor.withValues(alpha: alpha);
        canvas.drawCircle(Offset(x, y), 2, tickPaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DialPainter old) {
    return old.page != page ||
        old.itemCount != itemCount ||
        old.angleStep != angleStep ||
        old.arcRadius != arcRadius;
  }
}
