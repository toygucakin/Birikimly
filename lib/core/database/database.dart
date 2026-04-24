import 'dart:io';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

part 'database.g.dart';

class Transactions extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get remoteId => text().nullable()();
  TextColumn get userId => text()(); // Added for Auth
  RealColumn get amount => real()();
  TextColumn get category => text()();
  TextColumn get description => text()();
  DateTimeColumn get date => dateTime()();
  BoolColumn get isIncome => boolean()();
  BoolColumn get isSynced => boolean().withDefault(const Constant(false))();
}

@DriftDatabase(tables: [Transactions])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  @override
  int get schemaVersion => 2;

  @override
  MigrationStrategy get migration {
    return MigrationStrategy(
      onCreate: (Migrator m) async {
        await m.createAll();
      },
      onUpgrade: (Migrator m, int from, int to) async {
        if (from < 2) {
          await m.addColumn(transactions, transactions.userId);
        }
      },
    );
  }

  // CRUD Operations
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
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dbFolder = await getApplicationDocumentsDirectory();
    final file = File(p.join(dbFolder.path, 'birikimly.sqlite'));
    return NativeDatabase(file);
  });
}
