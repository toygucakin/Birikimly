import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:birikimly/core/theme/app_colors.dart';
import 'package:birikimly/core/utils/currency_utils.dart';
import 'package:birikimly/features/categories/presentation/providers/category_provider.dart';
import 'package:birikimly/features/categories/domain/models/category_model.dart';
import 'package:birikimly/core/database/database.dart';

class MonthDetailAnalysisScreen extends ConsumerWidget {
  final DateTime month;
  final List<Transaction> monthlyTransactions;

  const MonthDetailAnalysisScreen({
    super.key,
    required this.month,
    required this.monthlyTransactions,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categories = ref.watch(categoryProvider);

    return categories.when(
      loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, s) => Scaffold(body: Center(child: Text('Hata: $e'))),
      data: (categoriesList) {
        final incomeAnalysis = _getCategoryAnalysis(
          monthlyTransactions.where((t) => t.isIncome).toList(),
          categoriesList,
        );
        
        final expenseAnalysis = _getCategoryAnalysis(
          monthlyTransactions.where((t) => !t.isIncome).toList(),
          categoriesList,
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
                const SizedBox(height: 32),
                
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => _showAllMonthlyTransactions(context, monthlyTransactions, categoriesList),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    child: const Text('Ay İçerisindeki İşlemler', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  ),
                ),
                const SizedBox(height: 32),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showAllMonthlyTransactions(BuildContext context, List<Transaction> transactions, List<CategoryModel> categories) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.85,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (_, scrollController) => Container(
          padding: const EdgeInsets.only(top: 24, left: 20, right: 20),
          decoration: const BoxDecoration(
            color: AppColors.background,
            borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
          ),
          child: Column(
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 20),
              const Text('Ay İçerisindeki İşlemler', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 20),
              Expanded(
                child: transactions.isEmpty
                    ? const Center(child: Text('Bu ay işlem bulunmuyor.', style: TextStyle(color: AppColors.textSecondary)))
                    : ListView.builder(
                        controller: scrollController,
                        itemCount: transactions.length,
                        itemBuilder: (context, index) {
                          // Sort transactions by date descending inside the builder? No, let's sort them once or assume they are sorted
                          // The transactions passed here are from the main screen, which are sorted by date descending.
                          final tx = transactions[index];
                          
                          // Match category
                          CategoryModel? txCategory;
                          final rawId = tx.categoryId?.trim() ?? '';
                          if (rawId.isNotEmpty) {
                            txCategory = categories.cast<CategoryModel?>().firstWhere(
                              (c) {
                                final cleanId = rawId.replaceAll('def_', '').replaceAll('temp_', '').toLowerCase();
                                final cid = c?.id.replaceAll('def_', '').replaceAll('temp_', '').toLowerCase();
                                return cid == cleanId || c?.name.toLowerCase().trim() == rawId.toLowerCase();
                              },
                              orElse: () => null,
                            );
                          }
                          
                          String displayName = tx.isIncome ? 'Genel Gelir' : 'Genel Gider';
                          if (txCategory != null) {
                            displayName = txCategory.name;
                          }

                          final displayCategory = txCategory ?? CategoryModel(
                            id: 'unknown',
                            name: displayName,
                            icon: tx.isIncome ? Icons.add_circle_outline : Icons.remove_circle_outline,
                            color: Colors.grey,
                            isIncome: tx.isIncome,
                          );

                          return Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: displayCategory.color.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  child: Icon(displayCategory.icon, color: displayCategory.color, size: 24),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        displayCategory.name,
                                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        DateFormat('dd MMM yyyy', 'tr_TR').format(tx.date),
                                        style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                                      ),
                                    ],
                                  ),
                                ),
                                Text(
                                  '${tx.isIncome ? '+' : '-'}${CurrencyUtils.format(tx.amount)}',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: tx.isIncome ? AppColors.income : AppColors.expense,
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<_CategoryStats> _getCategoryAnalysis(List<Transaction> transactions, List<CategoryModel> categories) {
    if (transactions.isEmpty) return [];
    
    final Map<String, double> categoryTotals = {};
    for (final t in transactions) {
      final String catId = t.categoryId ?? 'Bilinmeyen';
      categoryTotals[catId] = (categoryTotals[catId] ?? 0) + t.amount;
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
        percentage: totalAmount == 0 ? 0 : (entry.value / totalAmount),
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
