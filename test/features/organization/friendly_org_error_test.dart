import 'package:flutter_test/flutter_test.dart';

import 'package:camp_connect/features/organization/presentation/organization_screen.dart';
import 'package:camp_connect/l10n/app_localizations_en.g.dart';

void main() {
  final l10n = AppL10nEn();

  group('friendlyOrgError', () {
    test('not-org-owner maps to notOrgOwner', () {
      expect(friendlyOrgError('not-org-owner', l10n), l10n.notOrgOwner);
    });

    test('network errors map to networkError', () {
      expect(
        friendlyOrgError('firebase_functions/unavailable network error', l10n),
        l10n.networkError,
      );
    });

    test('anything else maps to somethingWentWrong', () {
      expect(friendlyOrgError('kaboom', l10n), l10n.somethingWentWrong);
    });
  });
}
