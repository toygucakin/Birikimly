import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:birikimly/core/theme/app_colors.dart';
import 'package:birikimly/features/auth/presentation/providers/auth_provider.dart';
import 'package:birikimly/features/categories/presentation/providers/category_provider.dart';
import 'package:birikimly/features/categories/domain/models/category_model.dart';
import 'package:birikimly/core/providers/preferences_provider.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categories = ref.watch(categoryProvider);
    final isGuest = ref.watch(guestModeProvider);
    final customName = ref.watch(userNameProvider);
    final user = ref.watch(currentUserProvider);

    String displayName = isGuest ? customName : (user?.email?.split('@').first ?? 'Kullanıcı');

    final incomeCategories = categories.where((c) => c.isIncome).toList();
    final expenseCategories = categories.where((c) => !c.isIncome).toList();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Profil'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: AppColors.expense),
            onPressed: () {
              if (isGuest) {
                ref.read(guestModeProvider.notifier).setGuestMode(false);
              } else {
                ref.read(authNotifierProvider.notifier).signOut();
              }
              Navigator.pop(context);
            },
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

  void _showEditNameDialog(BuildContext context, WidgetRef ref, String currentName) {
    final controller = TextEditingController(text: currentName);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
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

  void _showRenameDialog(BuildContext context, WidgetRef ref, CategoryModel cat) {
    final controller = TextEditingController(text: cat.name);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Kategoriyi Düzenle'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(hintText: 'Kategori adı'),
          autofocus: true,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('İptal')),
          TextButton(
            onPressed: () {
              if (controller.text.trim().isNotEmpty) {
                ref.read(categoryProvider.notifier).updateCategory(cat.id, controller.text.trim());
              }
              Navigator.pop(context);
            },
            child: const Text('Kaydet'),
          ),
        ],
      ),
    );
  }

  void _showDeleteConfirm(BuildContext context, WidgetRef ref, CategoryModel cat) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
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
    String name = '';
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(isIncome ? 'Gelir Kategorisi Ekle' : 'Gider Kategorisi Ekle'),
        content: TextField(
          onChanged: (v) => name = v,
          decoration: const InputDecoration(hintText: 'Kategori adı'),
          autofocus: true,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('İptal')),
          TextButton(
            onPressed: () {
              if (name.trim().isNotEmpty) {
                ref.read(categoryProvider.notifier).addCategory(
                  name.trim(),
                  isIncome ? Icons.trending_up : Icons.category,
                  isIncome ? Colors.teal : Colors.blueGrey,
                  isIncome,
                );
              }
              Navigator.pop(context);
            },
            child: const Text('Ekle'),
          ),
        ],
      ),
    );
  }
}
