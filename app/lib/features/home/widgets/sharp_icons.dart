import 'dart:math' as math;

import 'package:flutter/material.dart';

/// 홈 화면 전역에서 공유하는 얇은 sharp-line 아이콘 세트.
///
/// - stroke width를 고정값으로 두어 사이즈가 달라도 **시각적 무게가 일관**.
/// - stroke cap은 `butt`, join은 `miter` — rounded가 아니라 "샤프한 선".
/// - 색상은 호출부에서 주입. 보통 transport에서는 `foreground`, add card에서는
///   `foregroundMuted`를 사용.
class SharpPlus extends StatelessWidget {
  const SharpPlus({
    super.key,
    required this.size,
    required this.color,
    this.strokeWidth = 1.5,
  });

  final double size;
  final Color color;
  final double strokeWidth;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size.square(size),
      painter: _PlusPainter(color: color, strokeWidth: strokeWidth),
    );
  }
}

class SharpSort extends StatelessWidget {
  const SharpSort({
    super.key,
    required this.size,
    required this.color,
    this.strokeWidth = 1.5,
  });

  final double size;
  final Color color;
  final double strokeWidth;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size.square(size),
      painter: _SortPainter(color: color, strokeWidth: strokeWidth),
    );
  }
}

class SharpPlay extends StatelessWidget {
  const SharpPlay({
    super.key,
    required this.size,
    required this.color,
    this.strokeWidth = 1.5,
  });

  final double size;
  final Color color;
  final double strokeWidth;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size.square(size),
      painter: _PlayPainter(color: color, strokeWidth: strokeWidth),
    );
  }
}

class SharpChevronLeft extends StatelessWidget {
  const SharpChevronLeft({
    super.key,
    required this.size,
    required this.color,
    this.strokeWidth = 1.5,
  });

  final double size;
  final Color color;
  final double strokeWidth;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size.square(size),
      painter: _ChevronLeftPainter(color: color, strokeWidth: strokeWidth),
    );
  }
}

class SharpSettings extends StatelessWidget {
  const SharpSettings({
    super.key,
    required this.size,
    required this.color,
    this.strokeWidth = 1.5,
  });

  final double size;
  final Color color;
  final double strokeWidth;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size.square(size),
      painter: _SettingsPainter(color: color, strokeWidth: strokeWidth),
    );
  }
}

class SharpShare extends StatelessWidget {
  const SharpShare({
    super.key,
    required this.size,
    required this.color,
    this.strokeWidth = 1.5,
  });

  final double size;
  final Color color;
  final double strokeWidth;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size.square(size),
      painter: _SharePainter(color: color, strokeWidth: strokeWidth),
    );
  }
}

class SharpClose extends StatelessWidget {
  const SharpClose({
    super.key,
    required this.size,
    required this.color,
    this.strokeWidth = 1.5,
  });

  final double size;
  final Color color;
  final double strokeWidth;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size.square(size),
      painter: _ClosePainter(color: color, strokeWidth: strokeWidth),
    );
  }
}

class SharpEllipsis extends StatelessWidget {
  const SharpEllipsis({
    super.key,
    required this.size,
    required this.color,
  });

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size.square(size),
      painter: _EllipsisPainter(color: color),
    );
  }
}

// ── Painters ─────────────────────────────────────────────────

class _PlusPainter extends CustomPainter {
  _PlusPainter({required this.color, required this.strokeWidth});
  final Color color;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.butt;
    final cx = size.width / 2;
    final cy = size.height / 2;
    canvas.drawLine(Offset(cx, 0), Offset(cx, size.height), paint);
    canvas.drawLine(Offset(0, cy), Offset(size.width, cy), paint);
  }

  @override
  bool shouldRepaint(covariant _PlusPainter old) =>
      old.color != color || old.strokeWidth != strokeWidth;
}

class _SortPainter extends CustomPainter {
  _SortPainter({required this.color, required this.strokeWidth});
  final Color color;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.butt;
    final w = size.width;
    final h = size.height;
    // 세로 정중앙 기준 위·중간·아래 3줄, 길이 점감.
    canvas.drawLine(Offset(0, h * 0.25), Offset(w, h * 0.25), paint);
    canvas.drawLine(Offset(0, h * 0.5), Offset(w * 0.72, h * 0.5), paint);
    canvas.drawLine(Offset(0, h * 0.75), Offset(w * 0.44, h * 0.75), paint);
  }

  @override
  bool shouldRepaint(covariant _SortPainter old) =>
      old.color != color || old.strokeWidth != strokeWidth;
}

class _PlayPainter extends CustomPainter {
  _PlayPainter({required this.color, required this.strokeWidth});
  final Color color;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.butt
      ..strokeJoin = StrokeJoin.miter
      ..style = PaintingStyle.stroke;
    // 좌측 세로축, 우측 꼭짓점 삼각형. 내부 여백 살짝.
    final w = size.width;
    final h = size.height;
    final path = Path()
      ..moveTo(w * 0.1, h * 0.1)
      ..lineTo(w * 0.95, h * 0.5)
      ..lineTo(w * 0.1, h * 0.9)
      ..close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _PlayPainter old) =>
      old.color != color || old.strokeWidth != strokeWidth;
}

