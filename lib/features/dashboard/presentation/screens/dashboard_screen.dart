import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:birikimly/core/theme/app_colors.dart';
import 'package:birikimly/features/categories/presentation/providers/category_provider.dart';
import 'package:birikimly/features/auth/presentation/providers/auth_provider.dart';
import 'package:birikimly/features/dashboard/presentation/widgets/summary_card.dart';
import 'package:birikimly/features/transactions/presentation/providers/transaction_provider.dart';
import 'package:birikimly/features/transactions/widgets/transaction_item.dart';
import 'package:birikimly/core/providers/preferences_provider.dart';
import 'package:flutter_speed_dial/flutter_speed_dial.dart';
import 'package:birikimly/features/transactions/widgets/transaction_wizard.dart';
import 'package:birikimly/features/reports/presentation/screens/financial_history_screen.dart';
import 'package:birikimly/features/profile/presentation/screens/profile_screen.dart';
import 'package:birikimly/core/database/database.dart';
import 'package:birikimly/features/categories/domain/models/category_model.dart';
import 'package:intl/intl.dart';
import 'package:birikimly/core/utils/currency_utils.dart';
import 'package:birikimly/features/main/presentation/providers/main_screen_provider.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pageController = ref.watch(mainPageControllerProvider);
    return _DashboardScreenContent(pageController: pageController);
  }
}

class _DashboardScreenContent extends ConsumerStatefulWidget {
  final PageController pageController;
  const _DashboardScreenContent({required this.pageController});

  @override
  ConsumerState<_DashboardScreenContent> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<_DashboardScreenContent> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      FocusScope.of(context).unfocus();
    });
  }

  void _showTransactionWizard(BuildContext context, bool isIncome) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => Dialog(
        alignment: Alignment.topCenter,
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 30),
        child: TransactionWizard(isIncome: isIncome),
      ),
    );
  }

  void _showTransactionDetail(BuildContext context, Transaction tx, CategoryModel category) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: category.color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(category.icon, color: category.color, size: 28),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        category.name,
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      Text(
                        DateFormat('dd MMMM yyyy, HH:mm', 'tr_TR').format(tx.date),
                        style: const TextStyle(color: AppColors.textSecondary, fontSize: 14),
                      ),
                    ],
                  ),
                ),
                Text(
                  '${tx.isIncome ? '+' : '-'}${CurrencyUtils.format(tx.amount)}',
                  style: TextStyle(
                    color: tx.isIncome ? AppColors.income : AppColors.expense,
                    fontWeight: FontWeight.bold,
                    fontSize: 20,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 32),
            const Text(
              'Açıklama',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(
                tx.description.isEmpty ? 'Açıklama belirtilmemiş.' : tx.description,
                style: const TextStyle(fontSize: 16, color: AppColors.textPrimary),
              ),
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                child: const Text('Kapat', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final transactionsAsync = ref.watch(transactionStreamProvider);
    final notifier = ref.watch(transactionNotifierProvider.notifier);
    final categories = ref.watch(categoryProvider);
    final isGuest = ref.watch(guestModeProvider);
    final customName = ref.watch(userNameProvider);
    final user = ref.watch(currentUserProvider);

    String displayName = isGuest
        ? customName
        : (customName.isNotEmpty && customName != 'Misafir')
            ? customName
            : (user?.email?.split('@').first ?? 'Kullanıcı');

    return Scaffold(
      body: SafeArea(
        child: transactionsAsync.when(
          data: (transactions) => CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          GestureDetector(
                            onTap: () => widget.pageController.animateToPage(
                              1,
                              duration: const Duration(milliseconds: 300),
                              curve: Curves.easeInOut,
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Hoş Geldin,',
                                  style: TextStyle(
                                    color: AppColors.textSecondary,
                                    fontSize: 16,
                                  ),
                                ),
                                Text(
                                  displayName,
                                  style: const TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          // Profile Button on Right
                          Container(
                            decoration: BoxDecoration(
                              color: AppColors.surface,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: IconButton(
                              icon: const Icon(Icons.account_circle_outlined, size: 28),
                              onPressed: () {
                                widget.pageController.animateToPage(
                                  1,
                                  duration: const Duration(milliseconds: 300),
                                  curve: Curves.easeInOut,
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 30),
                      // Aylık Net Durum Card
                      () {
                        final now = DateTime.now();
                        final currentMonthTransactions = transactions.where((t) => 
                          t.date.year == now.year && t.date.month == now.month).toList();
                        
                        return SummaryCard(
                          totalBalance: notifier.calculateBalance(currentMonthTransactions),
                          income: notifier.calculateIncome(currentMonthTransactions),
                          expense: notifier.calculateExpense(currentMonthTransactions),
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (context) => const FinancialHistoryScreen()),
                            );
                          },
                        );
                      }(),
                      const SizedBox(height: 40),
                      const Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Son İşlemler',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ),
              if (transactions.isEmpty)
                const SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(
                    child: Text(
                      'Henüz işlem eklenmemiş.',
                      style: TextStyle(color: AppColors.textSecondary),
                    ),
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final tx = transactions[index];
                        final txCategory = categories.firstWhere(
                          (c) => c.id == tx.categoryId || c.name == tx.categoryId,
                          orElse: () => categories.first,
                        );
                        return TransactionItem(
                          transaction: tx,
                          categoryIcon: txCategory.icon,
                          categoryColor: txCategory.color,
                          categoryName: txCategory.name,
                          onTap: () => _showTransactionDetail(context, tx, txCategory),
                          onEdit: (newAmount) {
                            ref.read(transactionNotifierProvider.notifier)
                               .updateTransactionAmount(tx, newAmount);
                          },
                          onDelete: () {
                            ref.read(transactionNotifierProvider.notifier)
                               .deleteTransaction(tx);
                          },
                        );
                      },
                      childCount: transactions.length,
                    ),
                  ),
                ),
              const SliverToBoxAdapter(child: SizedBox(height: 100)),
            ],
          ),
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (err, stack) => Center(child: Text('Hata: $err')),
        ),
      ),
      floatingActionButton: SpeedDial(
        icon: Icons.add,
        activeIcon: Icons.close,
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        overlayColor: Colors.black,
        overlayOpacity: 0.5,
        spacing: 12,
        spaceBetweenChildren: 12,
        children: [
          SpeedDialChild(
            child: const Icon(Icons.add_circle_outline),
            backgroundColor: AppColors.income,
            foregroundColor: Colors.white,
            label: 'Gelir Ekle',
            onTap: () => _showTransactionWizard(context, true),
          ),
          SpeedDialChild(
            child: const Icon(Icons.remove_circle_outline),
            backgroundColor: AppColors.expense,
            foregroundColor: Colors.white,
            label: 'Gider Ekle',
            onTap: () => _showTransactionWizard(context, false),
          ),
        ],
      ),
    );
  }
}

