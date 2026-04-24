import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:birikimly/features/categories/domain/models/category_model.dart';
import 'package:uuid/uuid.dart';

class CategoryNotifier extends Notifier<List<CategoryModel>> {
  @override
  List<CategoryModel> build() => _defaultCategories;

  static final List<CategoryModel> _defaultCategories = [
    // --- Legacy Categories (IDs 1-7 preserved for data compatibility) ---
    CategoryModel(id: '1', name: 'Gıda', icon: Icons.fastfood, color: Colors.orangeAccent, isIncome: false),
    CategoryModel(id: '2', name: 'Ulaşım', icon: Icons.directions_car, color: Colors.blue, isIncome: false),
    CategoryModel(id: '3', name: 'Eğlence', icon: Icons.videogame_asset, color: Colors.indigo, isIncome: false),
    CategoryModel(id: '4', name: 'Kira', icon: Icons.home, color: Colors.brown, isIncome: false),
    CategoryModel(id: '5', name: 'Maaş', icon: Icons.account_balance_wallet, color: Colors.green, isIncome: true),
    CategoryModel(id: '6', name: 'Alışveriş', icon: Icons.shopping_bag, color: Colors.pink, isIncome: false),
    CategoryModel(id: '7', name: 'Yan Gelir', icon: Icons.add_chart, color: Colors.teal, isIncome: true),

    // --- New Categories (IDs 8+) ---
    // Giderler
    CategoryModel(id: '8', name: 'Yiyecek & İçecek', icon: Icons.restaurant, color: Colors.orange, isIncome: false),
    CategoryModel(id: '9', name: 'Market', icon: Icons.local_grocery_store, color: Colors.green, isIncome: false),
    CategoryModel(id: '10', name: 'Giyim', icon: Icons.checkroom, color: Colors.purple, isIncome: false),
    CategoryModel(id: '11', name: 'Sağlık', icon: Icons.medical_services, color: Colors.red, isIncome: false),
    CategoryModel(id: '12', name: 'Faturalar', icon: Icons.receipt_long, color: Colors.amber, isIncome: false),
    CategoryModel(id: '13', name: 'Spor', icon: Icons.fitness_center, color: Colors.teal, isIncome: false),
    CategoryModel(id: '14', name: 'Abonelikler', icon: Icons.subscriptions, color: Colors.redAccent, isIncome: false),
    CategoryModel(id: '15', name: 'Dekorasyon', icon: Icons.chair, color: Colors.cyan, isIncome: false),
    CategoryModel(id: '16', name: 'Kredi Kartı', icon: Icons.credit_card, color: Colors.blueGrey, isIncome: false),
    CategoryModel(id: '17', name: 'Yatırım', icon: Icons.trending_up, color: Colors.deepPurple, isIncome: false),
    CategoryModel(id: '18', name: 'Diğer', icon: Icons.more_horiz, color: Colors.grey, isIncome: false),

    // Gelirler
    CategoryModel(id: '19', name: 'Burs', icon: Icons.school, color: Colors.blue, isIncome: true),
    CategoryModel(id: '20', name: 'Kira Geliri', icon: Icons.home_work, color: Colors.brown, isIncome: true),
    CategoryModel(id: '21', name: 'Yatırım Geliri', icon: Icons.payments, color: Colors.greenAccent, isIncome: true),
  ];

  void addCategory(String name, IconData icon, Color color, bool isIncome) {
    final newCategory = CategoryModel(
      id: const Uuid().v4(),
      name: name,
      icon: icon,
      color: color,
      isIncome: isIncome,
    );
    state = [...state, newCategory];
  }

  void updateCategory(String id, {String? name, IconData? icon, Color? color}) {
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

  void removeCategory(String id) {
    state = state.where((cat) => cat.id != id).toList();
  }
}

final categoryProvider = NotifierProvider<CategoryNotifier, List<CategoryModel>>(CategoryNotifier.new);
