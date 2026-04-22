import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:taptap/core/database/database.dart';
import 'package:taptap/core/services/sync_service.dart';
import 'package:taptap/features/auth/presentation/providers/auth_provider.dart';

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
  final user = ref.watch(currentUserProvider);
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
