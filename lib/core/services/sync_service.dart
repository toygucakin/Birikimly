import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:drift/drift.dart';
import 'package:birikimly/core/database/database.dart';
import 'package:birikimly/core/services/supabase_service.dart';

class SyncService {
  final AppDatabase _db;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;
  bool _isSyncing = false;

  SyncService(this._db);

  void start() {
    print('SyncService: Starting...');
    _connectivitySubscription = Connectivity().onConnectivityChanged.listen((results) {
      if (results.any((result) => result != ConnectivityResult.none)) {
        print('SyncService: Network detected, triggering sync...');
        syncAll();
      }
    });
    
    Future.delayed(const Duration(seconds: 2), () {
      syncAll();
    });
  }

  void stop() {
    print('SyncService: Stopping...');
    _connectivitySubscription?.cancel();
  }

  Future<void> syncAll() async {
    if (_isSyncing) {
      print('SyncService: Sync already in progress, skipping call.');
      return;
    }

    try {
      final user = SupabaseService.client.auth.currentUser;
      if (user == null) {
        print('SyncService: No active user session found, skipping sync.');
        return;
      }
      
      _isSyncing = true;
      print('SyncService: [START] Full sync for user: ${user.id}');
      
      await _cleanupLocalDuplicates(user.id);
      await syncCategories();
      await syncTransactions();
      
      print('SyncService: [SUCCESS] Sync session finished.');
    } catch (e, st) {
      print('SyncService: [CRITICAL ERROR] Sync session failed: $e');
      print(st);
    } finally {
      _isSyncing = false;
    }
  }

  Future<void> _cleanupLocalDuplicates(String userId) async {
    try {
      final allCats = await _db.getAllCategories(userId);
      if (allCats.isEmpty) return;

      final seenKeys = <String, Category>{};
      final idsToDelete = <int>[];

      for (final cat in allCats) {
        final key = '${cat.name.toLowerCase().trim()}_${cat.isIncome}';
        if (seenKeys.containsKey(key)) {
          idsToDelete.add(cat.id);
        } else {
          seenKeys[key] = cat;
        }
      }

      if (idsToDelete.isNotEmpty) {
        print('SyncService: Found ${idsToDelete.length} local duplicates. Cleaning up...');
        for (final id in idsToDelete) {
          await (_db.delete(_db.categories)..where((t) => t.id.equals(id))).go();
        }
        print('SyncService: Local cleanup completed.');
      }
    } catch (e) {
      print('SyncService: Local cleanup encountered an error: $e');
    }
  }

