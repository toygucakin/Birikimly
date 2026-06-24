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
                return Center(
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
                    style: TextStyle(color: AppColors.primary, fontSize: 10, fontWeight: FontWeight.bold),
                  ),
                ),
                if (rt.maxOccurrences != 100) ...[
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.amber.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'Taksit: ${rt.occurrencesExecuted}/${rt.maxOccurrences}',
                      style: const TextStyle(color: Colors.amber, fontSize: 10, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
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
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.repeat, 
                      size: 14, 
                      color: rt.isActive ? AppColors.textSecondary : Colors.grey.withValues(alpha: 0.5)
                    ),
                    const SizedBox(width: 6),
                    Text(
                      rt.maxOccurrences == 100
                          ? 'Kalan: Süresiz'
                          : 'Kalan: ${rt.maxOccurrences - rt.occurrencesExecuted} taksit',
                      style: TextStyle(
                        fontSize: 12,
                        color: rt.isActive ? AppColors.textSecondary : Colors.grey.withValues(alpha: 0.5),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                if (rt.maxOccurrences != 100) ...[
                  Builder(
                    builder: (context) {
                      final endDate = _calculateEndDate(rt.startDate, rt.frequency, rt.maxOccurrences);
                      final formattedEndDate = DateFormat('MMMM yyyy', 'tr_TR').format(endDate);
                      return Row(
                        children: [
                          Icon(
                            Icons.event_available, 
                            size: 14, 
                            color: rt.isActive ? AppColors.textSecondary : Colors.grey.withValues(alpha: 0.5)
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Bitiş: $formattedEndDate',
                            style: TextStyle(
                              fontSize: 12,
                              color: rt.isActive ? AppColors.textSecondary : Colors.grey.withValues(alpha: 0.5),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ] else ...[
                  Row(
                    children: [
                      Icon(
                        Icons.event_repeat, 
                        size: 14, 
                        color: rt.isActive ? AppColors.textSecondary : Colors.grey.withValues(alpha: 0.5)
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Bitiş: Süresiz',
                        style: TextStyle(
                          fontSize: 12,
                          color: rt.isActive ? AppColors.textSecondary : Colors.grey.withValues(alpha: 0.5),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
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
                      icon: Icon(Icons.edit, color: AppColors.textSecondary, size: 20),
                      onPressed: () => _showEditDialog(context, ref, rt, category.name),
                    ),
                    IconButton(
                      icon: Icon(Icons.delete_outline, color: AppColors.expense, size: 20),
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
            child: Text('Vazgeç', style: TextStyle(color: AppColors.textSecondary)),
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
    final initialValue = NumberFormat('#,###', 'tr_TR')
        .format(rt.amount)
        .replaceAll(',', '.');
    final amountController = TextEditingController(text: initialValue);
    final descController = TextEditingController(text: rt.description);
    
    showDialog(
      context: context,
      builder: (context) {
        String? localError;
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              title: const Text('Düzenli İşlemi Düzenle'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.background,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: localError != null 
                            ? AppColors.expense 
                            : AppColors.primary.withValues(alpha: 0.2)
                      ),
                    ),
                    child: TextField(
                      controller: amountController,
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppColors.primary),
                      keyboardType: TextInputType.number,
                      inputFormatters: [ThousandsFormatter()],
                      decoration: InputDecoration(
                        border: InputBorder.none,
                        labelText: 'Yeni Miktar',
                        labelStyle: TextStyle(fontSize: 14, color: AppColors.textSecondary),
                        prefixText: '₺ ',
                        prefixStyle: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.primary),
                      ),
                      onChanged: (val) {
                        final cleanText = val.replaceAll('.', '').replaceAll(',', '.');
                        final newAmount = double.tryParse(cleanText) ?? 0;
                        if (newAmount > 9999999999) {
                          setStateDialog(() {
                            localError = 'En fazla 9.999.999.999 ₺ girilebilir.';
                          });
                        } else {
                          if (localError != null) {
                            setStateDialog(() {
                              localError = null;
                            });
                          }
                        }
                      },
                    ),
                  ),
                  if (localError != null) ...[
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.error_outline, size: 14, color: AppColors.expense),
                        const SizedBox(width: 6),
                        Text(
                          localError!,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            color: AppColors.expense,
                          ),
                        ),
                      ],
                    ),
                  ],
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
                  onPressed: localError != null || amountController.text.isEmpty
                      ? null
                      : () {
                          final cleanText = amountController.text.replaceAll('.', '').replaceAll(',', '.');
                          final newAmount = double.tryParse(cleanText);
                          if (newAmount != null && newAmount != rt.amount) {
                            ref.read(transactionNotifierProvider.notifier).updateRecurringTransactionAmount(rt, newAmount);
                          }
                          if (descController.text != rt.description) {
                            ref.read(transactionNotifierProvider.notifier).updateRecurringTransactionName(rt, descController.text);
                          }
                          Navigator.pop(context);
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: localError != null || amountController.text.isEmpty
                        ? Colors.grey
                        : AppColors.primary,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Kaydet'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  DateTime _calculateEndDate(DateTime start, String freq, int maxOccs) {
    DateTime date = start;
    for (int i = 0; i < maxOccs - 1; i++) {
      date = _advanceDate(date, start, freq);
    }
    return date;
  }

  DateTime _advanceDate(DateTime current, DateTime originalStart, String frequency) {
    switch (frequency) {
      case 'weekly':
        return current.add(const Duration(days: 7));
      case 'yearly':
        return _advanceOneYear(current, originalStart);
      case 'monthly':
      default:
        return _advanceOneMonth(current, originalStart);
    }
  }

  DateTime _advanceOneMonth(DateTime current, DateTime originalStart) {
    int nextMonth = current.month + 1;
    int nextYear = current.year;
    
    if (nextMonth > 12) {
      nextMonth = 1;
      nextYear++;
    }

    final targetDay = originalStart.day;
    final maxDaysInNextMonth = DateTime(nextYear, nextMonth + 1, 0).day;
    final clampedDay = targetDay > maxDaysInNextMonth ? maxDaysInNextMonth : targetDay;

    return DateTime(
      nextYear,
      nextMonth,
      clampedDay,
      originalStart.hour,
      originalStart.minute,
      originalStart.second,
    );
  }

  DateTime _advanceOneYear(DateTime current, DateTime originalStart) {
    int nextYear = current.year + 1;
    int nextMonth = current.month;
    
    final targetDay = originalStart.day;
    final maxDaysInNextMonth = DateTime(nextYear, nextMonth + 1, 0).day;
    final clampedDay = targetDay > maxDaysInNextMonth ? maxDaysInNextMonth : targetDay;

    return DateTime(
      nextYear,
      nextMonth,
      clampedDay,
      originalStart.hour,
      originalStart.minute,
      originalStart.second,
    );
  }
}
