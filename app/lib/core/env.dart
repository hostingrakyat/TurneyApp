/// Compile-time configuration, supplied via `--dart-define` /
/// `--dart-define-from-file`. Everything has a safe empty default so the app
/// still launches (in demo mode) when nothing is configured — handy for CI
/// builds and first-run exploration.
class Env {
  Env._();

  static const String supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  static const String supabaseAnonKey =
      String.fromEnvironment('SUPABASE_ANON_KEY');

  /// Platform commission taken from every paid registration (10%).
  /// Stored in basis points to keep it a compile-time int.
  static const int platformFeeBps =
      int.fromEnvironment('PLATFORM_FEE_BPS', defaultValue: 1000);

  static double get platformFeeRate => platformFeeBps / 10000.0;

  /// Minutes both players have to report a result before auto-resolution.
  static const int matchAutoResolveMinutes =
      int.fromEnvironment('MATCH_AUTO_RESOLVE_MINUTES', defaultValue: 5);

  /// True once a real Supabase backend is wired up. When false the app runs
  /// against in-memory demo data so the UI is fully explorable offline.
  static bool get hasBackend =>
      supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty;

  /// Build destined for an app store (Google Play / App Store).
  ///
  /// Google Play's Payments policy requires Play Billing for anything bought
  /// inside the app, and its Real-Money Games policy does not cover paid-entry,
  /// cash-prize contests in Indonesia — so a Play build that collected entry
  /// fees via QRIS or bank transfer risks removal. Store builds therefore ship
  /// with **every monetary surface hidden**: no entry fees, no prize amounts, no
  /// checkout, no payout or transaction screens. Paid competitions become
  /// view-only; free ones still work end-to-end.
  ///
  ///   flutter build appbundle --release --dart-define=STORE_BUILD=true
  ///
  /// The web build (cPanel) leaves this off and keeps the full payment flow.
  /// See `docs/GOOGLE_PLAY.md`.
  static const bool storeBuild = bool.fromEnvironment('STORE_BUILD');

  /// Whether any money UI (fees, prizes, checkout, payouts) may be shown.
  static bool get paymentsEnabled => !storeBuild;
}