class _ChevronLeftPainter extends CustomPainter {
  _ChevronLeftPainter({required this.color, required this.strokeWidth});
  final Color color;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.butt
      ..strokeJoin = StrokeJoin.miter
      ..style = PaintingStyle.stroke;
    final w = size.width;
    final h = size.height;
    final path = Path()
      ..moveTo(w * 0.65, h * 0.15)
      ..lineTo(w * 0.3, h * 0.5)
      ..lineTo(w * 0.65, h * 0.85);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _ChevronLeftPainter old) =>
      old.color != color || old.strokeWidth != strokeWidth;
}

class _SettingsPainter extends CustomPainter {
  _SettingsPainter({required this.color, required this.strokeWidth});
  final Color color;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.butt
      ..strokeJoin = StrokeJoin.miter
      ..style = PaintingStyle.stroke;
    final cx = size.width / 2;
    final cy = size.height / 2;
    final outerR = size.width * 0.46;
    final innerR = size.width * 0.32;
    final holeR = size.width * 0.14;
    // 8개 톱니의 tooth path.
    const teeth = 8;
    const halfToothAngle = 0.20; // radians (이 값 좌우로 tooth 너비)
    final path = Path();
    for (int i = 0; i < teeth; i++) {
      final center = (i * 2 * math.pi) / teeth;
      // tooth: innerR → outerR → outerR → innerR
      final a1 = center - halfToothAngle;
      final a2 = center + halfToothAngle;
      final aGapEnd = center + (2 * math.pi / teeth) - halfToothAngle;
      final p1 = Offset(cx + innerR * math.cos(a1), cy + innerR * math.sin(a1));
      final p2 = Offset(cx + outerR * math.cos(a1), cy + outerR * math.sin(a1));
      final p3 = Offset(cx + outerR * math.cos(a2), cy + outerR * math.sin(a2));
      final p4 = Offset(cx + innerR * math.cos(a2), cy + innerR * math.sin(a2));
      final p5 = Offset(
        cx + innerR * math.cos(aGapEnd),
        cy + innerR * math.sin(aGapEnd),
      );
      if (i == 0) {
        path.moveTo(p1.dx, p1.dy);
      } else {
        path.lineTo(p1.dx, p1.dy);
      }
      path.lineTo(p2.dx, p2.dy);
      path.lineTo(p3.dx, p3.dy);
      path.lineTo(p4.dx, p4.dy);
      path.lineTo(p5.dx, p5.dy);
    }
    path.close();
    canvas.drawPath(path, stroke);
    // 중앙 구멍.
    canvas.drawCircle(Offset(cx, cy), holeR, stroke);
  }

  @override
  bool shouldRepaint(covariant _SettingsPainter old) =>
      old.color != color || old.strokeWidth != strokeWidth;
}

class _SharePainter extends CustomPainter {
  _SharePainter({required this.color, required this.strokeWidth});
  final Color color;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.butt
      ..strokeJoin = StrokeJoin.miter
      ..style = PaintingStyle.stroke;
    final w = size.width;
    final h = size.height;
    // iOS 스타일 share: 박스 + 위로 나가는 화살표.
    final boxLeft = w * 0.22;
    final boxRight = w * 0.78;
    final boxTop = h * 0.42;
    final boxBottom = h * 0.92;
    // Box (U 모양, 상단은 열려 있음)
    final boxPath = Path()
      ..moveTo(w * 0.5 - w * 0.12, boxTop)
      ..lineTo(boxLeft, boxTop)
      ..lineTo(boxLeft, boxBottom)
      ..lineTo(boxRight, boxBottom)
      ..lineTo(boxRight, boxTop)
      ..lineTo(w * 0.5 + w * 0.12, boxTop);
    canvas.drawPath(boxPath, paint);
    // 위쪽 arrow: 수직선 + 화살촉
    canvas.drawLine(Offset(w * 0.5, h * 0.08), Offset(w * 0.5, h * 0.58), paint);
    final arrowPath = Path()
      ..moveTo(w * 0.5 - w * 0.16, h * 0.24)
      ..lineTo(w * 0.5, h * 0.08)
      ..lineTo(w * 0.5 + w * 0.16, h * 0.24);
    canvas.drawPath(arrowPath, paint);
  }

  @override
  bool shouldRepaint(covariant _SharePainter old) =>
      old.color != color || old.strokeWidth != strokeWidth;
}

class _ClosePainter extends CustomPainter {
  _ClosePainter({required this.color, required this.strokeWidth});
  final Color color;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.butt;
    canvas.drawLine(Offset.zero, Offset(size.width, size.height), paint);
    canvas.drawLine(Offset(size.width, 0), Offset(0, size.height), paint);
  }

  @override
  bool shouldRepaint(covariant _ClosePainter old) =>
      old.color != color || old.strokeWidth != strokeWidth;
}

class _EllipsisPainter extends CustomPainter {
  _EllipsisPainter({required this.color});
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    final cy = size.height / 2;
    // bounding box를 꽉 채우도록 좌/우 점의 바깥 edge가 size 경계에 닿게.
    final r = size.width * 0.12;
    final cx = size.width / 2;
    final outerOffset = size.width / 2 - r;
    canvas.drawCircle(Offset(cx - outerOffset, cy), r, paint);
    canvas.drawCircle(Offset(cx, cy), r, paint);
    canvas.drawCircle(Offset(cx + outerOffset, cy), r, paint);
  }

  @override
  bool shouldRepaint(covariant _EllipsisPainter old) => old.color != color;
}
