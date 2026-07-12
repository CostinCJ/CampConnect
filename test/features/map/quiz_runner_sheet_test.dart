// test/features/map/quiz_runner_sheet_test.dart
//
// Widget tests for QuizRunnerSheet (lib/features/map/presentation/
// quiz_runner_sheet.dart) plus the best-score display of the private
// _QuizEntryButton it's launched from (lib/features/map/presentation/
// location_detail_page.dart). QuizRunnerSheet is public, so it's pumped
// directly; _QuizEntryButton is private to its library, so -- mirroring
// _CheckInSection's treatment in check_in_section_test.dart -- it's driven
// through the public LocationDetailPage instead.
//
// QuizRunnerSheet only touches Hive indirectly, through
// passportStorageProvider.saveQuizResult(). Following check_in_section_test
// .dart's precedent, only that storage boundary is faked
// (_FakePassportLocalStorage); the widget's own state machine runs for
// real.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:camp_connect/core/theme/app_theme.dart';
import 'package:camp_connect/features/auth/domain/app_user.dart';
import 'package:camp_connect/features/map/domain/location.dart';
import 'package:camp_connect/features/map/presentation/location_detail_page.dart';
import 'package:camp_connect/features/map/presentation/quiz_runner_sheet.dart';
import 'package:camp_connect/features/passport/data/passport_local_storage.dart';
import 'package:camp_connect/features/passport/domain/passport_stamp.dart';
import 'package:camp_connect/l10n/app_localizations.g.dart';
import 'package:camp_connect/shared/providers/providers.dart';

/// In-memory fake: real PassportLocalStorage logic (best-score-wins,
/// per-location keying) runs unmodified in the real notifier/providers
/// above it; only the Hive-backed box access is swapped out. Exposes
/// [quizResults] directly so tests can assert what QuizRunnerSheet actually
/// persisted, without going through a provider round-trip.
class _FakePassportLocalStorage extends PassportLocalStorage {
  final Map<String, QuizResult> quizResults;
  final List<PassportStamp> _stamps;

