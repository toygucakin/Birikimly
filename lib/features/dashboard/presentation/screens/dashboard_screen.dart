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

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      FocusScope.of(context).unfocus();
    });
  }

  void _showTransactionWizard(BuildContext context, bool isIncome) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => TransactionWizard(isIncome: isIncome),
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

    String displayName = isGuest ? customName : (user?.email?.split('@').first ?? 'Kullanıcı');

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
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(builder: (context) => const ProfileScreen()),
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
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (context) => const ProfileScreen()),
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
                        final category = categories.firstWhere(
                          (c) => c.id == tx.category || c.name == tx.category,
                          orElse: () => categories.first,
                        );
                        return TransactionItem(
                          transaction: tx,
                          categoryIcon: category.icon,
                          categoryColor: category.color,
                          categoryName: category.name,
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

