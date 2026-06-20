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
import 'package:birikimly/features/transactions/presentation/screens/recurring_transactions_screen.dart' as birikimly_rt_screen;
import 'package:birikimly/core/database/database.dart';
import 'package:birikimly/features/categories/domain/models/category_model.dart';
import 'package:intl/intl.dart';
import 'package:birikimly/core/utils/currency_utils.dart';

import 'package:birikimly/features/dashboard/presentation/widgets/category_budget_card.dart';

class DashboardScreen extends ConsumerWidget {
  final PageController pageController;
  const DashboardScreen({super.key, required this.pageController});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return _DashboardScreenContent(pageController: pageController);
  }
}

class _DashboardScreenContent extends ConsumerStatefulWidget {
  final PageController pageController;
  const _DashboardScreenContent({required this.pageController});

  @override
  ConsumerState<_DashboardScreenContent> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<_DashboardScreenContent> with TickerProviderStateMixin {
  bool _isUpcomingExpanded = false;

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
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
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
                        style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
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
            Text(
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
                style: TextStyle(fontSize: 16, color: AppColors.textPrimary),
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
    final recurringAsync = ref.watch(recurringTransactionStreamProvider);
    final notifier = ref.watch(transactionNotifierProvider.notifier);
    final categoriesAsync = ref.watch(categoryProvider);
    final isGuest = ref.watch(guestModeProvider);
    final customName = ref.watch(userNameProvider);
    final user = ref.watch(currentUserProvider);

    final metaName = user?.userMetadata?['display_name']?.toString();
    
    final displayName = isGuest
        ? customName
        : (metaName != null && metaName.isNotEmpty)
            ? metaName
            : (customName.isNotEmpty && customName != 'Misafir')
                ? customName
                : (user?.email?.split('@').first ?? 'Kullanıcı');

    final localLimit = ref.watch(monthlyLimitProvider);
    final double? monthlyLimit = isGuest
        ? localLimit
        : (user?.userMetadata?['monthly_limit'] != null
            ? double.tryParse(user!.userMetadata!['monthly_limit'].toString())
            : localLimit);

    return Scaffold(
      body: SafeArea(
        child: categoriesAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (err, stack) => Center(child: Text('Kategoriler yüklenemedi: $err')),
          data: (categories) => transactionsAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (err, stack) => Center(child: Text('İşlemler yüklenemedi: $err')),
            data: (allTransactions) {
              final now = DateTime.now();
              final transactions = allTransactions.where((t) => 
                t.date.year == now.year && t.date.month == now.month).toList();
              
              return CustomScrollView(
              slivers: [
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
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
                            Row(
                              children: [
                                Container(
                                  decoration: BoxDecoration(
                                    color: AppColors.surface,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: IconButton(
                                    icon: Icon(Icons.event_repeat_rounded, size: 24, color: AppColors.primary),
                                    onPressed: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(builder: (context) => const birikimly_rt_screen.RecurringTransactionsScreen()),
                                      );
                                    },
                                  ),
                                ),
                                const SizedBox(width: 8),
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
                          ],
                        ),
                        const SizedBox(height: 16),
                        () {
                          return SummaryCard(
                            totalBalance: notifier.calculateBalance(transactions),
                            income: notifier.calculateIncome(transactions),
                            expense: notifier.calculateExpense(transactions),
                            monthlyLimit: monthlyLimit,
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(builder: (context) => const FinancialHistoryScreen()),
                              );
                            },
                          );
                        }(),
                        () {
                          final totalExpense = notifier.calculateExpense(transactions);

                          double totalCategoryLimits = 0;
                          final List<Widget> warningWidgets = [];
                          final List<Map<String, dynamic>> exceededCategories = [];
                          final List<Map<String, dynamic>> categoryBudgetCardData = [];

                          for (final cat in categories) {
                            if (!cat.isIncome && cat.maxLimit != null) {
                              totalCategoryLimits += cat.maxLimit!;

                              // Kategoriye ait bu ayki harcamayı hesapla
                              double spentForCat = 0;
                              final List<Transaction> catTransactions = [];
                              for (final tx in transactions) {
                                if (!tx.isIncome && tx.categoryId != null) {
                                  final rawId = tx.categoryId!.trim().toLowerCase();
                                  final catCleanId = cat.id.replaceAll('def_', '').replaceAll('temp_', '').toLowerCase();
                                  final txCleanId = rawId.replaceAll('def_', '').replaceAll('temp_', '').toLowerCase();
                                  
                                  if (txCleanId == catCleanId || txCleanId == cat.name.toLowerCase().trim()) {
                                    spentForCat += tx.amount;
                                    catTransactions.add(tx);
                                  }
                                }
                              }

                              final double percent = cat.maxLimit! > 0 ? spentForCat / cat.maxLimit! : (spentForCat > 0 ? double.infinity : 0.0);
                              final double overrun = spentForCat - cat.maxLimit!;
                              
                              categoryBudgetCardData.add({
                                'widget': CategoryBudgetCard(
                                  category: cat,
                                  spentAmount: spentForCat,
                                  onTap: () {
                                    if (catTransactions.isEmpty) return;
                                    catTransactions.sort((a, b) => b.date.compareTo(a.date));
                                    final animationController = BottomSheet.createAnimationController(this);
                                    animationController.duration = const Duration(milliseconds: 300);
                                    animationController.reverseDuration = const Duration(milliseconds: 500);
                                    showModalBottomSheet(
                                      context: context,
                                      transitionAnimationController: animationController,
                                      backgroundColor: Colors.transparent,
                                      isScrollControlled: true,
                                      builder: (context) => Container(
                                        height: MediaQuery.of(context).size.height * 0.7,
                                        padding: const EdgeInsets.all(24),
                                        decoration: BoxDecoration(
                                          color: AppColors.surface,
                                          borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
                                        ),
                                        child: Column(
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
                                                    color: cat.color.withValues(alpha: 0.1),
                                                    borderRadius: BorderRadius.circular(16),
                                                  ),
                                                  child: Icon(cat.icon, color: cat.color, size: 28),
                                                ),
                                                const SizedBox(width: 16),
                                                Expanded(
                                                  child: Column(
                                                    crossAxisAlignment: CrossAxisAlignment.start,
                                                    children: [
                                                      Text(
                                                        cat.name,
                                                        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                                                      ),
                                                      Text(
                                                        'Bu Ayki İşlemler',
                                                        style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 24),
                                            Expanded(
                                              child: ListView.builder(
                                                itemCount: catTransactions.length,
                                                itemBuilder: (context, idx) {
                                                  final tx = catTransactions[idx];
                                                  return Container(
                                                    margin: const EdgeInsets.only(bottom: 12),
                                                    padding: const EdgeInsets.all(16),
                                                    decoration: BoxDecoration(
                                                      color: AppColors.background,
                                                      borderRadius: BorderRadius.circular(16),
                                                    ),
                                                    child: Row(
                                                      children: [
                                                        Expanded(
                                                          child: Column(
                                                            crossAxisAlignment: CrossAxisAlignment.start,
                                                            children: [
                                                              Text(
                                                                tx.description.isEmpty ? 'Açıklama yok' : tx.description,
                                                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                                              ),
                                                              const SizedBox(height: 4),
                                                              Text(
                                                                DateFormat('dd MMMM', 'tr_TR').format(tx.date),
                                                                style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
                                                              ),
                                                            ],
                                                          ),
                                                        ),
                                                        Text(
                                                          '-${CurrencyUtils.format(tx.amount)}',
                                                          style: TextStyle(
                                                            color: AppColors.expense,
                                                            fontWeight: FontWeight.bold,
                                                            fontSize: 16,
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  );
                                                },
                                              ),
                                            ),
                                            const SizedBox(height: 16),
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
                                    ).whenComplete(() {
                                      Future.delayed(const Duration(milliseconds: 600), () {
                                        try {
                                          animationController.dispose();
                                        } catch (_) {}
                                      });
                                    });
                                  },
                                ),
                                'percent': percent,
                                'overrun': overrun,
                              });

                              // Aşım kontrolü
                              if (spentForCat > cat.maxLimit!) {
                                exceededCategories.add({
                                  'category': cat,
                                  'spent': spentForCat,
                                  'limit': cat.maxLimit!,
                                });
                              }
                            }
                          }

                          // Sıralama Algoritması:
                          // 1. İkisi de aşılmışsa -> Miktar (TL) olarak en çok aşan en önde
                          // 2. Biri aşılmış, diğeri aşılmamışsa -> Aşılan en önde
                          // 3. İkisi de aşılmamışsa -> Yüzdelik doluluğu en yüksek olan en önde
                          categoryBudgetCardData.sort((a, b) {
                            final double percentA = a['percent'] as double;
                            final double percentB = b['percent'] as double;
                            final double overA = a['overrun'] as double;
                            final double overB = b['overrun'] as double;

                            if (percentA > 1.0 && percentB > 1.0) {
                              return overB.compareTo(overA);
                            } else if (percentA > 1.0 && percentB <= 1.0) {
                              return -1;
                            } else if (percentB > 1.0 && percentA <= 1.0) {
                              return 1;
                            } else {
                              return percentB.compareTo(percentA);
                            }
                          });
                          
                          final List<Widget> categoryBudgetCards = categoryBudgetCardData.map((e) => e['widget'] as Widget).toList();

                          if (exceededCategories.isNotEmpty) {
                            warningWidgets.add(
                              GestureDetector(
                                onTap: () {
                                  showModalBottomSheet(
                                    context: context,
                                    backgroundColor: Colors.transparent,
                                    builder: (context) => Container(
                                      padding: const EdgeInsets.all(24),
                                      decoration: BoxDecoration(
                                        color: AppColors.surface,
                                        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
                                      ),
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Container(
                                            width: 40,
                                            height: 4,
                                            margin: const EdgeInsets.only(bottom: 24),
                                            decoration: BoxDecoration(
                                              color: Colors.grey.withValues(alpha: 0.3),
                                              borderRadius: BorderRadius.circular(2),
                                            ),
                                          ),
                                          Icon(Icons.warning_amber_rounded, color: AppColors.expense, size: 48),
                                          const SizedBox(height: 16),
                                          const Text(
                                            'Aşılan Kategoriler',
                                            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                                          ),
                                          const SizedBox(height: 24),
                                          ...exceededCategories.map((item) {
                                            final CategoryModel cat = item['category'];
                                            final double spent = item['spent'];
                                            final double limit = item['limit'];
                                            return Padding(
                                              padding: const EdgeInsets.only(bottom: 16),
                                              child: Row(
                                                children: [
                                                  Container(
                                                    padding: const EdgeInsets.all(8),
                                                    decoration: BoxDecoration(
                                                      color: cat.color.withValues(alpha: 0.1),
                                                      borderRadius: BorderRadius.circular(12),
                                                    ),
                                                    child: Icon(cat.icon, color: cat.color, size: 24),
                                                  ),
                                                  const SizedBox(width: 12),
                                                  Expanded(
                                                    child: Text(cat.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                                  ),
                                                  Column(
                                                    crossAxisAlignment: CrossAxisAlignment.end,
                                                    children: [
                                                      Text(
                                                        'Aşım: ${CurrencyUtils.format(spent - limit)}',
                                                        style: TextStyle(color: AppColors.expense, fontWeight: FontWeight.bold),
                                                      ),
                                                      Text(
                                                        '${CurrencyUtils.format(spent)} / ${CurrencyUtils.format(limit)}',
                                                        style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
                                                      ),
                                                    ],
                                                  ),
                                                ],
                                              ),
                                            );
                                          }),
                                          const SizedBox(height: 16),
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
                                },
                                child: Container(
                                  margin: const EdgeInsets.only(top: 16),
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                  decoration: BoxDecoration(
                                    color: AppColors.expense.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(color: AppColors.expense.withValues(alpha: 0.3), width: 1.5),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(Icons.warning_amber_rounded, color: AppColors.expense, size: 24),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              'Kategori Limitleri Aşıldı!',
                                              style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.expense, fontSize: 14),
                                            ),
                                            Text(
                                              '${exceededCategories.length} kategoride limitinizi aştınız. Detaylar için tıklayın.',
                                              style: TextStyle(color: AppColors.expense, fontSize: 13),
                                            ),
                                          ],
                                        ),
                                      ),
                                      Icon(Icons.chevron_right, color: AppColors.expense),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          }

                          if (monthlyLimit != null) {
                            final hasExpenseExceeded = totalExpense > monthlyLimit;
                            final hasCategoryMismatch = totalCategoryLimits > monthlyLimit;

                            if (hasExpenseExceeded) {
                              warningWidgets.insert(0, Container(
                                margin: const EdgeInsets.only(top: 16),
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                decoration: BoxDecoration(
                                  color: AppColors.expense.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: AppColors.expense.withValues(alpha: 0.3), width: 1.5),
                                ),
                                child: Row(
                                  children: [
                                    Icon(Icons.warning_amber_rounded, color: AppColors.expense, size: 24),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'Genel Bütçe Sınırı Aşıldı!',
                                            style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.expense, fontSize: 14),
                                          ),
                                          Text(
                                            'Aylık harcama limitinizi ${CurrencyUtils.format(totalExpense - monthlyLimit)} aştınız.',
                                            style: TextStyle(color: AppColors.expense, fontSize: 13),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ));
                            }

                            if (hasCategoryMismatch) {
                              warningWidgets.add(Container(
                                margin: const EdgeInsets.only(top: 16),
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                decoration: BoxDecoration(
                                  color: Colors.amber.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: Colors.amber.withValues(alpha: 0.3), width: 1.5),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(Icons.info_outline_rounded, color: Colors.amber, size: 24),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          const Text(
                                            'Kategori Limit Uyuşmazlığı',
                                            style: TextStyle(fontWeight: FontWeight.bold, color: Colors.amber, fontSize: 14),
                                          ),
                                          Text(
                                            'Kategori limitlerinin toplamı (${CurrencyUtils.format(totalCategoryLimits)}), aylık genel limitinizi (${CurrencyUtils.format(monthlyLimit)}) aşıyor.',
                                            style: const TextStyle(color: Colors.amber, fontSize: 13),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ));
                            }
                          }

                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              ...warningWidgets,
                              if (categoryBudgetCards.isNotEmpty) ...[
                                const SizedBox(height: 16),
                                const Text(
                                  'Kategori Bütçeleri',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 16),
                                SizedBox(
                                  height: 160,
                                  child: ListView(
                                    scrollDirection: Axis.horizontal,
                                    physics: const BouncingScrollPhysics(),
                                    children: categoryBudgetCards,
                                  ),
                                ),
                              ],
                              recurringAsync.maybeWhen(
                                data: (recurringTxs) {
                                  final today = DateTime(now.year, now.month, now.day);
                                  final upcoming = recurringTxs.where((rt) {
                                    if (!rt.isActive) return false;
                                    final execDate = DateTime(rt.nextExecutionDate.year, rt.nextExecutionDate.month, rt.nextExecutionDate.day);
                                    return execDate.year == today.year && execDate.month == today.month && execDate.difference(today).inDays >= 0;
                                  }).toList();
                                  
                                  if (upcoming.isEmpty) return const SizedBox.shrink();

                                  upcoming.sort((a, b) => a.nextExecutionDate.compareTo(b.nextExecutionDate));

                                  return Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const SizedBox(height: 16),
                                      GestureDetector(
                                        onTap: () {
                                          setState(() {
                                            _isUpcomingExpanded = !_isUpcomingExpanded;
                                          });
                                        },
                                        behavior: HitTestBehavior.opaque,
                                        child: Padding(
                                          padding: const EdgeInsets.symmetric(vertical: 8.0),
                                          child: Row(
                                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                            children: [
                                              const Text(
                                                'Yaklaşan Ödemeler (Bu Ay)',
                                                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                                              ),
                                              Icon(
                                                _isUpcomingExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                                                color: AppColors.textSecondary,
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                      AnimatedSize(
                                        duration: const Duration(milliseconds: 300),
                                        curve: Curves.easeInOut,
                                        child: _isUpcomingExpanded
                                            ? Column(
                                                children: [
                                                  const SizedBox(height: 8),
                                                  SizedBox(
                                                    height: 110,
                                        child: ListView.builder(
                                          scrollDirection: Axis.horizontal,
                                          physics: const BouncingScrollPhysics(),
                                          itemCount: upcoming.length,
                                          itemBuilder: (context, index) {
                                            final rt = upcoming[index];
                                            final execDate = DateTime(rt.nextExecutionDate.year, rt.nextExecutionDate.month, rt.nextExecutionDate.day);
                                            final daysLeft = execDate.difference(today).inDays;
                                            final isIncome = rt.isIncome;
                                            
                                            // Find category
                                            final rawId = rt.categoryId?.trim() ?? '';
                                            CategoryModel? cat = categories.cast<CategoryModel?>().firstWhere(
                                              (c) => c?.id == rawId,
                                              orElse: () => null,
                                            );
                                            final catName = cat?.name ?? (isIncome ? 'Gelir' : 'Gider');
                                            final catIcon = cat?.icon ?? (isIncome ? Icons.add_circle_outline : Icons.remove_circle_outline);
                                            final catColor = cat?.color ?? Colors.grey;

                                            return Container(
                                              width: 160,
                                              margin: const EdgeInsets.only(right: 12),
                                              padding: const EdgeInsets.all(12),
                                              decoration: BoxDecoration(
                                                color: AppColors.surface,
                                                borderRadius: BorderRadius.circular(16),
                                                border: Border.all(color: AppColors.primary.withValues(alpha: 0.1)),
                                              ),
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                children: [
                                                  Row(
                                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                    children: [
                                                      Icon(catIcon, color: catColor, size: 24),
                                                      Container(
                                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                        decoration: BoxDecoration(
                                                          color: daysLeft <= 3 ? AppColors.expense.withValues(alpha: 0.1) : AppColors.primary.withValues(alpha: 0.1),
                                                          borderRadius: BorderRadius.circular(8),
                                                        ),
                                                        child: Text(
                                                          daysLeft == 0 ? 'Bugün' : (daysLeft == 1 ? 'Yarın' : '$daysLeft gün'),
                                                          style: TextStyle(
                                                            fontSize: 10,
                                                            fontWeight: FontWeight.bold,
                                                            color: daysLeft <= 3 ? AppColors.expense : AppColors.primary,
                                                          ),
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                  Text(
                                                    rt.description.isNotEmpty ? rt.description : catName,
                                                    maxLines: 1,
                                                    overflow: TextOverflow.ellipsis,
                                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                                  ),
                                                  Text(
                                                    '${isIncome ? '+' : '-'}${CurrencyUtils.format(rt.amount)}',
                                                    style: TextStyle(
                                                      color: isIncome ? AppColors.income : AppColors.expense,
                                                      fontWeight: FontWeight.bold,
                                                      fontSize: 16,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            );
                                          },
                                        ),
                                      ),
                                    ],
                                  )
                                : const SizedBox(width: double.infinity, height: 0),
                                      ),
                                    ],
                                  );
                                },
                                orElse: () => const SizedBox.shrink(),
                              ),
                            ],
                          );
                        }(),
                        const SizedBox(height: 24),
                        const Text(
                          'Bu Ayki İşlemler',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 20),
                      ],
                    ),
                  ),
                ),
                if (transactions.isEmpty)
                  SliverFillRemaining(
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
                          
                          // ÜST DÜZEY AKILLI KATEGORİ EŞLEŞTİRME (V4 - ULTRA RESILIENT)
                          CategoryModel? txCategory;
                          final rawId = tx.categoryId?.trim() ?? '';

                          if (rawId.isNotEmpty) {
                            // 1. Aşama: Tam ID eşleşmesi (UUID veya def_id)
                            txCategory = categories.cast<CategoryModel?>().firstWhere(
                              (c) => c?.id == rawId,
                              orElse: () => null,
                            );

                            // 2. Aşama: Prefix-Agnostic eşleştirme (temp_ vs def_ karmaşasını çözer)
                            if (txCategory == null) {
                              final cleanId = rawId.replaceAll('def_', '').replaceAll('temp_', '').toLowerCase();
                              txCategory = categories.cast<CategoryModel?>().firstWhere(
                                (c) {
                                  final cid = c?.id.replaceAll('def_', '').replaceAll('temp_', '').toLowerCase();
                                  return cid == cleanId;
                                },
                                orElse: () => null,
                              );
                            }

                            // 3. Aşama: İsim üzerinden tam eşleşme (Legacy Name ID'ler için)
                            if (txCategory == null) {
                              txCategory = categories.cast<CategoryModel?>().firstWhere(
                                (c) => c?.name.toLowerCase().trim() == rawId.toLowerCase(),
                                orElse: () => null,
                              );
                            }
                          }

                          // 4. Aşama: GÖRÜNÜR İSİM OLUŞTURMA (Her şey başarısız olursa ID'den isim üret veya tip göster)
                          String displayName = tx.isIncome ? 'Genel Gelir' : 'Genel Gider';
                          if (txCategory != null) {
                            displayName = txCategory.name;
                          } else if (rawId.isNotEmpty) {
                            if (rawId.startsWith('def_') || rawId.startsWith('temp_')) {
                              // ID'den ismi kurtar: 'def_gıda_&_market' -> 'Gıda & Market'
                              final parts = rawId.split('_').skip(1).join(' ');
                              if (parts.isNotEmpty) {
                                displayName = parts[0].toUpperCase() + parts.substring(1);
                              }
                            } else if (!rawId.contains('-') && rawId.length < 20) {
                              // Eğer UUID değilse ve makul bir uzunluktaysa doğrudan ID'yi göster
                              displayName = rawId;
                            }
                          }

                          final displayCategory = txCategory ?? CategoryModel(
                            id: 'unknown',
                            name: displayName,
                            icon: tx.isIncome ? Icons.add_circle_outline : Icons.remove_circle_outline,
                            color: Colors.grey,
                            isIncome: tx.isIncome,
                          );

                          bool isNewMonth = false;
                          if (index == 0) {
                            isNewMonth = true;
                          } else {
                            final prevTx = transactions[index - 1];
                            if (tx.date.month != prevTx.date.month || tx.date.year != prevTx.date.year) {
                              isNewMonth = true;
                            }
                          }

                          final transactionItem = TransactionItem(
                            transaction: tx,
                            categoryIcon: displayCategory.icon,
                            categoryColor: displayCategory.color,
                            categoryName: displayCategory.name,
                            onTap: () => _showTransactionDetail(context, tx, displayCategory),
                            onEdit: (newAmount) {
                              ref.read(transactionNotifierProvider.notifier)
                                 .updateTransactionAmount(tx, newAmount);
                            },
                            onDelete: () {
                              ref.read(transactionNotifierProvider.notifier)
                                 .deleteTransaction(tx);
                            },
                          );

                          if (isNewMonth) {
                            // Example format: Nisan 2026
                            final monthName = DateFormat('MMMM yyyy', 'tr_TR').format(tx.date);
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Padding(
                                  padding: EdgeInsets.only(
                                    top: index == 0 ? 0 : 24, 
                                    bottom: 12, 
                                    left: 4
                                  ),
                                  child: Text(
                                    monthName,
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                ),
                                transactionItem,
                              ],
                            );
                          }

                          return transactionItem;
                        },
                        childCount: transactions.length,
                      ),
                    ),
                  ),
                const SliverToBoxAdapter(child: SizedBox(height: 100)),
              ],
            );
            },
          ),
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
