import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// PassForge logo: a shield with a keyhole cut out of it.
///
/// The three parameters let the splash screen animate it in; the defaults draw
/// the finished logo (also used to generate the launcher icon PNGs).
class ForgeLogoPainter extends CustomPainter {
  const ForgeLogoPainter({
    this.draw = 1,
    this.fill = 1,
    this.keyhole = 1,
  });

  /// 0→1: how much of the shield outline has been traced.
  final double draw;

  /// 0→1: opacity of the solid gradient fill (the outline fades as this grows).
  final double fill;

  /// 0→1+: keyhole scale. Values above 1 overshoot for a "pop" effect.
  final double keyhole;

  static Path shieldPath(Size s) {
    final w = s.width, h = s.height;
    return Path()
      ..moveTo(0.5 * w, 0.04 * h)
      ..cubicTo(0.62 * w, 0.12 * h, 0.78 * w, 0.16 * h, 0.90 * w, 0.16 * h)
      ..lineTo(0.90 * w, 0.50 * h)
      ..cubicTo(0.90 * w, 0.74 * h, 0.72 * w, 0.90 * h, 0.5 * w, 0.97 * h)
      ..cubicTo(0.28 * w, 0.90 * h, 0.10 * w, 0.74 * h, 0.10 * w, 0.50 * h)
      ..lineTo(0.10 * w, 0.16 * h)
      ..cubicTo(0.22 * w, 0.16 * h, 0.38 * w, 0.12 * h, 0.5 * w, 0.04 * h)
      ..close();
  }

  static Path _keyholePath(Size s, double scale) {
    final w = s.width, h = s.height;
    final cx = 0.5 * w, cy = 0.43 * h;
    final r = 0.095 * w * scale;
    final stemTop = cy + r * 0.4;
    final stemBottom = cy + 0.26 * h * scale;
    final stemHalfTop = 0.035 * w * scale;
    final stemHalfBottom = 0.055 * w * scale;
    return Path()
      ..addOval(Rect.fromCircle(center: Offset(cx, cy), radius: r))
      ..moveTo(cx - stemHalfTop, stemTop)
      ..lineTo(cx + stemHalfTop, stemTop)
      ..lineTo(cx + stemHalfBottom, stemBottom)
      ..lineTo(cx - stemHalfBottom, stemBottom)
      ..close();
  }

  @override
  void paint(Canvas canvas, Size size) {
    final shield = shieldPath(size);
    final rect = Offset.zero & size;

    if (fill > 0) {
      // Cut the keyhole out of the shield so the background shows through.
      final body = keyhole > 0
          ? Path.combine(PathOperation.difference, shield, _keyholePath(size, keyhole))
          : shield;
      final paint = Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.primaryBright, AppColors.primary],
        ).createShader(rect)
        ..color = Colors.white.withValues(alpha: fill);
      canvas.drawPath(body, paint);
    }

    if (draw > 0 && fill < 1) {
      final stroke = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = size.width * 0.028
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..color = AppColors.primaryBright.withValues(alpha: 1 - fill);
      for (final metric in shield.computeMetrics()) {
        canvas.drawPath(metric.extractPath(0, metric.length * draw), stroke);
      }
    }
  }

  @override
  bool shouldRepaint(ForgeLogoPainter old) =>
      old.draw != draw || old.fill != fill || old.keyhole != keyhole;
}
