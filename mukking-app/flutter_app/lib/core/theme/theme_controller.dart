import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../constants/app_constants.dart';
import 'theme_tokens.dart';

final sharedPreferencesProvider = Provider<SharedPreferences?>((ref) {
  return null;
});

final themeControllerProvider =
    StateNotifierProvider<ThemeController, MukkingThemeId>((ref) {
  final preferences = ref.watch(sharedPreferencesProvider);
  return ThemeController(preferences);
});

class ThemeController extends StateNotifier<MukkingThemeId> {
  ThemeController(this._preferences) : super(MukkingThemeId.violet) {
    _loadTheme();
  }

  final SharedPreferences? _preferences;

  void setTheme(MukkingThemeId themeId) {
    state = themeId;
    _preferences?.setString(AppConstants.themeStorageKey, themeId.name);
  }

  void _loadTheme() {
    final savedValue = _preferences?.getString(AppConstants.themeStorageKey);
    state = MukkingThemeId.fromValue(savedValue);
  }
}
