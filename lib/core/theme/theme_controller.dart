import 'package:flutter/material.dart';

import '../security/key_store.dart';

/// Holds the selected [ThemeMode] and remembers it across launches.
class ThemeController extends ChangeNotifier {
  ThemeController(this._store);

  static const _key = 'passforge_theme_mode';
  final KeyStore _store;

  // Brand look is dark, so that's the default until the user picks otherwise.
  ThemeMode _mode = ThemeMode.dark;
  ThemeMode get mode => _mode;

  Future<void> load() async {
    final saved = await _store.read(_key);
    _mode = ThemeMode.values.firstWhere(
      (m) => m.name == saved,
      orElse: () => ThemeMode.dark,
    );
    notifyListeners();
  }

  Future<void> setMode(ThemeMode mode) async {
    if (mode == _mode) return;
    _mode = mode;
    notifyListeners();
    await _store.write(_key, mode.name);
  }
}
