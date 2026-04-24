import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:birikimly/core/theme/app_colors.dart';
import 'package:birikimly/core/utils/currency_utils.dart';
import 'package:birikimly/features/transactions/presentation/providers/transaction_provider.dart';
import 'package:birikimly/features/reports/presentation/screens/month_detail_analysis_screen.dart';

class FinancialHistoryScreen extends ConsumerWidget {
  const FinancialHistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final transactionsAsync = ref.watch(transactionStreamProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'Mali Geçmiş',
          style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: AppColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: transactionsAsync.when(
        data: (transactions) {
          final groupedData = _groupTransactionsByMonth(transactions);
          return ListView.builder(
            padding: const EdgeInsets.all(20),
            itemCount: groupedData.length,
            itemBuilder: (context, index) {
              final data = groupedData[index];
              return GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => MonthDetailAnalysisScreen(
                        month: data.month,
                        monthlyTransactions: data.transactions,
                      ),
                    ),
                  );
                },
                child: _buildMonthCard(data),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('Hata: $err')),
      ),
    );
  }

  List<_MonthData> _groupTransactionsByMonth(List<dynamic> transactions) {
    final List<_MonthData> result = [];
    final now = DateTime.now();
    final start = DateTime(2026, 1);
    
    // Generate months from Jan 2026 to current month
    DateTime current = DateTime(now.year, now.month);
    while (current.isAfter(start) || current.isAtSameMomentAs(start)) {
      final monthTransactions = transactions.where((t) {
        return t.date.year == current.year && t.date.month == current.month;
      }).toList();

      double income = 0;
      double expense = 0;
      for (final t in monthTransactions) {
        if (t.isIncome) {
          income += t.amount;
        } else {
          expense += t.amount;
        }
      }

      result.add(_MonthData(
        month: current,
        income: income,
        expense: expense,
        transactions: monthTransactions,
      ));

      current = DateTime(current.year, current.month - 1);
    }
    
    return result;
  }

  Widget _buildMonthCard(_MonthData data) {
    final net = data.income - data.expense;
    final isPositive = net >= 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(24),
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
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                DateFormat('MMMM yyyy', 'tr_TR').format(data.month),
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: (isPositive ? AppColors.income : AppColors.expense).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  CurrencyUtils.format(net),
                  style: TextStyle(
                    color: isPositive ? AppColors.income : AppColors.expense,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: _buildSubStat(
                  label: 'Gelir',
                  amount: data.income,
                  color: AppColors.income,
                  icon: Icons.arrow_upward,
                ),
              ),
              Container(width: 1, height: 30, color: Colors.grey.withValues(alpha: 0.2)),
              Expanded(
                child: _buildSubStat(
                  label: 'Gider',
                  amount: data.expense,
                  color: AppColors.expense,
                  icon: Icons.arrow_downward,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSubStat({
    required String label,
    required double amount,
    required Color color,
    required IconData icon,
  }) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 12, color: color),
            const SizedBox(width: 4),
            Text(
              label,
              style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          CurrencyUtils.format(amount),
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
      ],
    );
  }
}

class _MonthData {
  final DateTime month;
  final double income;
  final double expense;
  final List<dynamic> transactions;

  _MonthData({
    required this.month,
    required this.income,
    required this.expense,
    required this.transactions,
  });
}
