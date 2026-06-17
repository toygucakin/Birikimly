import 'package:home_widget/home_widget.dart';
import 'package:intl/intl.dart';

class WidgetService {
  static const String androidWidgetName = 'BirikimlyWidgetProvider';
  static const String iOSWidgetName = 'BirikimlyWidget';
  static const String appGroupId = 'group.com.example.birikimly';

  static Future<void> init() async {
    await HomeWidget.setAppGroupId(appGroupId);
  }

  static String _formatCurrency(double val) {
    return NumberFormat.currency(
      locale: 'tr_TR',
      symbol: '₺',
      decimalDigits: 2,
    ).format(val);
  }

  static Future<void> updateWidgetData({
    required double income,
    required double expense,
    required double net,
    double? limit,
    String? themeHex,
  }) async {
    try {
      await HomeWidget.saveWidgetData<String>('net_amount', _formatCurrency(net));
      await HomeWidget.saveWidgetData<String>('income_amount', _formatCurrency(income));
      await HomeWidget.saveWidgetData<String>('expense_amount', _formatCurrency(expense));
      
      if (limit != null) {
        await HomeWidget.saveWidgetData<String>('limit_amount', _formatCurrency(limit));
      } else {
        await HomeWidget.saveWidgetData<String>('limit_amount', '');
      }
      
      if (themeHex != null) {
        await HomeWidget.saveWidgetData<String>('theme_hex', themeHex);
      }

      await HomeWidget.updateWidget(
        name: androidWidgetName,
        iOSName: iOSWidgetName,
      );
    } catch (e) {
      print('Widget güncelleme hatası: $e');
    }
  }
}
