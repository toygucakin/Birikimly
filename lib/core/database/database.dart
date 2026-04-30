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
  TextColumn get uuid => text().withDefault(const Constant(''))();
  TextColumn get remoteId => text().nullable()();
  TextColumn get userId => text()();
  RealColumn get amount => real()();
  TextColumn get categoryId => text().nullable().named('category')(); 
  TextColumn get description => text()();
  DateTimeColumn get date => dateTime()();
  BoolColumn get isIncome => boolean()();
  BoolColumn get isSynced => boolean().withDefault(const Constant(false))();
  BoolColumn get isDeleted => boolean().withDefault(const Constant(false))();
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
  IntColumn get orderIndex => integer().withDefault(const Constant(0))();
  BoolColumn get isSynced => boolean().withDefault(const Constant(false))();
  BoolColumn get isDeleted => boolean().withDefault(const Constant(false))();
}

@DriftDatabase(tables: [Transactions, Categories])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  @override
  int get schemaVersion => 11;

  @override
  MigrationStrategy get migration {
    return MigrationStrategy(
      onUpgrade: (m, from, to) async {
        if (from < 8) {
          await m.addColumn(transactions, transactions.categoryId);
        }
        if (from < 9) {
          await m.addColumn(transactions, transactions.uuid);
        }
        if (from < 10) {
          await m.addColumn(transactions, transactions.isDeleted);
          await m.addColumn(categories, categories.isDeleted);
        }
        if (from < 11) {
          await m.addColumn(categories, categories.orderIndex);
        }
      },
      beforeOpen: (details) async {
        await customStatement('PRAGMA foreign_keys = ON');
      },
    );
  }

  // Categories Queries
  Stream<List<Category>> watchAllCategories(String userId) {
    return (select(categories)
      ..where((c) => c.userId.equals(userId) & c.isDeleted.equals(false))
      ..orderBy([(c) => OrderingTerm(expression: c.orderIndex, mode: OrderingMode.asc)])
    ).watch();
  }

  Future<List<Category>> getAllCategories(String userId) => 
    (select(categories)..where((c) => c.userId.equals(userId) & c.isDeleted.equals(false))).get();

  Future<List<Category>> getAllCategoriesRaw(String userId) => 
    (select(categories)..where((c) => c.userId.equals(userId))).get();

  Future<int> insertCategory(CategoriesCompanion entry) => into(categories).insert(entry);
  
  Future<bool> updateCategoryRecord(Category category) => update(categories).replace(category);
  
  Future<int> deleteCategoryRecord(Category category) => 
    (update(categories)..where((t) => t.id.equals(category.id))).write(const CategoriesCompanion(isDeleted: Value(true), isSynced: Value(false)));

  Future<List<Category>> getUnsyncedCategories(String userId) => 
    (select(categories)..where((c) => c.userId.equals(userId) & c.isSynced.equals(false))).get();

  // Transactions Queries
  Stream<List<Transaction>> watchAllTransactions(String userId, {int? limitCount}) {
    final query = select(transactions)
      ..where((t) => t.userId.equals(userId) & t.isDeleted.equals(false))
      ..orderBy([
        (t) => OrderingTerm(expression: t.date, mode: OrderingMode.desc),
        (t) => OrderingTerm(expression: t.id, mode: OrderingMode.desc),
      ]);
    
    if (limitCount != null) {
      query.limit(limitCount);
    }
    
    return query.watch();
  }

  Future<List<Transaction>> getAllTransactions(String userId) => 
    (select(transactions)..where((t) => t.userId.equals(userId) & t.isDeleted.equals(false))).get();

  Future<List<Transaction>> getAllTransactionsRaw(String userId) => 
    (select(transactions)..where((t) => t.userId.equals(userId))).get();

  Future<int> insertTransaction(TransactionsCompanion entry) => into(transactions).insert(entry);
  
  Future<bool> updateTransaction(Transaction transaction) => 
    update(transactions).replace(transaction);
  
  Future<int> deleteTransaction(Transaction transaction) => 
    (update(transactions)..where((t) => t.id.equals(transaction.id)))
        .write(const TransactionsCompanion(isDeleted: Value(true), isSynced: Value(false)));

  Future<List<Transaction>> getUnsyncedTransactions(String userId) => 
    (select(transactions)..where((t) => t.userId.equals(userId) & t.isSynced.equals(false))).get();
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dbFolder = await getApplicationDocumentsDirectory();
    final file = File(p.join(dbFolder.path, 'db.sqlite'));
    return NativeDatabase(file);
  });
}

final databaseProvider = Provider<AppDatabase>((ref) => AppDatabase());

final syncServiceProvider = Provider<SyncService>((ref) {
  final db = ref.watch(databaseProvider);
  return SyncService(db);
});