  _FakePassportLocalStorage({
    Map<String, QuizResult>? initialQuizResults,
    List<PassportStamp> initialStamps = const [],
  })  : quizResults = Map.of(initialQuizResults ?? {}),
        _stamps = List.of(initialStamps),
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
        visitedAt: DateTime(2026, 7, 10),
        locationName: locationName,
        categoryName: categoryName,
      ),
    );
  }

  @override
  Future<List<PassportStamp>> getStamps() async => List.of(_stamps);

  @override
  Future<void> saveQuizResult(QuizResult result) async {
    final existing = quizResults[result.locationId];
    if (existing != null && existing.correct >= result.correct) return;
    quizResults[result.locationId] = result;
  }

  @override
  Future<QuizResult?> getQuizResult(String locationId) async =>
      quizResults[locationId];

  @override
  Future<List<QuizResult>> getQuizResults() async =>
      quizResults.values.toList();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const oneQuestionQuiz = [
    QuizQuestion(
      question: 'What color is the sky?',
      options: ['Blue', 'Green', 'Red'],
      correctIndex: 0,
    ),
  ];

  const twoQuestionQuiz = [
    QuizQuestion(
      question: 'What color is the sky?',
      options: ['Blue', 'Green'],
      correctIndex: 0,
    ),
    QuizQuestion(
      question: 'What color is grass?',
      options: ['Purple', 'Green'],
      correctIndex: 1,
    ),
  ];

  Widget buildSheet({
    required List<QuizQuestion> quiz,
    required PassportLocalStorage storage,
    String locationId = 'loc-1',
  }) {
    return ProviderScope(
      overrides: [
        passportStorageProvider.overrideWithValue(storage),
      ],
      child: MaterialApp(
        theme: AppTheme.light(),
        locale: const Locale('en'),
        localizationsDelegates: AppL10n.localizationsDelegates,
        supportedLocales: AppL10n.supportedLocales,
        home: Scaffold(
          body: QuizRunnerSheet(locationId: locationId, quiz: quiz),
        ),
      ),
    );
  }

  testWidgets(
    'tapping an option shows correct feedback; further taps on other '
    'options (or the same option again) in that question are ineffective '
    'and do not double-count the score',
    (tester) async {
      final storage = _FakePassportLocalStorage();
      await tester.pumpWidget(
        buildSheet(quiz: oneQuestionQuiz, storage: storage),
      );
      await tester.pumpAndSettle();
      final l10n = AppL10n.of(tester.element(find.byType(QuizRunnerSheet)));

      await tester.tap(find.text('Blue')); // correct option
      await tester.pump();
      expect(find.text(l10n.quizCorrect), findsOneWidget);
      expect(find.text(l10n.quizWrong), findsNothing);

      // Tap a different (wrong) option in the SAME question: must be a
      // no-op (onTap became null once answered), so the feedback must not
      // flip to "wrong".
      await tester.tap(find.text('Green'));
      await tester.pump();
      expect(find.text(l10n.quizCorrect), findsOneWidget);
      expect(find.text(l10n.quizWrong), findsNothing);

      // Tap the correct option again: also a no-op. This is the case that
      // would reveal a _correctCount double-increment bug.
      await tester.tap(find.text('Blue'));
      await tester.pump();
      expect(find.text(l10n.quizCorrect), findsOneWidget);

      // Finish. With only one question, a double-increment bug would make
      // the persisted correctCount (2 or 3) diverge from total (1) --
      // observable both as a non-perfect score view and in the persisted
      // result.
      expect(find.text(l10n.quizFinish), findsOneWidget);
      await tester.tap(find.text(l10n.quizFinish));
      await tester.pumpAndSettle();

      expect(find.text(l10n.quizPerfect), findsOneWidget);
      expect(find.byIcon(Icons.star), findsOneWidget);

      final saved = storage.quizResults['loc-1'];
      expect(saved, isNotNull);
      expect(saved!.correct, 1);
      expect(saved.total, 1);
    },
  );

  testWidgets(
    'tapping Next on a non-final question advances to the next question '
    'without leaving stale correct/wrong feedback visible',
    (tester) async {
      final storage = _FakePassportLocalStorage();
      await tester.pumpWidget(
        buildSheet(quiz: twoQuestionQuiz, storage: storage),
      );
      await tester.pumpAndSettle();
      final l10n = AppL10n.of(tester.element(find.byType(QuizRunnerSheet)));

      expect(find.text(l10n.quizQuestionOf(1, 2)), findsOneWidget);

      await tester.tap(find.text('Blue')); // Q1, correct
      await tester.pump();
      expect(find.text(l10n.quizCorrect), findsOneWidget);
      expect(find.text(l10n.quizNext), findsOneWidget);

      await tester.tap(find.text(l10n.quizNext));
      await tester.pump();

      expect(find.text(l10n.quizQuestionOf(2, 2)), findsOneWidget);
      // No stale feedback text or answer-only controls from Q1 must be
      // showing before the kid has tapped anything on Q2.
      expect(find.text(l10n.quizCorrect), findsNothing);
      expect(find.text(l10n.quizWrong), findsNothing);
      expect(find.text(l10n.quizNext), findsNothing);
      expect(find.text(l10n.quizFinish), findsNothing);
    },
  );

  testWidgets(
    'completing a multi-question quiz with a mix of correct/wrong answers '
    'shows the non-perfect score view and persists the right correct/total',
    (tester) async {
      final storage = _FakePassportLocalStorage();
      await tester.pumpWidget(
        buildSheet(quiz: twoQuestionQuiz, storage: storage),
      );
      await tester.pumpAndSettle();
      final l10n = AppL10n.of(tester.element(find.byType(QuizRunnerSheet)));

      await tester.tap(find.text('Blue')); // Q1, correct
      await tester.pump();
      await tester.tap(find.text(l10n.quizNext));
      await tester.pump();

      await tester.tap(find.text('Purple')); // Q2, WRONG (correct is Green)
      await tester.pump();
      expect(find.text(l10n.quizFinish), findsOneWidget);
      await tester.tap(find.text(l10n.quizFinish));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.emoji_events_outlined), findsOneWidget);
      expect(find.text(l10n.quizScore(1, 2)), findsOneWidget);
      expect(find.byIcon(Icons.star), findsNothing);
      expect(find.text(l10n.quizPerfect), findsNothing);

      final saved = storage.quizResults['loc-1'];
      expect(saved, isNotNull);
      expect(saved!.correct, 1);
      expect(saved.total, 2);
    },
  );

  testWidgets(
    'completing a quiz with all correct answers shows the perfect-score '
    'view instead of the plain score view',
    (tester) async {
      final storage = _FakePassportLocalStorage();
      await tester.pumpWidget(
        buildSheet(quiz: twoQuestionQuiz, storage: storage),
      );
      await tester.pumpAndSettle();
      final l10n = AppL10n.of(tester.element(find.byType(QuizRunnerSheet)));

      await tester.tap(find.text('Blue')); // Q1, correct
      await tester.pump();
      await tester.tap(find.text(l10n.quizNext));
      await tester.pump();

      await tester.tap(find.text('Green')); // Q2, correct
      await tester.pump();
      await tester.tap(find.text(l10n.quizFinish));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.star), findsOneWidget);
      expect(find.text(l10n.quizPerfect), findsOneWidget);
      expect(find.byIcon(Icons.emoji_events_outlined), findsNothing);
      expect(find.text(l10n.quizScore(2, 2)), findsNothing);

      final saved = storage.quizResults['loc-1'];
      expect(saved, isNotNull);
      expect(saved!.correct, 2);
      expect(saved.total, 2);
    },
  );

  // -- _QuizEntryButton best-score display -----------------------------
  //
  // _QuizEntryButton is private to location_detail_page.dart, so it's
  // driven through the public LocationDetailPage, mirroring how
  // check_in_section_test.dart drives _CheckInSection. The fixture location
  // needs a non-empty knowledgeBase.quiz for the button to render at all
  // (its `kb.quiz.isNotEmpty` gate), and the signed-in user is a guide (not
  // a kid) so _CheckInSection -- rendered lower on the same page -- bails
  // out early and can't add confounding widgets to the tree.
  group('_QuizEntryButton best-score display (via LocationDetailPage)', () {
    final quizLocation = Location(
      id: 'loc-1',
      name: 'Old Oak Tree',
      latitude: 45.0,
      longitude: 25.0,
      description: '',
      category: LocationCategory.nature,
      createdBy: 'guide-1',
      timestamp: DateTime(2026, 7, 1),
      knowledgeBase: const KnowledgeBase(quiz: oneQuestionQuiz),
    );

    final guideUser = AppUser(
      uid: 'g1',
      role: 'guide',
      displayName: 'Guide',
      createdAt: DateTime(2026, 7, 1),
    );

    Widget buildDetailPage({
      required Location location,
      required Map<String, QuizResult> quizResults,
    }) {
      return ProviderScope(
        overrides: [
          appUserProvider.overrideWith((ref) => Future.value(guideUser)),
          quizResultsProvider.overrideWith(
            (ref) => Future.value(quizResults),
          ),
        ],
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppL10n.localizationsDelegates,
          supportedLocales: AppL10n.supportedLocales,
          home: LocationDetailPage(masterLocation: location),
        ),
      );
    }

    testWidgets(
      'renders with no best-score text when there is no result for this '
      'location',
      (tester) async {
        await tester.pumpWidget(
          buildDetailPage(location: quizLocation, quizResults: const {}),
        );
        await tester.pumpAndSettle();

        final l10n =
            AppL10n.of(tester.element(find.byType(LocationDetailPage)));
        expect(find.text(l10n.takeQuiz), findsOneWidget);
        // The best-score line is only ever "Best score: {correct}/{total}"
        // -- checking the fixed prefix is robust to whatever numbers a
        // (bugged) implementation might otherwise show.
        expect(find.textContaining('Best score'), findsNothing);
      },
    );

    testWidgets(
      'renders the best-score text when quizResultsProvider resolves an '
      'entry for this location',
      (tester) async {
        final result = QuizResult(
          locationId: quizLocation.id,
          correct: 1,
          total: 1,
          completedAt: DateTime(2026, 7, 10),
        );
        await tester.pumpWidget(
          buildDetailPage(
            location: quizLocation,
            quizResults: {quizLocation.id: result},
          ),
        );
        await tester.pumpAndSettle();

        final l10n =
            AppL10n.of(tester.element(find.byType(LocationDetailPage)));
        expect(find.text(l10n.takeQuiz), findsOneWidget);
        expect(find.text(l10n.quizBestScore(1, 1)), findsOneWidget);
      },
    );
  });
}
