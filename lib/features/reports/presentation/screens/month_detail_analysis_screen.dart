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
              style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold),
            ),
            leading: IconButton(
              icon: Icon(Icons.arrow_back_ios, color: AppColors.textPrimary),
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
      builder: (context) => _MonthlyTransactionsSheet(
        transactions: transactions,
        categories: categories,
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
        style: TextStyle(
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
        style: TextStyle(color: AppColors.textSecondary),
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
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    Text(
                      '${(stats.percentage * 100).toStringAsFixed(1)}%',
                      style: TextStyle(
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

class _MonthlyTransactionsSheet extends StatefulWidget {
  final List<Transaction> transactions;
  final List<CategoryModel> categories;

  const _MonthlyTransactionsSheet({
    required this.transactions,
    required this.categories,
  });

  @override
  State<_MonthlyTransactionsSheet> createState() => _MonthlyTransactionsSheetState();
}

class _MonthlyTransactionsSheetState extends State<_MonthlyTransactionsSheet> {
  String _selectedType = 'all'; // 'all', 'income', 'expense'
  final Set<String> _selectedCategoryIds = {};

  void _showCategorySelectionSheet() {
    final availableCategories = widget.categories.where((c) {
      if (_selectedType == 'income') return c.isIncome;
      if (_selectedType == 'expense') return !c.isIncome;
      return true;
    }).toList();

    final tempSelectedIds = Set<String>.from(_selectedCategoryIds);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) => Container(
          padding: const EdgeInsets.only(top: 24, left: 20, right: 20, bottom: 20),
          decoration: BoxDecoration(
            color: AppColors.background,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Kategorileri Filtrele',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  if (tempSelectedIds.isNotEmpty)
                    TextButton(
                      onPressed: () {
                        setSheetState(() {
                          tempSelectedIds.clear();
                        });
                      },
                      child: Text(
                        'Temizle',
                        style: TextStyle(color: AppColors.expense, fontWeight: FontWeight.bold),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              if (availableCategories.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  child: Center(
                    child: Text(
                      'Kategori bulunmuyor.',
                      style: TextStyle(color: AppColors.textSecondary),
                    ),
                  ),
                )
              else
                Flexible(
                  child: GridView.builder(
                    shrinkWrap: true,
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 4,
                      crossAxisSpacing: 10,
                      mainAxisSpacing: 10,
                      childAspectRatio: 0.9,
                    ),
                    itemCount: availableCategories.length,
                    itemBuilder: (context, index) {
                      final cat = availableCategories[index];
                      final isSelected = tempSelectedIds.contains(cat.id);

                      return GestureDetector(
                        onTap: () {
                          setSheetState(() {
                            if (isSelected) {
                              tempSelectedIds.remove(cat.id);
                            } else {
                              tempSelectedIds.add(cat.id);
                            }
                          });
                        },
                        child: Stack(
                          children: [
                            Container(
                              width: double.infinity,
                              height: double.infinity,
                              decoration: BoxDecoration(
                                color: isSelected ? cat.color.withValues(alpha: 0.1) : AppColors.surface,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: isSelected ? cat.color : Colors.transparent,
                                  width: 2,
                                ),
                              ),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    cat.icon,
                                    color: isSelected ? cat.color : AppColors.textSecondary,
                                    size: 24,
                                  ),
                                  const SizedBox(height: 6),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 4.0),
                                    child: Text(
                                      cat.name,
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                        color: isSelected ? cat.color : AppColors.textSecondary,
                                      ),
                                      textAlign: TextAlign.center,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (isSelected)
                              Positioned(
                                top: 6,
                                right: 6,
                                child: Container(
                                  padding: const EdgeInsets.all(2),
                                  decoration: BoxDecoration(
                                    color: cat.color,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.check,
                                    color: Colors.white,
                                    size: 10,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    setState(() {
                      _selectedCategoryIds.clear();
                      _selectedCategoryIds.addAll(tempSelectedIds);
                      
                      if (_selectedCategoryIds.isNotEmpty) {
                        final firstCat = widget.categories.cast<CategoryModel?>().firstWhere(
                          (c) => c?.id == _selectedCategoryIds.first,
                          orElse: () => null,
                        );
                        if (firstCat != null) {
                          final allSame = _selectedCategoryIds.every((id) {
                            final cat = widget.categories.cast<CategoryModel?>().firstWhere(
                              (c) => c?.id == id,
                              orElse: () => null,
                            );
                            return cat != null && cat.isIncome == firstCat.isIncome;
                          });
                          if (allSame) {
                            _selectedType = firstCat.isIncome ? 'income' : 'expense';
                          }
                        }
                      }
                    });
                    Navigator.pop(context);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: const Text(
                    'Uygula',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFilterChip({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : AppColors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? AppColors.primary : AppColors.primary.withValues(alpha: 0.1),
            width: 1.5,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : AppColors.textPrimary,
            fontWeight: FontWeight.bold,
            fontSize: 13,
          ),
        ),
      ),
    );
  }

  Widget _buildCategoryFilterChip() {
    final hasCategories = _selectedCategoryIds.isNotEmpty;
    String label;
    IconData icon;
    Color iconColor;
    
    if (!hasCategories) {
      label = 'Kategori Seç';
      icon = Icons.arrow_drop_down;
      iconColor = AppColors.textSecondary;
    } else if (_selectedCategoryIds.length == 1) {
      final cat = widget.categories.cast<CategoryModel?>().firstWhere(
        (c) => c?.id == _selectedCategoryIds.first,
        orElse: () => null,
      );
      label = cat != null ? 'Kategori: ${cat.name}' : 'Kategori Seç';
      icon = cat?.icon ?? Icons.category;
      iconColor = Colors.white;
    } else {
      label = 'Kategori: ${_selectedCategoryIds.length} Seçili';
      icon = Icons.filter_list;
      iconColor = Colors.white;
    }
    final isSelected = hasCategories;

    return GestureDetector(
      onTap: _showCategorySelectionSheet,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : AppColors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? AppColors.primary : AppColors.primary.withValues(alpha: 0.1),
            width: 1.5,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isSelected) ...[
              Icon(
                icon,
                color: iconColor,
                size: 14,
              ),
              const SizedBox(width: 6),
            ],
            Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.white : AppColors.textPrimary,
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
            if (!isSelected) ...[
              const SizedBox(width: 4),
              Icon(
                icon,
                color: iconColor,
                size: 18,
              ),
            ],
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filteredTransactions = widget.transactions.where((tx) {
      if (_selectedType == 'income' && !tx.isIncome) return false;
      if (_selectedType == 'expense' && tx.isIncome) return false;
      
      if (_selectedCategoryIds.isNotEmpty) {
        final rawId = tx.categoryId?.trim() ?? '';
        final cleanId = rawId.replaceAll('def_', '').replaceAll('temp_', '').toLowerCase();
        
        return _selectedCategoryIds.any((selId) {
          final cleanSelId = selId.replaceAll('def_', '').replaceAll('temp_', '').toLowerCase();
          final cat = widget.categories.cast<CategoryModel?>().firstWhere(
            (c) => c?.id == selId,
            orElse: () => null,
          );
          if (cat == null) return false;
          return cleanId == cleanSelId || tx.categoryId?.toLowerCase().trim() == cat.name.toLowerCase().trim();
        });
      }
      return true;
    }).toList();

    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (_, scrollController) => Container(
        padding: const EdgeInsets.only(top: 24, left: 20, right: 20),
        decoration: BoxDecoration(
          color: AppColors.background,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
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
            const Text(
              'Ay İçerisindeki İşlemler',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildFilterChip(
                    label: 'Tümü',
                    isSelected: _selectedType == 'all' && _selectedCategoryIds.isEmpty,
                    onTap: () {
                      setState(() {
                        _selectedType = 'all';
                        _selectedCategoryIds.clear();
                      });
                    },
                  ),
                  const SizedBox(width: 8),
                  _buildFilterChip(
                    label: 'Gelirler',
                    isSelected: _selectedType == 'income' && _selectedCategoryIds.isEmpty,
                    onTap: () {
                      setState(() {
                        _selectedType = 'income';
                        _selectedCategoryIds.clear();
                      });
                    },
                  ),
                  const SizedBox(width: 8),
                  _buildFilterChip(
                    label: 'Giderler',
                    isSelected: _selectedType == 'expense' && _selectedCategoryIds.isEmpty,
                    onTap: () {
                      setState(() {
                        _selectedType = 'expense';
                        _selectedCategoryIds.clear();
                      });
                    },
                  ),
                  const SizedBox(width: 8),
                  _buildCategoryFilterChip(),
                ],
              ),
            ),
            const SizedBox(height: 20),
            
            Expanded(
              child: filteredTransactions.isEmpty
                  ? Center(
                      child: Text(
                        'Filtreye uygun işlem bulunmuyor.',
                        style: TextStyle(color: AppColors.textSecondary),
                      ),
                    )
                  : ListView.builder(
                      controller: scrollController,
                      itemCount: filteredTransactions.length,
                      itemBuilder: (context, index) {
                        final tx = filteredTransactions[index];
                        
                        CategoryModel? txCategory;
                        final rawId = tx.categoryId?.trim() ?? '';
                        if (rawId.isNotEmpty) {
                          txCategory = widget.categories.cast<CategoryModel?>().firstWhere(
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
                                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      DateFormat('dd MMM yyyy', 'tr_TR').format(tx.date),
                                      style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
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
