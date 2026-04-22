import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:taptap/core/theme/app_colors.dart';
import 'package:taptap/features/categories/presentation/providers/category_provider.dart';
import 'package:taptap/features/auth/presentation/providers/auth_provider.dart';
import 'package:taptap/features/dashboard/presentation/widgets/summary_card.dart';
import 'package:taptap/features/transactions/presentation/providers/transaction_provider.dart';
import 'package:taptap/features/transactions/widgets/transaction_item.dart';
import 'package:taptap/features/transactions/widgets/quick_add_form.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final transactionsAsync = ref.watch(transactionStreamProvider);
    final notifier = ref.watch(transactionNotifierProvider.notifier);
    final categories = ref.watch(categoryProvider);

    return Scaffold(
      body: SafeArea(
        child: transactionsAsync.when(
          data: (transactions) => CustomScrollView(
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.all(20),
                sliver: SliverToBoxAdapter(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
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
                                ref.watch(currentUserProvider)?.email?.split('@').first ?? 'Kullanıcı',
                                style: const TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          Row(
                            children: [
                              _SyncIndicator(transactions: transactions),
                              const SizedBox(width: 12),
                              Container(
                                padding: const EdgeInsets.all(4),
                                decoration: BoxDecoration(
                                  color: AppColors.surface,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: IconButton(
                                  icon: const Icon(Icons.logout),
                                  onPressed: () {
                                    ref.read(authNotifierProvider.notifier).signOut();
                                  },
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 30),
                      SummaryCard(
                        totalBalance: notifier.calculateBalance(transactions),
                        income: notifier.calculateIncome(transactions),
                        expense: notifier.calculateExpense(transactions),
                      ),
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
                          Text(
                            'Tümünü Gör',
                            style: TextStyle(
                              color: AppColors.primary,
                              fontWeight: FontWeight.w600,
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
                          (c) => c.name == tx.category,
                          orElse: () => categories.first,
                        );
                        return TransactionItem(
                          transaction: tx,
                          categoryIcon: category.icon,
                          categoryColor: category.color,
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
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          showModalBottomSheet(
            context: context,
            isScrollControlled: true,
            backgroundColor: AppColors.background,
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
            ),
            builder: (context) => const QuickAddForm(),
          );
        },
        label: const Text('İşlem Ekle'),
        icon: const Icon(Icons.add),
      ),
    );
  }
}

class _SyncIndicator extends StatelessWidget {
  final List<dynamic> transactions;

  const _SyncIndicator({required this.transactions});

  @override
  Widget build(BuildContext context) {
    final unsyncedCount = transactions.where((t) => !t.isSynced).length;
    final isSynced = unsyncedCount == 0;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: isSynced ? Colors.green.withValues(alpha: 0.1) : Colors.orange.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isSynced ? Icons.cloud_done : Icons.cloud_upload_outlined,
            size: 14,
            color: isSynced ? Colors.green : Colors.orange,
          ),
          const SizedBox(width: 6),
          Text(
            isSynced ? 'Synced' : '$unsyncedCount Pending',
            style: TextStyle(
              fontSize: 12,
              color: isSynced ? Colors.green : Colors.orange,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
