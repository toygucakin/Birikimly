import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

class CurrencyUtils {
  static String format(double amount) {
    final formatter = NumberFormat.currency(locale: 'tr_TR', symbol: '₺');
    return formatter.format(amount);
  }
}

class ThousandsFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    if (newValue.text.isEmpty) return newValue;

    // Remove all non-digits
    String stripped = newValue.text.replaceAll(RegExp(r'[^\d]'), '');
    
    if (stripped.isEmpty) return newValue.copyWith(text: '');

    final number = int.parse(stripped);
    final formatted = NumberFormat('#,###', 'tr_TR').format(number).replaceAll(',', '.');

    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}
