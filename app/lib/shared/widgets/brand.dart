import 'package:flutter/material.dart';

import '../../core/theme.dart';
import 'surface.dart';

/// A surface with the brand gradient plus an etched vector pattern — used for
/// hero panels and CTAs.
class GradientPanel extends StatelessWidget {
  const GradientPanel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(20),
    this.radius = 24,
    this.pattern = PatternType.bracket,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;
  final PatternType pattern;

  @override
  Widget build(BuildContext context) {
    return PanelSurface(
      gradient: AppColors.brand,
      pattern: pattern,
      patternOpacity: 0.17,
      patternSpacing: 26,
      padding: padding,
      radius: radius,
      accent: AppColors.gold,
      child: child,
    );
  }
}

/// A small rounded status/format pill.
class TagPill extends StatelessWidget {
  const TagPill(this.label, {super.key, this.color, this.icon});

  final String label;
  final Color? color;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final c = color ?? AppColors.cyan;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: c.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 13, color: c),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: TextStyle(
              color: c,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

/// Consistent empty-state placeholder.
class EmptyState extends StatelessWidget {
  const EmptyState({super.key, required this.title, this.subtitle, this.icon});

  final String title;
  final String? subtitle;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon ?? Icons.inbox_outlined,
                size: 48, color: Colors.white24),
            const SizedBox(height: 12),
            Text(title,
                style: const TextStyle(
                    fontSize: 16, fontWeight: FontWeight.w700)),
            if (subtitle != null) ...[
              const SizedBox(height: 6),
              Text(subtitle!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white54)),
            ],
          ],
        ),
      ),
    );
  }
}
