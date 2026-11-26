import 'package:flutter/material.dart' show ThemeMode;
import 'package:just_audio/just_audio.dart' show LoopMode;
import 'package:shared_preferences/shared_preferences.dart';

/// Thin wrapper around SharedPreferences so the rest of the app never
/// touches raw keys.
class QuranPreferences {
  QuranPreferences._(this._prefs);

  final SharedPreferences _prefs;

  static Future<QuranPreferences> create() async {
    return QuranPreferences._(await SharedPreferences.getInstance());
  }

  static const _favoritesKey = 'favorites';
  static const _lastIndexKey = 'last_index';
  static const _lastPositionKey = 'last_position_ms';
  static const _themeKey = 'theme_mode';
  static const _speedKey = 'speed';
  static const _loopKey = 'loop_mode';
  static const _shuffleKey = 'shuffle';

  // Favorites
  Set<int> get favorites {
    final raw = _prefs.getStringList(_favoritesKey) ?? const <String>[];
    return raw.map(int.tryParse).whereType<int>().toSet();
  }

  Future<void> setFavorites(Set<int> value) {
    final sorted = value.toList()..sort();
    return _prefs.setStringList(
      _favoritesKey,
      sorted.map((e) => e.toString()).toList(),
    );
  }

  // Last session (resume)
  bool get hasLastSession => _prefs.containsKey(_lastIndexKey);

  int get lastIndex => _prefs.getInt(_lastIndexKey) ?? 0;

  Future<void> setLastIndex(int value) => _prefs.setInt(_lastIndexKey, value);

  /// Saves the surah index and the position inside it together, so the two
  /// values can never get out of sync (e.g. new surah + old position).
  Future<void> saveSession({required int index, required int positionMs}) async {
    await Future.wait([
      _prefs.setInt(_lastIndexKey, index),
      _prefs.setInt(_lastPositionKey, positionMs < 0 ? 0 : positionMs),
    ]);
  }

  int get lastPositionMs => _prefs.getInt(_lastPositionKey) ?? 0;

  Future<void> setLastPositionMs(int value) {
    return _prefs.setInt(_lastPositionKey, value);
  }

  // Theme
  ThemeMode get themeMode {
    switch (_prefs.getString(_themeKey)) {
      case 'dark':
        return ThemeMode.dark;
      case 'light':
        return ThemeMode.light;
      default:
        return ThemeMode.system;
    }
  }

  Future<void> setThemeMode(ThemeMode mode) {
    return _prefs.setString(_themeKey, mode.name);
  }

  // Playback settings
  double get speed => _prefs.getDouble(_speedKey) ?? 1.0;

  Future<void> setSpeed(double value) => _prefs.setDouble(_speedKey, value);

  LoopMode get loopMode {
    final index = _prefs.getInt(_loopKey) ?? 0;
    if (index < 0 || index >= LoopMode.values.length) return LoopMode.off;
    return LoopMode.values[index];
  }

  Future<void> setLoopMode(LoopMode mode) {
    return _prefs.setInt(_loopKey, mode.index);
  }

  bool get shuffle => _prefs.getBool(_shuffleKey) ?? false;

  Future<void> setShuffle(bool value) => _prefs.setBool(_shuffleKey, value);
}