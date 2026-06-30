import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:birikimly/core/utils/currency_utils.dart';
import 'package:birikimly/core/theme/app_colors.dart';
import 'package:birikimly/core/providers/theme_provider.dart';
import 'package:birikimly/features/auth/presentation/providers/auth_provider.dart';
import 'package:birikimly/core/services/supabase_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:birikimly/features/categories/presentation/providers/category_provider.dart';
import 'package:birikimly/features/categories/domain/models/category_model.dart';
import 'package:birikimly/core/providers/preferences_provider.dart';
import 'package:birikimly/core/database/database.dart';

import 'package:drift/drift.dart' as drift;
import 'package:intl/intl.dart';

String _formatLimit(double val) {
  return NumberFormat('#,##0', 'en_US').format(val).replaceAll(',', '.');
}

class ProfileScreen extends ConsumerStatefulWidget {
  final PageController pageController;
  const ProfileScreen({super.key, required this.pageController});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> with TickerProviderStateMixin {
  @override
  Widget build(BuildContext context) {
    final pageController = widget.pageController;
    final categories = ref.watch(categoryProvider);
    final isGuest = ref.watch(guestModeProvider);
    final customName = ref.watch(userNameProvider);
    final user = ref.watch(currentUserProvider);

    final metaName = user?.userMetadata?['display_name']?.toString();
    
    String displayName = isGuest
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

    return categories.when(
      loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, s) => Scaffold(body: Center(child: Text('Hata: $e'))),
      data: (categoriesList) {
        final incomeCategories = categoriesList.where((c) => c.isIncome).toList();
        final expenseCategories = categoriesList.where((c) => !c.isIncome).toList();

        return Scaffold(
          backgroundColor: AppColors.background,
          appBar: AppBar(
            title: const Text('Profil'),
            leading: Navigator.of(context).canPop()
                ? null
                : IconButton(
                    icon: const Icon(Icons.arrow_back),
                    onPressed: () => pageController.animateToPage(
                      0,
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeInOut,
                    ),
                  ),
            actions: [
              IconButton(
                icon: const Icon(Icons.palette_outlined),
                onPressed: () => _showThemeSelectionSheet(context, ref),
              ),
            ],
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                // User Avatar & Name
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Column(
                    children: [
                      CircleAvatar(
                        radius: 40,
                        backgroundColor: AppColors.primary,
                        child: const Icon(Icons.person, size: 40, color: Colors.white),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            displayName,
                            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                          ),
                          IconButton(
                            icon: const Icon(Icons.edit, size: 20),
                            onPressed: () => _showEditNameDialog(context, ref, displayName),
                          ),
                        ],
                      ),
                      Text(
                        isGuest ? 'Misafir Modu' : (user?.email ?? ''),
                        style: TextStyle(color: AppColors.textSecondary),
                      ),
                      const SizedBox(height: 12),
                      InkWell(
                        onTap: () => _showEditLimitDialog(context, ref, monthlyLimit),
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          decoration: BoxDecoration(
                            color: AppColors.background,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.teal.withValues(alpha: 0.25)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.speed, size: 16, color: Colors.teal),
                              const SizedBox(width: 8),
                              Text(
                                monthlyLimit != null 
                                    ? 'Aylık Limit: ${_formatLimit(monthlyLimit)} ₺'
                                    : 'Aylık Limit Belirle',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  color: Colors.teal,
                                  fontSize: 14,
                                ),
                              ),
                              const SizedBox(width: 4),
                              const Icon(Icons.edit, size: 14, color: Colors.teal),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),

                // Income Categories
                _buildCategorySection(
                  context,
                  ref,
                  title: 'Gelir Kategorileri',
                  categories: incomeCategories,
                  isIncome: true,
                ),
                const SizedBox(height: 24),

                // Expense Categories
                _buildCategorySection(
                  context,
                  ref,
                  title: 'Gider Kategorileri',
                  categories: expenseCategories,
                  isIncome: false,
                  totalCategoryLimit: expenseCategories.fold<double>(0.0, (sum, cat) => sum + (cat.maxLimit ?? 0.0)),
                  monthlyLimit: monthlyLimit,
                ),
                const SizedBox(height: 48),

                // Logout Button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () => _showLogoutConfirm(context, ref, isGuest),
                    icon: const Icon(Icons.logout),
                    label: const Text('Çıkış Yap', style: TextStyle(fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.expense.withValues(alpha: 0.1),
                      foregroundColor: AppColors.expense,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                        side: BorderSide(color: AppColors.expense, width: 1.5),
                      ),
                      elevation: 0,
                    ),
                  ),
                ),
                if (!isGuest) ...[
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: TextButton.icon(
                      onPressed: () => _showDeleteAccountConfirm(context, ref),
                      icon: Icon(Icons.delete_forever, color: AppColors.expense),
                      label: Text(
                        'Hesabımı Kalıcı Olarak Sil',
                        style: TextStyle(
                          color: AppColors.expense,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 24),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildCategorySection(
    BuildContext context,
    WidgetRef ref, {
    required String title,
    required List<CategoryModel> categories,
    required bool isIncome,
    double? totalCategoryLimit,
    double? monthlyLimit,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                if (!isIncome && totalCategoryLimit != null && totalCategoryLimit > 0)
                  Padding(
                    padding: const EdgeInsets.only(top: 4.0),
                    child: Text(
                      'Toplam Limit: ${_formatLimit(totalCategoryLimit)} ₺' + 
                      (monthlyLimit != null ? ' / ${_formatLimit(monthlyLimit)} ₺' : ''),
                      style: TextStyle(fontSize: 13, color: AppColors.textSecondary, fontWeight: FontWeight.w500),
                    ),
                  ),
              ],
            ),
            IconButton(
              icon: Icon(Icons.add_circle, color: AppColors.primary),
              onPressed: () => _showAddCategoryDialog(context, ref, isIncome),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ReorderableListView(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          buildDefaultDragHandles: false,
          proxyDecorator: (Widget child, int index, Animation<double> animation) {
            return AnimatedBuilder(
              animation: animation,
              builder: (BuildContext context, Widget? child) {
                final double animValue = Curves.easeInOut.transform(animation.value);
                return Transform.scale(
                  scale: 1.0 + (animValue * 0.03),
                  child: Material(
                    color: Colors.transparent,
                    elevation: animValue * 10,
                    shadowColor: AppColors.primary.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(16),
                    child: child,
                  ),
                );
              },
              child: child,
            );
          },
          onReorder: (oldIndex, newIndex) {
            ref.read(categoryProvider.notifier).reorderCategories(oldIndex, newIndex, isIncome);
          },
          children: categories.asMap().entries.map((entry) => 
            _buildCategoryTile(context, ref, entry.value, entry.key)
          ).toList(),
        ),
      ],
    );
  }

  Widget _buildCategoryTile(BuildContext context, WidgetRef ref, CategoryModel cat, int index) {
    bool isPressed = false;
    return StatefulBuilder(
      key: ValueKey(cat.id),
      builder: (context, setState) {
        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(16),
            border: isPressed 
                ? Border.all(color: AppColors.primary, width: 2) 
                : Border.all(color: Colors.transparent, width: 2),
          ),
          child: ListTile(
            leading: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Listener(
                  onPointerDown: (_) => setState(() => isPressed = true),
                  onPointerUp: (_) => setState(() => isPressed = false),
                  onPointerCancel: (_) => setState(() => isPressed = false),
                  child: ReorderableDragStartListener(
                    index: index,
                    child: Container(
                      color: Colors.transparent, // Ensures the touch area is large enough
                      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
                      child: const Icon(Icons.drag_handle, color: Colors.grey),
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                Icon(cat.icon, color: cat.color),
              ],
            ),
            title: Text(cat.name),
            subtitle: (cat.maxLimit != null && !cat.isIncome)
                ? Text(
                    'Limit: ${_formatLimit(cat.maxLimit!)} ₺',
                    style: TextStyle(fontSize: 12, color: AppColors.textSecondary, fontWeight: FontWeight.w500),
                  )
                : null,
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.edit, size: 20),
                  onPressed: () => _showRenameDialog(context, ref, cat),
                ),
                IconButton(
                  icon: Icon(Icons.delete_outline, size: 20, color: AppColors.expense),
                  onPressed: () => _showDeleteConfirm(context, ref, cat),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  static const List<IconData> _availableIcons = [
    Icons.restaurant, Icons.shopping_bag, Icons.directions_car, 
    Icons.videogame_asset, Icons.home, Icons.account_balance_wallet, 
    Icons.trending_up, Icons.fitness_center, Icons.medical_services, 
    Icons.school, Icons.flight, Icons.local_gas_station, 
    Icons.coffee, Icons.pets, Icons.celebration, Icons.work, 
    Icons.phone_android, Icons.subscriptions, Icons.movie, 
    Icons.brush, Icons.shopping_cart, Icons.build, 
    Icons.child_care, Icons.electric_bolt, Icons.water_drop,
    Icons.fastfood, Icons.local_mall, Icons.sports_esports, 
    Icons.health_and_safety, Icons.savings, Icons.receipt_long,
    Icons.card_giftcard, Icons.currency_exchange, Icons.face_retouching_natural, Icons.payments,
  ];

  static const List<Color> _curatedColors = [
    Colors.blue, Colors.indigo, Colors.deepPurple, Colors.pink,
    Colors.red, Colors.deepOrange, Colors.orange, Colors.amber,
    Colors.teal, Colors.cyan, Colors.green, Colors.lightGreen,
    Colors.lime, Colors.blueGrey, Colors.brown,
  ];

  void _showThemeSelectionSheet(BuildContext context, WidgetRef ref) {
    final activePreset = ref.read(themeProvider);

    final animationController = BottomSheet.createAnimationController(this);
    animationController.duration = const Duration(milliseconds: 400);
    animationController.reverseDuration = const Duration(milliseconds: 900);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      transitionAnimationController: animationController,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
          ),
          child: SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header (Non-scrollable to allow drag dismissal)
                Stack(
                  children: [
                    Align(
                      alignment: Alignment.center,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const SizedBox(height: 12),
                          // Drag Handle
                          Container(
                            width: 40,
                            height: 4,
                            decoration: BoxDecoration(
                              color: Colors.grey.withValues(alpha: 0.3),
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            'Görünüm Teması',
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Uygulamanın renk temasını değiştirerek kişiselleştirin.',
                            style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                    Positioned(
                      right: 12,
                      top: 16,
                      child: IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                // Scrollable Grid
                Flexible(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                    child: GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        crossAxisSpacing: 16,
                        mainAxisSpacing: 16,
                        childAspectRatio: 2.2,
                      ),
                      itemCount: AppThemePreset.values.length,
                      itemBuilder: (context, index) {
                        final preset = AppThemePreset.values[index];
                        final palette = preset.palette;
                        final isSelected = preset == activePreset;

                        return InkWell(
                          onTap: () {
                            ref.read(themeProvider.notifier).setPreset(preset);
                            Navigator.pop(context);
                          },
                          borderRadius: BorderRadius.circular(16),
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: palette.background,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: isSelected 
                                    ? palette.primary 
                                    : palette.surface.withValues(alpha: 0.5),
                                width: isSelected ? 2.5 : 1,
                              ),
                              boxShadow: isSelected ? [
                                BoxShadow(
                                  color: palette.primary.withValues(alpha: 0.25),
                                  blurRadius: 8,
                                  spreadRadius: 1,
                                )
                              ] : null,
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text(
                                        preset.displayName,
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.bold,
                                          color: palette.textPrimary,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 6),
                                      Row(
                                        children: [
                                          Container(
                                            width: 12,
                                            height: 12,
                                            decoration: BoxDecoration(
                                              color: palette.primary,
                                              shape: BoxShape.circle,
                                            ),
                                          ),
                                          const SizedBox(width: 4),
                                          Container(
                                            width: 12,
                                            height: 12,
                                            decoration: BoxDecoration(
                                              color: palette.secondary,
                                              shape: BoxShape.circle,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                if (isSelected)
                                  Icon(
                                   Icons.check_circle,
                                    color: palette.primary,
                                    size: 20,
                                  ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showEditNameDialog(BuildContext context, WidgetRef ref, String currentName) {
    final controller = TextEditingController(text: currentName);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        alignment: Alignment.topCenter,
        insetPadding: const EdgeInsets.only(top: 40, left: 20, right: 20),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: BorderSide(color: AppColors.primary.withValues(alpha: 0.2), width: 1.5),
        ),
        title: const Text('İsmini Değiştir'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(hintText: 'Yeni isminiz'),
          autofocus: true,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('İptal')),
          TextButton(
            onPressed: () {
              final newName = controller.text.trim();
              if (newName.isNotEmpty) {
                ref.read(userNameProvider.notifier).setUserName(newName);
                ref.read(authNotifierProvider.notifier).updateDisplayName(newName);
              }
              Navigator.pop(context);
            },
            child: const Text('Kaydet'),
          ),
        ],
      ),
    );
  }

  void _showColorPicker(BuildContext context, Color currentColor, Function(Color) onSelected) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.only(top: 8, left: 24, right: 24, bottom: 24),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(vertical: 16),
              width: double.infinity,
              alignment: Alignment.center,
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const Text('Renk Seçin', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 5,
                mainAxisSpacing: 16,
                crossAxisSpacing: 16,
              ),
              itemCount: _curatedColors.length,
              itemBuilder: (context, index) {
                final color = _curatedColors[index];
                final isSelected = color.value == currentColor.value;
                return InkWell(
                  onTap: () {
                    onSelected(color);
                    Navigator.pop(context);
                  },
                  borderRadius: BorderRadius.circular(50),
                  child: Container(
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                      border: isSelected ? Border.all(color: Colors.white, width: 3) : null,
                      boxShadow: isSelected ? [
                        BoxShadow(color: color.withValues(alpha: 0.4), blurRadius: 10, spreadRadius: 2)
                      ] : null,
                    ),
                    child: isSelected ? const Icon(Icons.check, color: Colors.white) : null,
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showIconPicker(BuildContext context, Color themeColor, IconData currentIcon, Function(IconData) onSelected) {
    bool isExpanded = false;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          // Calculate the exact height the grid needs when fully expanded
          final screenWidth = MediaQuery.of(context).size.width;
          final iconWidth = (screenWidth - 48 - (4 * 16)) / 5;
          final rows = (_availableIcons.length / 5).ceil();
          final expandedGridHeight = (rows * iconWidth) + ((rows - 1) * 16);

          return Container(
            padding: const EdgeInsets.only(top: 8, left: 24, right: 24, bottom: 24),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                GestureDetector(
                  onVerticalDragUpdate: (details) {
                    if (details.primaryDelta! < -2 && !isExpanded) {
                      setState(() => isExpanded = true);
                    } else if (details.primaryDelta! > 2 && isExpanded) {
                      setState(() => isExpanded = false);
                    }
                  },
                  child: Container(
                    color: Colors.transparent, // expand hit area
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    width: double.infinity,
                    alignment: Alignment.center,
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                ),
                const Text('İkon Seçin', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 20),
                AnimatedContainer(
                  duration: const Duration(milliseconds: 700),
                  curve: Curves.easeInOutQuart,
                  height: isExpanded ? expandedGridHeight : 330,
                  child: GridView.builder(
                    padding: EdgeInsets.zero,
                    shrinkWrap: false,
                    physics: isExpanded ? const NeverScrollableScrollPhysics() : const BouncingScrollPhysics(),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 5,
                      mainAxisSpacing: 16,
                      crossAxisSpacing: 16,
                    ),
                    itemCount: _availableIcons.length,
                    itemBuilder: (context, index) {
                      final icon = _availableIcons[index];
                      final isSelected = icon == currentIcon;
                      return InkWell(
                        onTap: () {
                          onSelected(icon);
                          Navigator.pop(context);
                        },
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          decoration: BoxDecoration(
                            color: isSelected ? themeColor.withValues(alpha: 0.1) : Colors.transparent,
                            border: Border.all(
                              color: isSelected ? themeColor : Colors.grey.withValues(alpha: 0.2),
                            ),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(icon, color: isSelected ? themeColor : AppColors.textPrimary),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _showRenameDialog(BuildContext context, WidgetRef ref, CategoryModel cat) {
    final controller = TextEditingController(text: cat.name);
    final limitController = TextEditingController(
      text: (cat.maxLimit != null) ? _formatLimit(cat.maxLimit!) : ''
    );
    IconData selectedIcon = cat.icon;
    Color selectedColor = cat.color;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          final screenHeight = MediaQuery.of(context).size.height;
          final keyboardHeight = MediaQuery.of(context).viewInsets.bottom;
          final isKeyboardOpen = keyboardHeight > 0;
          final double maxDialogHeight = screenHeight - keyboardHeight - 120;

          return Dialog(
            alignment: Alignment.topCenter,
            insetPadding: const EdgeInsets.only(top: 40, left: 20, right: 20, bottom: 20),
            backgroundColor: AppColors.surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
              side: BorderSide(color: AppColors.primary.withValues(alpha: 0.2), width: 1.5),
            ),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 350),
              curve: Curves.fastOutSlowIn,
              constraints: BoxConstraints(
                maxHeight: maxDialogHeight.clamp(150.0, screenHeight * 0.9),
              ),
              child: SingleChildScrollView(
                child: AnimatedPadding(
                  duration: const Duration(milliseconds: 350),
                  curve: Curves.fastOutSlowIn,
                  padding: EdgeInsets.fromLTRB(24, isKeyboardOpen ? 12 : 24, 24, isKeyboardOpen ? 10 : 16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      AnimatedDefaultTextStyle(
                        duration: const Duration(milliseconds: 350),
                        curve: Curves.fastOutSlowIn,
                        style: (Theme.of(context).textTheme.titleLarge ?? const TextStyle()).copyWith(
                          fontWeight: FontWeight.w600,
                          fontSize: isKeyboardOpen ? 18 : 22,
                        ),
                        textAlign: TextAlign.center,
                        child: const Text('Kategoriyi Düzenle'),
                      ),
                      SizedBox(height: isKeyboardOpen ? 12 : 24),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          Column(
                            children: [
                              if (!isKeyboardOpen) ...[
                                Text('İkon', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                                const SizedBox(height: 8),
                              ],
                              InkWell(
                                onTap: () => _showIconPicker(context, selectedColor, selectedIcon, (icon) {
                                  setDialogState(() => selectedIcon = icon);
                                }),
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 350),
                                  curve: Curves.fastOutSlowIn,
                                  padding: EdgeInsets.all(isKeyboardOpen ? 10 : 16),
                                  decoration: BoxDecoration(
                                    color: selectedColor.withValues(alpha: 0.1),
                                    shape: BoxShape.circle,
                                    border: Border.all(color: selectedColor.withValues(alpha: 0.3)),
                                  ),
                                  child: AnimatedScale(
                                    scale: isKeyboardOpen ? 0.75 : 1.0,
                                    duration: const Duration(milliseconds: 350),
                                    curve: Curves.fastOutSlowIn,
                                    child: Icon(selectedIcon, color: selectedColor, size: 32),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          Column(
                            children: [
                              if (!isKeyboardOpen) ...[
                                Text('Renk', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                                const SizedBox(height: 8),
                              ],
                              InkWell(
                                onTap: () => _showColorPicker(context, selectedColor, (color) {
                                  setDialogState(() => selectedColor = color);
                                }),
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 350),
                                  curve: Curves.fastOutSlowIn,
                                  padding: EdgeInsets.all(isKeyboardOpen ? 10 : 16),
                                  decoration: BoxDecoration(
                                    color: selectedColor,
                                    shape: BoxShape.circle,
                                    border: Border.all(color: Colors.white.withValues(alpha: 0.3), width: 2),
                                  ),
                                  child: AnimatedScale(
                                    scale: isKeyboardOpen ? 0.75 : 1.0,
                                    duration: const Duration(milliseconds: 350),
                                    curve: Curves.fastOutSlowIn,
                                    child: const Icon(Icons.palette, color: Colors.white, size: 32),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      SizedBox(height: isKeyboardOpen ? 12 : 16),
                      TextField(
                        controller: controller,
                        decoration: InputDecoration(
                          hintText: 'Kategori adı',
                          filled: true,
                          fillColor: AppColors.background,
                          contentPadding: isKeyboardOpen ? const EdgeInsets.symmetric(horizontal: 16, vertical: 10) : null,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide.none,
                          ),
                        ),
                        autofocus: true,
                      ),
                      if (!cat.isIncome) ...[
                        SizedBox(height: isKeyboardOpen ? 8 : 12),
                        TextField(
                          controller: limitController,
                          decoration: InputDecoration(
                            hintText: 'Kategori limiti (Opsiyonel)',
                            suffixText: '₺',
                            filled: true,
                            fillColor: AppColors.background,
                            contentPadding: isKeyboardOpen ? const EdgeInsets.symmetric(horizontal: 16, vertical: 10) : null,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: BorderSide.none,
                            ),
                          ),
                          keyboardType: const TextInputType.numberWithOptions(decimal: false),
                          inputFormatters: [ThousandsFormatter()],
                        ),
                      ],
                      SizedBox(height: isKeyboardOpen ? 16 : 24),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: Text('İptal', style: TextStyle(color: AppColors.textSecondary)),
                          ),
                          const SizedBox(width: 12),
                          ElevatedButton(
                            onPressed: () {
                              if (controller.text.trim().isNotEmpty) {
                                final limitStr = limitController.text.trim().replaceAll('.', '');
                                final double? limitVal = limitStr.isNotEmpty ? double.tryParse(limitStr) : null;
                                
                                Navigator.pop(context); // Pop first
                                
                                _checkAndSaveCategoryLimit(
                                  context,
                                  ref,
                                  categoryId: cat.id,
                                  name: controller.text.trim(),
                                  icon: selectedIcon,
                                  color: selectedColor,
                                  isIncome: cat.isIncome,
                                  newCategoryLimit: limitVal,
                                );
                              } else {
                                Navigator.pop(context);
                              }
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            child: const Text('Kaydet'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  void _showDeleteConfirm(BuildContext context, WidgetRef ref, CategoryModel cat) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        alignment: Alignment.topCenter,
        insetPadding: const EdgeInsets.only(top: 120, left: 20, right: 20),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: BorderSide(color: AppColors.expense.withValues(alpha: 0.2), width: 1.5),
        ),
        title: const Text('Kategoriyi Sil'),
        content: Text('${cat.name} kategorisini silmek istediğinize emin misiniz?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('İptal')),
          TextButton(
            onPressed: () {
              ref.read(categoryProvider.notifier).removeCategory(cat.id);
              Navigator.pop(context);
            },
            style: TextButton.styleFrom(foregroundColor: AppColors.expense),
            child: const Text('Sil'),
          ),
        ],
      ),
    );
  }

  void _showAddCategoryDialog(BuildContext context, WidgetRef ref, bool isIncome) {
    final controller = TextEditingController();
    final limitController = TextEditingController();
    IconData selectedIcon = isIncome ? Icons.trending_up : Icons.category;
    Color selectedColor = isIncome ? Colors.teal : Colors.blueGrey;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          final screenHeight = MediaQuery.of(context).size.height;
          final keyboardHeight = MediaQuery.of(context).viewInsets.bottom;
          final isKeyboardOpen = keyboardHeight > 0;
          final double maxDialogHeight = screenHeight - keyboardHeight - 120;

          return Dialog(
            alignment: Alignment.topCenter,
            insetPadding: const EdgeInsets.only(top: 40, left: 20, right: 20, bottom: 20),
            backgroundColor: AppColors.surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
              side: BorderSide(color: AppColors.primary.withValues(alpha: 0.2), width: 1.5),
            ),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 350),
              curve: Curves.fastOutSlowIn,
              constraints: BoxConstraints(
                maxHeight: maxDialogHeight.clamp(150.0, screenHeight * 0.9),
              ),
              child: SingleChildScrollView(
                child: AnimatedPadding(
                  duration: const Duration(milliseconds: 350),
                  curve: Curves.fastOutSlowIn,
                  padding: EdgeInsets.fromLTRB(24, isKeyboardOpen ? 12 : 24, 24, isKeyboardOpen ? 10 : 16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      AnimatedDefaultTextStyle(
                        duration: const Duration(milliseconds: 350),
                        curve: Curves.fastOutSlowIn,
                        style: (Theme.of(context).textTheme.titleLarge ?? const TextStyle()).copyWith(
                          fontWeight: FontWeight.w600,
                          fontSize: isKeyboardOpen ? 18 : 22,
                        ),
                        textAlign: TextAlign.center,
                        child: Text(
                          isIncome ? 'Gelir Kategorisi Ekle' : 'Gider Kategorisi Ekle',
                        ),
                      ),
                      SizedBox(height: isKeyboardOpen ? 12 : 24),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          Column(
                            children: [
                              if (!isKeyboardOpen) ...[
                                Text('İkon', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                                const SizedBox(height: 8),
                              ],
                              InkWell(
                                onTap: () => _showIconPicker(context, selectedColor, selectedIcon, (icon) {
                                  setDialogState(() => selectedIcon = icon);
                                }),
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 350),
                                  curve: Curves.fastOutSlowIn,
                                  padding: EdgeInsets.all(isKeyboardOpen ? 10 : 16),
                                  decoration: BoxDecoration(
                                    color: selectedColor.withValues(alpha: 0.1),
                                    shape: BoxShape.circle,
                                    border: Border.all(color: selectedColor.withValues(alpha: 0.3)),
                                  ),
                                  child: AnimatedScale(
                                    scale: isKeyboardOpen ? 0.75 : 1.0,
                                    duration: const Duration(milliseconds: 350),
                                    curve: Curves.fastOutSlowIn,
                                    child: Icon(selectedIcon, color: selectedColor, size: 32),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          Column(
                            children: [
                              if (!isKeyboardOpen) ...[
                                Text('Renk', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                                const SizedBox(height: 8),
                              ],
                              InkWell(
                                onTap: () => _showColorPicker(context, selectedColor, (color) {
                                  setDialogState(() => selectedColor = color);
                                }),
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 350),
                                  curve: Curves.fastOutSlowIn,
                                  padding: EdgeInsets.all(isKeyboardOpen ? 10 : 16),
                                  decoration: BoxDecoration(
                                    color: selectedColor,
                                    shape: BoxShape.circle,
                                    border: Border.all(color: Colors.white.withValues(alpha: 0.3), width: 2),
                                  ),
                                  child: AnimatedScale(
                                    scale: isKeyboardOpen ? 0.75 : 1.0,
                                    duration: const Duration(milliseconds: 350),
                                    curve: Curves.fastOutSlowIn,
                                    child: const Icon(Icons.palette, color: Colors.white, size: 32),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      SizedBox(height: isKeyboardOpen ? 12 : 16),
                      TextField(
                        controller: controller,
                        decoration: InputDecoration(
                          hintText: 'Kategori adı',
                          filled: true,
                          fillColor: AppColors.background,
                          contentPadding: isKeyboardOpen ? const EdgeInsets.symmetric(horizontal: 16, vertical: 10) : null,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide.none,
                          ),
                        ),
                        autofocus: true,
                      ),
                      if (!isIncome) ...[
                        SizedBox(height: isKeyboardOpen ? 8 : 12),
                        TextField(
                          controller: limitController,
                          decoration: InputDecoration(
                            hintText: 'Kategori limiti (Opsiyonel)',
                            suffixText: '₺',
                            filled: true,
                            fillColor: AppColors.background,
                            contentPadding: isKeyboardOpen ? const EdgeInsets.symmetric(horizontal: 16, vertical: 10) : null,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: BorderSide.none,
                            ),
                          ),
                          keyboardType: const TextInputType.numberWithOptions(decimal: false),
                          inputFormatters: [ThousandsFormatter()],
                        ),
                      ],
                      SizedBox(height: isKeyboardOpen ? 16 : 24),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: Text('İptal', style: TextStyle(color: AppColors.textSecondary)),
                          ),
                          const SizedBox(width: 12),
                          ElevatedButton(
                            onPressed: () {
                              if (controller.text.trim().isNotEmpty) {
                                final limitStr = limitController.text.trim().replaceAll('.', '');
                                final double? limitVal = limitStr.isNotEmpty ? double.tryParse(limitStr) : null;

                                Navigator.pop(context); // Pop first

                                _checkAndSaveCategoryLimit(
                                  context,
                                  ref,
                                  categoryId: null,
                                  name: controller.text.trim(),
                                  icon: selectedIcon,
                                  color: selectedColor,
                                  isIncome: isIncome,
                                  newCategoryLimit: limitVal,
                                );
                              } else {
                                Navigator.pop(context);
                              }
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            child: const Text('Ekle'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  void _showLogoutConfirm(BuildContext context, WidgetRef ref, bool isGuest) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        alignment: Alignment.topCenter,
        insetPadding: const EdgeInsets.only(top: 120, left: 20, right: 20),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: BorderSide(color: AppColors.expense.withValues(alpha: 0.2), width: 1.5),
        ),
        title: const Text('Çıkış Yap'),
        content: const Text('Çıkış yapmak istediğinize emin misiniz?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('İptal'),
          ),
          TextButton(
            onPressed: () async {
              if (isGuest) {
                ref.read(guestModeProvider.notifier).setGuestMode(false);
                await ref.read(databaseProvider).clearAllData();
              } else {
                await ref.read(authNotifierProvider.notifier).signOut();
              }
              if (context.mounted) {
                Navigator.pop(context);
              }
            },
            style: TextButton.styleFrom(foregroundColor: AppColors.expense),
            child: const Text('Çıkış Yap'),
          ),
        ],
      ),
    );
  }

  void _showDeleteAccountConfirm(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const _DeleteAccountDialog(),
    );
  }

  void _showEditLimitDialog(BuildContext context, WidgetRef ref, double? currentLimit) {
    final controller = TextEditingController(text: currentLimit != null ? _formatLimit(currentLimit) : '');
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        alignment: Alignment.topCenter,
        insetPadding: const EdgeInsets.only(top: 40, left: 20, right: 20),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: BorderSide(color: AppColors.primary.withValues(alpha: 0.2), width: 1.5),
        ),
        title: const Text('Aylık Harcama Limiti'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            hintText: 'Örn: 5.000',
            suffixText: '₺',
          ),
          keyboardType: const TextInputType.numberWithOptions(decimal: false),
          inputFormatters: [ThousandsFormatter()],
          autofocus: true,
        ),
        actions: [
          if (currentLimit != null)
            TextButton(
              onPressed: () async {
                final isGuest = ref.read(guestModeProvider);
                if (isGuest) {
                  await ref.read(monthlyLimitProvider.notifier).setMonthlyLimit(null);
                } else {
                  await ref.read(authNotifierProvider.notifier).updateMonthlyLimit(null);
                  await ref.read(monthlyLimitProvider.notifier).setMonthlyLimit(null);
                }
                Navigator.pop(context);
              },
              style: TextButton.styleFrom(foregroundColor: AppColors.expense),
              child: const Text('Limiti Kaldır'),
            ),
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('İptal')),
          TextButton(
            onPressed: () async {
              final valStr = controller.text.trim().replaceAll('.', '');
              final double? newLimit = double.tryParse(valStr);
              Navigator.pop(context); // Pop first

              if (newLimit != null && newLimit > 0) {
                final categoriesState = ref.read(categoryProvider).value ?? [];
                double totalExpenseLimit = 0;
                for (final c in categoriesState) {
                  if (!c.isIncome && c.maxLimit != null) {
                    totalExpenseLimit += c.maxLimit!;
                  }
                }

                final isGuest = ref.read(guestModeProvider);

                if (newLimit < totalExpenseLimit) {
                  await showDialog(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                      title: const Text('Limit Uyuşmazlığı'),
                      content: Text(
                        'Mevcut gider kategori limitleriniz toplamı ($totalExpenseLimit ₺), belirlediğiniz aylık limitten ($newLimit ₺) daha yüksek. Aylık limitiniz toplam gider limitinize ($totalExpenseLimit ₺) eşitlensin mi?',
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(ctx),
                          child: const Text('İptal'),
                        ),
                        ElevatedButton(
                          onPressed: () async {
                            if (isGuest) {
                              await ref.read(monthlyLimitProvider.notifier).setMonthlyLimit(totalExpenseLimit);
                            } else {
                              await ref.read(authNotifierProvider.notifier).updateMonthlyLimit(totalExpenseLimit);
                              await ref.read(monthlyLimitProvider.notifier).setMonthlyLimit(totalExpenseLimit);
                            }
                            Navigator.pop(ctx);
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          child: const Text('Eşitle'),
                        ),
                      ],
                    ),
                  );
                } else {
                  if (isGuest) {
                    await ref.read(monthlyLimitProvider.notifier).setMonthlyLimit(newLimit);
                  } else {
                    await ref.read(authNotifierProvider.notifier).updateMonthlyLimit(newLimit);
                    await ref.read(monthlyLimitProvider.notifier).setMonthlyLimit(newLimit);
                  }
                }
              }
            },
            child: const Text('Kaydet'),
          ),
        ],
      ),
    );
  }

  Future<void> _checkAndSaveCategoryLimit(
    BuildContext context,
    WidgetRef ref, {
    required String? categoryId,
    required String name,
    required IconData icon,
    required Color color,
    required bool isIncome,
    required double? newCategoryLimit,
  }) async {
    final isGuest = ref.read(guestModeProvider);
    final user = ref.read(currentUserProvider);
    final localLimit = ref.read(monthlyLimitProvider);
    final double? monthlyLimit = isGuest
        ? localLimit
        : (user?.userMetadata?['monthly_limit'] != null
            ? double.tryParse(user!.userMetadata!['monthly_limit'].toString())
            : localLimit);

    if (isIncome || newCategoryLimit == null || monthlyLimit == null) {
      await _executeCategorySave(ref, categoryId, name, icon, color, isIncome, newCategoryLimit);
      return;
    }

    final categoriesState = ref.read(categoryProvider).value ?? [];
    double otherLimitsSum = 0;
    for (final c in categoriesState) {
      if (!c.isIncome && c.id != categoryId && c.maxLimit != null) {
        otherLimitsSum += c.maxLimit!;
      }
    }

    final totalProposedLimits = otherLimitsSum + newCategoryLimit;

    if (totalProposedLimits > monthlyLimit) {
      final excess = totalProposedLimits - monthlyLimit;
      final maxAllowedCategoryLimit = monthlyLimit - otherLimitsSum;

      await showDialog(
        context: context,
        builder: (context) => AlertDialog(
          alignment: Alignment.center,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: const Text('Limit Aşımı Tespit Edildi'),
          content: Text(
            'Belirlediğiniz kategori limitlerinin toplamı ($totalProposedLimits ₺), aylık genel harcama limitinizi ($monthlyLimit ₺) $excess ₺ aşıyor.\n\nNasıl ilerlemek istersiniz?',
            style: const TextStyle(fontSize: 15),
          ),
          actionsAlignment: MainAxisAlignment.center,
          actionsOverflowButtonSpacing: 8,
          actions: [
            ElevatedButton(
              onPressed: () async {
                final newMonthlyLimit = monthlyLimit + excess;
                if (isGuest) {
                  await ref.read(monthlyLimitProvider.notifier).setMonthlyLimit(newMonthlyLimit);
                } else {
                  await ref.read(authNotifierProvider.notifier).updateMonthlyLimit(newMonthlyLimit);
                  await ref.read(monthlyLimitProvider.notifier).setMonthlyLimit(newMonthlyLimit);
                }
                await _executeCategorySave(ref, categoryId, name, icon, color, isIncome, newCategoryLimit);
                Navigator.pop(context);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: Text('Aylık Limiti ${excess.toStringAsFixed(0)} ₺ Artır'),
            ),
            OutlinedButton(
              onPressed: () async {
                final adjustedLimit = maxAllowedCategoryLimit > 0 ? maxAllowedCategoryLimit : 0.0;
                await _executeCategorySave(ref, categoryId, name, icon, color, isIncome, adjustedLimit);
                Navigator.pop(context);
              },
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.primary,
                side: BorderSide(color: AppColors.primary),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: Text('Kategori Limitini ${maxAllowedCategoryLimit > 0 ? maxAllowedCategoryLimit.toStringAsFixed(0) : '0'} ₺ Olarak Ayarla'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Vazgeç', style: TextStyle(color: AppColors.textSecondary)),
            ),
          ],
        ),
      );
    } else {
      await _executeCategorySave(ref, categoryId, name, icon, color, isIncome, newCategoryLimit);
    }
  }

  Future<void> _executeCategorySave(
    WidgetRef ref,
    String? categoryId,
    String name,
    IconData icon,
    Color color,
    bool isIncome,
    double? limit,
  ) async {
    if (categoryId == null) {
      await ref.read(categoryProvider.notifier).addCategory(
        name: name,
        icon: icon,
        color: color,
        isIncome: isIncome,
        maxLimit: limit,
      );
    }
  }
}

class _DeleteAccountDialog extends ConsumerStatefulWidget {
  const _DeleteAccountDialog();

  @override
  ConsumerState<_DeleteAccountDialog> createState() => _DeleteAccountDialogState();
}

class _DeleteAccountDialogState extends ConsumerState<_DeleteAccountDialog> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _otpController = TextEditingController();
  
  bool _obscurePassword = true;
  bool _isLoading = false;
  bool _isPasswordVerified = false;
  bool _isSendingOtp = false;
  int _cooldownSeconds = 0;
  Timer? _cooldownTimer;
  String? _errorMessage;
  String? _successMessage;

  @override
  void initState() {
    super.initState();
    final user = SupabaseService.client.auth.currentUser;
    _emailController.text = user?.email ?? '';
  }

  @override
  void dispose() {
    _cooldownTimer?.cancel();
    _emailController.dispose();
    _passwordController.dispose();
    _otpController.dispose();
    super.dispose();
  }

  void _startCooldown() {
    _cooldownTimer?.cancel();
    setState(() {
      _cooldownSeconds = 60;
    });
    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_cooldownSeconds > 0) {
        setState(() {
          _cooldownSeconds--;
        });
      } else {
        _cooldownTimer?.cancel();
      }
    });
  }

  Future<void> _handleActionButtonPressed() async {
    if (!_isPasswordVerified) {
      // Step 1: Verify Password
      final email = _emailController.text.trim();
      final password = _passwordController.text;
      if (password.isEmpty) {
        setState(() {
          _errorMessage = 'Lütfen şifrenizi girin.';
        });
        return;
      }
      
      setState(() {
        _isLoading = true;
        _errorMessage = null;
        _successMessage = null;
      });

      try {
        // Re-authenticate user to confirm identity
        await SupabaseService.client.auth.signInWithPassword(
          email: email,
          password: password,
        ).timeout(const Duration(seconds: 10));

        // Password is correct! Now trigger OTP automatically
        setState(() {
          _isPasswordVerified = true;
          _isSendingOtp = true;
        });

        try {
          await SupabaseService.client.auth.signInWithOtp(
            email: email,
          ).timeout(const Duration(seconds: 10));
          setState(() {
            _isSendingOtp = false;
            _successMessage = 'Şifre doğrulandı. Doğrulama kodu e-postanıza gönderildi.';
            _isLoading = false;
            _startCooldown();
          });
        } catch (otpError) {
          setState(() {
            _isSendingOtp = false;
            _errorMessage = 'Şifre doğru fakat doğrulama kodu gönderilemedi: ${otpError.toString().replaceAll('AuthException: ', '')}';
            _isLoading = false;
          });
        }
      } catch (passwordError) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Şifre hatalı. Lütfen tekrar deneyin.';
        });
      }
    } else {
      // Step 2: Verify OTP and Delete Account
      final messenger = ScaffoldMessenger.of(context);
      final email = _emailController.text.trim();
      final password = _passwordController.text;
      final otp = _otpController.text.trim();

      if (otp.isEmpty) {
        setState(() {
          _errorMessage = 'Lütfen doğrulama kodunu girin.';
        });
        return;
      }

      setState(() {
        _isLoading = true;
        _errorMessage = null;
        _successMessage = null;
      });

      try {
        // Step 2a: Verify OTP
        await SupabaseService.client.auth.verifyOTP(
          email: email,
          token: otp,
          type: OtpType.email,
        ).timeout(const Duration(seconds: 10));

        // Pop dialog cleanly to avoid getting stuck on screen
        if (mounted) {
          Navigator.pop(context);
        }

        try {
          // Step 2b: Delete Account
          await ref.read(authNotifierProvider.notifier).deleteAccount(
                email: email,
                password: password,
              );
        } catch (deleteError) {
          messenger.showSnackBar(
            SnackBar(
              content: Text('Hesap silme başarısız: ${deleteError.toString().replaceAll('AuthException: ', '')}'),
              backgroundColor: AppColors.expense,
            ),
          );
        }
      } catch (otpError) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Kod doğrulama başarısız: ${otpError.toString().replaceAll('AuthException: ', '')}';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final keyboardHeight = MediaQuery.of(context).viewInsets.bottom;
    final isKeyboardOpen = keyboardHeight > 0;
    final double maxDialogHeight = screenHeight - keyboardHeight - 120;

    return Dialog(
      alignment: Alignment.center,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: BorderSide(color: AppColors.expense.withValues(alpha: 0.2), width: 1.5),
      ),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 350),
        curve: Curves.fastOutSlowIn,
        constraints: BoxConstraints(
          maxHeight: maxDialogHeight.clamp(150.0, screenHeight * 0.9),
        ),
        child: SingleChildScrollView(
          child: AnimatedPadding(
            duration: const Duration(milliseconds: 350),
            curve: Curves.fastOutSlowIn,
            padding: EdgeInsets.fromLTRB(24, isKeyboardOpen ? 12 : 24, 24, isKeyboardOpen ? 10 : 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.warning_amber_rounded, color: AppColors.expense, size: isKeyboardOpen ? 20 : 28),
                    const SizedBox(width: 8),
                    AnimatedDefaultTextStyle(
                      duration: const Duration(milliseconds: 350),
                      curve: Curves.fastOutSlowIn,
                      style: (Theme.of(context).textTheme.titleLarge ?? const TextStyle()).copyWith(
                        fontWeight: FontWeight.bold,
                        fontSize: isKeyboardOpen ? 18 : 22,
                        color: AppColors.expense,
                      ),
                      child: const Text('Hesabı Sil'),
                    ),
                  ],
                ),
                SizedBox(height: isKeyboardOpen ? 10 : 16),
                
                if (!_isPasswordVerified) ...[
                  if (!isKeyboardOpen) ...[
                    const Text(
                      'Hesabınızı silmek istediğinize emin misiniz? Bu işlem geri alınamaz. Buluttaki tüm verileriniz ve yerel kayıtlarınız kalıcı olarak silinecektir.\n\nİşlemi başlatmak için e-posta ve şifrenizi girerek doğrulayın:',
                      style: TextStyle(fontSize: 13),
                    ),
                    const SizedBox(height: 12),
                  ],
                  TextField(
                    controller: _emailController,
                    enabled: false,
                    style: TextStyle(color: AppColors.textSecondary),
                    decoration: InputDecoration(
                      labelText: 'E-posta',
                      labelStyle: TextStyle(color: AppColors.textSecondary),
                      disabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: AppColors.textSecondary.withValues(alpha: 0.15)),
                      ),
                      prefixIcon: Icon(Icons.email_outlined, color: AppColors.textSecondary),
                      contentPadding: isKeyboardOpen ? const EdgeInsets.symmetric(horizontal: 16, vertical: 10) : null,
                    ),
                  ),
                  SizedBox(height: isKeyboardOpen ? 8 : 12),
                  TextField(
                    controller: _passwordController,
                    obscureText: _obscurePassword,
                    obscuringCharacter: '•',
                    style: GoogleFonts.robotoMono(
                      fontSize: 16,
                      height: 1.0,
                      letterSpacing: 2.0,
                      color: AppColors.textPrimary,
                    ),
                    onChanged: (val) {
                      setState(() {});
                    },
                    decoration: InputDecoration(
                      labelText: 'Şifre',
                      labelStyle: TextStyle(color: AppColors.textSecondary),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: AppColors.textSecondary.withValues(alpha: 0.3)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: AppColors.primary),
                      ),
                      prefixIcon: Icon(Icons.lock_outline, color: AppColors.textSecondary),
                      contentPadding: isKeyboardOpen ? const EdgeInsets.symmetric(horizontal: 16, vertical: 10) : null,
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscurePassword ? Icons.visibility_off : Icons.visibility,
                          color: AppColors.textSecondary,
                        ),
                        onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                      ),
                    ),
                  ),
                ] else ...[
                  if (!isKeyboardOpen) ...[
                    Text(
                      'Güvenliğiniz için ${_emailController.text} adresine 6 haneli bir doğrulama kodu gönderdik. Lütfen aşağıdaki alana girin:',
                      style: const TextStyle(fontSize: 13),
                    ),
                    const SizedBox(height: 12),
                  ],
                  TextField(
                    controller: _otpController,
                    keyboardType: TextInputType.number,
                    style: TextStyle(color: AppColors.textPrimary),
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(6),
                    ],
                    onChanged: (val) {
                      setState(() {});
                    },
                    decoration: InputDecoration(
                      labelText: 'E-posta Doğrulama Kodu',
                      hintText: '6 Haneli Kod',
                      counterText: '',
                      labelStyle: TextStyle(color: AppColors.textSecondary),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: AppColors.textSecondary.withValues(alpha: 0.3)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: AppColors.primary),
                      ),
                      prefixIcon: Icon(Icons.pin_outlined, color: AppColors.textSecondary),
                      contentPadding: isKeyboardOpen ? const EdgeInsets.symmetric(horizontal: 16, vertical: 10) : null,
                    ),
                  ),
                  SizedBox(height: isKeyboardOpen ? 8 : 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      TextButton.icon(
                        onPressed: (_cooldownSeconds > 0 || _isSendingOtp || _isLoading) 
                          ? null 
                          : () async {
                              setState(() {
                                _isSendingOtp = true;
                                _errorMessage = null;
                                _successMessage = null;
                              });
                              try {
                                await SupabaseService.client.auth.signInWithOtp(email: _emailController.text.trim()).timeout(const Duration(seconds: 10));
                                setState(() {
                                  _isSendingOtp = false;
                                  _successMessage = 'Doğrulama kodu tekrar e-postanıza gönderildi.';
                                  _startCooldown();
                                });
                              } catch (e) {
                                setState(() {
                                  _isSendingOtp = false;
                                  _errorMessage = 'Kod gönderilemedi: ${e.toString().replaceAll('AuthException: ', '')}';
                                });
                              }
                            },
                        icon: _isSendingOtp 
                          ? const SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 1.5))
                          : const Icon(Icons.send_outlined, size: 16),
                        label: Text(
                          _cooldownSeconds > 0 
                            ? 'Tekrar Kod Gönder (${_cooldownSeconds}sn)' 
                            : 'Tekrar Kod Gönder', 
                          style: const TextStyle(fontSize: 12)
                        ),
                      ),
                    ],
                  ),
                ],
                
                if (_errorMessage != null) ...[
                  const SizedBox(height: 10),
                  Text(
                    _errorMessage!,
                    style: TextStyle(color: AppColors.expense, fontSize: 13, fontWeight: FontWeight.w600),
                    textAlign: TextAlign.center,
                  ),
                ],
                if (_successMessage != null) ...[
                  const SizedBox(height: 10),
                  Text(
                    _successMessage!,
                    style: const TextStyle(color: Colors.green, fontSize: 13, fontWeight: FontWeight.w600),
                    textAlign: TextAlign.center,
                  ),
                ],
                SizedBox(height: isKeyboardOpen ? 12 : 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: _isLoading ? null : () => Navigator.pop(context),
                      child: Text('İptal', style: TextStyle(color: AppColors.textSecondary)),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton(
                      onPressed: (_isLoading || (_isPasswordVerified && _otpController.text.length != 6) || (!_isPasswordVerified && _passwordController.text.isEmpty))
                          ? null
                          : () => _handleActionButtonPressed(),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.expense,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: _isLoading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                            )
                          : Text(!_isPasswordVerified ? 'Devam Et' : 'Kalıcı Olarak Sil'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
