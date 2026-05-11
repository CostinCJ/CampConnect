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
      llmEnabled: _prefs.getBool(AppConstants.keyLlmEnabled) ?? true,
      deviceCapable: _prefs.getBool(AppConstants.keyDeviceCapable) ?? true,
      modelDownloaded: _prefs.getBool(AppConstants.keyModelDownloaded) ?? false,
      lastCampId: _prefs.getString(AppConstants.keyLastCampId),
    );
  }

  Future<void> setLanguage(String language) async {
    await _prefs.setString(AppConstants.keyLanguage, language);
  }

  Future<void> setTheme(String theme) async {
    await _prefs.setString(AppConstants.keyTheme, theme);
  }

  Future<void> setLlmEnabled(bool enabled) async {
    await _prefs.setBool(AppConstants.keyLlmEnabled, enabled);
  }

  Future<void> setDeviceCapable(bool capable) async {
    await _prefs.setBool(AppConstants.keyDeviceCapable, capable);
  }

  Future<void> setModelDownloaded(bool downloaded) async {
    await _prefs.setBool(AppConstants.keyModelDownloaded, downloaded);
  }

  Future<void> setLastCampId(String campId) async {
    await _prefs.setString(AppConstants.keyLastCampId, campId);
  }

  Future<void> clear() async {
    await _prefs.clear();
  }
}
