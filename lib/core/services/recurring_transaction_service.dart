import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:birikimly/core/database/database.dart';
import 'package:uuid/uuid.dart';
import 'package:drift/drift.dart';

final recurringTransactionServiceProvider = Provider<RecurringTransactionService>((ref) {
  final db = ref.watch(databaseProvider);
  return RecurringTransactionService(db);
});

class RecurringTransactionService {
  final AppDatabase _db;
  final _uuid = const Uuid();

  RecurringTransactionService(this._db);

  /// Processes all pending recurring transactions for the given user.
  /// If a transaction's next execution date has passed, it creates a regular transaction
  /// and updates the next execution date. Returns the list of created transactions.
  Future<List<Transaction>> processRecurringTransactions(String userId) async {
    final recurringTxs = await _db.getAllRecurringTransactions(userId);
    final now = DateTime.now();
    final List<Transaction> processed = [];
    
    for (var rt in recurringTxs) {
      if (!rt.isActive) continue;

      DateTime nextDate = rt.nextExecutionDate;
      bool wasUpdated = false;
      int occurrencesExecuted = rt.occurrencesExecuted;
      bool isActive = rt.isActive;

      // Use a while loop in case the user hasn't opened the app for multiple months
      while (isActive && (nextDate.isBefore(now) || nextDate.isAtSameMomentAs(now))) {
        final execDate = nextDate;
        
        final currentInstallment = occurrencesExecuted + 1;
        final total = rt.maxOccurrences;

        // 1. Create a transaction for this execution date
        final txCompanion = TransactionsCompanion(
          uuid: Value(_uuid.v4()),
          userId: Value(rt.userId),
          amount: Value(rt.amount),
          categoryId: Value(rt.categoryId),
          description: Value(rt.description),
          date: Value(execDate),
          isIncome: Value(rt.isIncome),
          isSynced: const Value(false),
          isDeleted: const Value(false),
          recurringUuid: Value(rt.uuid),
          installmentNumber: Value(total != null ? currentInstallment : null),
          totalInstallments: Value(total),
        );
        
        final insertedTx = await _db.insertTransaction(txCompanion);
        processed.add(insertedTx);

        occurrencesExecuted++;
        if (total != null && occurrencesExecuted >= total) {
          isActive = false;
        }

        // 2. Advance the nextDate based on frequency
        nextDate = _advanceDate(nextDate, rt.startDate, rt.frequency);
        // Normalize advanced date to 12:00 PM
        nextDate = DateTime(nextDate.year, nextDate.month, nextDate.day, 12, 0, 0);
        wasUpdated = true;
      }

      // 3. Update the recurring transaction record if we executed it
      if (wasUpdated) {
        final updatedRt = rt.copyWith(
          nextExecutionDate: nextDate,
          occurrencesExecuted: occurrencesExecuted,
          isActive: isActive,
          isSynced: false, // Mark for sync since we updated the execution date
        );
        await _db.updateRecurringTransaction(updatedRt);
      }
    }
    
    return processed;
  }

  DateTime _advanceDate(DateTime current, DateTime originalStart, String frequency) {
    switch (frequency) {
      case 'weekly':
        return current.add(const Duration(days: 7));
      case 'yearly':
        return _advanceOneYear(current, originalStart);
      case 'monthly':
      default:
        return _advanceOneMonth(current, originalStart);
    }
  }

  /// Safely advances a date by exactly 1 month.
  /// Uses the original startDate's day to keep the schedule consistent (e.g., always 31st),
  /// but handles months with fewer days (e.g., capping to 30 or 28/29 for Feb).
  DateTime _advanceOneMonth(DateTime current, DateTime originalStart) {
    int nextMonth = current.month + 1;
    int nextYear = current.year;
    
    if (nextMonth > 12) {
      nextMonth = 1;
      nextYear++;
    }

    final targetDay = originalStart.day;
    final maxDaysInNextMonth = DateTime(nextYear, nextMonth + 1, 0).day;
    
    // Clamp the day so we don't overflow (e.g. asking for Feb 30 -> Feb 28/29)
    final clampedDay = targetDay > maxDaysInNextMonth ? maxDaysInNextMonth : targetDay;

    return DateTime(
      nextYear,
      nextMonth,
      clampedDay,
      originalStart.hour,
      originalStart.minute,
      originalStart.second,
    );
  }

  DateTime _advanceOneYear(DateTime current, DateTime originalStart) {
    int nextYear = current.year + 1;
    int nextMonth = current.month;
    
    final targetDay = originalStart.day;
    final maxDaysInNextMonth = DateTime(nextYear, nextMonth + 1, 0).day;
    
    final clampedDay = targetDay > maxDaysInNextMonth ? maxDaysInNextMonth : targetDay;

    return DateTime(
      nextYear,
      nextMonth,
      clampedDay,
      originalStart.hour,
      originalStart.minute,
      originalStart.second,
    );
  }
}
