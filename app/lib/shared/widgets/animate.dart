import 'package:flutter/material.dart';

/// Fades and slides its [child] in on first build. Pass a [delay] (e.g.
/// `index * 40ms`, capped) to stagger a list into view.
class FadeSlideIn extends StatefulWidget {
  const FadeSlideIn({
    super.key,
    required this.child,
    this.delay = Duration.zero,
    this.offsetY = 0.08,
    this.duration = const Duration(milliseconds: 420),
  });

  final Widget child;
  final Duration delay;

  /// Starting vertical offset as a fraction of the child's height.
  final double offsetY;
  final Duration duration;

  @override
  State<FadeSlideIn> createState() => _FadeSlideInState();
}

class _FadeSlideInState extends State<FadeSlideIn>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: widget.duration);
  late final Animation<double> _fade =
      CurvedAnimation(parent: _c, curve: Curves.easeOut);
  late final Animation<Offset> _slide = Tween<Offset>(
    begin: Offset(0, widget.offsetY),
    end: Offset.zero,
  ).animate(CurvedAnimation(parent: _c, curve: Curves.easeOutCubic));

  @override
  void initState() {
    super.initState();
    if (widget.delay == Duration.zero) {
      _c.forward();
    } else {
      Future.delayed(widget.delay, () {
        if (mounted) _c.forward();
      });
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fade,
      child: SlideTransition(position: _slide, child: widget.child),
    );
  }
}

/// Staggered delay for the i-th item in a list, capped so long lists don't
/// wait too long before the last item appears.
Duration stagger(int index, {int stepMs = 45, int capMs = 320}) =>
    Duration(milliseconds: (index * stepMs).clamp(0, capMs));
