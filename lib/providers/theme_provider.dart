import 'package:flutter/material.dart';

/// Starts in system mode, so the app follows the phone's light/dark setting
/// until the user explicitly chooses an appearance.
class ThemeProvider extends ChangeNotifier {
  ThemeMode _themeMode = ThemeMode.system;

  ThemeMode get themeMode => _themeMode;

  void setThemeMode(ThemeMode mode) {
    if (_themeMode == mode) return;
    _themeMode = mode;
    notifyListeners();
  }
}
