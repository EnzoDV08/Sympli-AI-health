import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppSettings {
  final bool notificationsEnabled;
  final bool darkModeEnabled;

  const AppSettings({
    this.notificationsEnabled = true,
    this.darkModeEnabled = false,
  });

  AppSettings copyWith({
    bool? notificationsEnabled,
    bool? darkModeEnabled,
  }) {
    return AppSettings(
      notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
      darkModeEnabled: darkModeEnabled ?? this.darkModeEnabled,
    );
  }
}

class AppSettingsNotifier extends StateNotifier<AppSettings> {
  AppSettingsNotifier() : super(const AppSettings()) {
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final notif = prefs.getBool('notificationsEnabled') ?? true;
    final dark = prefs.getBool('darkModeEnabled') ?? false;
    state = AppSettings(notificationsEnabled: notif, darkModeEnabled: dark);
  }

  Future<void> toggleNotifications(bool value) async {
    state = state.copyWith(notificationsEnabled: value);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('notificationsEnabled', value);
  }

  Future<void> toggleTheme(bool value) async {
    state = state.copyWith(darkModeEnabled: value);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('darkModeEnabled', value);
  }
}

final appSettingsProvider =
    StateNotifierProvider<AppSettingsNotifier, AppSettings>((ref) {
  return AppSettingsNotifier();
});
