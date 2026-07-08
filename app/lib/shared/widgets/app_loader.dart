import 'dart:math';

import 'package:flutter/material.dart';

import '../../core/theme.dart';

/// Branded spinner: a faint ring with a bright gradient arc sweeping around it.
/// Replaces the stock [CircularProgressIndicator] on async screens.
class AppLoader extends StatefulWidget {
  const AppLoader({super.key, this.size = 46, this.label});
  final double size;
  final String? label;

  @override
  State<AppLoader> createState() => _AppLoaderState();
}

class _AppLoaderState extends State<AppLoader>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  )..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: widget.size,
          height: widget.size,
          child: AnimatedBuilder(
            animation: _c,
            builder: (_, __) =>
                CustomPaint(painter: _RingPainter(_c.value)),
          ),
        ),
        if (widget.label != null) ...[
          const SizedBox(height: 14),
          Text(widget.label!,
              style: const TextStyle(color: Colors.white54)),
        ],
      ],
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter(this.t);
  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final center = rect.center;
    final radius = size.width / 2 - 3;

    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..color = Colors.white.withValues(alpha: 0.08),
    );

    final rot = t * 2 * pi;
    final arc = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.5
      ..strokeCap = StrokeCap.round
      ..shader = SweepGradient(
        colors: const [AppColors.violet, AppColors.sky, AppColors.gold],
        transform: GradientRotation(rot),
      ).createShader(rect);
    canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius), rot, pi * 1.4, false,
        arc);
  }

  @override
  bool shouldRepaint(covariant _RingPainter old) => old.t != t;
}

/// Full-screen centered [AppLoader].
class AppLoading extends StatelessWidget {
  const AppLoading({super.key, this.label});
  final String? label;
  @override
  Widget build(BuildContext context) =>
      Center(child: AppLoader(label: label));
}

/// A moving-highlight shimmer applied to its (placeholder) [child]. One
/// controller drives an entire skeleton group.
class Shimmer extends StatefulWidget {
  const Shimmer({super.key, required this.child});
  final Widget child;

  @override
  State<Shimmer> createState() => _ShimmerState();
}

class _ShimmerState extends State<Shimmer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1350),
  )..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (_, child) => ShaderMask(
        blendMode: BlendMode.srcATop,
        shaderCallback: (bounds) => LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: const [
            Color(0x00FFFFFF),
            Color(0x1FFFFFFF),
            Color(0x00FFFFFF),
          ],
          stops: const [0.35, 0.5, 0.65],
          transform: _SlideGradient(_c.value),
        ).createShader(bounds),
        child: child,
      ),
      child: widget.child,
    );
  }
}

class _SlideGradient extends GradientTransform {
  const _SlideGradient(this.t);
  final double t;
  @override
  Matrix4? transform(Rect bounds, {TextDirection? textDirection}) =>
      Matrix4.translationValues(bounds.width * (t * 2 - 1), 0, 0);
}

/// A rounded placeholder block for skeleton screens.
class SkeletonBox extends StatelessWidget {
  const SkeletonBox({super.key, this.width, this.height = 14, this.radius = 8});
  final double? width;
  final double height;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: AppColors.surfaceHigh,
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }
}

/// A shimmering list of card-shaped skeletons — the loading state for lists.
class SkeletonList extends StatelessWidget {
  const SkeletonList({super.key, this.count = 4, this.padding});
  final int count;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    return Shimmer(
      child: Padding(
        padding: padding ?? const EdgeInsets.symmetric(horizontal: 16),
        child: Column(
          children: [
            for (var i = 0; i < count; i++)
              Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                        color: Colors.white.withValues(alpha: 0.06)),
                  ),
                  child: Row(
                    children: [
                      const SkeletonBox(width: 48, height: 48, radius: 14),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: const [
                            SkeletonBox(height: 14, width: 160),
                            SizedBox(height: 10),
                            SkeletonBox(height: 12, width: 100),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      const SkeletonBox(width: 54, height: 24, radius: 999),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
