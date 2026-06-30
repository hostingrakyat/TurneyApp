import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../core/app_settings.dart';
import '../../core/theme.dart';

/// The ProTourney logo. Renders the SVG bracket **mark** plus a Flutter text
/// wordmark (flutter_svg cannot render SVG `<text>`, so the wordmark is real
/// text). If an admin has uploaded a custom logo, that image is shown instead.
class AppLogo extends ConsumerWidget {
  const AppLogo({super.key, this.size = 48, this.full = false});

  /// Height of the mark. For [full], the wordmark scales relative to it.
  final double size;

  /// When true, shows the mark + "ProTourney" wordmark; otherwise just the mark.
  final bool full;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(appSettingsProvider);

    if (settings.logoBytes != null) {
      return Image.memory(settings.logoBytes!, height: size);
    }
    if (settings.logoUrl != null && settings.logoUrl!.isNotEmpty) {
      return Image.network(
        settings.logoUrl!,
        height: size,
        errorBuilder: (_, __, ___) => _Default(size: size, full: full),
      );
    }
    return _Default(size: size, full: full);
  }
}

class _Default extends StatelessWidget {
  const _Default({required this.size, required this.full});
  final double size;
  final bool full;

  @override
  Widget build(BuildContext context) {
    final mark = SvgPicture.asset(
      'assets/branding/logo-mark.svg',
      height: size,
      semanticsLabel: 'ProTourney',
    );
    if (!full) return mark;
    // Scale the whole lockup down to fit its width so the wordmark never clips.
    return FittedBox(
      fit: BoxFit.scaleDown,
      alignment: Alignment.centerLeft,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          mark,
          SizedBox(width: size * 0.24),
          Text.rich(
            TextSpan(
              children: const [
                TextSpan(text: 'Pro', style: TextStyle(color: Colors.white)),
                TextSpan(
                    text: 'Tourney',
                    style: TextStyle(color: AppColors.cyan)),
              ],
            ),
            style: TextStyle(
              fontSize: size * 0.6,
              fontWeight: FontWeight.w900,
              letterSpacing: -1,
            ),
          ),
        ],
      ),
    );
  }
}
