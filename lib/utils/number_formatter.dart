import 'package:intl/intl.dart';

class NumberFormatter {
  static final NumberFormat _formatter = NumberFormat('#,##0');

  /// Formats any number (int, double, num) with thousands comma separator.
  /// If [decimals] is true or [value] has fractional parts and [decimals] is null, formats with decimals.
  /// By default (decimals = 0), formats as integer with commas, e.g. 1000 -> "1,000".
  static String format(num? value, {int decimals = 0}) {
    if (value == null) return '0';
    if (decimals > 0) {
      final custom = NumberFormat.currency(
        customPattern: '#,##0.${'0' * decimals}',
        symbol: '',
      );
      return custom.format(value).trim();
    }
    return _formatter.format(value.round());
  }

  /// Formats currency with currency symbol / prefix.
  /// e.g. formatCurrency(25000) -> "MWK 25,000"
  static String formatCurrency(num? value, {String prefix = 'MWK ', int decimals = 0}) {
    return '$prefix${format(value, decimals: decimals)}';
  }
}
