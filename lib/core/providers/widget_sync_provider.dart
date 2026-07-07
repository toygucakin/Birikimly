import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:birikimly/features/transactions/presentation/providers/transaction_provider.dart';
import 'package:birikimly/core/providers/preferences_provider.dart';
import 'package:birikimly/core/providers/theme_provider.dart';
import 'package:birikimly/core/services/widget_service.dart';
import 'package:birikimly/features/auth/presentation/providers/auth_provider.dart';

final widgetSyncProvider = Provider<void>((ref) {
  final limit = ref.watch(monthlyLimitProvider);
  final theme = ref.watch(themeProvider);
  final transactionsAsync = ref.watch(transactionStreamProvider);
  final user = ref.watch(currentUserProvider);
  final isGuest = ref.watch(guestModeProvider);

  transactionsAsync.whenData((transactions) {
    final now = DateTime.now();
    final currentMonthTransactions = transactions.where((t) => 
      t.date.year == now.year && t.date.month == now.month).toList();

    double income = 0;
    double expense = 0;

    for (var t in currentMonthTransactions) {
      if (t.isIncome) {
        income += t.amount;
      } else {
        expense += t.amount;
      }
    }
    
    double net = income - expense;
    
    // Extrah hex from Color
    final primaryColorValue = theme.palette.primary.value.toRadixString(16).padLeft(8, '0');
    final themeHex = '#$primaryColorValue';

    WidgetService.updateWidgetData(
      income: income,
      expense: expense,
      net: net,
      limit: limit,
      themeHex: themeHex,
      isAuthenticated: user != null || isGuest,
    );
  });
});
