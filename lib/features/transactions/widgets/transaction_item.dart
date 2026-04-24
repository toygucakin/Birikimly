import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:birikimly/core/database/database.dart';
import 'package:birikimly/core/theme/app_colors.dart';
import 'package:birikimly/core/utils/currency_utils.dart';

class TransactionItem extends StatelessWidget {
  final Transaction transaction;
  final IconData categoryIcon;
  final Color categoryColor;
  final VoidCallback? onDelete;
  final Function(double)? onEdit;

  const TransactionItem({
    super.key,
    required this.transaction,
    required this.categoryIcon,
    required this.categoryColor,
    this.onDelete,
    this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: categoryColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              categoryIcon,
              color: categoryColor,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  transaction.description.isEmpty
                      ? transaction.category
                      : transaction.description,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                  ),
                ),
                Row(
                  children: [
                    Text(
                      DateFormat('dd MMM yyyy').format(transaction.date),
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                    if (!transaction.isSynced) ...[
                      const SizedBox(width: 8),
                      const Icon(Icons.sync_problem, size: 12, color: Colors.orange),
                    ],
                  ],
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${transaction.isIncome ? '+' : '-'}${CurrencyUtils.format(transaction.amount)}',
                style: TextStyle(
                  color: transaction.isIncome ? AppColors.income : AppColors.expense,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert, size: 20, color: AppColors.textSecondary),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                onSelected: (value) {
                  if (value == 'edit') {
                    _showEditAmountDialog(context);
                  } else if (value == 'delete') {
                    _showDeleteConfirm(context);
                  }
                },
                itemBuilder: (context) => [
                  const PopupMenuItem(
                    value: 'edit',
                    child: Row(
                      children: [
                        Icon(Icons.edit, size: 18),
                        SizedBox(width: 8),
                        Text('Düzenle'),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'delete',
                    child: Row(
                      children: [
                        Icon(Icons.delete, size: 18, color: AppColors.expense),
                        SizedBox(width: 8),
                        Text('Sil', style: TextStyle(color: AppColors.expense)),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showDeleteConfirm(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('İşlemi Sil'),
        content: const Text('Bu işlemi silmek istediğinize emin misiniz?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('İptal'),
          ),
          TextButton(
            onPressed: () {
              onDelete?.call();
              Navigator.pop(context);
            },
            style: TextButton.styleFrom(foregroundColor: AppColors.expense),
            child: const Text('Sil'),
          ),
        ],
      ),
    );
  }

  void _showEditAmountDialog(BuildContext context) {
    final controller = TextEditingController(text: transaction.amount.toString());
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Miktarı Düzenle'),
        content: TextField(
          controller: controller,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(
            labelText: 'Yeni Miktar',
            suffixText: 'TL',
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('İptal'),
          ),
          TextButton(
            onPressed: () {
              final newAmount = double.tryParse(controller.text);
              if (newAmount != null) {
                onEdit?.call(newAmount);
              }
              Navigator.pop(context);
            },
            child: const Text('Kaydet'),
          ),
        ],
      ),
    );
  }
}
