import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:birikimly/features/categories/domain/models/category_model.dart';
import 'package:birikimly/core/database/database.dart';
import 'package:birikimly/features/auth/presentation/providers/auth_provider.dart';
import 'package:birikimly/core/providers/preferences_provider.dart';
import 'package:birikimly/core/services/sync_service.dart';
import 'package:uuid/uuid.dart';
import 'package:drift/drift.dart' as drift;

class CategoryNotifier extends StreamNotifier<List<CategoryModel>> {
  @override
  Stream<List<CategoryModel>> build() {
    final user = ref.watch(currentUserProvider);
    final isGuest = ref.watch(guestModeProvider);
    
    if (user == null && !isGuest) {
      return Stream.value([]);
    }

    final userId = isGuest ? 'guest' : user!.id;
    return ref.watch(databaseProvider).watchAllCategories(userId).map((list) {
      return list.map((c) => CategoryModel.fromDb(c)).toList();
    });
  }

  Future<void> addCategory({
    required String name,
    required IconData icon,
    required Color color,
    required bool isIncome,
  }) async {
    final user = ref.read(currentUserProvider);
    final isGuest = ref.read(guestModeProvider);
    if (user == null && !isGuest) return;

    final userId = isGuest ? 'guest' : user!.id;
    final uuid = const Uuid().v4();

    await ref.read(databaseProvider).insertCategory(CategoriesCompanion.insert(
      uuid: uuid,
      userId: userId,
      name: name,
      iconCode: icon.codePoint,
      colorValue: color.value,
      isIncome: isIncome,
      isSynced: const drift.Value(false),
    ));

    if (!isGuest) {
      ref.read(syncServiceProvider).syncAll();
    }
  }

  Future<void> updateCategory(String id, {String? name, IconData? icon, Color? color}) async {
    final user = ref.read(currentUserProvider);
    final isGuest = ref.read(guestModeProvider);
    if (user == null && !isGuest) return;

    final currentUserId = isGuest ? 'guest' : user!.id;
    final db = ref.read(databaseProvider);
    final dbList = await db.getAllCategories(currentUserId);
    final record = dbList.firstWhere((c) => c.uuid == id);

    final updatedRecord = record.copyWith(
      name: name ?? record.name,
      iconCode: icon?.codePoint ?? record.iconCode,
      colorValue: color?.value ?? record.colorValue,
      isSynced: false,
    );

    await db.updateCategoryRecord(updatedRecord);

    if (!isGuest) {
      ref.read(syncServiceProvider).syncAll();
    }
  }

  Future<void> removeCategory(String id) async {
    final user = ref.read(currentUserProvider);
    final isGuest = ref.read(guestModeProvider);
    if (user == null && !isGuest) return;

    final currentUserId = isGuest ? 'guest' : user!.id;
    final db = ref.read(databaseProvider);
    final dbList = await db.getAllCategories(currentUserId);
    final record = dbList.firstWhere((c) => c.uuid == id);

    await db.deleteCategoryRecord(record);

    if (!isGuest) {
      ref.read(syncServiceProvider).syncAll();
    }
  }
}

final categoryProvider = StreamNotifierProvider<CategoryNotifier, List<CategoryModel>>(CategoryNotifier.new);
