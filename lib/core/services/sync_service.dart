import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:drift/drift.dart';
import 'package:taptap/core/database/database.dart';
import 'package:taptap/core/services/supabase_service.dart';

class SyncService {
  final AppDatabase _db;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;

  SyncService(this._db);

  void start() {
    _connectivitySubscription = Connectivity().onConnectivityChanged.listen((results) {
      if (results.any((result) => result != ConnectivityResult.none)) {
        syncTransactions();
      }
    });
  }

  void stop() {
    _connectivitySubscription?.cancel();
  }

  Future<void> syncTransactions() async {
    final user = SupabaseService.client.auth.currentUser;
    if (user == null) return;

    final unsynced = await _db.getUnsyncedTransactions(user.id);
    if (unsynced.isEmpty) return;

    for (final tx in unsynced) {
      try {
        final response = await SupabaseService.client.from('transactions').upsert({
          'id': tx.remoteId, 
          'amount': tx.amount,
          'category': tx.category,
          'description': tx.description,
          'date': tx.date.toIso8601String(),
          'is_income': tx.isIncome,
          'user_id': user.id, // Auth linking
        }).select().single();

        final updatedTx = tx.copyWith(
          remoteId: Value(response['id'].toString()),
          isSynced: true,
        );
        await _db.updateTransaction(updatedTx);
      } catch (e) {
        // ignore: avoid_print
        print('Sync failed for transaction ${tx.id}: $e');
      }
    }
  }
}
