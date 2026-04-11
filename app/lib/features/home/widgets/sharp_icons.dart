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
