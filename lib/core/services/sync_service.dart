import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:drift/drift.dart';
import 'package:birikimly/core/database/database.dart';
import 'package:birikimly/core/services/supabase_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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
      await syncRecurringTransactions();
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
      final allCats = await _db.getAllCategoriesRaw(userId);
      if (allCats.isEmpty) return;

      final seenKeys = <String, Category>{};
      final idsToDelete = <int>[];

      final sortedCats = List<Category>.from(allCats)..sort((a, b) {
        int getPriority(Category c) {
          // 1: Kullanıcının manuel oluşturduğu aktif kategori (en değerli)
          if (!c.isDeleted && !c.uuid.startsWith('def_')) return 1;
          // 2: Kullanıcının bilerek sildiği kategori
          if (c.isDeleted) return 2;
          // 3: Sistemin otomatik ürettiği varsayılan kategori (en değersiz)
          return 3;
        }
        int cmp = getPriority(a).compareTo(getPriority(b));
        if (cmp == 0) {
          // Eğer öncelikler eşitse, daha yeni ekleneni (ID'si büyük olanı) koru
          return b.id.compareTo(a.id);
        }
        return cmp;
      });

      for (final cat in sortedCats) {
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

  Future<Map<String, dynamic>> _resilientUpsert(String table, Map<String, dynamic> data) async {
    Map<String, dynamic> currentData = Map.of(data);
    const maxRetries = 5;
    int attempt = 0;

    while (attempt < maxRetries) {
      try {
        return await SupabaseService.client.from(table).upsert(currentData).select().single();
      } catch (e) {
        attempt++;
        final errStr = e.toString();
        
        final match = RegExp(r"column ['""](\w+)['""]").firstMatch(errStr);
        if (match != null) {
          final columnName = match.group(1)!;
          
          if (!currentData.containsKey(columnName) && columnName != 'category_id' && columnName != 'transaction_date') {
             print('SyncService: RESILIENT PUSH ($table): Match "$columnName" not in payload. Trying generic removal...');
             // If we matched something like 'of' or 'relation', the regex is still too broad or error is different.
             // We'll throw to avoid infinite loop.
             rethrow;
          }

          print('SyncService: RESILIENT PUSH ($table): $columnName unsupported. Replacing or removing...');
          
          if (columnName == 'category_id' || columnName == 'category') {
            final val = currentData.remove('category_id') ?? currentData.remove('category');
            if (val != null) {
              final targetKey = columnName == 'category_id' ? 'category' : 'category_id';
              print('SyncService: Remapping category ID column');
              currentData[targetKey] = val.toString();
            }
          } else if (columnName == 'transaction_date' || columnName == 'date') {
            final val = currentData.remove('transaction_date') ?? currentData.remove('date');
            if (val != null) {
              final targetKey = columnName == 'transaction_date' ? 'date' : 'transaction_date';
              print('SyncService: Remapping date column');
              currentData[targetKey] = val;
            }
          } else if (columnName == 'uuid') {
            currentData.remove('uuid');
          } else if (columnName == 'is_deleted') {
            currentData.remove('is_deleted');
          } else {
            currentData.remove(columnName);
          }
          
          if (currentData.isEmpty) rethrow;
          continue;
        } else {
          print('SyncService: Upsert error for $table: $e');
          if (e is PostgrestException) {
            print('SyncService: Error Details: ${e.message} | ${e.details} | ${e.hint}');
            
            // If it's a foreign key or constraint error related to category, try stripping it
            final message = e.message.toLowerCase();
            final details = e.details?.toString().toLowerCase() ?? '';
            
            if ((message.contains('foreign key') || message.contains('constraint')) && 
                (message.contains('category') || details.contains('category'))) {
              print('SyncService: RESILIENT PUSH ($table): Category constraint error. Stripping category...');
              currentData.remove('category_id');
              currentData.remove('category');
              attempt++; // Count as an attempt
              if (currentData.isNotEmpty && attempt < maxRetries) continue;
            }
          }
          rethrow;
        }
      }
    }
    throw Exception('SyncService: Max retries exceeded for $table push');
  }

  Future<void> syncCategories() async {
    final user = SupabaseService.client.auth.currentUser;
    if (user == null) return;

    print('SyncService: Syncing categories...');

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
              // Ignore UUID check errors
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
            'order_index': cat.orderIndex,
            'user_id': user.id,
            'max_limit': cat.maxLimit,
          };

          try {
            final responseData = await _resilientUpsert('categories', data);
            await _db.updateCategoryRecord(cat.copyWith(
              remoteId: Value(responseData['id'].toString()),
              isSynced: true,
            ));
          } catch (e) {
            print('SyncService: Category individual push failed: $e');
          }
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

      final allLocalCats = await _db.getAllCategoriesRaw(user.id);
      final localByRemoteId = {for (var c in allLocalCats) if (c.remoteId != null) c.remoteId!: c};
      final localByUuid = {for (var c in allLocalCats) c.uuid: c};

      int restoredCount = 0;
      int updatedCount = 0;
      for (final rc in remoteCats) {
        final rId = rc['id'].toString();
        final rUuid = rc['uuid']?.toString() ?? '';
        final isRemoteDeleted = rc['is_deleted'] == true;

        final rcName = (rc['name'] ?? '').toString();
        if (rcName.trim().isEmpty) continue;

        final rcIsIncome = rc['is_income'] as bool;
        final rIconCode = rc['icon_code'] as int? ?? 0;
        final rColorValue = (rc['color_value'] as int? ?? 0).toSigned(32);
        final rOrderIndex = rc['order_index'] as int? ?? 0;
        final rMaxLimit = rc['max_limit'] != null ? (rc['max_limit'] as num).toDouble() : null;

        final localCat = localByRemoteId[rId] ?? (rUuid.isNotEmpty ? localByUuid[rUuid] : null);

        if (localCat != null) {
          if (localCat.isSynced) {
            // Eğer uzaktan gelen limit null ise ve lokalde bir limit varsa, lokaldeki limiti KORU!
            // Bu, Supabase'de limit kolonu eksik olduğunda veya boş döndüğünde limitlerin silinmesini engeller.
            final resolvedLimit = rMaxLimit ?? localCat.maxLimit;

            final hasChanged = localCat.name != rcName ||
                localCat.iconCode != rIconCode ||
                localCat.colorValue != rColorValue ||
                localCat.isIncome != rcIsIncome ||
                localCat.isDeleted != isRemoteDeleted ||
                localCat.orderIndex != rOrderIndex ||
                localCat.maxLimit != resolvedLimit ||
                localCat.remoteId != rId;

            if (hasChanged) {
              final updated = localCat.copyWith(
                remoteId: Value(rId),
                name: rcName,
                iconCode: rIconCode,
                colorValue: rColorValue,
                isIncome: rcIsIncome,
                isDeleted: isRemoteDeleted,
                orderIndex: rOrderIndex,
                maxLimit: Value(resolvedLimit),
                isSynced: true,
              );
              await _db.updateCategoryRecord(updated);
              updatedCount++;
            }
          }
        } else {
          print('SyncService: [PULL] Restoring unique newest category: $rcName');
          await _db.insertCategory(CategoriesCompanion.insert(
            uuid: rUuid,
            userId: user.id,
            name: rcName,
            iconCode: rIconCode,
            colorValue: rColorValue,
            isIncome: rcIsIncome,
            isSynced: const Value(true),
            remoteId: Value(rId),
            isDeleted: Value(isRemoteDeleted),
            orderIndex: Value(rOrderIndex),
            maxLimit: Value(rMaxLimit),
          ));
          restoredCount++;
        }
      }
      if (restoredCount > 0) print('SyncService: Restored $restoredCount unique categories.');
      if (updatedCount > 0) print('SyncService: Updated $updatedCount categories.');
    } catch (e) {
      print('SyncService: Category pull failed: $e');
    }
  }

  Future<void> syncRecurringTransactions() async {
    final user = SupabaseService.client.auth.currentUser;
    if (user == null) return;

    print('SyncService: Syncing recurring transactions...');
    try {
      final unsynced = await _db.getUnsyncedRecurringTransactions(user.id);
      if (unsynced.isNotEmpty) {
        print('SyncService: Pushing ${unsynced.length} recurring transactions to cloud.');
        for (final rt in unsynced) {
          String? remoteIdToUse = rt.remoteId;
          final data = {
            if (remoteIdToUse != null) 'id': remoteIdToUse,
            'uuid': rt.uuid,
            'user_id': user.id,
            'amount': rt.amount,
            'category_id': rt.categoryId,
            'description': rt.description,
            'start_date': rt.startDate.toUtc().toIso8601String(),
            'next_execution_date': rt.nextExecutionDate.toUtc().toIso8601String(),
            'is_income': rt.isIncome,
            'is_deleted': rt.isDeleted,
            'frequency': rt.frequency,
            'is_active': rt.isActive,
            'max_occurrences': rt.maxOccurrences,
            'occurrences_executed': rt.occurrencesExecuted,
          };
          try {
            final responseData = await _resilientUpsert('recurring_transactions', data);
            await _db.updateRecurringTransaction(rt.copyWith(
              remoteId: Value(responseData['id'].toString()),
              isSynced: true,
            ));
          } catch (e) {
            print('SyncService: Recurring transaction push failed: $e');
          }
        }
      }

      // Pull from server
      final remoteTxs = await SupabaseService.client
          .from('recurring_transactions')
          .select()
          .eq('user_id', user.id)
          .order('id', ascending: false);

      if (remoteTxs.isNotEmpty) {
        final localTxs = await _db.getAllRecurringTransactionsRaw(user.id);
        final localByRemoteId = {for (var t in localTxs) if (t.remoteId != null) t.remoteId!: t};
        final localByUuid = {for (var t in localTxs) t.uuid: t};
        
        int restored = 0;
        int updatedCount = 0;
        for (final rt in remoteTxs) {
          final rId = rt['id'].toString();
          final rUuid = rt['uuid']?.toString() ?? '';
          
          final localRt = localByRemoteId[rId] ?? (rUuid.isNotEmpty ? localByUuid[rUuid] : null);
          
          final rAmount = (rt['amount'] as num).toDouble();
          final rCategoryId = rt['category_id']?.toString();
          final rDescription = rt['description'] ?? '';
          final rStartDate = DateTime.parse(rt['start_date'] ?? DateTime.now().toIso8601String()).toLocal();
          final rNextExecutionDate = DateTime.parse(rt['next_execution_date'] ?? DateTime.now().toIso8601String()).toLocal();
          final rIsIncome = rt['is_income'] ?? false;
          final rIsDeleted = rt['is_deleted'] ?? false;
          final rFrequency = rt['frequency'] ?? 'monthly';
          final rIsActive = rt['is_active'] ?? true;
          final rMaxOccurrences = rt['max_occurrences'] as int? ?? 100;
          final rOccurrencesExecuted = rt['occurrences_executed'] as int? ?? 0;

          if (localRt != null) {
            // Update only if local is already synced (no unsynced local edits pending)
            if (localRt.isSynced) {
              final hasChanged = localRt.amount != rAmount ||
                  localRt.categoryId != rCategoryId ||
                  localRt.description != rDescription ||
                  localRt.startDate != rStartDate ||
                  localRt.nextExecutionDate != rNextExecutionDate ||
                  localRt.isIncome != rIsIncome ||
                  localRt.isDeleted != rIsDeleted ||
                  localRt.frequency != rFrequency ||
                  localRt.isActive != rIsActive ||
                  localRt.maxOccurrences != rMaxOccurrences ||
                  localRt.occurrencesExecuted != rOccurrencesExecuted ||
                  localRt.remoteId != rId;

              if (hasChanged) {
                final updated = localRt.copyWith(
                  remoteId: Value(rId),
                  amount: rAmount,
                  categoryId: Value(rCategoryId),
                  description: rDescription,
                  startDate: rStartDate,
                  nextExecutionDate: rNextExecutionDate,
                  isIncome: rIsIncome,
                  isDeleted: rIsDeleted,
                  frequency: rFrequency,
                  isActive: rIsActive,
                  maxOccurrences: rMaxOccurrences,
                  occurrencesExecuted: rOccurrencesExecuted,
                  isSynced: true,
                );
                await _db.updateRecurringTransaction(updated);
                updatedCount++;
              }
            }
          } else {
            final data = RecurringTransactionsCompanion(
              uuid: Value(rUuid),
              remoteId: Value(rId),
              userId: Value(user.id),
              amount: Value(rAmount),
              categoryId: Value(rCategoryId),
              description: Value(rDescription),
              startDate: Value(rStartDate),
              nextExecutionDate: Value(rNextExecutionDate),
              isIncome: Value(rIsIncome),
              isSynced: const Value(true),
              isDeleted: Value(rIsDeleted),
              frequency: Value(rFrequency),
              isActive: Value(rIsActive),
              maxOccurrences: Value(rMaxOccurrences),
              occurrencesExecuted: Value(rOccurrencesExecuted),
            );
            await _db.insertRecurringTransaction(data);
            restored++;
          }
        }
        if (restored > 0) print('SyncService: Restored $restored recurring transactions from cloud.');
        if (updatedCount > 0) print('SyncService: Updated $updatedCount recurring transactions from cloud.');
      }
    } catch (e) {
      print('SyncService: Recurring transaction sync failed: $e');
    }
  }

