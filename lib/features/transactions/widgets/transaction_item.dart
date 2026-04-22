import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:taptap/core/database/database.dart';
import 'package:taptap/core/theme/app_colors.dart';
import 'package:taptap/core/utils/currency_utils.dart';

class TransactionItem extends StatelessWidget {
  final Transaction transaction;
  final IconData categoryIcon;
  final Color categoryColor;
  final VoidCallback? onDelete;

  const TransactionItem({
    super.key,
    required this.transaction,
    required this.categoryIcon,
    required this.categoryColor,
    this.onDelete,
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
          Text(
            '${transaction.isIncome ? '+' : '-'}${CurrencyUtils.format(transaction.amount)}',
            style: TextStyle(
              color: transaction.isIncome ? AppColors.income : AppColors.expense,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }
}
