import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:birikimly/core/database/database.dart';
import 'package:birikimly/features/auth/presentation/providers/auth_provider.dart';
import 'package:birikimly/core/providers/preferences_provider.dart';
import 'package:uuid/uuid.dart';
import 'package:drift/drift.dart' as drift;

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
    return db.watchAllTransactions('guest', limitCount: 20);
  }
  
  if (user == null) {
    return Stream.value([]);
  }
  return db.watchAllTransactions(user.id, limitCount: 20);
});

final recurringTransactionStreamProvider = StreamProvider<List<RecurringTransaction>>((ref) {
  final db = ref.watch(databaseProvider);
  final isGuest = ref.watch(guestModeProvider);
  final user = ref.watch(currentUserProvider);
  
  if (isGuest) {
    return db.watchAllRecurringTransactions('guest');
  }
  
  if (user == null) {
    return Stream.value([]);
  }
  return db.watchAllRecurringTransactions(user.id);
});

final autoProcessedTransactionStreamProvider = StreamProvider<List<Transaction>>((ref) {
  final db = ref.watch(databaseProvider);
  final isGuest = ref.watch(guestModeProvider);
  final user = ref.watch(currentUserProvider);
  
  if (isGuest) {
    return db.watchAutoProcessedTransactions('guest');
  }
  
  if (user == null) {
    return Stream.value([]);
  }
  return db.watchAutoProcessedTransactions(user.id);
});

class TransactionNotifier extends Notifier<void> {
  @override
  void build() {
    ref.read(syncServiceProvider).start();
  }

  Future<void> addTransaction(TransactionsCompanion entry) async {
    try {
      final db = ref.read(databaseProvider);
      
      final uuid = (entry.uuid.present && entry.uuid.value.isNotEmpty) ? entry.uuid.value : const Uuid().v4();
      final finalEntry = entry.copyWith(uuid: drift.Value(uuid));
      
      await db.insertTransaction(finalEntry);
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

  Future<void> addRecurringTransaction(RecurringTransactionsCompanion entry) async {
    try {
      final db = ref.read(databaseProvider);
      final uuid = (entry.uuid.present && entry.uuid.value.isNotEmpty) ? entry.uuid.value : const Uuid().v4();
      final finalEntry = entry.copyWith(uuid: drift.Value(uuid));
      
      await db.insertRecurringTransaction(finalEntry);
      ref.read(syncServiceProvider).syncAll();
    } catch (e) {
      print('CRITICAL: Recurring Transaction add failed: $e');
    }
  }

  Future<void> updateRecurringTransactionAmount(RecurringTransaction rt, double newAmount) async {
    final db = ref.read(databaseProvider);
    await db.updateRecurringTransaction(rt.copyWith(amount: newAmount, isSynced: false));
    ref.read(syncServiceProvider).syncAll();
  }

  Future<void> updateRecurringTransactionName(RecurringTransaction rt, String newName) async {
    final db = ref.read(databaseProvider);
    await db.updateRecurringTransaction(rt.copyWith(description: newName, isSynced: false));
    ref.read(syncServiceProvider).syncAll();
  }

  Future<void> deleteRecurringTransaction(RecurringTransaction rt) async {
    final db = ref.read(databaseProvider);
    await db.deleteRecurringTransaction(rt);
    ref.read(syncServiceProvider).syncAll();
  }

  Future<void> toggleRecurringTransactionActive(RecurringTransaction rt, bool isActive) async {
    final db = ref.read(databaseProvider);
    await db.updateRecurringTransaction(rt.copyWith(isActive: isActive, isSynced: false));
    ref.read(syncServiceProvider).syncAll();
  }

  Future<void> updateRecurringTransactionFrequency(RecurringTransaction rt, String frequency) async {
    final db = ref.read(databaseProvider);
    await db.updateRecurringTransaction(rt.copyWith(frequency: frequency, isSynced: false));
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
