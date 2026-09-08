import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Persisted light/dark preference — "Nocturnal" (dark, the app's original
/// look) vs "Light". Read by [NocturneColors] getters and by
/// `buildNocturneTheme()`, so switching it re-themes the whole app without
/// every screen needing to know how.
class ThemeController extends ChangeNotifier {
  ThemeController._();
  static final ThemeController instance = ThemeController._();

  static const _prefsKey = 'sigraforce_dark_mode';

  bool _isDark = true;
  bool get isDark => _isDark;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    _isDark = prefs.getBool(_prefsKey) ?? true;
    notifyListeners();
  }

  Future<void> setDark(bool value) async {
    if (_isDark == value) return;
    _isDark = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefsKey, value);
  }
}
