import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:birikimly/features/categories/domain/models/category_model.dart';
import 'package:birikimly/core/database/database.dart';
import 'package:birikimly/features/auth/presentation/providers/auth_provider.dart';
import 'package:birikimly/core/providers/preferences_provider.dart';
import 'package:birikimly/core/services/sync_service.dart';
import 'package:birikimly/core/services/supabase_service.dart';
import 'package:uuid/uuid.dart';
import 'package:drift/drift.dart' as drift;

class CategoryNotifier extends StreamNotifier<List<CategoryModel>> {
  bool _isInitializing = false;

  // Varsayılan kategoriler listesi (Hafızada tutulup anında döndürülmek üzere)
  static final List<Map<String, dynamic>> _staticDefaults = [
    // Gelirler
    {'name': 'Maaş', 'icon': Icons.payments, 'color': Colors.green, 'income': true},
    {'name': 'Yan Gelir', 'icon': Icons.add_card, 'color': Colors.teal, 'income': true},
    {'name': 'Kira Geliri', 'icon': Icons.apartment, 'color': Colors.amber, 'income': true},
    {'name': 'Yatırım Geliri', 'icon': Icons.trending_up, 'color': Colors.blue, 'income': true},
    {'name': 'Burs & Harçlık', 'icon': Icons.school, 'color': Colors.indigo, 'income': true},
    // Giderler
    {'name': 'Gıda & Market', 'icon': Icons.shopping_basket, 'color': Colors.orange, 'income': false},
    {'name': 'Yiyecek & İçecek', 'icon': Icons.restaurant, 'color': Colors.deepOrange, 'income': false},
    {'name': 'Ulaşım', 'icon': Icons.directions_bus, 'color': Colors.blue, 'income': false},
    {'name': 'Kira & Aidat', 'icon': Icons.home, 'color': Colors.brown, 'income': false},
    {'name': 'Faturalar', 'icon': Icons.receipt_long, 'color': Colors.red, 'income': false},
    {'name': 'Abonelikler', 'icon': Icons.subscriptions, 'color': Colors.deepPurple, 'income': false},
    {'name': 'Kredi Kartı', 'icon': Icons.credit_card, 'color': Colors.blueGrey, 'income': false},
    {'name': 'Giyim', 'icon': Icons.checkroom, 'color': Colors.pinkAccent, 'income': false},
    {'name': 'Alışveriş', 'icon': Icons.shopping_bag, 'color': Colors.pink, 'income': false},
    {'name': 'Dekorasyon', 'icon': Icons.chair, 'color': Colors.cyan, 'income': false},
    {'name': 'Spor', 'icon': Icons.fitness_center, 'color': Colors.lightGreen, 'income': false},
    {'name': 'Eğlence', 'icon': Icons.movie, 'color': Colors.purple, 'income': false},
    {'name': 'Eğitim', 'icon': Icons.menu_book, 'color': Colors.indigoAccent, 'income': false},
    {'name': 'Sağlık', 'icon': Icons.medical_services, 'color': Colors.redAccent, 'income': false},
    {'name': 'Yatırım', 'icon': Icons.account_balance_wallet, 'color': Colors.teal, 'income': false},
  ];

  @override
  Stream<List<CategoryModel>> build() {
    final user = ref.watch(currentUserProvider);
    final isGuest = ref.watch(guestModeProvider);
    
    if (user == null && !isGuest) {
      return Stream.value([]);
    }

    final userId = isGuest ? 'guest' : user!.id;
    final db = ref.watch(databaseProvider);

    return db.watchAllCategories(userId).map((list) {
      if (list.isEmpty) {
        // Arka planda veritabanına ekle (Eğer daha önce hiç eklenmemişse)
        if (!_isInitializing) {
          _ensureDefaultCategories(userId);
        }

        // KULLANICI BEKLEMESİN: Hemen hafızadaki varsayılanları döndür
        return _staticDefaults.map((def) => CategoryModel(
          id: 'def_${(def['name'] as String).toLowerCase().replaceAll(' ', '_')}',
          name: def['name'] as String,
          icon: def['icon'] as IconData,
          color: def['color'] as Color,
          isIncome: def['income'] as bool,
        )).toList();
      }

      return list.map((c) => CategoryModel.fromDb(c)).toList();
    });
  }

  Future<void> _ensureDefaultCategories(String userId) async {
    if (_isInitializing) return;
    _isInitializing = true;

    try {
      final db = ref.read(databaseProvider);
      final isGuest = ref.read(guestModeProvider);

      // SİLİNENLER DAHİL yerel geçmiş kontrolü
      final allHistory = await (db.select(db.categories)..where((c) => c.userId.equals(userId))).get();
      if (allHistory.isNotEmpty) {
        _isInitializing = false;
        return;
      }

      // Bulut kontrolü
      if (!isGuest) {
        try {
          final remoteCheck = await SupabaseService.client
              .from('categories')
              .select('id')
              .eq('user_id', userId)
              .limit(1)
              .maybeSingle();
          
          if (remoteCheck != null) {
            print('CategoryNotifier: Remote user has history on cloud, restoring...');
            ref.read(syncServiceProvider).syncAll();
            _isInitializing = false;
            return;
          }
        } catch (e) {
          print('CategoryNotifier: Cloud check error: $e');
        }
      }

      print('CategoryNotifier: Initializing default categories for user: $userId');
      for (final def in _staticDefaults) {
        await db.insertCategory(CategoriesCompanion.insert(
          uuid: 'def_${(def['name'] as String).toLowerCase().replaceAll(' ', '_')}',
          userId: userId,
          name: def['name'] as String,
          iconCode: (def['icon'] as IconData).codePoint,
          colorValue: (def['color'] as Color).value,
          isIncome: def['income'] as bool,
          isSynced: drift.Value(!isGuest),
        ));
      }
      
      if (!isGuest) {
        ref.read(syncServiceProvider).syncAll();
      }
    } finally {
      _isInitializing = false;
    }
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
