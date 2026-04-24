import 'package:drift/drift.dart' as drift;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:birikimly/core/database/database.dart';
import 'package:birikimly/core/theme/app_colors.dart';
import 'package:birikimly/features/categories/presentation/providers/category_provider.dart';
import 'package:birikimly/features/transactions/presentation/providers/transaction_provider.dart';
import 'package:birikimly/features/auth/presentation/providers/auth_provider.dart';
import 'package:birikimly/core/providers/preferences_provider.dart';

class TransactionWizard extends ConsumerStatefulWidget {
  final bool isIncome;
  const TransactionWizard({super.key, required this.isIncome});

  @override
  ConsumerState<TransactionWizard> createState() => _TransactionWizardState();
}

class _TransactionWizardState extends ConsumerState<TransactionWizard> {
  final PageController _pageController = PageController();
  int _currentStep = 0;

  // Form State
  final _amountController = TextEditingController();
  final _descriptionController = TextEditingController();
  DateTime _selectedDate = DateTime.now();
  String? _selectedCategoryId;
  late FocusNode _amountFocusNode;
  late FocusNode _descriptionFocusNode;

  @override
  void initState() {
    super.initState();
    _amountFocusNode = FocusNode();
    _descriptionFocusNode = FocusNode();
    // Re-enable post-frame focus request for better sync with bottom sheet animation
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _amountFocusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    _amountController.dispose();
    _descriptionController.dispose();
    _amountFocusNode.dispose();
    _descriptionFocusNode.dispose();
    super.dispose();
  }

  void _nextStep() async {
    // Hide keyboard before moving to next page
    FocusScope.of(context).unfocus();
    if (_currentStep < 3) {
      await _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  void _previousStep() {
    if (_currentStep > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  void _submit() {
    // Ensure keyboard is closed
    FocusScope.of(context).unfocus();
    
    final amount = double.tryParse(_amountController.text);
    if (amount == null || _selectedCategoryId == null) return;

    final categories = ref.read(categoryProvider);
    final category = categories.firstWhere((c) => c.id == _selectedCategoryId);

    final isGuest = ref.read(guestModeProvider);
    final user = ref.read(currentUserProvider);
    
    if (!isGuest && user == null) return;
    
    final userId = isGuest ? 'guest' : user!.id;

    final entry = TransactionsCompanion(
      userId: drift.Value(userId),
      amount: drift.Value(amount),
      category: drift.Value(category.name),
      description: drift.Value(_descriptionController.text),
      date: drift.Value(_selectedDate),
      isIncome: drift.Value(widget.isIncome),
      isSynced: const drift.Value(false),
    );

    ref.read(transactionNotifierProvider.notifier).addTransaction(entry);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) FocusScope.of(context).unfocus();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.fastOutSlowIn,
        clipBehavior: Clip.antiAlias,
        height: (MediaQuery.of(context).size.height * 
                (_currentStep == 0 ? 0.42 : (_currentStep == 3 ? 0.65 : 0.5))) + 
                MediaQuery.of(context).viewInsets.bottom,
      decoration: const BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
      ),
      child: Column(
        children: [
          const SizedBox(height: 12),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.textSecondary.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 10),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  widget.isIncome ? 'Gelir Ekle' : 'Gider Ekle',
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                Text(
                  '${_currentStep + 1} / 4',
                  style: const TextStyle(color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Expanded(
            child: PageView(
              controller: _pageController,
              onPageChanged: (int step) async {
                setState(() => _currentStep = step);
                // Close any open keyboard
                FocusScope.of(context).unfocus();
                if (step == 1) {
                  // Otomatik takvim açılışı kaldırıldı. Kullanıcı tıklayarak açacak.
                }
              },
              physics: const NeverScrollableScrollPhysics(),
              children: [
                _buildAmountStep(),
                _buildDateStep(),
                _buildDescriptionStep(),
                _buildCategoryStep(),
              ],
            ),
          ),
          _buildNavigation(),
        ],
      ),
    ),
  );
}

  Widget _buildAmountStep() {
    return SingleChildScrollView(
      physics: const NeverScrollableScrollPhysics(),
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              'Miktarı Girin',
              style: TextStyle(fontSize: 18, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 8),
            TextField(
              focusNode: _amountFocusNode,
              controller: _amountController,
              keyboardType: TextInputType.number,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 42, fontWeight: FontWeight.bold, color: AppColors.primary),
              decoration: const InputDecoration(
                prefixText: '₺ ',
                border: InputBorder.none,
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDateStep() {
    return SingleChildScrollView(
      physics: const NeverScrollableScrollPhysics(),
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              'İşlem Tarihi',
              style: TextStyle(fontSize: 18, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 16),
            GestureDetector(
            onTap: _openDatePicker,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.calendar_today, color: AppColors.primary),
                  const SizedBox(width: 12),
                  Text(
                    DateFormat('dd MMMM yyyy').format(_selectedDate),
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

  Widget _buildDescriptionStep() {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: SingleChildScrollView(
        reverse: true,
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              'Açıklama Ekleyin',
              style: TextStyle(fontSize: 18, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 24),
            TextField(
              focusNode: _descriptionFocusNode,
              controller: _descriptionController,
              maxLines: 4,
              decoration: InputDecoration(
                hintText: 'Harcama veya gelir detayı...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
// Opens the date picker automatically for the date step
Future<void> _openDatePicker() async {
  final date = await showDatePicker(
    context: context,
    initialDate: _selectedDate,
    firstDate: DateTime(2026, 1, 1),
    lastDate: DateTime.now().add(const Duration(days: 365)),
  );
  if (date != null) {
    setState(() => _selectedDate = date);
  }
}
  Widget _buildCategoryStep() {
    final categories = ref.watch(categoryProvider);
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        children: [
          const Text(
            'Kategori Seçin ve Kaydedin',
            style: TextStyle(fontSize: 18, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 20),
          Expanded(
            child: GridView.builder(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 1,
              ),
              itemCount: categories.length,
              itemBuilder: (context, index) {
                final category = categories[index];
                final isSelected = _selectedCategoryId == category.id;
                return GestureDetector(
                  onTap: () {
                    setState(() => _selectedCategoryId = category.id);
                    _submit(); // Final step
                  },
                  child: Container(
                    decoration: BoxDecoration(
                      color: isSelected
                          ? category.color.withValues(alpha: 0.2)
                          : AppColors.surface,
                      borderRadius: BorderRadius.circular(20),
                      border: isSelected
                          ? Border.all(color: category.color, width: 2)
                          : null,
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(category.icon,
                            color: isSelected ? category.color : Colors.grey, size: 32),
                        const SizedBox(height: 8),
                        Text(
                          category.name,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                            color: isSelected ? category.color : Colors.grey,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNavigation() {
    if (_currentStep == 3) return const SizedBox.shrink(); // Last step handles submission

    return Padding(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        bottom: 24 + MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Row(
        children: [
          if (_currentStep > 0)
            Expanded(
              child: OutlinedButton(
                onPressed: _previousStep,
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: const Text('Geri'),
              ),
            ),
          if (_currentStep > 0) const SizedBox(width: 12),
          Expanded(
            flex: 2,
            child: ElevatedButton(
              onPressed: () {
                if (_currentStep == 0 && _amountController.text.isEmpty) return;
                _nextStep();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: const Text('Devam Et', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }
}
