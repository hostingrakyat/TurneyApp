import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/theme.dart';

/// The onboarding motion graphic: counter-rotating orbit rings and drifting
/// diamonds around a tournament bracket that draws itself, then pops a glowing
/// gold champion node. Pure Flutter — no animation package, no asset.
class OnboardingHero extends StatefulWidget {
  const OnboardingHero({super.key, this.size = 200, this.parallax = 0});

  final double size;

  /// Horizontal page offset (-1…1) — shifts and tilts the art as pages slide.
  final double parallax;

  @override
  State<OnboardingHero> createState() => _OnboardingHeroState();
}

class _OnboardingHeroState extends State<OnboardingHero>
    with TickerProviderStateMixin {
  /// One full draw → pop → hold → reset cycle.
  late final AnimationController _cycle = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 5200),
  )..repeat();

  /// Never-restarting ambient motion (orbits + particles).
  late final AnimationController _ambient = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 24),
  )..repeat();

  @override
  void dispose() {
    _cycle.dispose();
    _ambient.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: RepaintBoundary(
        child: AnimatedBuilder(
          animation: Listenable.merge([_cycle, _ambient]),
          builder: (_, __) => Transform.translate(
            offset: Offset(widget.parallax * -26, 0),
            child: Transform.rotate(
              angle: widget.parallax * 0.05,
              child: CustomPaint(
                painter: _HeroPainter(t: _cycle.value, spin: _ambient.value),
                size: Size.square(widget.size),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _HeroPainter extends CustomPainter {
  _HeroPainter({required this.t, required this.spin});

  /// Draw/pop cycle phase, 0…1.
  final double t;

  /// Ambient rotation phase, 0…1.
  final double spin;

  static const _tau = math.pi * 2;

  /// Bracket geometry in the 512-space of `branding/logo-mark.svg`.
  static final List<List<Offset>> _bracket = [
    [Offset(150, 388), Offset(150, 342)],
    [Offset(210, 388), Offset(210, 342)],
    [Offset(302, 388), Offset(302, 342)],
    [Offset(362, 388), Offset(362, 342)],
    [Offset(150, 342), Offset(210, 342)],
    [Offset(302, 342), Offset(362, 342)],
    [Offset(180, 342), Offset(180, 272)],
    [Offset(332, 342), Offset(332, 272)],
    [Offset(180, 272), Offset(332, 272)],
    [Offset(256, 272), Offset(256, 206)],
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final r = size.shortestSide / 2;

    // ── phases ────────────────────────────────────────────────
    // 0.00–0.42 draw · 0.42–0.56 pop · 0.56–0.92 hold · 0.92–1 fade out
    final draw = Curves.easeInOutCubic.transform((t / 0.42).clamp(0.0, 1.0).toDouble());
    final pop = t < 0.42
        ? 0.0
        : Curves.elasticOut.transform(((t - 0.42) / 0.14).clamp(0.0, 1.0).toDouble());
    final fade = t < 0.92
        ? 1.0
        : 1.0 - Curves.easeIn.transform((t - 0.92) / 0.08);

    _glow(canvas, center, r, pop, fade);
    _orbits(canvas, center, r, fade);
    _particles(canvas, size, fade);

    // ── bracket, drawn on ─────────────────────────────────────
    final scale = size.width / 512 * 1.06;
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.scale(scale);
    canvas.translate(-256, -300); // centre the bracket + champion node

    final path = Path();
    for (final seg in _bracket) {
      path.moveTo(seg.first.dx, seg.first.dy);
      path.lineTo(seg.last.dx, seg.last.dy);
    }
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 22
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..color = Colors.white.withValues(alpha: 0.94 * fade);

    final grown = Path();
    for (final m in path.computeMetrics()) {
      grown.addPath(m.extractPath(0, m.length * draw), Offset.zero);
    }
    canvas.drawPath(grown, stroke);

    // ── champion diamond ──────────────────────────────────────
    if (pop > 0) {
      const node = Offset(256, 166);
      canvas.save();
      canvas.translate(node.dx, node.dy);
      canvas.scale(pop.clamp(0.0, 1.4).toDouble());
      canvas.rotate(math.pi / 4);
      final rect = Rect.fromCenter(
          center: Offset.zero, width: 62, height: 62);
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, const Radius.circular(14)),
        // Alpha is baked into the gradient — a Paint.color would be ignored
        // once a shader is set.
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              const Color(0xFFFDE68A).withValues(alpha: fade),
              AppColors.gold.withValues(alpha: fade),
            ],
          ).createShader(rect),
      );
      canvas.restore();
    }
    canvas.restore();
  }

  /// Soft halo behind the champion node, breathing with the pop.
  void _glow(Canvas canvas, Offset center, double r, double pop, double fade) {
    final c = center.translate(0, -r * 0.42);
    final radius = r * (0.42 + 0.16 * pop);
    canvas.drawCircle(
      c,
      radius,
      Paint()
        ..shader = RadialGradient(colors: [
          AppColors.gold.withValues(alpha: 0.42 * pop * fade),
          AppColors.gold.withValues(alpha: 0),
        ]).createShader(Rect.fromCircle(center: c, radius: radius)),
    );
  }

  /// Two counter-rotating dashed rings.
  void _orbits(Canvas canvas, Offset center, double r, double fade) {
    for (var i = 0; i < 2; i++) {
      final radius = r * (i == 0 ? 0.94 : 0.74);
      final dir = i == 0 ? 1.0 : -1.4;
      final dashes = i == 0 ? 30 : 22;
      final p = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = i == 0 ? 2 : 1.4
        ..strokeCap = StrokeCap.round
        ..color = Colors.white.withValues(alpha: (i == 0 ? 0.20 : 0.13) * fade);
      final sweep = _tau / dashes * 0.52;
      for (var d = 0; d < dashes; d++) {
        final a = spin * _tau * dir + d * _tau / dashes;
        canvas.drawArc(Rect.fromCircle(center: center, radius: radius), a,
            sweep, false, p);
      }
    }
  }

  /// Diamonds drifting upward and wrapping — depth behind the bracket.
  void _particles(Canvas canvas, Size size, double fade) {
    const n = 9;
    for (var i = 0; i < n; i++) {
      final seed = i / n;
      final speed = 0.6 + (i % 3) * 0.25;
      final y = (1.15 - ((spin * speed + seed) % 1.0) * 1.3) * size.height;
      final x = size.width *
          (0.1 + 0.8 * seed + 0.05 * math.sin((spin * _tau * speed) + i));
      final s = 3.0 + (i % 3) * 1.6;
      final alpha = (0.10 + 0.14 * ((i % 4) / 3)) * fade;
      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(math.pi / 4 + spin * _tau * speed);
      canvas.drawRect(
        Rect.fromCenter(center: Offset.zero, width: s, height: s),
        Paint()
          ..color = (i.isEven ? AppColors.gold : Colors.white)
              .withValues(alpha: alpha),
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _HeroPainter old) =>
      old.t != t || old.spin != spin;
}
