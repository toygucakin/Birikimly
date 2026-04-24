import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:birikimly/features/categories/domain/models/category_model.dart';
import 'package:uuid/uuid.dart';

class CategoryNotifier extends Notifier<List<CategoryModel>> {
  @override
  List<CategoryModel> build() => _defaultCategories;

  static final List<CategoryModel> _defaultCategories = [
    CategoryModel(id: '1', name: 'Gıda', icon: Icons.restaurant, color: Colors.orange, isIncome: false),
    CategoryModel(id: '2', name: 'Ulaşım', icon: Icons.directions_car, color: Colors.blue, isIncome: false),
    CategoryModel(id: '3', name: 'Eğlence', icon: Icons.videogame_asset, color: Colors.purple, isIncome: false),
    CategoryModel(id: '4', name: 'Kira', icon: Icons.home, color: Colors.red, isIncome: false),
    CategoryModel(id: '5', name: 'Maaş', icon: Icons.account_balance_wallet, color: Colors.green, isIncome: true),
    CategoryModel(id: '6', name: 'Alışveriş', icon: Icons.shopping_bag, color: Colors.pink, isIncome: false),
    CategoryModel(id: '7', name: 'Yan Gelir', icon: Icons.trending_up, color: Colors.teal, isIncome: true),
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
