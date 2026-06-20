import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:birikimly/core/theme/app_colors.dart';
import 'package:birikimly/core/providers/theme_provider.dart';
import 'package:birikimly/features/auth/presentation/providers/auth_provider.dart';
import 'package:birikimly/features/categories/presentation/providers/category_provider.dart';
import 'package:birikimly/features/categories/domain/models/category_model.dart';
import 'package:birikimly/core/providers/preferences_provider.dart';

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
      text: (cat.maxLimit != null) ? cat.maxLimit!.toStringAsFixed(0) : ''
    );
    IconData selectedIcon = cat.icon;
    Color selectedColor = cat.color;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          alignment: Alignment.topCenter,
          insetPadding: const EdgeInsets.only(top: 40, left: 20, right: 20),
          backgroundColor: AppColors.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
            side: BorderSide(color: AppColors.primary.withValues(alpha: 0.2), width: 1.5),
          ),
          title: const Text('Kategoriyi Düzenle'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    Column(
                      children: [
                        Text('İkon', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                        const SizedBox(height: 8),
                        InkWell(
                          onTap: () => _showIconPicker(context, selectedColor, selectedIcon, (icon) {
                            setDialogState(() => selectedIcon = icon);
                          }),
                          child: Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: selectedColor.withValues(alpha: 0.1),
                              shape: BoxShape.circle,
                              border: Border.all(color: selectedColor.withValues(alpha: 0.3)),
                            ),
                            child: Icon(selectedIcon, color: selectedColor, size: 32),
                          ),
                        ),
                      ],
                    ),
                    Column(
                      children: [
                        Text('Renk', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                        const SizedBox(height: 8),
                        InkWell(
                          onTap: () => _showColorPicker(context, selectedColor, (color) {
                            setDialogState(() => selectedColor = color);
                          }),
                          child: Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: selectedColor,
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white.withValues(alpha: 0.3), width: 2),
                            ),
                            child: const Icon(Icons.palette, color: Colors.white, size: 32),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: controller,
                  decoration: InputDecoration(
                    hintText: 'Kategori adı',
                    filled: true,
                    fillColor: AppColors.background,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  autofocus: true,
                ),
                if (!cat.isIncome) ...[
                  const SizedBox(height: 12),
                  TextField(
                    controller: limitController,
                    decoration: InputDecoration(
                      hintText: 'Kategori limiti (Opsiyonel)',
                      suffixText: '₺',
                      filled: true,
                      fillColor: AppColors.background,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    keyboardType: const TextInputType.numberWithOptions(decimal: false),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('İptal', style: TextStyle(color: AppColors.textSecondary)),
            ),
            ElevatedButton(
              onPressed: () {
                if (controller.text.trim().isNotEmpty) {
                  final limitStr = limitController.text.trim();
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
        builder: (context, setDialogState) => AlertDialog(
          alignment: Alignment.topCenter,
          insetPadding: const EdgeInsets.only(top: 40, left: 20, right: 20),
          backgroundColor: AppColors.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
            side: BorderSide(color: AppColors.primary.withValues(alpha: 0.2), width: 1.5),
          ),
          title: Text(isIncome ? 'Gelir Kategorisi Ekle' : 'Gider Kategorisi Ekle'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    Column(
                      children: [
                        Text('İkon', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                        const SizedBox(height: 8),
                        InkWell(
                          onTap: () => _showIconPicker(context, selectedColor, selectedIcon, (icon) {
                            setDialogState(() => selectedIcon = icon);
                          }),
                          child: Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: selectedColor.withValues(alpha: 0.1),
                              shape: BoxShape.circle,
                              border: Border.all(color: selectedColor.withValues(alpha: 0.3)),
                            ),
                            child: Icon(selectedIcon, color: selectedColor, size: 32),
                          ),
                        ),
                      ],
                    ),
                    Column(
                      children: [
                        Text('Renk', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                        const SizedBox(height: 8),
                        InkWell(
                          onTap: () => _showColorPicker(context, selectedColor, (color) {
                            setDialogState(() => selectedColor = color);
                          }),
                          child: Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: selectedColor,
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white.withValues(alpha: 0.3), width: 2),
                            ),
                            child: const Icon(Icons.palette, color: Colors.white, size: 32),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: controller,
                  decoration: InputDecoration(
                    hintText: 'Kategori adı',
                    filled: true,
                    fillColor: AppColors.background,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  autofocus: true,
                ),
                if (!isIncome) ...[
                  const SizedBox(height: 12),
                  TextField(
                    controller: limitController,
                    decoration: InputDecoration(
                      hintText: 'Kategori limiti (Opsiyonel)',
                      suffixText: '₺',
                      filled: true,
                      fillColor: AppColors.background,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    keyboardType: const TextInputType.numberWithOptions(decimal: false),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('İptal', style: TextStyle(color: AppColors.textSecondary)),
            ),
            ElevatedButton(
              onPressed: () {
                if (controller.text.trim().isNotEmpty) {
                  final limitStr = limitController.text.trim();
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
            onPressed: () {
              if (isGuest) {
                ref.read(guestModeProvider.notifier).setGuestMode(false);
              } else {
                ref.read(authNotifierProvider.notifier).signOut();
              }
              Navigator.pop(context); 
            },
            style: TextButton.styleFrom(foregroundColor: AppColors.expense),
            child: const Text('Çıkış Yap'),
          ),
        ],
      ),
    );
  }

  void _showEditLimitDialog(BuildContext context, WidgetRef ref, double? currentLimit) {
    final controller = TextEditingController(text: currentLimit != null ? currentLimit.toStringAsFixed(0) : '');
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
            hintText: 'Örn: 5000',
            suffixText: '₺',
          ),
          keyboardType: const TextInputType.numberWithOptions(decimal: false),
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
              final valStr = controller.text.trim();
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
    } else {
      await ref.read(categoryProvider.notifier).updateCategory(
        categoryId,
        name: name,
        icon: icon,
        color: color,
        maxLimit: drift.Value(limit),
      );
    }
  }
}
