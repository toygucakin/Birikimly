import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:birikimly/core/database/database.dart';
import 'package:birikimly/core/theme/app_colors.dart';
import 'package:birikimly/core/utils/currency_utils.dart';

class ProcessedTransactionsDialog extends ConsumerStatefulWidget {
  final List<Transaction> transactions;
  final String userId;

  const ProcessedTransactionsDialog({
    super.key,
    required this.transactions,
    required this.userId,
  });

  @override
  ConsumerState<ProcessedTransactionsDialog> createState() =>
      _ProcessedTransactionsDialogState();
}

class _ProcessedTransactionsDialogState
    extends ConsumerState<ProcessedTransactionsDialog> {
  bool _isLoading = true;
  final Map<String, Category> _categoryMap = {};

  @override
  void initState() {
    super.initState();
    _loadCategories();
  }

  Future<void> _loadCategories() async {
    try {
      final db = ref.read(databaseProvider);
      final categories = await db.getAllCategories(widget.userId);
      for (var tx in widget.transactions) {
        final rawId = tx.categoryId?.trim() ?? '';
        final category = categories.firstWhere(
          (c) => c.uuid == rawId,
          orElse: () => categories.firstWhere(
            (c) =>
                c.uuid
                    .replaceAll('def_', '')
                    .replaceAll('temp_', '')
                    .toLowerCase() ==
                rawId
                    .replaceAll('def_', '')
                    .replaceAll('temp_', '')
                    .toLowerCase(),
            orElse: () => categories.first,
          ),
        );
        _categoryMap[tx.uuid] = category;
      }
    } catch (e) {
      debugPrint('Failed to load categories for processed transactions: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Dialog(
        backgroundColor: Colors.transparent,
        elevation: 0,
        child: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
      ),
      backgroundColor: AppColors.background,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 30),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: AppColors.primary.withValues(alpha: 0.15),
            width: 1.5,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header Section
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF22C55E).withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.check_circle_outline,
                    color: Color(0xFF22C55E),
                    size: 28,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'İşlemleriniz Gerçekleşti',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Planlanan işlemleriniz bugün otomatik uygulandı.',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            
            // List Section
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: widget.transactions.length,
                separatorBuilder: (context, index) => Divider(
                  color: AppColors.textSecondary.withValues(alpha: 0.1),
                  height: 16,
                ),
                itemBuilder: (context, index) {
                  final tx = widget.transactions[index];
                  final category = _categoryMap[tx.uuid];
                  
                  final categoryName = category?.name ?? 'Kategori';
                  final categoryIcon = category != null
                      ? IconData(category.iconCode, fontFamily: 'MaterialIcons')
                      : Icons.category;
                  final categoryColor = category != null
                      ? Color(category.colorValue)
                      : AppColors.primary;
                      
                  final isIncome = tx.isIncome;
                  final amountSign = isIncome ? '+' : '-';
                  final amountColor = isIncome ? AppColors.income : AppColors.expense;
                  final amountStr = CurrencyUtils.format(tx.amount);
                  
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      children: [
                        // Category Icon
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: categoryColor.withValues(alpha: 0.12),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: categoryColor.withValues(alpha: 0.2),
                              width: 1,
                            ),
                          ),
                          child: Icon(
                            categoryIcon,
                            color: categoryColor,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        
                        // Details
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                categoryName,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                              if (tx.description.isNotEmpty) ...[
                                const SizedBox(height: 2),
                                Text(
                                  tx.description,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: AppColors.textSecondary,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        
                        // Amount
                        Text(
                          '$amountSign$amountStr',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                            color: amountColor,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 24),
            
            // Action Button
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: 0,
              ),
              child: const Text(
                'Harika, Anladım',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