  Future<void> syncCategories() async {
    final user = SupabaseService.client.auth.currentUser;
    if (user == null) return;

    print('SyncService: Syncing categories...');

    // 1. Push local changes
    try {
      final unsynced = await _db.getUnsyncedCategories(user.id);
      if (unsynced.isNotEmpty) {
        print('SyncService: Pushing ${unsynced.length} unsynced categories to cloud.');
        for (final cat in unsynced) {
          // GÜNCELLEME: upsert içine remoteId'yi de ekliyoruz ve uuid üzerinden çakışmayı yönetiyoruz
          final response = await SupabaseService.client.from('categories').upsert({
            if (cat.remoteId != null) 'id': int.parse(cat.remoteId!),
            'uuid': cat.uuid,
            'name': cat.name,
            'icon_code': cat.iconCode,
            'color_value': cat.colorValue.toSigned(32),
            'is_income': cat.isIncome,
            'is_deleted': cat.isDeleted,
            'user_id': user.id,
          }, onConflict: 'uuid').select().single();

          await _db.updateCategoryRecord(cat.copyWith(
            remoteId: Value(response['id'].toString()),
            isSynced: true,
          ));
        }
      }
    } catch (e) {
      print('SyncService: Category push failed: $e');
    }

    // 2. Pull remote changes
    try {
      final remoteCats = await SupabaseService.client
          .from('categories')
          .select()
          .eq('user_id', user.id);

      print('SyncService: Remote check - Found ${remoteCats.length} categories on Supabase.');
      if (remoteCats.isEmpty) return;

      final localCats = await _db.getAllCategories(user.id);
      final existingKeys = localCats.map((c) => 
        '${c.name.toLowerCase().trim()}_${c.isIncome}'
      ).toSet();
      final existingUuids = localCats.map((c) => c.uuid).toSet();

      int restoredCount = 0;
      for (final rc in remoteCats) {
        if (rc['is_deleted'] == true) continue;

        final rcName = (rc['name'] ?? '').toString().toLowerCase().trim();
        if (rcName.isEmpty) continue;

        final rcIsIncome = rc['is_income'] as bool;
        final rcUuid = rc['uuid']?.toString() ?? '';
        final key = '${rcName}_$rcIsIncome';

        // Hem UUID hem isim bazlı kontrol
        if (existingUuids.contains(rcUuid)) continue;
        if (existingKeys.contains(key)) continue;

        print('SyncService: [PULL] Restoring unique category: ${rc['name']}');
        await _db.insertCategory(CategoriesCompanion.insert(
          uuid: rcUuid,
          userId: user.id,
          name: rc['name'].toString(),
          iconCode: rc['icon_code'] ?? 0,
          colorValue: (rc['color_value'] as int? ?? 0).toSigned(32),
          isIncome: rcIsIncome,
          isSynced: const Value(true),
          remoteId: Value(rc['id'].toString()),
        ));

        existingKeys.add(key);
        existingUuids.add(rcUuid);
        restoredCount++;
      }
      if (restoredCount > 0) print('SyncService: Restored $restoredCount categories from cloud.');
    } catch (e) {
      print('SyncService: Category pull failed: $e');
    }
  }

  Future<void> syncTransactions() async {
    final user = SupabaseService.client.auth.currentUser;
    if (user == null) return;

    print('SyncService: Syncing transactions...');

    // 1. Push
    try {
      final unsynced = await _db.getUnsyncedTransactions(user.id);
      if (unsynced.isNotEmpty) {
        print('SyncService: Pushing ${unsynced.length} transactions to cloud.');
        for (final tx in unsynced) {
          final response = await SupabaseService.client.from('transactions').upsert({
            if (tx.remoteId != null) 'id': int.parse(tx.remoteId!),
            'user_id': user.id,
            'amount': tx.amount,
            'category_id': tx.categoryId,
            'description': tx.description,
            'transaction_date': tx.date.toIso8601String(),
            'is_income': tx.isIncome,
          }).select().single();

          await _db.updateTransaction(tx.copyWith(
            remoteId: Value(response['id'].toString()),
            isSynced: true,
          ));
        }
      }
    } catch (e) {
      print('SyncService: Transaction push failed: $e');
    }

    // 2. Pull
    try {
      final remoteTxs = await SupabaseService.client
          .from('transactions')
          .select()
          .eq('user_id', user.id);

      print('SyncService: Remote check - Found ${remoteTxs.length} transactions on Supabase.');
      if (remoteTxs.isEmpty) return;

      final localTxs = await _db.getAllTransactions(user.id);
      final existingRemoteIds = localTxs.map((t) => t.remoteId).toSet();

      int restoredCount = 0;
      for (final rt in remoteTxs) {
        final rId = rt['id'].toString();
        if (existingRemoteIds.contains(rId)) continue;

        await _db.insertTransaction(TransactionsCompanion.insert(
          remoteId: Value(rId),
          userId: user.id,
          amount: (rt['amount'] as num? ?? 0.0).toDouble(),
          categoryId: Value(rt['category_id']?.toString() ?? ''),
          description: rt['description'] ?? '',
          date: DateTime.parse(rt['transaction_date'] ?? DateTime.now().toIso8601String()),
          isIncome: rt['is_income'] ?? false,
          isSynced: const Value(true),
        ));
        
        existingRemoteIds.add(rId);
        restoredCount++;
      }
      if (restoredCount > 0) print('SyncService: Restored $restoredCount transactions from cloud.');
    } catch (e) {
      print('SyncService: Transaction pull failed: $e');
    }
  }
}