Future<void> syncTransactions() async {
    final user = SupabaseService.client.auth.currentUser;
    if (user == null) return;

    print('SyncService: Syncing transactions...');

    try {
      final unsynced = await _db.getUnsyncedTransactions(user.id);
      if (unsynced.isNotEmpty) {
        print('SyncService: Pushing ${unsynced.length} transactions to cloud.');
        for (final tx in unsynced) {
          String? remoteIdToUse = tx.remoteId;

          if (tx.isDeleted) {
            if (remoteIdToUse != null) {
              try {
                await SupabaseService.client
                    .from('transactions')
                    .delete()
                    .eq('id', remoteIdToUse);
              } catch (e) {
                print('SyncService: Transaction delete failed: $e');
              }
            }
            await _db.updateTransaction(tx.copyWith(isSynced: true));
            continue;
          }

          final data = {
            if (remoteIdToUse != null) 'id': remoteIdToUse,
            'uuid': tx.uuid,
            'user_id': user.id,
            'amount': tx.amount,
            'category': tx.categoryId,
            'description': tx.description,
            'date': tx.date.toUtc().toIso8601String(),
            'is_income': tx.isIncome,
            if (tx.recurringUuid != null) 'recurring_uuid': tx.recurringUuid,
            'installment_number': tx.installmentNumber,
            'total_installments': tx.totalInstallments,
          };

          try {
            final responseData = await _resilientUpsert('transactions', data);
            await _db.updateTransaction(tx.copyWith(
              remoteId: Value(responseData['id'].toString()),
              isSynced: true,
            ));
          } catch (e) {
            print('SyncService: Transaction individual push failed: $e');
          }
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

      final localTxs = await _db.getAllTransactionsRaw(user.id);
      final localByRemoteId = {for (var t in localTxs) if (t.remoteId != null) t.remoteId!: t};
      final localByUuid = {for (var t in localTxs) t.uuid: t};

      int restoredCount = 0;
      int updatedCount = 0;
      for (final rt in remoteTxs) {
        final rId = rt['id'].toString();
        final rUuid = rt['uuid']?.toString() ?? '';
        final isRemoteDeleted = rt['is_deleted'] == true;

        final localTx = localByRemoteId[rId] ?? (rUuid.isNotEmpty ? localByUuid[rUuid] : null);

        final rAmount = (rt['amount'] as num? ?? 0.0).toDouble();
        final rCategoryId = (rt['category_id'] ?? rt['category'] ?? rt['categoryId'] ?? '').toString();
        final rDescription = rt['description'] ?? '';
        final rDate = DateTime.parse(rt['transaction_date'] ?? rt['date'] ?? DateTime.now().toIso8601String()).toLocal();
        final rIsIncome = rt['is_income'] ?? false;
        final rRecurringUuid = rt['recurring_uuid']?.toString();
        final rInstallmentNumber = rt['installment_number'] as int?;
        final rTotalInstallments = rt['total_installments'] as int?;

        if (localTx != null) {
          if (localTx.isSynced) {
            final hasChanged = localTx.amount != rAmount ||
                localTx.categoryId != rCategoryId ||
                localTx.description != rDescription ||
                localTx.date != rDate ||
                localTx.isIncome != rIsIncome ||
                localTx.isDeleted != isRemoteDeleted ||
                localTx.recurringUuid != rRecurringUuid ||
                localTx.installmentNumber != rInstallmentNumber ||
                localTx.totalInstallments != rTotalInstallments ||
                localTx.remoteId != rId;

            if (hasChanged) {
              final updated = localTx.copyWith(
                remoteId: Value(rId),
                amount: rAmount,
                categoryId: Value(rCategoryId),
                description: rDescription,
                date: rDate,
                isIncome: rIsIncome,
                isDeleted: isRemoteDeleted,
                recurringUuid: Value(rRecurringUuid),
                installmentNumber: Value(rInstallmentNumber),
                totalInstallments: Value(rTotalInstallments),
                isSynced: true,
              );
              await _db.updateTransaction(updated);
              updatedCount++;
            }
          }
        } else {
          print('SyncService: [PULL] Restoring transaction: $rDescription (Resolved Cat: $rCategoryId)');
          await _db.insertTransaction(TransactionsCompanion.insert(
            remoteId: Value(rId),
            uuid: Value(rUuid),
            userId: user.id,
            amount: rAmount,
            categoryId: Value(rCategoryId),
            description: rDescription,
            date: rDate,
            isIncome: rIsIncome,
            isSynced: const Value(true),
            isDeleted: Value(isRemoteDeleted),
            recurringUuid: Value(rRecurringUuid),
            installmentNumber: Value(rInstallmentNumber),
            totalInstallments: Value(rTotalInstallments),
          ));
          restoredCount++;
        }
      }

      // Cleanup local transactions that were deleted from Supabase (server is ground truth)
      final remoteIdsInServer = remoteTxs.map((rt) => rt['id'].toString()).toSet();
      int deletedCount = 0;
      for (final localTx in localTxs) {
        if (localTx.isSynced && !localTx.isDeleted && localTx.remoteId != null && !remoteIdsInServer.contains(localTx.remoteId)) {
          print('SyncService: Local transaction ${localTx.description} was deleted on server. Deleting locally...');
          await (_db.update(_db.transactions)..where((t) => t.id.equals(localTx.id)))
              .write(const TransactionsCompanion(isDeleted: Value(true), isSynced: Value(true)));
          deletedCount++;
        }
      }

      if (restoredCount > 0) print('SyncService: Restored $restoredCount transactions from cloud.');
      if (updatedCount > 0) print('SyncService: Updated $updatedCount transactions from cloud.');
      if (deletedCount > 0) print('SyncService: Deleted $deletedCount local transactions.');
    } catch (e) {
      print('SyncService: Transaction pull failed: $e');
    }
  }
  Future<void> _normalizeTransactionCategories(String userId) async {
    try {
      final txs = await _db.getTransactionsNeedingNormalization(userId);
      if (txs.isEmpty) return;
      final cats = await _db.getAllCategoriesRaw(userId);

      for (final tx in txs) {
        final rawId = tx.categoryId ?? '';
        if (rawId.isEmpty) continue;

        // 1. Durum: ID 'temp_' veya legacy 'in-'/'ex-' ile başlıyorsa düzelt
        if (rawId.startsWith('temp_') || rawId.startsWith('in-') || rawId.startsWith('ex-')) {
          String newId = rawId;
          if (rawId.startsWith('temp_')) {
            newId = rawId.replaceFirst('temp_', 'def_');
          } else if (rawId.startsWith('in-')) {
            // Legacy in-1, in-2 mapping -> def_...
            final index = int.tryParse(rawId.split('-').last);
            if (index != null && index >= 1 && index <= 5) {
              final names = ['Maaş', 'Yan Gelir', 'Kira Geliri', 'Yatırım Geliri', 'Burs & Harçlık'];
              newId = 'def_${names[index - 1].toLowerCase().replaceAll(' ', '_')}';
            }
          } else if (rawId.startsWith('ex-')) {
            // Legacy ex-1, ex-2 mapping -> def_...
            final index = int.tryParse(rawId.split('-').last);
            final names = [
              'Gıda & Market', 'Yiyecek & İçecek', 'Ulaşım', 'Kira & Aidat', 'Faturalar',
              'Abonelikler', 'Kredi Kartı', 'Giyim', 'Alışveriş', 'Dekorasyon',
              'Spor', 'Eğlence', 'Eğitim', 'Sağlık', 'Yatırım'
            ];
            if (index != null && index >= 1 && index <= names.length) {
              newId = 'def_${names[index - 1].toLowerCase().replaceAll(' ', '_')}';
            }
          }

          if (cats.any((c) => c.uuid == newId)) {
            await _db.updateTransaction(tx.copyWith(categoryId: Value(newId), isSynced: false));
          }
        } 
        // 2. Durum: ID bir isim ise
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
