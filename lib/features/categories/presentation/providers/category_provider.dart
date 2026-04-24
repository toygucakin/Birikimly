import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:birikimly/features/categories/domain/models/category_model.dart';
import 'package:uuid/uuid.dart';

class CategoryNotifier extends Notifier<List<CategoryModel>> {
  @override
  List<CategoryModel> build() => _defaultCategories;

  static final List<CategoryModel> _defaultCategories = [
    CategoryModel(id: '1', name: 'Gıda', icon: Icons.restaurant, color: Colors.orange),
    CategoryModel(id: '2', name: 'Ulaşım', icon: Icons.directions_car, color: Colors.blue),
    CategoryModel(id: '3', name: 'Eğlence', icon: Icons.videogame_asset, color: Colors.purple),
    CategoryModel(id: '4', name: 'Kira', icon: Icons.home, color: Colors.red),
    CategoryModel(id: '5', name: 'Maaş', icon: Icons.account_balance_wallet, color: Colors.green),
    CategoryModel(id: '6', name: 'Alışveriş', icon: Icons.shopping_bag, color: Colors.pink),
  ];

  void addCategory(String name, IconData icon, Color color) {
    final newCategory = CategoryModel(
      id: const Uuid().v4(),
      name: name,
      icon: icon,
      color: color,
    );
    state = [...state, newCategory];
  }
}

final categoryProvider = NotifierProvider<CategoryNotifier, List<CategoryModel>>(CategoryNotifier.new);
