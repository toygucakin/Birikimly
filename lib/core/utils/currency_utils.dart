import 'package:intl/intl.dart';

class CurrencyUtils {
  static String format(double amount) {
    final formatter = NumberFormat.currency(locale: 'tr_TR', symbol: '₺');
    return formatter.format(amount);
  }
}
