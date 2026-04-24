import 'package:drift/drift.dart' as drift;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:birikimly/core/database/database.dart';
import 'package:birikimly/core/theme/app_colors.dart';
import 'package:birikimly/features/categories/presentation/providers/category_provider.dart';
import 'package:birikimly/features/transactions/presentation/providers/transaction_provider.dart';
import 'package:birikimly/features/auth/presentation/providers/auth_provider.dart';
import 'package:birikimly/core/providers/preferences_provider.dart';

class QuickAddForm extends ConsumerStatefulWidget {
  const QuickAddForm({super.key});

  @override
  ConsumerState<QuickAddForm> createState() => _QuickAddFormState();
}

class _QuickAddFormState extends ConsumerState<QuickAddForm> {
  final _amountController = TextEditingController();
  final _descriptionController = TextEditingController();
  bool _isIncome = false;
  String? _selectedCategoryId;

  @override
  void dispose() {
    _amountController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  void _submit() {
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
      date: drift.Value(DateTime.now()),
      isIncome: drift.Value(_isIncome),
      isSynced: const drift.Value(false),
    );

    ref.read(transactionNotifierProvider.notifier).addTransaction(entry);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final categories = ref.watch(categoryProvider);

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        left: 24,
        right: 24,
        top: 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Expanded(
                child: Text(
                  'Yeni İşlem',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(width: 8),
              ToggleButtons(
                constraints: const BoxConstraints(minHeight: 40),
                borderRadius: BorderRadius.circular(12),
                isSelected: [!_isIncome, _isIncome],
                onPressed: (index) {
                  setState(() {
                    _isIncome = index == 1;
                  });
                },
                children: const [
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 12),
                    child: Text('Gider'),
                  ),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 12),
                    child: Text('Gelir'),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 24),
          TextField(
            controller: _amountController,
            keyboardType: TextInputType.number,
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            decoration: InputDecoration(
              labelText: 'Miktar',
              prefixText: '₺ ',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
          const SizedBox(height: 20),
          const Text('Kategori Seç',
              style: TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 12),
          SizedBox(
            height: 100,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: categories.length,
              itemBuilder: (context, index) {
                final category = categories[index];
                final isSelected = _selectedCategoryId == category.id;
                return GestureDetector(
                  onTap: () {
                    setState(() {
                      _selectedCategoryId = category.id;
                    });
                  },
                  child: Container(
                    width: 70,
                    margin: const EdgeInsets.only(right: 12),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? category.color.withValues(alpha: 0.2)
                          : AppColors.surface,
                      borderRadius: BorderRadius.circular(16),
                      border: isSelected
                          ? Border.all(color: category.color, width: 2)
                          : null,
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(category.icon,
                            color: isSelected ? category.color : Colors.grey),
                        const SizedBox(height: 4),
                        Text(
                          category.name,
                          style: TextStyle(
                            fontSize: 10,
                            color: isSelected ? category.color : Colors.grey,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 20),
          TextField(
            controller: _descriptionController,
            decoration: InputDecoration(
              labelText: 'Açıklama (Opsiyonel)',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: _submit,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              minimumSize: const Size(double.infinity, 56),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            child: const Text('Kaydet',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}
