// test/features/map/check_in_section_test.dart
//
// _CheckInSection is a private widget declared inside
// location_detail_page.dart, so these tests drive it through the public
// LocationDetailPage. Using a Location with an empty knowledge base and
// empty description keeps the rendered tree minimal, so `find.byType(Card)`
// unambiguously means "the visited card" (there's no fun-fact/KB card to
// confuse it with).
//
// passportProvider's real notifier (PassportNotifier) is exercised as-is --
// only its storage dependency (PassportLocalStorage) is swapped for a small
// in-memory fake. That mirrors the two precedents already in this codebase:
// passport_local_storage_test.dart fakes the I/O boundary and drives the
// real logic above it, and journal_editor_photo_test.dart overrides a
// StateNotifierProvider by subclassing for a Riverpod widget test. Combining
// them here lets "tap -> real checkIn() -> real loadStamps() -> Riverpod
// rebuild" run end-to-end without touching Hive, so the reactive flip in
// test 3 is a genuine assertion, not a stubbed one.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';

import 'package:camp_connect/features/auth/domain/app_user.dart';
import 'package:camp_connect/features/map/domain/location.dart';
import 'package:camp_connect/features/map/presentation/location_detail_page.dart';
import 'package:camp_connect/features/passport/data/passport_local_storage.dart';
import 'package:camp_connect/features/passport/domain/passport_stamp.dart';
import 'package:camp_connect/l10n/app_localizations.g.dart';
import 'package:camp_connect/shared/providers/providers.dart';

/// Fixed so the "visited on {date}" text is deterministic to assert against.
final _fixedVisitDate = DateTime(2026, 7, 10);

/// In-memory fake: real PassportNotifier logic runs unmodified, only the
/// Hive-backed storage is swapped out.
class _FakePassportLocalStorage extends PassportLocalStorage {
  final List<PassportStamp> _stamps;

  _FakePassportLocalStorage({List<PassportStamp> initialStamps = const []})
      : _stamps = List.of(initialStamps),
        super(storageKey: 'test-device');

  @override
  Future<void> addStamp(
    String locationId, {
    String? locationName,
    String? categoryName,
  }) async {
    if (_stamps.any((s) => s.locationId == locationId)) return;
    _stamps.add(
      PassportStamp(
        locationId: locationId,
        visitedAt: _fixedVisitDate,
        locationName: locationName,
        categoryName: categoryName,
      ),
    );
  }

  @override
  Future<List<PassportStamp>> getStamps() async => List.of(_stamps);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final testLocation = Location(
    id: 'loc-1',
    name: 'Old Oak Tree',
    latitude: 45.0,
    longitude: 25.0,
    description: '',
    category: LocationCategory.nature,
    createdBy: 'guide-1',
    timestamp: DateTime(2026, 7, 1),
  );

  AppUser user(String role) => AppUser(
        uid: 'u1',
        role: role,
        displayName: 'Test',
        createdAt: DateTime(2026, 7, 1),
      );

  Widget buildTestable({
    required String role,
    List<PassportStamp> initialStamps = const [],
  }) {
    return ProviderScope(
      overrides: [
        appUserProvider.overrideWith((ref) => Future.value(user(role))),
        passportProvider.overrideWith(
          (ref) => PassportNotifier(
            _FakePassportLocalStorage(initialStamps: initialStamps),
          ),
        ),
      ],
      child: MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppL10n.localizationsDelegates,
        supportedLocales: AppL10n.supportedLocales,
        home: LocationDetailPage(masterLocation: testLocation),
      ),
    );
  }

  testWidgets('a guide (non-kid) sees no check-in section', (tester) async {
    await tester.pumpWidget(buildTestable(role: 'guide'));
    await tester.pumpAndSettle();

    final l10n = AppL10n.of(tester.element(find.byType(LocationDetailPage)));
    expect(find.text(l10n.checkInHere), findsNothing);
    expect(find.byType(FilledButton), findsNothing);
    expect(find.byType(Card), findsNothing);
  });

  testWidgets('a kid with no stamp yet sees the check-in button', (
    tester,
  ) async {
    await tester.pumpWidget(buildTestable(role: 'kid'));
    await tester.pumpAndSettle();

    final l10n = AppL10n.of(tester.element(find.byType(LocationDetailPage)));
    expect(find.text(l10n.checkInHere), findsOneWidget);
    expect(find.byIcon(Icons.verified), findsNothing);
    expect(find.byType(Card), findsNothing);
  });

  testWidgets(
    'tapping check-in persists the stamp and flips the UI to visited',
    (tester) async {
      await tester.pumpWidget(buildTestable(role: 'kid'));
      await tester.pumpAndSettle();

      final l10n = AppL10n.of(
        tester.element(find.byType(LocationDetailPage)),
      );
      expect(find.text(l10n.checkInHere), findsOneWidget);

      await tester.tap(find.text(l10n.checkInHere));
      await tester.pumpAndSettle();

      final expectedDate = DateFormat('d MMMM yyyy', 'en')
          .format(_fixedVisitDate);
      expect(find.text(l10n.checkInHere), findsNothing);
      expect(find.text(l10n.visitedOn(expectedDate)), findsOneWidget);
      expect(find.byIcon(Icons.verified), findsOneWidget);
      // Success snackbar from the same tap.
      expect(find.text(l10n.checkInDone), findsOneWidget);
    },
  );

  testWidgets(
    'a kid who already checked in sees the visited card on first render',
    (tester) async {
      await tester.pumpWidget(
        buildTestable(
          role: 'kid',
          initialStamps: [
            PassportStamp(
              locationId: testLocation.id,
              visitedAt: _fixedVisitDate,
            ),
          ],
        ),
      );
      await tester.pumpAndSettle();

      final l10n = AppL10n.of(
        tester.element(find.byType(LocationDetailPage)),
      );
      final expectedDate = DateFormat('d MMMM yyyy', 'en')
          .format(_fixedVisitDate);
      expect(find.text(l10n.checkInHere), findsNothing);
      expect(find.byType(FilledButton), findsNothing);
      expect(find.text(l10n.visitedOn(expectedDate)), findsOneWidget);
    },
  );
}
