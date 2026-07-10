import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:camp_connect/features/settings/data/settings_repository.dart';
import 'package:camp_connect/features/settings/domain/app_settings.dart';

void main() {
  group('AppSettings', () {
    test('kidLocationEnabled defaults to false', () {
      const settings = AppSettings();
      expect(settings.kidLocationEnabled, isFalse);
    });

    test('copyWith preserves and overrides kidLocationEnabled', () {
      const settings = AppSettings(kidLocationEnabled: true);
      expect(settings.copyWith(language: 'en').kidLocationEnabled, isTrue);
      expect(
        settings.copyWith(kidLocationEnabled: false).kidLocationEnabled,
        isFalse,
      );
    });
  });

  group('SettingsRepository', () {
    test('persists and loads kidLocationEnabled', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final repo = SettingsRepository(prefs);

      expect(repo.load().kidLocationEnabled, isFalse);
      await repo.setKidLocationEnabled(true);
      expect(repo.load().kidLocationEnabled, isTrue);
    });
  });
}
