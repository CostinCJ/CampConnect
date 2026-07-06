import 'package:flutter_test/flutter_test.dart';
import 'package:camp_connect/features/auth/domain/camp_session.dart';

void main() {
  // CampSession's real constructor also requires `teams` and `orgId`
  // (non-optional, no defaults) in addition to id/name/createdBy/startDate/
  // endDate. Only startDate/endDate matter for isActive/hasEnded, so the
  // rest are filled with placeholder values.
  CampSession sessionEnding(DateTime endDate) => CampSession(
        id: 'camp-1',
        name: 'Test Camp',
        createdBy: 'guide-1',
        startDate: DateTime(2026, 7, 1),
        endDate: endDate,
        teams: const [],
        orgId: 'org-1',
      );

  group('isActive / hasEnded boundary', () {
    test('is active one second before endDate', () {
      final session = sessionEnding(DateTime(2026, 7, 10, 23, 59, 59));
      final now = DateTime(2026, 7, 10, 23, 59, 58);
      expect(session.isActive(now: now), isTrue);
      expect(session.hasEnded(now: now), isFalse);
    });

    test('has ended exactly at endDate', () {
      final session = sessionEnding(DateTime(2026, 7, 10, 23, 59, 59));
      final now = DateTime(2026, 7, 10, 23, 59, 59);
      expect(session.isActive(now: now), isFalse);
      expect(session.hasEnded(now: now), isTrue);
    });

    test('has ended one second after endDate', () {
      final session = sessionEnding(DateTime(2026, 7, 10, 23, 59, 59));
      final now = DateTime(2026, 7, 11, 0, 0, 0);
      expect(session.isActive(now: now), isFalse);
      expect(session.hasEnded(now: now), isTrue);
    });

    test('is not active before startDate', () {
      final session = sessionEnding(DateTime(2026, 7, 10, 23, 59, 59));
      final now = DateTime(2026, 6, 30, 12, 0, 0);
      expect(session.isActive(now: now), isFalse);
    });

    test('defaults to DateTime.now() when now is not supplied', () {
      final farFuture = sessionEnding(DateTime(2099, 1, 1));
      expect(farFuture.isActive(), isTrue);
      final farPast = sessionEnding(DateTime(2000, 1, 1));
      expect(farPast.hasEnded(), isTrue);
    });
  });
}
