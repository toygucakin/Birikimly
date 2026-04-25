import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:birikimly/core/database/database.dart';
import 'package:birikimly/features/auth/presentation/providers/auth_provider.dart';
import 'package:birikimly/core/providers/preferences_provider.dart';

final transactionStreamProvider = StreamProvider<List<Transaction>>((ref) {
  final db = ref.watch(databaseProvider);
  final isGuest = ref.watch(guestModeProvider);
  final user = ref.watch(currentUserProvider);
  
  if (isGuest) {
    return db.watchAllTransactions('guest');
  }
  
  if (user == null) {
    return Stream.value([]);
  }
  return db.watchAllTransactions(user.id);
});

final recentTransactionsProvider = StreamProvider<List<Transaction>>((ref) {
  final db = ref.watch(databaseProvider);
  final isGuest = ref.watch(guestModeProvider);
  final user = ref.watch(currentUserProvider);
  
  if (isGuest) {
    return db.watchAllTransactions('guest', limitCount: 30);
  }
  
  if (user == null) {
    return Stream.value([]);
  }
  return db.watchAllTransactions(user.id, limitCount: 30);
});

class TransactionNotifier extends Notifier<void> {
  @override
  void build() {
    // Start sync service when this provider is used
    ref.read(syncServiceProvider).start();
  }

  Future<void> addTransaction(TransactionsCompanion entry) async {
    try {
      final db = ref.read(databaseProvider);
      await db.insertTransaction(entry);
      ref.read(syncServiceProvider).syncAll();
    } catch (e) {
      // ignore: avoid_print
      print('CRITICAL: Transaction add failed: $e');
    }
  }

  Future<void> updateTransactionAmount(Transaction transaction, double newAmount) async {
    final db = ref.read(databaseProvider);
    await db.updateTransaction(transaction.copyWith(amount: newAmount, isSynced: false));
    ref.read(syncServiceProvider).syncAll();
  }

  Future<void> deleteTransaction(Transaction transaction) async {
    final db = ref.read(databaseProvider);
    await db.deleteTransaction(transaction);
    ref.read(syncServiceProvider).syncAll();
  }

  double calculateBalance(List<Transaction> transactions) {
    return transactions.fold(0, (sum, item) {
      return item.isIncome ? sum + item.amount : sum - item.amount;
    });
  }

  double calculateIncome(List<Transaction> transactions) {
    return transactions.where((t) => t.isIncome).fold(0, (sum, item) => sum + item.amount);
  }

  double calculateExpense(List<Transaction> transactions) {
    return transactions.where((t) => !t.isIncome).fold(0, (sum, item) => sum + item.amount);
  }
}

final transactionNotifierProvider = NotifierProvider<TransactionNotifier, void>(TransactionNotifier.new);
