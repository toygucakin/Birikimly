import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:birikimly/core/theme/app_colors.dart';
import 'package:birikimly/features/auth/presentation/providers/auth_provider.dart';
import 'package:birikimly/features/categories/presentation/providers/category_provider.dart';
import 'package:birikimly/features/categories/domain/models/category_model.dart';
import 'package:birikimly/core/providers/preferences_provider.dart';
import 'package:birikimly/features/main/presentation/providers/main_screen_provider.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pageController = ref.watch(mainPageControllerProvider);
    final categories = ref.watch(categoryProvider);
    final isGuest = ref.watch(guestModeProvider);
    final customName = ref.watch(userNameProvider);
    final user = ref.watch(currentUserProvider);

    String displayName = isGuest
        ? customName
        : (customName.isNotEmpty && customName != 'Misafir')
            ? customName
            : (user?.email?.split('@').first ?? 'Kullanıcı');

    final incomeCategories = categories.where((c) => c.isIncome).toList();
    final expenseCategories = categories.where((c) => !c.isIncome).toList();

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
                  const CircleAvatar(
                    radius: 40,
                    backgroundColor: AppColors.primary,
                    child: Icon(Icons.person, size: 40, color: Colors.white),
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
                        onPressed: () => _showEditNameDialog(context, ref, customName),
                      ),
                    ],
                  ),
                  Text(
                    isGuest ? 'Misafir Modu' : (user?.email ?? ''),
                    style: const TextStyle(color: AppColors.textSecondary),
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
                    side: const BorderSide(color: AppColors.expense, width: 1.5),
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
  }

  Widget _buildCategorySection(
    BuildContext context,
    WidgetRef ref, {
    required String title,
    required List<CategoryModel> categories,
    required bool isIncome,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            IconButton(
              icon: const Icon(Icons.add_circle, color: AppColors.primary),
              onPressed: () => _showAddCategoryDialog(context, ref, isIncome),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ...categories.map((cat) => _buildCategoryTile(context, ref, cat)),
      ],
    );
  }

  Widget _buildCategoryTile(BuildContext context, WidgetRef ref, CategoryModel cat) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: ListTile(
        leading: Icon(cat.icon, color: cat.color),
        title: Text(cat.name),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.edit, size: 20),
              onPressed: () => _showRenameDialog(context, ref, cat),
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline, size: 20, color: AppColors.expense),
              onPressed: () => _showDeleteConfirm(context, ref, cat),
            ),
          ],
        ),
      ),
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
  ];

  static const List<Color> _curatedColors = [
    Colors.blue, Colors.indigo, Colors.deepPurple, Colors.pink,
    Colors.red, Colors.deepOrange, Colors.orange, Colors.amber,
    Colors.teal, Colors.cyan, Colors.green, Colors.lightGreen,
    Colors.lime, Colors.blueGrey, Colors.brown,
  ];

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
              if (controller.text.trim().isNotEmpty) {
                ref.read(userNameProvider.notifier).setUserName(controller.text.trim());
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
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            const Text('Renk Seçin', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),
            SizedBox(
              height: 200,
              child: GridView.builder(
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
            ),
          ],
        ),
      ),
    );
  }

  void _showIconPicker(BuildContext context, Color themeColor, IconData currentIcon, Function(IconData) onSelected) {
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
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            const Text('İkon Seçin', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),
            SizedBox(
              height: 300,
              child: GridView.builder(
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
      ),
    );
  }

  void _showRenameDialog(BuildContext context, WidgetRef ref, CategoryModel cat) {
    final controller = TextEditingController(text: cat.name);
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
                        const Text('İkon', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
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
                        const Text('Renk', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
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
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('İptal', style: TextStyle(color: AppColors.textSecondary)),
            ),
            ElevatedButton(
              onPressed: () {
                if (controller.text.trim().isNotEmpty) {
                  ref.read(categoryProvider.notifier).updateCategory(
                    cat.id, 
                    name: controller.text.trim(),
                    icon: selectedIcon,
                    color: selectedColor,
                  );
                }
                Navigator.pop(context);
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
                        const Text('İkon', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
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
                        const Text('Renk', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
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
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('İptal', style: TextStyle(color: AppColors.textSecondary)),
            ),
            ElevatedButton(
              onPressed: () {
                if (controller.text.trim().isNotEmpty) {
                  ref.read(categoryProvider.notifier).addCategory(
                    controller.text.trim(),
                    selectedIcon,
                    selectedColor,
                    isIncome,
                  );
                }
                Navigator.pop(context);
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
}
