import 'package:intl/intl.dart';

/// Indonesian Rupiah + date formatting helpers.
class Format {
  Format._();

  static final NumberFormat _idr = NumberFormat.currency(
    locale: 'id_ID',
    symbol: 'Rp ',
    decimalDigits: 0,
  );

  /// e.g. 50000 -> "Rp 50.000". Returns "Free" for zero.
  static String rupiah(num value) =>
      value <= 0 ? 'Free' : _idr.format(value);

  static String date(DateTime dt) =>
      DateFormat('d MMM yyyy', 'id_ID').format(dt.toLocal());

  static String dateTime(DateTime dt) =>
      DateFormat('d MMM yyyy · HH:mm', 'id_ID').format(dt.toLocal());
}
