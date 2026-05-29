import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app_logger.dart';

/// Holds the user-selected app locale and persists it across launches.
///
/// A `null` value means "follow the system locale". Uses a [ValueNotifier]
/// (native state management) so `MaterialApp` can rebuild on change.
class LocaleController extends ValueNotifier<Locale?> {
  LocaleController() : super(null);

  static const _key = 'app_locale';

  /// Loads the saved locale from disk. Call once during startup.
  Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final code = prefs.getString(_key);
      if (code != null && code.isNotEmpty) {
        value = Locale(code);
      }
    } catch (e) {
      AppLogger.warning('failed to load saved locale: $e',
          name: 'locale_controller');
    }
  }

  /// Sets the active locale (or `null` to follow the system) and persists it.
  Future<void> setLocale(Locale? locale) async {
    value = locale;
    try {
      final prefs = await SharedPreferences.getInstance();
      if (locale == null) {
        await prefs.remove(_key);
      } else {
        await prefs.setString(_key, locale.languageCode);
      }
    } catch (e) {
      AppLogger.warning('failed to save locale: $e', name: 'locale_controller');
    }
  }
}
