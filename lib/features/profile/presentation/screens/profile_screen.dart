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
    final isGuest = ref.watch(guestModeProvider);
    final customName = ref.watch(userNameProvider);
    final user = ref.watch(currentUserProvider);

    String displayName = isGuest ? customName : (user?.email?.split('@').first ?? 'Kullanıcı');

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
}
