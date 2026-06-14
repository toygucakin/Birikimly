import 'package:flutter/material.dart';
import 'package:birikimly/core/theme/app_colors.dart';
import 'package:birikimly/features/categories/domain/models/category_model.dart';
import 'package:intl/intl.dart';

class CategoryBudgetCard extends StatelessWidget {
  final CategoryModel category;
  final double spentAmount;
  final VoidCallback? onTap;
  
  const CategoryBudgetCard({
    super.key,
    required this.category,
    required this.spentAmount,
    this.onTap,
  });

  String _formatLimit(double val) {
    return NumberFormat('#,##0', 'en_US').format(val).replaceAll(',', '.');
  }

  @override
  Widget build(BuildContext context) {
    final double limit = category.maxLimit ?? 1.0; // Fallback to avoid div by zero
    final double rawPercent = spentAmount / limit;
    final double percent = rawPercent.clamp(0.0, 1.0);
    final bool isExceeded = spentAmount > limit;

    return GestureDetector(
      onTap: onTap,
      child: Container(
      width: 160,
      margin: const EdgeInsets.only(right: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isExceeded ? AppColors.expense.withValues(alpha: 0.5) : Colors.transparent,
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: category.color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(category.icon, color: category.color, size: 20),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  category.name,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const Spacer(),
          Text(
            '${_formatLimit(spentAmount)} ₺',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: isExceeded ? AppColors.expense : AppColors.textPrimary,
            ),
          ),
          Text(
            '/ ${_formatLimit(limit)} ₺',
            style: TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: percent,
              backgroundColor: AppColors.background,
              valueColor: AlwaysStoppedAnimation<Color>(
                isExceeded ? AppColors.expense : (percent > 0.8 ? Colors.orange : category.color),
              ),
              minHeight: 6,
            ),
          ),
        ],
      ),
    ),
    );
  }
}
