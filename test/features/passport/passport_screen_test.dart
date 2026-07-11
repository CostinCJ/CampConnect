// test/features/passport/passport_screen_test.dart
//
// PassportScreen is a read-only grid, so this test overrides the three
// providers it watches directly (resolvedSessionLocationsProvider,
// passportProvider, quizResultsProvider) rather than exercising real
// storage end-to-end -- there's no user interaction to drive here, unlike
// check_in_section_test.dart's tap-to-checkin flow. passportProvider is
// still backed by the real PassportNotifier (as in check_in_section_test.dart)
// via a small in-memory fake storage, keeping that one piece of real logic
// exercised; the other two are plain FutureProvider overrides since they're
// simple reads.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:camp_connect/features/map/domain/location.dart';
import 'package:camp_connect/features/map/domain/session_location.dart';
import 'package:camp_connect/features/passport/data/passport_local_storage.dart';
import 'package:camp_connect/features/passport/domain/passport_stamp.dart';
import 'package:camp_connect/features/passport/presentation/passport_screen.dart';
import 'package:camp_connect/core/theme/app_theme.dart';
import 'package:camp_connect/l10n/app_localizations.g.dart';
import 'package:camp_connect/shared/providers/providers.dart';

/// In-memory fake: real PassportNotifier logic runs unmodified, only the
/// Hive-backed storage is swapped out (same pattern as
/// check_in_section_test.dart's _FakePassportLocalStorage).
class _FakePassportLocalStorage extends PassportLocalStorage {
  final List<PassportStamp> _stamps;

  _FakePassportLocalStorage({List<PassportStamp> initialStamps = const []})
      : _stamps = List.of(initialStamps),
        super(storageKey: 'test-device');

  @override
  Future<List<PassportStamp>> getStamps() async => List.of(_stamps);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final locationA = Location(
    id: 'loc-a',
    name: 'Old Oak Tree',
    latitude: 45.0,
    longitude: 25.0,
    description: '',
    category: LocationCategory.nature,
    createdBy: 'guide-1',
    timestamp: DateTime(2026, 7, 1),
  );

  final locationB = Location(
    id: 'loc-b',
    name: 'Stone Fort',
    latitude: 45.1,
    longitude: 25.1,
    description: '',
    category: LocationCategory.historical,
    createdBy: 'guide-1',
    timestamp: DateTime(2026, 7, 1),
  );

  ResolvedSessionLocation resolve(Location location) => ResolvedSessionLocation(
        sessionLocation: SessionLocation(
          id: 'session-${location.id}',
          masterLocationId: location.id,
          addedBy: 'guide-1',
          visitedAt: DateTime(2026, 7, 1),
        ),
        masterLocation: location,
      );

  Widget buildTestable({
    required List<ResolvedSessionLocation> locations,
    List<PassportStamp> stamps = const [],
    Map<String, QuizResult> quizResults = const {},
  }) {
    return ProviderScope(
      overrides: [
        resolvedSessionLocationsProvider.overrideWith(
          (ref) => Future.value(locations),
        ),
        passportProvider.overrideWith(
          (ref) => PassportNotifier(
            _FakePassportLocalStorage(initialStamps: stamps),
          ),
        ),
        quizResultsProvider.overrideWith((ref) => Future.value(quizResults)),
      ],
      child: MaterialApp(
        // PassportScreen reads theme.cardTheme.color! directly, so the
        // default MaterialApp ThemeData (which leaves cardTheme.color null)
        // isn't enough -- use the app's real theme, like
        // role_selection_screen_test.dart does.
        theme: AppTheme.light(),
        locale: const Locale('en'),
        localizationsDelegates: AppL10n.localizationsDelegates,
        supportedLocales: AppL10n.supportedLocales,
        home: const PassportScreen(),
      ),
    );
  }

  testWidgets(
    'zero session locations shows the empty state and no grid',
    (tester) async {
      await tester.pumpWidget(buildTestable(locations: const []));
      await tester.pumpAndSettle();

      final l10n = AppL10n.of(tester.element(find.byType(PassportScreen)));
      expect(find.text(l10n.noStampsYet), findsOneWidget);
      expect(find.byType(GridView), findsNothing);
    },
  );

  testWidgets(
    'a stamped location shows the verified icon; an unstamped one shows its category icon',
    (tester) async {
      await tester.pumpWidget(
        buildTestable(
          locations: [resolve(locationA), resolve(locationB)],
          stamps: [
            PassportStamp(
              locationId: locationA.id,
              visitedAt: DateTime(2026, 7, 5),
            ),
          ],
        ),
      );
      await tester.pumpAndSettle();

      // locationA is stamped: its own category icon is replaced by the
      // "verified" stamp icon.
      expect(find.byIcon(Icons.verified), findsOneWidget);
      expect(find.byIcon(LocationCategory.nature.icon), findsNothing);

      // locationB is unstamped: shows its plain category icon, no stamp.
      expect(find.byIcon(LocationCategory.historical.icon), findsOneWidget);
    },
  );

  testWidgets(
    'a perfect quiz result shows a star badge on the visited tile',
    (tester) async {
      await tester.pumpWidget(
        buildTestable(
          locations: [resolve(locationA)],
          stamps: [
            PassportStamp(
              locationId: locationA.id,
              visitedAt: DateTime(2026, 7, 5),
            ),
          ],
          quizResults: {
            locationA.id: QuizResult(
              locationId: locationA.id,
              correct: 3,
              total: 3,
              completedAt: DateTime(2026, 7, 5),
            ),
          },
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.star), findsOneWidget);
    },
  );

  testWidgets(
    'no session locations but existing stamps falls back to the stamps-only grid',
    (tester) async {
      await tester.pumpWidget(
        buildTestable(
          locations: const [],
          stamps: [
            PassportStamp(
              locationId: 'loc-a',
              visitedAt: DateTime(2026, 7, 5),
              locationName: 'Old Oak Tree',
              categoryName: 'nature',
            ),
            // Pre-denormalization stamp: no name/category stored.
            PassportStamp(
              locationId: 'loc-b',
              visitedAt: DateTime(2026, 7, 6),
            ),
          ],
          quizResults: {
            'loc-a': QuizResult(
              locationId: 'loc-a',
              correct: 3,
              total: 3,
              completedAt: DateTime(2026, 7, 5),
            ),
          },
        ),
      );
      await tester.pumpAndSettle();

      final l10n = AppL10n.of(tester.element(find.byType(PassportScreen)));
      // Not the empty state: the earned stamps render from their own data.
      expect(find.text(l10n.noStampsYet), findsNothing);
      expect(find.byType(GridView), findsOneWidget);
      expect(find.text('Old Oak Tree'), findsOneWidget);
      // The unnamed legacy stamp gets the generic label.
      expect(find.text(l10n.campLocationFallback), findsOneWidget);
      // Both cards are "visited"; the perfect quiz still earns its star.
      expect(find.byIcon(Icons.verified), findsNWidgets(2));
      expect(find.byIcon(Icons.star), findsOneWidget);
    },
  );

  testWidgets(
    'no quiz result means no star badge is shown',
    (tester) async {
      await tester.pumpWidget(
        buildTestable(
          locations: [resolve(locationA)],
          stamps: [
            PassportStamp(
              locationId: locationA.id,
              visitedAt: DateTime(2026, 7, 5),
            ),
          ],
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.star), findsNothing);
    },
  );
}
