import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/constants/app_constants.dart';
import '../domain/app_settings.dart';

class SettingsRepository {
  final SharedPreferences _prefs;

  SettingsRepository(this._prefs);

  AppSettings load() {
    return AppSettings(
      language: _prefs.getString(AppConstants.keyLanguage) ?? 'ro',
      theme: _prefs.getString(AppConstants.keyTheme) ?? 'light',
    );
  }

  Future<void> setLanguage(String language) async {
    await _prefs.setString(AppConstants.keyLanguage, language);
  }

  Future<void> setTheme(String theme) async {
    await _prefs.setString(AppConstants.keyTheme, theme);
  }

  Future<void> clear() async {
    await _prefs.clear();
  }
}
