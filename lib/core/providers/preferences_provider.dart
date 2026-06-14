import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
  static const _key = 'userName';

  @override
  String build() {
    final prefs = ref.watch(sharedPreferencesProvider);
    return prefs.getString(_key) ?? 'Misafir';
  }

  Future<void> setUserName(String value) async {
    final prefs = ref.read(sharedPreferencesProvider);
    await prefs.setString(_key, value);
    state = value;
  }
}

final userNameProvider = NotifierProvider<UserNameNotifier, String>(UserNameNotifier.new);

class MonthlyLimitNotifier extends Notifier<double?> {
  static const _key = 'monthlyLimit';

  @override
  double? build() {
    final prefs = ref.watch(sharedPreferencesProvider);
    return prefs.getDouble(_key);
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
