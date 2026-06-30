import 'package:intl/intl.dart';

/// Display currency. The numeric amount is shown as-is — switching currency
/// changes the symbol/formatting only, it does NOT convert (no FX rate).
enum AppCurrency {
  idr,
  usd;

  static AppCurrency fromName(String? v) =>
      v == 'usd' ? AppCurrency.usd : AppCurrency.idr;

  String get label => this == AppCurrency.usd ? 'US Dollar (\$)' : 'Rupiah (Rp)';
  String get symbol => this == AppCurrency.usd ? '\$' : 'Rp';
}

/// Currency + date formatting. Currency is process-global (set from the user's
/// saved preference at startup and whenever it changes) so the many
/// `Format.money(...)` call sites don't each need the current currency passed in.
class Format {
  Format._();

  static AppCurrency _currency = AppCurrency.idr;

  static void setCurrency(AppCurrency c) => _currency = c;

  static final NumberFormat _idr = NumberFormat.currency(
    locale: 'id_ID',
    symbol: 'Rp ',
    decimalDigits: 0,
  );
  static final NumberFormat _usd = NumberFormat.currency(
    locale: 'en_US',
    symbol: '\$',
    decimalDigits: 0,
  );

  /// e.g. 50000 -> "Rp 50.000" / "$50,000". Returns "Free" for zero.
  static String money(num value) {
    if (value <= 0) return 'Free';
    return (_currency == AppCurrency.usd ? _usd : _idr).format(value);
  }

  /// Backwards-compatible alias.
  static String rupiah(num value) => money(value);

  static String date(DateTime dt) =>
      DateFormat('d MMM yyyy', 'id_ID').format(dt.toLocal());

  static String dateTime(DateTime dt) =>
      DateFormat('d MMM yyyy · HH:mm', 'id_ID').format(dt.toLocal());
}
