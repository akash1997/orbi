import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeNotifier extends StateNotifier<bool> {
  static const String _key = 'is_dark_mode';
  final SharedPreferences _prefs;

  ThemeNotifier(this._prefs) : super(false) {
    _loadTheme();
  }

  void _loadTheme() {
    state = _prefs.getBool(_key) ?? false;
  }

  Future<void> toggleTheme() async {
    state = !state;
    await _prefs.setBool(_key, state);
  }

  Future<void> setTheme(bool isDark) async {
    print('🎨 [ThemeProvider] setTheme called with isDark: $isDark');
    print('🎨 [ThemeProvider] Current state: $state');
    state = isDark;
    print('🎨 [ThemeProvider] New state: $state');
    await _prefs.setBool(_key, isDark);
    print('🎨 [ThemeProvider] Saved to SharedPreferences');
  }
}

final themeProvider = StateNotifierProvider<ThemeNotifier, bool>((ref) {
  throw UnimplementedError('themeProvider must be overridden');
});
