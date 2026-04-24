import 'package:birikimly/features/categories/domain/models/category_model.dart';

class TransactionModel {
  final String id;
  final double amount;
  final DateTime date;
  final CategoryModel category;
  final String description;
  final bool isIncome;

  TransactionModel({
    required this.id,
    required this.amount,
    required this.date,
    required this.category,
    required this.description,
    required this.isIncome,
  });

  TransactionModel copyWith({
    String? id,
    double? amount,
    DateTime? date,
    CategoryModel? category,
    String? description,
    bool? isIncome,
  }) {
    return TransactionModel(
      id: id ?? this.id,
      amount: amount ?? this.amount,
      date: date ?? this.date,
      category: category ?? this.category,
      description: description ?? this.description,
      isIncome: isIncome ?? this.isIncome,
    );
  }
}
