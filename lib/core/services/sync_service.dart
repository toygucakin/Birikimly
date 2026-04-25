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
        print('SyncService: Network detected, running sync...');
        syncAll();
      }
    });
    // Run sync on start
    syncAll();
  }

  void stop() {
    print('SyncService: Stopping...');
    _connectivitySubscription?.cancel();
  }

  Future<void> syncAll() async {
    if (_isSyncing) return;
    _isSyncing = true;

    try {
      final user = SupabaseService.client.auth.currentUser;
      if (user == null) {
        print('SyncService: No active user, skipping sync.');
        return;
      }
      
      print('SyncService: Running full sync for ${user.id}...');
      
      // 0. KRİTİK: Mevcut yerel mükerrerleri temizle
      await _cleanupLocalDuplicates(user.id);
      
      await syncCategories();
      await syncTransactions();
      print('SyncService: Sync finished.');
    } catch (e) {
      print('SyncService: Sync failed: $e');
    } finally {
      _isSyncing = false;
    }
  }

  /// Mevcut veritabanındaki aynı isimli mükerrer kategorileri temizler.
  Future<void> _cleanupLocalDuplicates(String userId) async {
    try {
      final allCats = await _db.getAllCategories(userId);
      final seenKeys = <String, Category>{};
      final idsToDelete = <int>[];

      for (final cat in allCats) {
        final key = '${cat.name.toLowerCase().trim()}_${cat.isIncome}';
        if (seenKeys.containsKey(key)) {
          // Bu isimde zaten bir tane tuttuk, bunu silebiliriz
          idsToDelete.add(cat.id);
        } else {
          seenKeys[key] = cat;
        }
      }

      if (idsToDelete.isNotEmpty) {
        print('SyncService: Cleaning up ${idsToDelete.length} local local duplicates...');
        // Drift üzerinden toplu silme işlemi (is_deleted: true değil, direkt DB'den kaldırma)
        for (final id in idsToDelete) {
          await (_db.delete(_db.categories)..where((t) => t.id.equals(id))).go();
        }
      }
    } catch (e) {
      print('SyncService: Local cleanup error: $e');
    }
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
          'color_value': cat.colorValue.toSigned(32),
          'is_income': cat.isIncome,
          'is_deleted': cat.isDeleted,
          'user_id': user.id,
        }).select().single();

        await _db.updateCategoryRecord(cat.copyWith(
          remoteId: Value(response['id'].toString()),
          isSynced: true,
        ));
      } catch (e) {
        print('SyncService: Category push error (${cat.name}): $e');
      }
    }

    // 2. Pull remote changes
    try {
      final remoteCats = await SupabaseService.client
          .from('categories')
          .select()
          .eq('user_id', user.id);

      if (remoteCats.isEmpty) return;
      print('SyncService: Pulled ${remoteCats.length} remote categories.');

      // Mevcut yerel kategorileri çekelim
      final localCats = await _db.getAllCategories(user.id);
      final existingKeys = localCats.map((c) => 
        '${c.name.toLowerCase().trim()}_${c.isIncome}'
      ).toSet();
      final existingUuids = localCats.map((c) => c.uuid).toSet();

      for (final rc in remoteCats) {
        if (rc['is_deleted'] == true) continue;

        final rcName = rc['name'].toString().toLowerCase().trim();
        final rcIsIncome = rc['is_income'] as bool;
        final rcUuid = rc['uuid'].toString();
        final key = '${rcName}_$rcIsIncome';

        // Hem UUID hem isim bazlı kontrol
        if (existingUuids.contains(rcUuid) || existingKeys.contains(key)) {
          continue;
        }

        print('SyncService: Restoring unique category $rcName');
        await _db.insertCategory(CategoriesCompanion.insert(
          uuid: rcUuid,
          userId: user.id,
          name: rc['name'],
          iconCode: rc['icon_code'],
          colorValue: (rc['color_value'] as int).toSigned(32),
          isIncome: rcIsIncome,
          isSynced: const Value(true),
          remoteId: Value(rc['id'].toString()),
        ));

        existingKeys.add(key);
        existingUuids.add(rcUuid);
      }
    } catch (e) {
      print('SyncService: Category pull error: $e');
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
      } catch (e) {
        print('SyncService: Transaction push error: $e');
      }
    }

    // 2. Pull remote changes
    try {
      final remoteTxs = await SupabaseService.client
          .from('transactions')
          .select()
          .eq('user_id', user.id);

      if (remoteTxs.isEmpty) return;
      print('SyncService: Pulled ${remoteTxs.length} remote transactions.');

      final localTxs = await _db.getAllTransactions(user.id);
      final existingRemoteIds = localTxs.map((t) => t.remoteId).toSet();

      for (final rt in remoteTxs) {
        final rId = rt['id'].toString();
        if (existingRemoteIds.contains(rId)) continue;

        await _db.insertTransaction(TransactionsCompanion.insert(
          remoteId: Value(rId),
          userId: user.id,
          amount: (rt['amount'] as num).toDouble(),
          categoryId: Value(rt['category_id']),
          description: rt['description'] ?? '',
          date: DateTime.parse(rt['transaction_date']),
          isIncome: rt['is_income'],
          isSynced: const Value(true),
        ));
        
        existingRemoteIds.add(rId);
      }
    } catch (e) {
      print('SyncService: Transaction pull error: $e');
    }
  }
}
