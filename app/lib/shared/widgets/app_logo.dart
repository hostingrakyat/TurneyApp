import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// Renders the TurneyApp mark (and optional wordmark) from the bundled SVG.
class AppLogo extends StatelessWidget {
  const AppLogo({super.key, this.size = 48, this.full = false});

  /// Height of the logo. For [full], width scales to the wordmark ratio.
  final double size;

  /// When true, shows the mark + "TurneyApp" wordmark; otherwise just the mark.
  final bool full;

  @override
  Widget build(BuildContext context) {
    final asset = full
        ? 'assets/branding/logo-full.svg'
        : 'assets/branding/logo-mark.svg';
    return SvgPicture.asset(
      asset,
      height: size,
      semanticsLabel: 'TurneyApp',
    );
  }
}
