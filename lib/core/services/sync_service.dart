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
      await _normalizeTransactionCategories(user.id);
      
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
          final toDelete = allCats.firstWhere((c) => c.id == id);
          final key = '${toDelete.name.toLowerCase().trim()}_${toDelete.isIncome}';
          final kept = seenKeys[key]!;

          // ÖNEMLİ: Bu kategoriyi kullanan işlemleri güncelle
          await (_db.update(_db.transactions)..where((t) => t.categoryId.equals(toDelete.uuid)))
              .write(TransactionsCompanion(categoryId: Value(kept.uuid)));

          await (_db.delete(_db.categories)..where((t) => t.id.equals(id))).go();
        }
      }
    } catch (e) {
      print('SyncService: Local cleanup encountered an error: $e');
    }
  }

  Future<void> syncCategories() async {
    final user = SupabaseService.client.auth.currentUser;
    if (user == null) return;

    print('SyncService: Syncing categories...');

    // 1. Push
    try {
      final unsynced = await _db.getUnsyncedCategories(user.id);
      if (unsynced.isNotEmpty) {
        print('SyncService: Pushing ${unsynced.length} changes to cloud.');
        for (final cat in unsynced) {
          String? remoteIdToUse = cat.remoteId;

          if (remoteIdToUse == null) {
            try {
              final existing = await SupabaseService.client
                  .from('categories')
                  .select('id')
                  .eq('uuid', cat.uuid)
                  .maybeSingle();
              
              if (existing != null) {
                remoteIdToUse = existing['id'].toString();
              }
            } catch (e) {
              print('SyncService: Category UUID check failed: $e');
            }
          }

          final data = {
            if (remoteIdToUse != null) 'id': int.parse(remoteIdToUse),
            'uuid': cat.uuid,
            'name': cat.name,
            'icon_code': cat.iconCode,
            'color_value': cat.colorValue.toSigned(32),
            'is_income': cat.isIncome,
            'is_deleted': cat.isDeleted,
            'user_id': user.id,
          };

          Map<String, dynamic> responseData;
          try {
            responseData = await SupabaseService.client.from('categories').upsert(data).select().single();
          } catch (e) {
            final errorStr = e.toString().toLowerCase();
            if (errorStr.contains('uuid') && errorStr.contains('not exist')) {
              print('SyncService: RETRYING CATEGORY PUSH without uuid column...');
              data.remove('uuid');
              responseData = await SupabaseService.client.from('categories').upsert(data).select().single();
            } else {
              print('SyncService: Category individual push failed: $e');
              continue;
            }
          }

          await _db.updateCategoryRecord(cat.copyWith(
            remoteId: Value(responseData['id'].toString()),
            isSynced: true,
          ));
        }
      }
    } catch (e) {
      print('SyncService: Category push failed: $e');
    }

    // 2. Pull
    try {
      final List<dynamic> remoteCats = await SupabaseService.client
          .from('categories')
          .select()
          .eq('user_id', user.id)
          .order('id', ascending: false);

      if (remoteCats.isEmpty) return;

      final allLocalCats = await (
        _db.select(_db.categories)..where((c) => c.userId.equals(user.id))
      ).get();

      final existingKeys = allLocalCats.map((c) => 
        '${c.name.toLowerCase().trim()}_${c.isIncome}'
      ).toSet();
      final existingUuids = allLocalCats.map((c) => c.uuid).toSet();

      int restoredCount = 0;
      for (final rc in remoteCats) {
        if (rc['is_deleted'] == true) continue;

        final rcName = (rc['name'] ?? '').toString().toLowerCase().trim();
        if (rcName.isEmpty) continue;

        final rcIsIncome = rc['is_income'] as bool;
        final rcUuid = rc['uuid']?.toString() ?? '';
        final key = '${rcName}_$rcIsIncome';

        if (existingUuids.contains(rcUuid) || existingKeys.contains(key)) {
          continue;
        }

        print('SyncService: [PULL] Restoring unique newest category: ${rc['name']}');
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
      if (restoredCount > 0) print('SyncService: Restored $restoredCount unique categories.');
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
          String? remoteIdToUse = tx.remoteId;

          // UUID ile bulut kontrolü yapalım (Duplicate önlemek için)
          if (remoteIdToUse == null && tx.uuid.isNotEmpty) {
            try {
              final existing = await SupabaseService.client
                  .from('transactions')
                  .select('id')
                  .eq('uuid', tx.uuid)
                  .maybeSingle();
              
              if (existing != null) {
                remoteIdToUse = existing['id'].toString();
              }
            } catch (e) {
              print('SyncService: UUID check failed (likely column missing): $e');
            }
          }

          final data = {
            if (remoteIdToUse != null) 'id': int.parse(remoteIdToUse),
            'uuid': tx.uuid,
            'user_id': user.id,
            'amount': tx.amount,
            if (tx.categoryId != null) 'category_id': tx.categoryId,
            'description': tx.description,
            'transaction_date': tx.date.toIso8601String(),
            'is_income': tx.isIncome,
          };

          Map<String, dynamic> responseData;
          try {
            responseData = await SupabaseService.client.from('transactions').upsert(data).select().single();
          } catch (e) {
            final errorStr = e.toString().toLowerCase();
            if (errorStr.contains('uuid') && errorStr.contains('not exist')) {
              print('SyncService: RETRYING PUSH without uuid column...');
              data.remove('uuid');
              responseData = await SupabaseService.client.from('transactions').upsert(data).select().single();
            } else {
              print('SyncService: Transaction individual push failed: $e');
              continue;
            }
          }

          await _db.updateTransaction(tx.copyWith(
            remoteId: Value(responseData['id'].toString()),
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
          .eq('user_id', user.id)
          .order('id', ascending: false);

      if (remoteTxs.isEmpty) return;

      final localTxs = await _db.getAllTransactions(user.id);
      final existingRemoteIds = localTxs.map((t) => t.remoteId).toSet();
      final existingUuids = localTxs.map((t) => t.uuid).toSet();

      int restoredCount = 0;
      for (final rt in remoteTxs) {
        final rId = rt['id'].toString();
        final rUuid = rt['uuid']?.toString() ?? '';

        if (existingRemoteIds.contains(rId)) continue;
        if (rUuid.isNotEmpty && existingUuids.contains(rUuid)) continue;

        final remoteCatId = (rt['category_id'] ?? rt['category'] ?? rt['categoryId'] ?? '').toString();
        print('SyncService: [PULL] Restoring transaction: ${rt['description']} (Resolved Cat: $remoteCatId)');
        
        await _db.insertTransaction(TransactionsCompanion.insert(
          remoteId: Value(rId),
          uuid: Value(rUuid),
          userId: user.id,
          amount: (rt['amount'] as num? ?? 0.0).toDouble(),
          categoryId: Value(remoteCatId),
          description: rt['description'] ?? '',
          date: DateTime.parse(rt['transaction_date'] ?? DateTime.now().toIso8601String()),
          isIncome: rt['is_income'] ?? false,
          isSynced: const Value(true),
        ));
        
        existingRemoteIds.add(rId);
        if (rUuid.isNotEmpty) existingUuids.add(rUuid);
        restoredCount++;
      }
      if (restoredCount > 0) print('SyncService: Restored $restoredCount transactions from cloud.');
    } catch (e) {
      print('SyncService: Transaction pull failed: $e');
    }
  }
  Future<void> _normalizeTransactionCategories(String userId) async {
    try {
      final txs = await _db.getAllTransactions(userId);
      final cats = await _db.getAllCategories(userId);

      for (final tx in txs) {
        final rawId = tx.categoryId ?? '';
        if (rawId.isEmpty) continue;

        // 1. Durum: ID 'temp_' ile başlıyorsa 'def_'e çevir
        if (rawId.startsWith('temp_')) {
          final newId = rawId.replaceFirst('temp_', 'def_');
          if (cats.any((c) => c.uuid == newId)) {
            await _db.updateTransaction(tx.copyWith(categoryId: Value(newId), isSynced: false));
          }
        } 
        // 2. Durum: ID bir isim ise (Eski versiyonlarda isim kaydedilmiş olabilir)
        else if (!rawId.contains('-') && !rawId.startsWith('def_')) {
          final matchedCat = cats.cast<Category?>().firstWhere(
            (c) => c?.name.toLowerCase().trim() == rawId.toLowerCase().trim(),
            orElse: () => null,
          );
          if (matchedCat != null) {
            await _db.updateTransaction(tx.copyWith(categoryId: Value(matchedCat.uuid), isSynced: false));
          }
        }
      }
    } catch (e) {
      print('SyncService: Normalization failed: $e');
    }
  }
}
