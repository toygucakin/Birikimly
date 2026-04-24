import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:birikimly/core/theme/app_colors.dart';
import 'package:birikimly/core/utils/currency_utils.dart';
import 'package:birikimly/features/categories/presentation/providers/category_provider.dart';
import 'package:birikimly/features/categories/domain/models/category_model.dart';

class MonthDetailAnalysisScreen extends ConsumerWidget {
  final DateTime month;
  final List<dynamic> monthlyTransactions;

  const MonthDetailAnalysisScreen({
    super.key,
    required this.month,
    required this.monthlyTransactions,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categories = ref.watch(categoryProvider);
    
    final incomeAnalysis = _getCategoryAnalysis(
      monthlyTransactions.where((t) => t.isIncome).toList(),
      categories,
    );
    
    final expenseAnalysis = _getCategoryAnalysis(
      monthlyTransactions.where((t) => !t.isIncome).toList(),
      categories,
    );

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          DateFormat('MMMM yyyy', 'tr_TR').format(month),
          style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: AppColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionHeader('En Çok Gelir Getiren 5 Kategori'),
            if (incomeAnalysis.isEmpty)
              _buildEmptyState('Bu ay gelir kaydı bulunmuyor.')
            else
              ...incomeAnalysis.take(5).map((data) => _buildAnalysisCard(data, AppColors.income)),
            
            const SizedBox(height: 32),
            
            _buildSectionHeader('En Çok Harcanan 5 Kategori'),
            if (expenseAnalysis.isEmpty)
              _buildEmptyState('Bu ay gider kaydı bulunmuyor.')
            else
              ...expenseAnalysis.take(5).map((data) => _buildAnalysisCard(data, AppColors.expense)),
          ],
        ),
      ),
    );
  }

  List<_CategoryStats> _getCategoryAnalysis(List<dynamic> transactions, List<CategoryModel> categories) {
    if (transactions.isEmpty) return [];
    
    final Map<String, double> categoryTotals = {};
    for (final t in transactions) {
      categoryTotals[t.category] = (categoryTotals[t.category] ?? 0) + t.amount;
    }

    final totalAmount = transactions.fold<double>(0, (sum, t) => sum + t.amount);

    final List<_CategoryStats> stats = categoryTotals.entries.map((entry) {
      // Safely find category using manual loop to avoid firstWhere type issues
      CategoryModel? category;
      for (final c in categories) {
        if (c.id == entry.key || c.name == entry.key) {
          category = c;
          break;
        }
      }
      
      return _CategoryStats(
        categoryName: category?.name ?? 'Bilinmeyen',
        categoryIcon: category?.icon ?? Icons.category,
        amount: entry.value,
        percentage: entry.value / totalAmount,
      );
    }).toList();

    stats.sort((a, b) => b.amount.compareTo(a.amount));
    return stats;
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: AppColors.textPrimary,
        ),
      ),
    );
  }

  Widget _buildEmptyState(String message) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        message,
        textAlign: TextAlign.center,
        style: const TextStyle(color: AppColors.textSecondary),
      ),
    );
  }

  Widget _buildAnalysisCard(_CategoryStats stats, Color themeColor) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: themeColor.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  stats.categoryIcon,
                  color: themeColor,
                  size: 20,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      stats.categoryName,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    Text(
                      '${(stats.percentage * 100).toStringAsFixed(1)}%',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                CurrencyUtils.format(stats.amount),
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: themeColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: stats.percentage,
              backgroundColor: themeColor.withValues(alpha: 0.1),
              valueColor: AlwaysStoppedAnimation<Color>(themeColor),
              minHeight: 6,
            ),
          ),
        ],
      ),
    );
  }
}

class _CategoryStats {
  final String categoryName;
  final IconData categoryIcon;
  final double amount;
  final double percentage;

  _CategoryStats({
    required this.categoryName,
    required this.categoryIcon,
    required this.amount,
    required this.percentage,
  });
}
