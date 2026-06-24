import 'package:drift/drift.dart' as drift;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:birikimly/core/database/database.dart';
import 'package:birikimly/core/theme/app_colors.dart';
import 'package:birikimly/features/categories/presentation/providers/category_provider.dart';
import 'package:birikimly/features/transactions/presentation/providers/transaction_provider.dart';
import 'package:birikimly/features/auth/presentation/providers/auth_provider.dart';
import 'package:birikimly/core/providers/preferences_provider.dart';
import 'package:birikimly/core/utils/currency_utils.dart';

class TransactionWizard extends ConsumerStatefulWidget {
  final bool isIncome;
  const TransactionWizard({super.key, required this.isIncome});

  @override
  ConsumerState<TransactionWizard> createState() => _TransactionWizardState();
}

class _TransactionWizardState extends ConsumerState<TransactionWizard> {
  final PageController _pageController = PageController();
  int _currentStep = 0;
  bool _isRecurring = false;
  String _frequency = 'monthly';

  // Form State
  final _amountController = TextEditingController();
  final _descriptionController = TextEditingController();
  DateTime _selectedDate = DateTime.now();
  String? _selectedCategoryId;
  late FocusNode _amountFocusNode;
  late FocusNode _descriptionFocusNode;

  // Recurring Installments State
  int _maxOccurrences = 12;
  String _occurrenceSelection = '12'; // '3', '6', '12', 'custom'
  final _occurrencesController = TextEditingController();
  late FocusNode _occurrencesFocusNode;
  String? _occurrencesError;
  String? _occurrencesWarning;

  @override
  void initState() {
    super.initState();
    _amountFocusNode = FocusNode();
    _descriptionFocusNode = FocusNode();
    _occurrencesFocusNode = FocusNode();
  }

