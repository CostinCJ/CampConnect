import 'package:flutter_test/flutter_test.dart';
import 'package:camp_connect/core/l10n/localized_validators.dart';
import 'package:camp_connect/l10n/app_localizations_en.g.dart';

void main() {
  group('password validator', () {
    final validators = LocalizedValidators(AppL10nEn());

    test('rejects a 7-character password', () {
      final result = validators.password('abcdefg');
      expect(result, isNotNull);
    });

    test('accepts an 8-character password', () {
      final result = validators.password('abcdefgh');
      expect(result, isNull);
    });
  });
}
