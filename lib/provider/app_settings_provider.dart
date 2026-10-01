import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppSettingsProvider extends ChangeNotifier {
  static const String _storageKey = 'darkMode';

  bool _darkmode = false;

  bool get darkmode => _darkmode;

  AppSettingsProvider() {
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    _darkmode = prefs.getBool(_storageKey) ?? false;
    notifyListeners();
  }

  Future<void> toggleDarkMode(bool value) async {
    _darkmode = value;
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_storageKey, value);
  }

  // Alias to preserve backwards compatibility
  Future<void> tottgleDarkMode(bool value) => toggleDarkMode(value);
}