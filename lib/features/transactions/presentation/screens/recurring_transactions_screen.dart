import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:birikimly/core/theme/app_colors.dart';
import 'package:birikimly/features/transactions/presentation/providers/transaction_provider.dart';
import 'package:birikimly/features/categories/presentation/providers/category_provider.dart';
import 'package:birikimly/core/utils/currency_utils.dart';
import 'package:birikimly/core/database/database.dart';
import 'package:birikimly/features/categories/domain/models/category_model.dart';

class RecurringTransactionsScreen extends ConsumerWidget {
  const RecurringTransactionsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recurringTxsAsync = ref.watch(recurringTransactionStreamProvider);
    final categoriesAsync = ref.watch(categoryProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Düzenli İşlemler', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: AppColors.textPrimary,
      ),
      body: SafeArea(
        child: categoriesAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (err, stack) => Center(child: Text('Kategoriler yüklenemedi: $err')),
          data: (categories) => recurringTxsAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (err, stack) => Center(child: Text('İşlemler yüklenemedi: $err')),
            data: (transactions) {
              if (transactions.isEmpty) {
                return const Center(
                  child: Text(
                    'Henüz düzenli işlem eklenmemiş.',
                    style: TextStyle(color: AppColors.textSecondary, fontSize: 16),
                  ),
                );
              }

              return ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                itemCount: transactions.length,
                itemBuilder: (context, index) {
                  final rt = transactions[index];
                  
                  // Kategori Bulma Mantığı
                  CategoryModel? txCategory;
                  final rawId = rt.categoryId ?? '';
                  if (rawId.isNotEmpty) {
                    txCategory = categories.cast<CategoryModel?>().firstWhere(
                      (c) => c?.id == rawId,
                      orElse: () => null,
                    );
                  }

                  String displayName = rt.isIncome ? 'Genel Gelir' : 'Genel Gider';
                  if (txCategory != null) {
                    displayName = txCategory.name;
                  }

                  final displayCategory = txCategory ?? CategoryModel(
                    id: 'unknown',
                    name: displayName,
                    icon: rt.isIncome ? Icons.add_circle_outline : Icons.remove_circle_outline,
                    color: Colors.grey,
                    isIncome: rt.isIncome,
                  );

                  return _buildRecurringItem(context, ref, rt, displayCategory);
                },
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildRecurringItem(BuildContext context, WidgetRef ref, RecurringTransaction rt, CategoryModel category) {
    final today = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
    final execDate = DateTime(rt.nextExecutionDate.year, rt.nextExecutionDate.month, rt.nextExecutionDate.day);
    final daysLeft = execDate.difference(today).inDays;
    
    String daysLeftText;
    if (daysLeft == 0) {
      daysLeftText = 'Bugün';
    } else if (daysLeft == 1) {
      daysLeftText = 'Yarın';
    } else if (daysLeft > 1) {
      daysLeftText = '$daysLeft gün sonra';
    } else {
      daysLeftText = 'Geçti';
    }

    String freqText;
    switch(rt.frequency) {
      case 'weekly': freqText = 'Haftalık'; break;
      case 'yearly': freqText = 'Yıllık'; break;
      case 'monthly': 
      default: freqText = 'Aylık'; break;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: rt.isActive ? AppColors.surface : AppColors.background,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primary.withValues(alpha: rt.isActive ? 0.2 : 0.05)),
      ),
      child: Column(
        children: [
          ListTile(
            contentPadding: const EdgeInsets.fromLTRB(16, 8, 8, 0),
            leading: Opacity(
              opacity: rt.isActive ? 1.0 : 0.5,
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: category.color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(category.icon, color: category.color),
              ),
            ),
            title: Row(
              children: [
                Expanded(
                  child: Text(
                    rt.description.isNotEmpty ? rt.description : category.name,
                    style: TextStyle(
                      fontWeight: FontWeight.bold, 
                      fontSize: 16,
                      color: rt.isActive ? AppColors.textPrimary : AppColors.textSecondary,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    freqText,
                    style: const TextStyle(color: AppColors.primary, fontSize: 10, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 4.0),
              child: Row(
                children: [
                  Icon(Icons.calendar_today, size: 12, color: rt.isActive ? AppColors.textSecondary : Colors.grey.withValues(alpha: 0.5)),
                  const SizedBox(width: 4),
                  Text(
                    DateFormat('dd MMMM', 'tr_TR').format(rt.nextExecutionDate),
                    style: TextStyle(color: rt.isActive ? AppColors.textSecondary : Colors.grey.withValues(alpha: 0.5), fontSize: 12),
                  ),
                  const SizedBox(width: 8),
                  if (rt.isActive)
                    Text(
                      '($daysLeftText)',
                      style: TextStyle(color: daysLeft <= 3 ? AppColors.expense : AppColors.textSecondary, fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                ],
              ),
            ),
            trailing: Text(
              '${rt.isIncome ? '+' : '-'}${CurrencyUtils.format(rt.amount)}',
              style: TextStyle(
                color: !rt.isActive ? Colors.grey : (rt.isIncome ? AppColors.income : AppColors.expense),
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ),
          const Divider(height: 1, indent: 16, endIndent: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Text(
                      rt.isActive ? 'Aktif' : 'Duraklatıldı',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: rt.isActive ? AppColors.income : AppColors.textSecondary,
                      ),
                    ),
                    Transform.scale(
                      scale: 0.7,
                      child: Switch(
                        value: rt.isActive,
                        activeColor: AppColors.income,
                        onChanged: (val) {
                          ref.read(transactionNotifierProvider.notifier).toggleRecurringTransactionActive(rt, val);
                        },
                      ),
                    ),
                  ],
                ),
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.edit, color: AppColors.textSecondary, size: 20),
                      onPressed: () => _showEditDialog(context, ref, rt, category.name),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline, color: AppColors.expense, size: 20),
                      onPressed: () => _showDeleteDialog(context, ref, rt),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showDeleteDialog(BuildContext context, WidgetRef ref, RecurringTransaction rt) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Düzenli İşlemi İptal Et'),
        content: const Text('Bu düzenli işlemi iptal etmek istediğinize emin misiniz? Gelecek aylarda bu işlem artık otomatik olarak eklenmeyecek.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Vazgeç', style: TextStyle(color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () {
              ref.read(transactionNotifierProvider.notifier).deleteRecurringTransaction(rt);
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.expense, foregroundColor: Colors.white),
            child: const Text('İptal Et'),
          ),
        ],
      ),
    );
  }

  void _showEditDialog(BuildContext context, WidgetRef ref, RecurringTransaction rt, String categoryName) {
    final amountController = TextEditingController(text: rt.amount.toStringAsFixed(2).replaceAll('.00', ''));
    final descController = TextEditingController(text: rt.description);
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Düzenli İşlemi Düzenle'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: amountController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: 'Yeni Miktar', prefixText: '₺ '),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: descController,
              decoration: const InputDecoration(labelText: 'Yeni Açıklama'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('İptal'),
          ),
          ElevatedButton(
            onPressed: () {
              final newAmount = double.tryParse(amountController.text.replaceAll(',', '.'));
              if (newAmount != null && newAmount != rt.amount) {
                ref.read(transactionNotifierProvider.notifier).updateRecurringTransactionAmount(rt, newAmount);
              }
              if (descController.text != rt.description) {
                ref.read(transactionNotifierProvider.notifier).updateRecurringTransactionName(rt, descController.text);
              }
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white),
            child: const Text('Kaydet'),
          ),
        ],
      ),
    );
  }
}
