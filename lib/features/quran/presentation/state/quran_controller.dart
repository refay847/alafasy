import 'package:flutter/material.dart';

import '../../data/datasources/quran_preferences.dart';

/// Holds UI-level state that must survive navigation: favorites and theme.
class QuranController extends ChangeNotifier {
  QuranController({required QuranPreferences preferences})
      : _preferences = preferences,
        _favorites = preferences.favorites,
        _themeMode = preferences.themeMode;

  final QuranPreferences _preferences;

  final Set<int> _favorites;
  ThemeMode _themeMode;

  ThemeMode get themeMode => _themeMode;

  int get favoritesCount => _favorites.length;

  bool isFavorite(int surahNumber) => _favorites.contains(surahNumber);

  Future<void> toggleFavorite(int surahNumber) async {
    if (!_favorites.remove(surahNumber)) {
      _favorites.add(surahNumber);
    }

    notifyListeners();
    await _preferences.setFavorites(_favorites);
  }

  Future<void> toggleTheme({required bool isDarkNow}) async {
    _themeMode = isDarkNow ? ThemeMode.light : ThemeMode.dark;

    notifyListeners();
    await _preferences.setThemeMode(_themeMode);
  }
}