  @override
  void dispose() {
    _pageController.dispose();
    _amountController.dispose();
    _descriptionController.dispose();
    _occurrencesController.dispose();
    _amountFocusNode.dispose();
    _descriptionFocusNode.dispose();
    _occurrencesFocusNode.dispose();
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
    
    final amountString = _amountController.text.replaceAll('.', '').replaceAll(',', '.');
    final amount = double.tryParse(amountString);
    if (amount == null || _selectedCategoryId == null) return;

    final categoriesAsync = ref.read(categoryProvider);
    final categories = categoriesAsync.asData?.value;
    if (categories == null) return;
    
    final category = categories.firstWhere(
      (c) => c.id == _selectedCategoryId,
      orElse: () => categories.first,
    );

    final isGuest = ref.read(guestModeProvider);
    final user = ref.read(currentUserProvider);
    
    if (!isGuest && user == null) return;
    
    final userId = isGuest ? 'guest' : user!.id;

    if (_isRecurring) {
      final now = DateTime.now();
      // Ensure the selected date is not in the past months
      final startOfMonth = DateTime(now.year, now.month, 1);
      if (_selectedDate.isBefore(startOfMonth)) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Düzenli işlemler yalnızca bulunduğumuz ay ve gelecek aylar için eklenebilir.'),
            backgroundColor: AppColors.expense,
          ),
        );
        return;
      }

      final isSelectedDateToday = _selectedDate.year == now.year &&
          _selectedDate.month == now.month &&
          _selectedDate.day == now.day;

      if (isSelectedDateToday) {
        // 1. Create the regular transaction for today immediately with current time
        final entry = TransactionsCompanion(
          userId: drift.Value(userId),
          amount: drift.Value(amount),
          categoryId: drift.Value(category.id),
          description: drift.Value(_descriptionController.text),
          date: drift.Value(now),
          isIncome: drift.Value(widget.isIncome),
          isSynced: const drift.Value(false),
          installmentNumber: drift.Value(_maxOccurrences != 100 ? 1 : null),
          totalInstallments: drift.Value(_maxOccurrences != 100 ? _maxOccurrences : null),
        );
        ref.read(transactionNotifierProvider.notifier).addTransaction(entry);

        // 2. Schedule the next execution for the next period at 12:00 PM
        final nextDate = _advanceDate(now, now, _frequency);
        final nextDateAtNoon = DateTime(nextDate.year, nextDate.month, nextDate.day, 12, 0, 0);

        final rtEntry = RecurringTransactionsCompanion(
          userId: drift.Value(userId),
          amount: drift.Value(amount),
          categoryId: drift.Value(category.id),
          description: drift.Value(_descriptionController.text),
          startDate: drift.Value(now),
          nextExecutionDate: drift.Value(nextDateAtNoon),
          isIncome: drift.Value(widget.isIncome),
          isSynced: const drift.Value(false),
          frequency: drift.Value(_frequency),
          isActive: drift.Value(_maxOccurrences > 1),
          maxOccurrences: drift.Value(_maxOccurrences),
          occurrencesExecuted: const drift.Value(1),
        );
        ref.read(transactionNotifierProvider.notifier).addRecurringTransaction(rtEntry);
      } else {
        // Schedule future recurring transaction at 12:00 PM
        final dateAtNoon = DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day, 12, 0, 0);
        final rtEntry = RecurringTransactionsCompanion(
          userId: drift.Value(userId),
          amount: drift.Value(amount),
          categoryId: drift.Value(category.id),
          description: drift.Value(_descriptionController.text),
          startDate: drift.Value(dateAtNoon),
          nextExecutionDate: drift.Value(dateAtNoon),
          isIncome: drift.Value(widget.isIncome),
          isSynced: const drift.Value(false),
          frequency: drift.Value(_frequency),
          isActive: const drift.Value(true),
          maxOccurrences: drift.Value(_maxOccurrences),
          occurrencesExecuted: const drift.Value(0),
        );
        ref.read(transactionNotifierProvider.notifier).addRecurringTransaction(rtEntry);
      }
    } else {
      final entry = TransactionsCompanion(
        userId: drift.Value(userId),
        amount: drift.Value(amount),
        categoryId: drift.Value(category.id),
        description: drift.Value(_descriptionController.text),
        date: drift.Value(_selectedDate),
        isIncome: drift.Value(widget.isIncome),
        isSynced: const drift.Value(false),
      );
      ref.read(transactionNotifierProvider.notifier).addTransaction(entry);
    }

    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    // Dynamically calculate the category step height based on category count and screen size
    final categoriesAsync = ref.watch(categoryProvider);
    final categoriesCount = categoriesAsync.when(
      data: (all) => all.where((c) => c.isIncome == widget.isIncome).length,
      loading: () => 4,
      error: (_, __) => 4,
    );
    final rows = (categoriesCount / 4).ceil();
    final screenWidth = MediaQuery.of(context).size.width;
    final gridWidth = (screenWidth - 40) - 32; // Dialog inset padding (40) + Step padding (32)
    final itemHeight = (gridWidth - 30) / 4; // 4 columns, 10px spacing
    final gridHeight = (rows * itemHeight) + ((rows - 1) * 10);
    final double categoryStepHeight = (16 + 22 + 12 + gridHeight + 16).clamp(130.0, 360.0);

    return PopScope(
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) FocusScope.of(context).unfocus();
      },
      child: Container(
        clipBehavior: Clip.antiAlias,
        width: double.infinity,
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.65,
        ),
        decoration: BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.circular(30),
          border: Border.all(color: AppColors.primary.withValues(alpha: 0.2), width: 1.5),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    widget.isIncome ? 'Gelir Ekle' : 'Gider Ekle',
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  Text(
                    '${_currentStep + 1} / 4',
                    style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
                  ),
                ],
              ),
            ),
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOut,
              height: _currentStep == 3 
                  ? categoryStepHeight 
                  : (_currentStep == 0 
                      ? (_isRecurring 
                          ? (_occurrenceSelection == 'custom' 
                              ? 370.0 
                              : 310.0) 
                          : 130.0)
                      : 130.0),
              child: PageView(
                controller: _pageController,
                onPageChanged: (int step) async {
                  setState(() => _currentStep = step);
                  FocusScope.of(context).unfocus();
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
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Miktarı Girin',
                style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Düzenli',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textSecondary),
                  ),
                  const SizedBox(width: 4),
                  GestureDetector(
                    onTap: () {
                      showDialog(
                        context: context,
                        builder: (context) => AlertDialog(
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                          backgroundColor: AppColors.background,
                          title: Row(
                            children: [
                              Icon(Icons.info_outline, color: AppColors.primary),
                              const SizedBox(width: 8),
                              const Text(
                                'Düzenli İşlem Nedir?',
                                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                          content: Text(
                            'Bu seçeneği aktif ettiğinizde; girdiğiniz tutar, kategori ve açıklama, her ay seçtiğiniz işlem gününde otomatik olarak eklenir.\n\nGeçmiş tarihler için düzenli işlem oluşturulamaz.',
                            style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context),
                              child: Text('Anladım', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary)),
                            ),
                          ],
                        ),
                      );
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Icon(
                        Icons.info_outline,
                        size: 14,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Transform.scale(
                    scale: 0.8,
                    child: Switch(
                      value: _isRecurring,
                      activeColor: AppColors.primary,
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      onChanged: (val) => setState(() => _isRecurring = val),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            focusNode: _amountFocusNode,
            controller: _amountController,
            autofocus: true,
            keyboardType: TextInputType.number,
            inputFormatters: [ThousandsFormatter()],
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: AppColors.primary),
            decoration: InputDecoration(
              prefixText: '₺ ',
              prefixStyle: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppColors.primary),
              border: InputBorder.none,
              contentPadding: EdgeInsets.zero,
            ),
          ),
          if (_isRecurring) ...[
            const SizedBox(height: 12),
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'weekly', label: Text('Haftalık', style: TextStyle(fontSize: 12))),
                ButtonSegment(value: 'monthly', label: Text('Aylık', style: TextStyle(fontSize: 12))),
                ButtonSegment(value: 'yearly', label: Text('Yıllık', style: TextStyle(fontSize: 12))),
              ],
              selected: {_frequency},
              onSelectionChanged: (Set<String> newSelection) {
                final newFreq = newSelection.first;
                setState(() {
                  _frequency = newFreq;
                  if (newFreq == 'weekly') {
                    _occurrenceSelection = '4';
                    _maxOccurrences = 4;
                  } else if (newFreq == 'yearly') {
                    _occurrenceSelection = '1';
                    _maxOccurrences = 1;
                  } else {
                    _occurrenceSelection = '12';
                    _maxOccurrences = 12;
                  }
                });
              },
              style: ButtonStyle(
                backgroundColor: WidgetStateProperty.resolveWith<Color>(
                  (Set<WidgetState> states) {
                    if (states.contains(WidgetState.selected)) {
                      return AppColors.primary.withValues(alpha: 0.1);
                    }
                    return Colors.transparent;
                  },
                ),
                foregroundColor: WidgetStateProperty.resolveWith<Color>(
                  (Set<WidgetState> states) {
                    if (states.contains(WidgetState.selected)) {
                      return AppColors.primary;
                    }
                    return AppColors.textSecondary;
                  },
                ),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Geçerlilik Süresi (Taksit)',
                  style: TextStyle(fontSize: 13, color: AppColors.textSecondary, fontWeight: FontWeight.w500),
                ),
                Builder(
                  builder: (context) {
                    final endDate = _calculateEndDate(_selectedDate, _frequency, _maxOccurrences);
                    final formattedEndDate = DateFormat('MMMM yyyy', 'tr_TR').format(endDate);
                    return Text(
                      'Tahmini Bitiş: $formattedEndDate',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.primary),
                    );
                  },
                ),
              ],
            ),
            const SizedBox(height: 8),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Builder(
                builder: (context) {
                  final List<String> values;
                  if (_frequency == 'weekly') {
                    values = ['4', '26', '52'];
                  } else if (_frequency == 'yearly') {
                    values = ['1', '3', '5'];
                  } else {
                    values = ['3', '6', '12'];
                  }
                  
                  return Row(
                    children: [
                      ...values.map((v) => Padding(
                        padding: const EdgeInsets.only(right: 8.0),
                        child: _buildLimitChip(v, '$v ${_getFreqSuffix()}'),
                      )),
                      _buildLimitChip('custom', 'Özel'),
                    ],
                  );
                },
              ),
            ),
            if (_occurrenceSelection == 'custom') ...[
              const SizedBox(height: 10),
              SizedBox(
                height: 40,
                child: TextField(
                  focusNode: _occurrencesFocusNode,
                  controller: _occurrencesController,
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                  ],
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                  decoration: InputDecoration(
                    hintText: 'Taksit/Tekrar sayısı girin...',
                    hintStyle: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: _occurrencesError != null 
                            ? AppColors.expense 
                            : AppColors.primary.withValues(alpha: 0.2)
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: _occurrencesError != null 
                            ? AppColors.expense 
                            : AppColors.primary
                      ),
                    ),
                  ),
                  onChanged: (val) {
                    final num = int.tryParse(val);
                    if (val.isEmpty) {
                      setState(() {
                        _occurrencesError = 'Lütfen bir sayı girin.';
                        _occurrencesWarning = null;
                      });
                    } else if (num == null || num <= 0) {
                      setState(() {
                        _occurrencesError = 'Geçerli bir pozitif sayı girin.';
                        _occurrencesWarning = null;
                      });
                    } else if (num > 100) {
                      _occurrencesController.text = '100';
                      _occurrencesController.selection = TextSelection.fromPosition(
                        TextPosition(offset: _occurrencesController.text.length),
                      );
                      setState(() {
                        _occurrencesError = null;
                        _occurrencesWarning = 'En fazla 100 tekrar girilebilir.';
                        _maxOccurrences = 100;
                      });
                    } else {
                      setState(() {
                        _occurrencesError = null;
                        _occurrencesWarning = null;
                        _maxOccurrences = num;
                      });
                    }
                  },
                ),
              ),
              if (_occurrencesError != null || _occurrencesWarning != null) ...[
                const SizedBox(height: 4),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Row(
                    children: [
                      Icon(
                        Icons.error_outline, 
                        size: 14, 
                        color: AppColors.expense
                      ),
                      const SizedBox(width: 6),
                      Text(
                        _occurrencesError ?? _occurrencesWarning!,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: AppColors.expense,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ],
          ],
        ),
      ),
    );
  }

  Widget _buildDateStep() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
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
                  Icon(Icons.calendar_today, color: AppColors.primary),
                  const SizedBox(width: 12),
                  Text(
                    DateFormat('dd MMMM yyyy', 'tr_TR').format(_selectedDate),
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDescriptionStep() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            'Açıklama Ekleyin',
            style: TextStyle(fontSize: 16, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 12),
          TextField(
            focusNode: _descriptionFocusNode,
            controller: _descriptionController,
            maxLines: 1,
            decoration: InputDecoration(
              hintText: 'Harcama veya gelir detayı...',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openDatePicker() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2026, 1, 1),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      locale: const Locale('tr', 'TR'),
    );
    if (date != null) {
      final now = DateTime.now();
      setState(() {
        _selectedDate = DateTime(
          date.year,
          date.month,
          date.day,
          now.hour,
          now.minute,
          now.second,
        );
      });
    }
  }

  Widget _buildCategoryStep() {
    final categoriesAsync = ref.watch(categoryProvider);

    return categoriesAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, s) => Center(child: Text('Kategoriler Hatası: $e')),
      data: (allCategories) {
        final categories = allCategories.where((c) => c.isIncome == widget.isIncome).toList();
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: SingleChildScrollView(
            child: Column(
              children: [
                Text(
                  'Kategori Seçin ve Kaydedin',
                  style: TextStyle(fontSize: 18, color: AppColors.textSecondary),
                ),
                const SizedBox(height: 12),
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 4,
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10,
                    childAspectRatio: 1.0,
                  ),
                  itemCount: categories.length,
                  itemBuilder: (context, index) {
                    final cat = categories[index];
                    final isSelected = _selectedCategoryId == cat.id;
                    return GestureDetector(
                      onTap: () => setState(() => _selectedCategoryId = cat.id),
                      child: Container(
                        decoration: BoxDecoration(
                          color: isSelected ? cat.color.withValues(alpha: 0.1) : AppColors.surface,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isSelected ? cat.color : Colors.transparent,
                            width: 2,
                          ),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(cat.icon, color: isSelected ? cat.color : AppColors.textSecondary, size: 22),
                            const SizedBox(height: 4),
                            Text(
                              cat.name,
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                color: isSelected ? cat.color : AppColors.textSecondary,
                              ),
                              textAlign: TextAlign.center,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 12),
              ],
            ),
          ),
        );
      },
    );
  }



  Widget _buildNavigation() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
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
                if (_currentStep == 0 && _isRecurring && _occurrenceSelection == 'custom' && _occurrencesError != null) return;
                if (_currentStep == 3) {
                  if (_selectedCategoryId == null) return;
                  _submit();
                } else {
                  _nextStep();
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: (_currentStep == 3 && _selectedCategoryId == null) ||
                                 (_currentStep == 0 && _isRecurring && _occurrenceSelection == 'custom' && _occurrencesError != null)
                    ? Colors.grey
                    : AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: Text(
                _currentStep == 3 ? 'Onayla ve Kaydet' : 'Devam Et',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }

  DateTime _calculateEndDate(DateTime start, String freq, int maxOccs) {
    DateTime date = start;
    for (int i = 0; i < maxOccs - 1; i++) {
      date = _advanceDate(date, start, freq);
    }
    return date;
  }

  String _getFreqSuffix() {
    if (_frequency == 'weekly') {
      return 'Hafta';
    } else if (_frequency == 'yearly') {
      return 'Yıl';
    } else {
      return 'Ay';
    }
  }

  Widget _buildLimitChip(String val, String label) {
    final isSelected = _occurrenceSelection == val;
    return ChoiceChip(
      label: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          color: isSelected ? Colors.white : AppColors.textSecondary,
        ),
      ),
      selected: isSelected,
      selectedColor: AppColors.primary,
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(
          color: isSelected ? Colors.transparent : AppColors.primary.withValues(alpha: 0.15),
        ),
      ),
      showCheckmark: false,
      onSelected: (selected) {
        if (selected) {
          setState(() {
            _occurrenceSelection = val;
            _occurrencesError = null;
            _occurrencesWarning = null;
            if (val == 'custom') {
              if (_occurrencesController.text.isEmpty) {
                _occurrencesController.text = _maxOccurrences.toString();
              }
              _maxOccurrences = int.tryParse(_occurrencesController.text) ?? 12;
              FocusScope.of(context).requestFocus(_occurrencesFocusNode);
            } else {
              _maxOccurrences = int.parse(val);
              FocusScope.of(context).unfocus();
            }
          });
        }
      },
    );
  }

  DateTime _advanceDate(DateTime current, DateTime originalStart, String frequency) {
    switch (frequency) {
      case 'weekly':
        return current.add(const Duration(days: 7));
      case 'yearly':
        return _advanceOneYear(current, originalStart);
      case 'monthly':
      default:
        return _advanceOneMonth(current, originalStart);
    }
  }

  DateTime _advanceOneMonth(DateTime current, DateTime originalStart) {
    int nextMonth = current.month + 1;
    int nextYear = current.year;
    
    if (nextMonth > 12) {
      nextMonth = 1;
      nextYear++;
    }

    final targetDay = originalStart.day;
    final maxDaysInNextMonth = DateTime(nextYear, nextMonth + 1, 0).day;
    final clampedDay = targetDay > maxDaysInNextMonth ? maxDaysInNextMonth : targetDay;

    return DateTime(
      nextYear,
      nextMonth,
      clampedDay,
      originalStart.hour,
      originalStart.minute,
      originalStart.second,
    );
  }

  DateTime _advanceOneYear(DateTime current, DateTime originalStart) {
    int nextYear = current.year + 1;
    int nextMonth = current.month;
    
    final targetDay = originalStart.day;
    final maxDaysInNextMonth = DateTime(nextYear, nextMonth + 1, 0).day;
    final clampedDay = targetDay > maxDaysInNextMonth ? maxDaysInNextMonth : targetDay;

    return DateTime(
      nextYear,
      nextMonth,
      clampedDay,
      originalStart.hour,
      originalStart.minute,
      originalStart.second,
    );
  }
}
