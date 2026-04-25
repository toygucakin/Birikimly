import 'dart:io';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:birikimly/core/services/sync_service.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

part 'database.g.dart';

class Transactions extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get remoteId => text().nullable()();
  TextColumn get userId => text()();
  RealColumn get amount => real()();
  // Using .named('category') to fall back to the old column name while keeping the new logic
  TextColumn get categoryId => text().nullable().named('category')(); 
  TextColumn get description => text()();
  DateTimeColumn get date => dateTime()();
  BoolColumn get isIncome => boolean()();
  BoolColumn get isSynced => boolean().withDefault(const Constant(false))();
}

class Categories extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get uuid => text()(); 
  TextColumn get remoteId => text().nullable()();
  TextColumn get userId => text()();
  TextColumn get name => text()();
  IntColumn get iconCode => integer()();
  IntColumn get colorValue => integer()();
  BoolColumn get isIncome => boolean()();
  BoolColumn get isSynced => boolean().withDefault(const Constant(false))();
  BoolColumn get isDeleted => boolean().withDefault(const Constant(false))();
}

@DriftDatabase(tables: [Transactions, Categories])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  @override
  int get schemaVersion => 8; // Version 8: Backward compatibility bridge

  @override
  MigrationStrategy get migration {
    return MigrationStrategy(
      onCreate: (Migrator m) async {
        await m.createAll();
      },
      onUpgrade: (Migrator m, int from, int to) async {
        // v8: Cleanup and ensure compatibility
        if (from < 3) {
          try { await m.createTable(categories); } catch (_) {}
        }
        if (from < 2) {
          try { await m.addColumn(transactions, transactions.userId); } catch (_) {}
        }
        
        // No more ALTER TABLE needed since we're using the old column name 'category'
      },
    );
  }

  // Transaction CRUD
  Future<List<Transaction>> getAllTransactions(String userId) => 
    (select(transactions)..where((t) => t.userId.equals(userId))).get();
  
  Stream<List<Transaction>> watchAllTransactions(String userId) {
    return (select(transactions)
      ..where((t) => t.userId.equals(userId))
      ..orderBy([
        (t) => OrderingTerm(expression: t.date, mode: OrderingMode.desc),
        (t) => OrderingTerm(expression: t.id, mode: OrderingMode.desc),
      ]))
      .watch();
  }

  Future<int> insertTransaction(TransactionsCompanion entry) => 
    into(transactions).insert(entry);

  Future updateTransaction(Transaction entry) => 
    update(transactions).replace(entry);

  Future deleteTransaction(Transaction entry) => 
    delete(transactions).delete(entry);

  Future<List<Transaction>> getUnsyncedTransactions(String userId) => 
    (select(transactions)
      ..where((t) => t.isSynced.equals(false) & t.userId.equals(userId)))
      .get();

  // Category CRUD
  Future<List<Category>> getAllCategories(String userId) => 
    (select(categories)..where((c) => c.userId.equals(userId) & c.isDeleted.equals(false))).get();

  Future<int> insertCategory(CategoriesCompanion entry) => 
    into(categories).insert(entry);

  Future updateCategoryRecord(Category entry) => 
    update(categories).replace(entry);

  Future deleteCategoryRecord(Category entry) => 
    update(categories).replace(entry.copyWith(isDeleted: true, isSynced: false));

  Future<List<Category>> getUnsyncedCategories(String userId) => 
    (select(categories)
      ..where((c) => c.isSynced.equals(false) & c.userId.equals(userId)))
      .get();
}

final databaseProvider = Provider<AppDatabase>((ref) => AppDatabase());

final syncServiceProvider = Provider<SyncService>((ref) {
  final db = ref.watch(databaseProvider);
  return SyncService(db);
});

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dbFolder = await getApplicationDocumentsDirectory();
    final file = File(p.join(dbFolder.path, 'birikimly.sqlite'));
    return NativeDatabase(file);
  });
}
