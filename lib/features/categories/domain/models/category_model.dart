import 'package:flutter/material.dart';
import 'package:birikimly/core/database/database.dart' as db;

class CategoryModel {
  final String id;
  final String name;
  final IconData icon;
  final Color color;
  final bool isIncome;

  CategoryModel({
    required this.id,
    required this.name,
    required this.icon,
    required this.color,
    this.isIncome = false,
  });

  factory CategoryModel.fromDb(db.Category record) {
    return CategoryModel(
      id: record.uuid,
      name: record.name,
      icon: IconData(record.iconCode, fontFamily: 'MaterialIcons'),
      color: Color(record.colorValue),
      isIncome: record.isIncome,
    );
  }
}
