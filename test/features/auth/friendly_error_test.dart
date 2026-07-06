import 'package:flutter_test/flutter_test.dart';

import 'package:camp_connect/features/auth/presentation/guide_login_screen.dart';
import 'package:camp_connect/l10n/app_localizations_en.g.dart';

void main() {
  final l10n = AppL10nEn();

  group('friendlyGuideAuthError', () {
    test('maps weak-password to a specific, non-generic message', () {
      final result = friendlyGuideAuthError('weak-password', l10n);
      expect(result, isNot(contains('Something went wrong')));
      expect(result, equals(l10n.weakPassword));
    });

    test('maps auth-create-failed to a message (not silently generic-only by accident)', () {
      final result = friendlyGuideAuthError('auth-create-failed', l10n);
      expect(result, isNotEmpty);
      expect(result, equals(l10n.somethingWentWrong));
    });
  });
}
