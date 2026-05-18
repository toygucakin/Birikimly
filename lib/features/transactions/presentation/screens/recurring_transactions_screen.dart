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
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.1)),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: category.color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(category.icon, color: category.color),
        ),
        title: Text(
          rt.description.isNotEmpty ? rt.description : category.name,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(
              'Sonraki İşlem: ${DateFormat('dd MMMM yyyy', 'tr_TR').format(rt.nextExecutionDate)}',
              style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
            ),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '${rt.isIncome ? '+' : '-'}${CurrencyUtils.format(rt.amount)}',
              style: TextStyle(
                color: rt.isIncome ? AppColors.income : AppColors.expense,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
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
