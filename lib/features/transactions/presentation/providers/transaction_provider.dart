import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:birikimly/core/database/database.dart';
import 'package:birikimly/core/services/sync_service.dart';
import 'package:birikimly/features/auth/presentation/providers/auth_provider.dart';
import 'package:birikimly/core/providers/preferences_provider.dart';

final databaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  ref.onDispose(() => db.close());
  return db;
});

final syncServiceProvider = Provider<SyncService>((ref) {
  final db = ref.watch(databaseProvider);
  final service = SyncService(db);
  service.start();
  ref.onDispose(() => service.stop());
  return service;
});

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

class TransactionNotifier extends Notifier<void> {
  @override
  void build() {}

  Future<void> addTransaction(TransactionsCompanion entry) async {
    final db = ref.read(databaseProvider);
    await db.insertTransaction(entry);
    // Manual trigger for sync if online
    ref.read(syncServiceProvider).syncTransactions();
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
