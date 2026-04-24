import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:drift/drift.dart';
import 'package:birikimly/core/database/database.dart';
import 'package:birikimly/core/services/supabase_service.dart';

class SyncService {
  final AppDatabase _db;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;

  SyncService(this._db);

  void start() {
    _connectivitySubscription = Connectivity().onConnectivityChanged.listen((results) {
      if (results.any((result) => result != ConnectivityResult.none)) {
        syncAll();
      }
    });
    // Run sync on start
    syncAll();
  }

  void stop() {
    _connectivitySubscription?.cancel();
  }

  Future<void> syncAll() async {
    await syncCategories();
    await syncTransactions();
  }

  Future<void> syncCategories() async {
    final user = SupabaseService.client.auth.currentUser;
    if (user == null) return;

    // 1. Push local changes
    final unsynced = await _db.getUnsyncedCategories(user.id);
    for (final cat in unsynced) {
      try {
        final response = await SupabaseService.client.from('categories').upsert({
          'uuid': cat.uuid,
          'name': cat.name,
          'icon_code': cat.iconCode,
          'color_value': cat.colorValue,
          'is_income': cat.isIncome,
          'is_deleted': cat.isDeleted,
          'user_id': user.id,
        }).select().single();

        await _db.updateCategoryRecord(cat.copyWith(
          remoteId: Value(response['id'].toString()),
          isSynced: true,
        ));
      } catch (e) {
        print('Category sync push failed: $e');
      }
    }

    // 2. Pull remote changes
    try {
      final remoteCats = await SupabaseService.client
          .from('categories')
          .select()
          .eq('user_id', user.id);

      for (final rc in remoteCats) {
        final localCats = await _db.getAllCategories(user.id);
        final exists = localCats.any((c) => c.uuid == rc['uuid']);

        if (!exists && rc['is_deleted'] == false) {
          await _db.insertCategory(CategoriesCompanion.insert(
            uuid: rc['uuid'],
            userId: user.id,
            name: rc['name'],
            iconCode: rc['icon_code'],
            colorValue: rc['color_value'],
            isIncome: rc['is_income'],
            isSynced: const Value(true),
            remoteId: Value(rc['id'].toString()),
          ));
        }
      }
    } catch (e) {
      print('Category sync pull failed: $e');
    }
  }

  Future<void> syncTransactions() async {
    final user = SupabaseService.client.auth.currentUser;
    if (user == null) return;

    // 1. Push local changes
    final unsynced = await _db.getUnsyncedTransactions(user.id);
    for (final tx in unsynced) {
      try {
        final response = await SupabaseService.client.from('transactions').upsert({
          'id': tx.remoteId != null ? int.tryParse(tx.remoteId!) : null,
          'amount': tx.amount,
          'category_id': tx.categoryId,
          'description': tx.description,
          'date': tx.date.toIso8601String(),
          'is_income': tx.isIncome,
          'user_id': user.id,
        }).select().single();

        await _db.updateTransaction(tx.copyWith(
          remoteId: Value(response['id'].toString()),
          isSynced: true,
        ));
      } catch (e) {
        print('Transaction sync push failed indices: $e');
      }
    }

    // 2. Pull remote changes
    try {
      final remoteTxs = await SupabaseService.client
          .from('transactions')
          .select()
          .eq('user_id', user.id);

      final localTxs = await _db.getAllTransactions(user.id);
      
      for (final rt in remoteTxs) {
        final exists = localTxs.any((t) => t.remoteId == rt['id'].toString());

        if (!exists) {
          await _db.insertTransaction(TransactionsCompanion.insert(
            remoteId: Value(rt['id'].toString()),
            userId: user.id,
            amount: (rt['amount'] as num).toDouble(),
            categoryId: rt['category_id'],
            description: rt['description'],
            date: DateTime.parse(rt['date']),
            isIncome: rt['is_income'],
            isSynced: const Value(true),
          ));
        }
      }
    } catch (e) {
      print('Transaction sync pull failed: $e');
    }
  }
}
