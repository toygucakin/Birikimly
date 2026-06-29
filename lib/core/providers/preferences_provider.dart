import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:birikimly/features/auth/presentation/providers/auth_provider.dart';

final sharedPreferencesProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError('sharedPreferencesProvider must be overridden in ProviderScope');
});

class GuestModeNotifier extends Notifier<bool> {
  static const _key = 'isGuestMode';

  @override
  bool build() {
    final prefs = ref.watch(sharedPreferencesProvider);
    return prefs.getBool(_key) ?? false;
  }

  Future<void> setGuestMode(bool value) async {
    final prefs = ref.read(sharedPreferencesProvider);
    await prefs.setBool(_key, value);
    state = value;
  }
}

final guestModeProvider = NotifierProvider<GuestModeNotifier, bool>(GuestModeNotifier.new);

class UserNameNotifier extends Notifier<String> {
  String get _key {
    final isGuest = ref.watch(guestModeProvider);
    final user = ref.watch(currentUserProvider);
    if (isGuest) return 'userName_guest';
    if (user != null) return 'userName_${user.id}';
    return 'userName';
  }

  @override
  String build() {
    final prefs = ref.watch(sharedPreferencesProvider);
    final localVal = prefs.getString(_key);
    if (localVal != null) return localVal;

    // Restore from Supabase metadata on a new device
    final isGuest = ref.watch(guestModeProvider);
    if (!isGuest) {
      final user = ref.watch(currentUserProvider);
      final metaName = user?.userMetadata?['display_name']?.toString();
      if (metaName != null && metaName.isNotEmpty) {
        prefs.setString(_key, metaName);
        return metaName;
      }
    }
    return 'Misafir';
  }

  Future<void> setUserName(String value) async {
    final prefs = ref.read(sharedPreferencesProvider);
    await prefs.setString(_key, value);
    state = value;
  }
}

final userNameProvider = NotifierProvider<UserNameNotifier, String>(UserNameNotifier.new);

class MonthlyLimitNotifier extends Notifier<double?> {
  String get _key {
    final isGuest = ref.watch(guestModeProvider);
    final user = ref.watch(currentUserProvider);
    if (isGuest) return 'monthlyLimit_guest';
    if (user != null) return 'monthlyLimit_${user.id}';
    return 'monthlyLimit';
  }

  @override
  double? build() {
    final prefs = ref.watch(sharedPreferencesProvider);
    final localVal = prefs.getDouble(_key);
    if (localVal != null) return localVal;

    // Restore from Supabase metadata on a new device
    final isGuest = ref.watch(guestModeProvider);
    if (!isGuest) {
      final user = ref.watch(currentUserProvider);
      final metaLimit = user?.userMetadata?['monthly_limit'];
      if (metaLimit != null) {
        final parsed = double.tryParse(metaLimit.toString());
        if (parsed != null) {
          prefs.setDouble(_key, parsed);
          return parsed;
        }
      }
    }
    return null;
  }

  Future<void> setMonthlyLimit(double? value) async {
    final prefs = ref.read(sharedPreferencesProvider);
    if (value == null) {
      await prefs.remove(_key);
    } else {
      await prefs.setDouble(_key, value);
    }
    state = value;
  }
}

final monthlyLimitProvider = NotifierProvider<MonthlyLimitNotifier, double?>(MonthlyLimitNotifier.new);
