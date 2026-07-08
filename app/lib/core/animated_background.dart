import 'dart:math';

import 'package:flutter/material.dart';

import 'theme.dart';

/// Wraps the whole app: a static dark base + a slow, looping field of abstract
/// geometric shapes painted behind every (transparent-scaffold) screen. Kept
/// subtle and cheap — a handful of soft orbs and rotating wireframe polygons.
class AppBackdrop extends StatelessWidget {
  const AppBackdrop({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        const Positioned.fill(child: ColoredBox(color: AppColors.ink)),
        const Positioned.fill(
          child: RepaintBoundary(child: AnimatedBackground()),
        ),
        child,
      ],
    );
  }
}

class AnimatedBackground extends StatefulWidget {
  const AnimatedBackground({super.key});

  @override
  State<AnimatedBackground> createState() => _AnimatedBackgroundState();
}

class _AnimatedBackgroundState extends State<AnimatedBackground>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 48),
  )..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _c,
        builder: (_, __) => CustomPaint(
          painter: _BackdropPainter(_c.value),
          size: Size.infinite,
        ),
      ),
    );
  }
}

class _BackdropPainter extends CustomPainter {
  _BackdropPainter(this.t);

  /// Loop phase in [0, 1).
  final double t;

  static const _tau = 2 * pi;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final unit = sqrt(w * w + h * h);

    // Soft gradient orbs drifting on gentle lissajous paths — give depth.
    _orb(canvas, Offset(w * (0.18 + 0.06 * sin(_tau * t)),
        h * (0.16 + 0.05 * cos(_tau * t))), unit * 0.42, AppColors.violet, 0.22);
    _orb(canvas, Offset(w * (0.88 + 0.05 * cos(_tau * t * 0.8)),
        h * (0.34 + 0.06 * sin(_tau * t * 0.8))), unit * 0.38, AppColors.sky,
        0.18);
    _orb(canvas, Offset(w * (0.7 + 0.05 * sin(_tau * t * 1.2 + 1)),
        h * (0.92 + 0.04 * cos(_tau * t * 1.2))), unit * 0.5,
        AppColors.violetDeep, 0.2);

    // Rotating wireframe polygons — the abstract "geometry".
    _poly(canvas, Offset(w * 0.82, h * 0.15), unit * 0.05, 3, t * _tau, 0.11);
    _poly(canvas, Offset(w * 0.14, h * 0.7), unit * 0.07, 6, -t * _tau * 0.7,
        0.09);
    _poly(canvas, Offset(w * 0.5, h * 0.48), unit * 0.1, 4, t * _tau * 0.5,
        0.05);
    _poly(canvas, Offset(w * 0.9, h * 0.82), unit * 0.045, 3, -t * _tau + 1,
        0.1);
    _poly(canvas, Offset(w * 0.32, h * 0.22), unit * 0.035, 5,
        t * _tau * 1.3, 0.08);
  }

  void _orb(Canvas c, Offset center, double r, Color col, double a) {
    final rect = Rect.fromCircle(center: center, radius: r);
    final shader = RadialGradient(
      colors: [col.withValues(alpha: a), col.withValues(alpha: 0)],
    ).createShader(rect);
    c.drawCircle(center, r, Paint()..shader = shader);
  }

  void _poly(Canvas c, Offset center, double r, int sides, double rot,
      double a) {
    final path = Path();
    for (var i = 0; i < sides; i++) {
      final ang = rot + i * _tau / sides - pi / 2;
      final p = center + Offset(cos(ang) * r, sin(ang) * r);
      i == 0 ? path.moveTo(p.dx, p.dy) : path.lineTo(p.dx, p.dy);
    }
    path.close();
    c.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4
        ..strokeJoin = StrokeJoin.round
        ..color = AppColors.cyan.withValues(alpha: a),
    );
  }

  @override
  bool shouldRepaint(covariant _BackdropPainter old) => old.t != t;
}
