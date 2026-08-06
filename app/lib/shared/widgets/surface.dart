import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/theme.dart';

/// Thin etched vector motifs painted inside surfaces. Drawn in low-opacity
/// black (so they read as engraved shadow on brand-coloured fills) plus an
/// optional white hairline so they stay visible on very dark cards.
enum PatternType { grid, diagonal, dots, rays, bracket }

class PatternPainter extends CustomPainter {
  const PatternPainter({
    this.type = PatternType.diagonal,
    this.opacity = 0.16,
    this.spacing = 22,
    this.strokeWidth = 1,
    this.highlight = 0.03,
  });

  final PatternType type;

  /// Alpha of the black "etched" strokes.
  final double opacity;
  final double spacing;
  final double strokeWidth;

  /// Alpha of the white hairline drawn 1px below, for dark surfaces.
  final double highlight;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.clipRect(Offset.zero & size);
    if (highlight > 0) {
      canvas.save();
      canvas.translate(0, 1);
      _draw(canvas, size, Colors.white.withValues(alpha: highlight));
      canvas.restore();
    }
    _draw(canvas, size, Colors.black.withValues(alpha: opacity));
  }

  void _draw(Canvas canvas, Size size, Color color) {
    final p = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..color = color;
    switch (type) {
      case PatternType.grid:
        for (var x = spacing; x < size.width; x += spacing) {
          canvas.drawLine(Offset(x, 0), Offset(x, size.height), p);
        }
        for (var y = spacing; y < size.height; y += spacing) {
          canvas.drawLine(Offset(0, y), Offset(size.width, y), p);
        }
      case PatternType.diagonal:
        for (var x = -size.height; x < size.width; x += spacing) {
          canvas.drawLine(
              Offset(x, size.height), Offset(x + size.height, 0), p);
        }
      case PatternType.dots:
        final fill = Paint()..color = color;
        for (var y = spacing / 2; y < size.height; y += spacing) {
          for (var x = spacing / 2; x < size.width; x += spacing) {
            canvas.drawCircle(Offset(x, y), strokeWidth * 1.1, fill);
          }
        }
      case PatternType.rays:
        final origin = Offset(size.width, 0);
        final reach = size.width + size.height;
        for (var a = 0.0; a <= math.pi / 2; a += math.pi / 26) {
          canvas.drawLine(
            origin,
            origin + Offset(-math.cos(a) * reach, math.sin(a) * reach),
            p,
          );
        }
      case PatternType.bracket:
        // Repeating tournament-bracket motif: two seeds merging into one.
        final w = spacing * 2.4;
        final h = spacing * 1.8;
        for (var y = 0.0; y < size.height + h; y += h) {
          for (var x = -w; x < size.width + w; x += w) {
            final path = Path()
              ..moveTo(x, y + h * 0.22)
              ..lineTo(x + w * 0.42, y + h * 0.22)
              ..moveTo(x, y + h * 0.78)
              ..lineTo(x + w * 0.42, y + h * 0.78)
              ..moveTo(x + w * 0.42, y + h * 0.22)
              ..lineTo(x + w * 0.42, y + h * 0.78)
              ..moveTo(x + w * 0.42, y + h * 0.5)
              ..lineTo(x + w * 0.82, y + h * 0.5);
            canvas.drawPath(path, p);
          }
        }
    }
  }

  @override
  bool shouldRepaint(covariant PatternPainter old) =>
      old.type != type ||
      old.opacity != opacity ||
      old.spacing != spacing ||
      old.highlight != highlight;
}

/// Non-interactive pattern layer — drop into a [Stack] above a fill.
class PatternOverlay extends StatelessWidget {
  const PatternOverlay({
    super.key,
    this.type = PatternType.diagonal,
    this.opacity = 0.16,
    this.spacing = 22,
    this.highlight = 0.03,
  });

  final PatternType type;
  final double opacity;
  final double spacing;
  final double highlight;

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: IgnorePointer(
        child: CustomPaint(
          painter: PatternPainter(
            type: type,
            opacity: opacity,
            spacing: spacing,
            highlight: highlight,
          ),
        ),
      ),
    );
  }
}

/// A rounded surface with a fill, an etched vector pattern, a hairline border
/// and soft depth — the standard "container" look across the app.
class PanelSurface extends StatelessWidget {
  const PanelSurface({
    super.key,
    required this.child,
    this.gradient,
    this.color,
    this.pattern = PatternType.diagonal,
    this.patternOpacity = 0.16,
    this.patternSpacing = 22,
    this.padding = const EdgeInsets.all(20),
    this.radius = 24,
    this.borderColor,
    this.shadow = true,
    this.accent,
  });

  final Widget child;
  final Gradient? gradient;
  final Color? color;
  final PatternType pattern;
  final double patternOpacity;
  final double patternSpacing;
  final EdgeInsetsGeometry padding;
  final double radius;
  final Color? borderColor;
  final bool shadow;

  /// Optional colour for a soft corner glow (e.g. gold for prize panels).
  final Color? accent;

  @override
  Widget build(BuildContext context) {
    final br = BorderRadius.circular(radius);
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: br,
        boxShadow: shadow
            ? [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.34),
                  blurRadius: 22,
                  offset: const Offset(0, 10),
                ),
              ]
            : null,
      ),
      child: ClipRRect(
        borderRadius: br,
        child: Stack(
          children: [
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: gradient,
                  color: gradient == null ? (color ?? AppColors.surface) : null,
                ),
              ),
            ),
            PatternOverlay(
              type: pattern,
              opacity: patternOpacity,
              spacing: patternSpacing,
            ),
            if (accent != null)
              Positioned(
                right: -40,
                top: -40,
                child: IgnorePointer(
                  child: Container(
                    width: 150,
                    height: 150,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(colors: [
                        accent!.withValues(alpha: 0.30),
                        accent!.withValues(alpha: 0),
                      ]),
                    ),
                  ),
                ),
              ),
            // Top highlight — catches the light like a physical panel.
            Positioned(
              left: 0,
              right: 0,
              top: 0,
              child: IgnorePointer(
                child: Container(
                  height: 1,
                  color: Colors.white.withValues(alpha: 0.10),
                ),
              ),
            ),
            Positioned.fill(
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: br,
                    border: Border.all(
                      color: borderColor ??
                          Colors.white.withValues(alpha: 0.07),
                    ),
                  ),
                ),
              ),
            ),
            Padding(padding: padding, child: child),
          ],
        ),
      ),
    );
  }
}

/// Section title with a brand accent bar — used above list sections.
class SectionHeader extends StatelessWidget {
  const SectionHeader(this.title, {super.key, this.subtitle, this.trailing});

  final String title;
  final String? subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 4,
            height: subtitle == null ? 20 : 34,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [AppColors.sky, AppColors.violet],
              ),
              borderRadius: BorderRadius.circular(3),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(title,
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.w800)),
                if (subtitle != null)
                  Text(subtitle!,
                      style: const TextStyle(color: Colors.white54)),
              ],
            ),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}
