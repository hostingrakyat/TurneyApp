import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// ProTourney brand palette — Maroon Red primary with white sub-accents,
/// dark maroon-tinted base. Field names are kept stable to limit churn:
/// `violet` = primary maroon, `cyan`/`sky` = white/light sub-accent.
class AppColors {
  AppColors._();

  static const Color violet = Color(0xFF9E1B32); // primary maroon
  static const Color violetDeep = Color(0xFF6E1422); // deep maroon
  static const Color sky = Color(0xFFB91C3B); // crimson (gradient end)
  static const Color cyan = Color(0xFFF5E9EC); // white sub-accent
  static const Color gold = Color(0xFFF1B24A); // champion gold
  static const Color ink = Color(0xFF120A0D); // near-black, warm
  static const Color surface = Color(0xFF1E1216);
  static const Color surfaceHigh = Color(0xFF2A171D);
  static const Color danger = Color(0xFFEF4444);
  static const Color success = Color(0xFF22C55E);

  static const LinearGradient brand = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [violet, sky],
  );
}

class AppTheme {
  AppTheme._();

  static ThemeData get dark {
    final base = ThemeData.dark(useMaterial3: true);
    final scheme = ColorScheme.fromSeed(
      seedColor: AppColors.violet,
      brightness: Brightness.dark,
      primary: AppColors.violet,
      secondary: AppColors.cyan,
      surface: AppColors.surface,
      error: AppColors.danger,
    ).copyWith(surfaceContainerHighest: AppColors.surfaceHigh);

    final textTheme = GoogleFonts.plusJakartaSansTextTheme(base.textTheme)
        .apply(bodyColor: Colors.white, displayColor: Colors.white);

    return base.copyWith(
      colorScheme: scheme,
      scaffoldBackgroundColor: AppColors.ink,
      textTheme: textTheme,
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.ink,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: textTheme.titleLarge?.copyWith(
          fontWeight: FontWeight.w800,
          letterSpacing: -0.5,
        ),
      ),
      cardTheme: CardThemeData(
        color: AppColors.surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: Colors.white.withValues(alpha: 0.06)),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surfaceHigh,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.06)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.cyan, width: 1.5),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.violet,
          foregroundColor: Colors.white,
          minimumSize: const Size.fromHeight(52),
          textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
      chipTheme: base.chipTheme.copyWith(
        backgroundColor: AppColors.surfaceHigh,
        side: BorderSide(color: Colors.white.withValues(alpha: 0.06)),
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: AppColors.surface,
        indicatorColor: AppColors.violet.withValues(alpha: 0.25),
        labelTextStyle: WidgetStateProperty.all(
          textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w600),
        ),
      ),
      dividerTheme: DividerThemeData(
        color: Colors.white.withValues(alpha: 0.06),
        space: 1,
      ),
    );
  }
}
