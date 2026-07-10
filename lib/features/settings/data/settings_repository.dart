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
      kidLocationEnabled:
          _prefs.getBool(AppConstants.keyKidLocationEnabled) ?? false,
    );
  }

  Future<void> setLanguage(String language) async {
    await _prefs.setString(AppConstants.keyLanguage, language);
  }

  Future<void> setTheme(String theme) async {
    await _prefs.setString(AppConstants.keyTheme, theme);
  }

  Future<void> setKidLocationEnabled(bool enabled) async {
    await _prefs.setBool(AppConstants.keyKidLocationEnabled, enabled);
  }

  Future<void> clear() async {
    await _prefs.clear();
  }
}
