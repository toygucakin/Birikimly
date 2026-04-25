import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:birikimly/features/categories/domain/models/category_model.dart';
import 'package:birikimly/features/auth/presentation/providers/auth_provider.dart';
import 'package:birikimly/core/database/database.dart';
import 'package:drift/drift.dart' as drift;
import 'package:uuid/uuid.dart';
import 'package:birikimly/core/providers/preferences_provider.dart';

class CategoryNotifier extends Notifier<List<CategoryModel>> {
  @override
  List<CategoryModel> build() {
    _loadCategories();
    return _defaultCategories;
  }

  static final List<CategoryModel> _defaultCategories = [
    // GİDERLER
    CategoryModel(id: 'ex-1', name: 'Gıda & Market', icon: Icons.local_grocery_store, color: Colors.orange, isIncome: false),
    CategoryModel(id: 'ex-2', name: 'Ulaşım', icon: Icons.directions_car, color: Colors.blue, isIncome: false),
    CategoryModel(id: 'ex-3', name: 'Kira & Aidat', icon: Icons.home, color: Colors.brown, isIncome: false),
    CategoryModel(id: 'ex-4', name: 'Faturalar', icon: Icons.receipt_long, color: Colors.amber, isIncome: false),
    CategoryModel(id: 'ex-5', name: 'Alışveriş', icon: Icons.shopping_bag, color: Colors.pink, isIncome: false),
    CategoryModel(id: 'ex-6', name: 'Eğlence & Sosyal', icon: Icons.sports_esports, color: Colors.indigo, isIncome: false),
    CategoryModel(id: 'ex-7', name: 'Sağlık', icon: Icons.medical_services, color: Colors.red, isIncome: false),
    CategoryModel(id: 'ex-8', name: 'Eğitim', icon: Icons.school, color: Colors.deepPurple, isIncome: false),
    CategoryModel(id: 'ex-9', name: 'Yatırım', icon: Icons.savings, color: Colors.teal, isIncome: false),
    CategoryModel(id: 'ex-10', name: 'Diğer', icon: Icons.more_horiz, color: Colors.grey, isIncome: false),

    // GELİRLER
    CategoryModel(id: 'in-1', name: 'Maaş', icon: Icons.account_balance_wallet, color: Colors.green, isIncome: true),
    CategoryModel(id: 'in-2', name: 'Yan Gelir', icon: Icons.add_chart, color: Colors.teal, isIncome: true),
    CategoryModel(id: 'in-3', name: 'Burs & Harçlık', icon: Icons.payments, color: Colors.lightGreen, isIncome: true),
    CategoryModel(id: 'in-4', name: 'Yatırım Geliri', icon: Icons.trending_up, color: Colors.indigoAccent, isIncome: true),
  ];

  Future<void> _loadCategories() async {
    final user = ref.read(currentUserProvider);
    final isGuest = ref.read(guestModeProvider);
    
    if (user == null && !isGuest) return;
    
    final currentUserId = isGuest ? 'guest' : user!.id;
    final db = ref.read(databaseProvider);
    final dbCategories = await db.getAllCategories(currentUserId);

    if (dbCategories.isEmpty) {
      // Setup defaults in DB
      for (final cat in _defaultCategories) {
        await db.insertCategory(CategoriesCompanion.insert(
          uuid: cat.id,
          userId: currentUserId,
          name: cat.name,
          iconCode: cat.icon.codePoint,
          colorValue: cat.color.value,
          isIncome: cat.isIncome,
        ));
      }
      state = _defaultCategories;
    } else {
      state = dbCategories.map((c) => CategoryModel(
        id: c.uuid,
        name: c.name,
        icon: IconData(c.iconCode, fontFamily: 'MaterialIcons'),
        color: Color(c.colorValue),
        isIncome: c.isIncome,
      )).toList();
    }
  }

  Future<void> addCategory(String name, IconData icon, Color color, bool isIncome) async {
    final user = ref.read(currentUserProvider);
    final isGuest = ref.read(guestModeProvider);
    if (user == null && !isGuest) return;

    final currentUserId = isGuest ? 'guest' : user!.id;
    final uuid = const Uuid().v4();
    final newCategory = CategoryModel(
      id: uuid,
      name: name,
      icon: icon,
      color: color,
      isIncome: isIncome,
    );

    await ref.read(databaseProvider).insertCategory(CategoriesCompanion.insert(
      uuid: uuid,
      userId: currentUserId,
      name: name,
      iconCode: icon.codePoint,
      colorValue: color.value,
      isIncome: isIncome,
    ));

    state = [...state, newCategory];
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
    
    state = [
      for (final cat in state)
        if (cat.id == id)
          CategoryModel(
            id: cat.id, 
            name: name ?? cat.name, 
            icon: icon ?? cat.icon, 
            color: color ?? cat.color, 
            isIncome: cat.isIncome
          )
        else
          cat
    ];
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
    state = state.where((cat) => cat.id != id).toList();
  }
}

final categoryProvider = NotifierProvider<CategoryNotifier, List<CategoryModel>>(CategoryNotifier.new);
