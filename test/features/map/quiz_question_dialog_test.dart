// test/features/map/quiz_question_dialog_test.dart
//
// Regression test for a correctness bug in the private _QuizQuestionDialog
// (declared inside knowledge_base_editor_screen.dart): _correctIndex tracks
// the position among the 4 ORIGINAL option text-field slots, but the
// options list submitted to QuizQuestion is FILTERED (empty slots dropped).
// Before the fix, comparing the raw _correctIndex against the filtered
// list's length silently produced the WRONG correctIndex whenever a
// non-trailing slot was left empty -- e.g. filling slots 1, 3, 4 and
// marking slot 3 as correct stored slot 4's text as the "correct answer"
// instead, with no validation error.
//
// _QuizQuestionDialog is private to its library, so it can't be
// instantiated directly from this test file; it's driven end-to-end
// through the public KnowledgeBaseEditorScreen (open editor -> tap "add
// question" -> fill the dialog -> save), mirroring the precedent in
// teams_management_dialog_test.dart of testing a private in-screen dialog
// through its host screen. LocationRepository is a concrete class
// constructed from FirebaseFirestore (same shape as TeamsRepository in that
// precedent), so updateKnowledgeBase is overridden to capture the payload
// instead of hitting Firestore.
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:camp_connect/features/auth/domain/app_user.dart';
import 'package:camp_connect/features/map/data/location_repository.dart';
import 'package:camp_connect/features/map/domain/location.dart';
import 'package:camp_connect/features/map/presentation/knowledge_base_editor_screen.dart';
import 'package:camp_connect/l10n/app_localizations.g.dart';
import 'package:camp_connect/shared/providers/providers.dart';

class _CapturingLocationRepository extends LocationRepository {
  _CapturingLocationRepository() : super(firestore: FakeFirebaseFirestore());

  Map<String, dynamic>? lastKnowledgeBase;

  @override
  Future<void> updateKnowledgeBase(
    String orgId,
    String locationId,
    Map<String, dynamic> knowledgeBase,
  ) async {
    lastKnowledgeBase = knowledgeBase;
  }
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

  final testUser = AppUser(
    uid: 'guide-1',
    role: 'guide',
    displayName: 'Guide',
    orgId: 'org-1',
    createdAt: DateTime(2026, 7, 1),
  );

  Widget buildTestable(_CapturingLocationRepository repo) => ProviderScope(
        overrides: [
          appUserProvider.overrideWith((ref) => Future.value(testUser)),
          locationRepositoryProvider.overrideWithValue(repo),
        ],
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppL10n.localizationsDelegates,
          supportedLocales: AppL10n.supportedLocales,
          home: KnowledgeBaseEditorScreen(location: testLocation),
        ),
      );

  /// Opens the "add question" dialog (must already be open), fills the
  /// question field plus whichever of the 4 option slots in [options] are
  /// non-null (leaving the rest blank), selects [correctSlot] (0-3, an
  /// index into the 4 ORIGINAL slots) as the correct answer, and saves.
  Future<void> fillAndSubmitDialog(
    WidgetTester tester, {
    required String question,
    required List<String?> options,
    required int correctSlot,
  }) async {
    final l10n = AppL10n.of(
      tester.element(find.byType(KnowledgeBaseEditorScreen)),
    );

    final dialogFields = find.descendant(
      of: find.byType(AlertDialog),
      matching: find.byType(TextFormField),
    );
    // Slot 0 is the question field; slots 1-4 are the 4 option fields.
    await tester.enterText(dialogFields.at(0), question);
    for (var i = 0; i < options.length; i++) {
      final text = options[i];
      if (text != null) {
        await tester.enterText(dialogFields.at(i + 1), text);
      }
    }

    final radios = find.descendant(
      of: find.byType(AlertDialog),
      matching: find.byType(Radio<int>),
    );
    await tester.ensureVisible(radios.at(correctSlot));
    await tester.tap(radios.at(correctSlot));
    await tester.pump();

    final saveButton = find.widgetWithText(FilledButton, l10n.saveChanges);
    await tester.ensureVisible(saveButton);
    await tester.tap(saveButton);
    await tester.pumpAndSettle();
  }

  testWidgets(
    'marking a non-trailing option as correct while an earlier slot is '
    'empty still stores the guide-selected answer, not a shifted one '
    '(regression for the silent wrong-answer bug)',
    (tester) async {
      final repo = _CapturingLocationRepository();
      await tester.pumpWidget(buildTestable(repo));
      await tester.pumpAndSettle();

      final screenContext = tester.element(
        find.byType(KnowledgeBaseEditorScreen),
      );
      final l10n = AppL10n.of(screenContext);
      // KnowledgeBaseEditorScreen only ref.reads appUserProvider (inside
      // _save, on tap) rather than ref.watching it during build, so in
      // isolation nothing has triggered/awaited it yet. In the real app
      // some earlier screen has already watched it by the time a guide
      // reaches this screen; here we prime it explicitly so _save's
      // ref.read(appUserProvider).valueOrNull isn't still AsyncLoading
      // (with a null orgId) on the very first save attempt.
      await ProviderScope.containerOf(screenContext)
          .read(appUserProvider.future);

      await tester.tap(find.widgetWithText(TextButton, l10n.addQuizQuestion));
      await tester.pumpAndSettle();

      // Fill slots 0, 2, 3 (i.e. options 1, 3, 4); leave slot 1 (option 2)
      // empty; mark slot 2 (option 3) -- NOT the trailing slot -- correct.
      await fillAndSubmitDialog(
        tester,
        question: 'Which one?',
        options: ['Option A', null, 'Option C', 'Option D'],
        correctSlot: 2,
      );

      expect(find.byType(AlertDialog), findsNothing);
      // The list tile's subtitle shows the actual correct-answer text. It's
      // below the fold in the test viewport (the ListView isn't scrolled),
      // so these checks look at the full element tree rather than only
      // on-screen widgets -- the text is genuinely present, just unscrolled.
      expect(find.text('Option C', skipOffstage: false), findsOneWidget);
      expect(find.text('Option D', skipOffstage: false), findsNothing);

      // Persist and inspect exactly what would be written to Firestore.
      final saveLocation = find.widgetWithText(
        FilledButton,
        l10n.saveLocation,
        skipOffstage: false,
      );
      await tester.ensureVisible(saveLocation);
      await tester.pumpAndSettle();
      await tester.tap(saveLocation);
      await tester.pumpAndSettle();

      final quiz = repo.lastKnowledgeBase!['quiz'] as List;
      expect(quiz, hasLength(1));
      final saved = quiz.first as Map<String, dynamic>;
      final savedOptions = List<String>.from(saved['options'] as List);
      final correctIndex = saved['correctIndex'] as int;

      // The empty slot was dropped: the filtered list is 3 items long.
      expect(savedOptions, ['Option A', 'Option C', 'Option D']);
      // Bug (pre-fix): raw _correctIndex (2) would point at savedOptions[2]
      // == 'Option D', silently storing the wrong answer.
      // Fix: correctIndex is remapped to the filtered position of the
      // slot the guide actually selected.
      expect(correctIndex, 1);
      expect(savedOptions[correctIndex], 'Option C');
    },
  );

  testWidgets(
    'a trailing empty option (the case that happened to work before the '
    'fix) still remaps correctly',
    (tester) async {
      final repo = _CapturingLocationRepository();
      await tester.pumpWidget(buildTestable(repo));
      await tester.pumpAndSettle();

      final screenContext = tester.element(
        find.byType(KnowledgeBaseEditorScreen),
      );
      final l10n = AppL10n.of(screenContext);
      // KnowledgeBaseEditorScreen only ref.reads appUserProvider (inside
      // _save, on tap) rather than ref.watching it during build, so in
      // isolation nothing has triggered/awaited it yet. In the real app
      // some earlier screen has already watched it by the time a guide
      // reaches this screen; here we prime it explicitly so _save's
      // ref.read(appUserProvider).valueOrNull isn't still AsyncLoading
      // (with a null orgId) on the very first save attempt.
      await ProviderScope.containerOf(screenContext)
          .read(appUserProvider.future);

      await tester.tap(find.widgetWithText(TextButton, l10n.addQuizQuestion));
      await tester.pumpAndSettle();

      // Fill slots 0-2 (options 1-3); leave slot 3 (option 4, trailing)
      // empty; mark slot 1 (option 2) as correct.
      await fillAndSubmitDialog(
        tester,
        question: 'Which one?',
        options: ['Option A', 'Option B', 'Option C', null],
        correctSlot: 1,
      );

      expect(find.byType(AlertDialog), findsNothing);
      expect(find.text('Option B', skipOffstage: false), findsOneWidget);

      final saveLocation = find.widgetWithText(
        FilledButton,
        l10n.saveLocation,
        skipOffstage: false,
      );
      await tester.ensureVisible(saveLocation);
      await tester.pumpAndSettle();
      await tester.tap(saveLocation);
      await tester.pumpAndSettle();

      final quiz = repo.lastKnowledgeBase!['quiz'] as List;
      final saved = quiz.first as Map<String, dynamic>;
      final savedOptions = List<String>.from(saved['options'] as List);
      final correctIndex = saved['correctIndex'] as int;

      expect(savedOptions, ['Option A', 'Option B', 'Option C']);
      expect(correctIndex, 1);
      expect(savedOptions[correctIndex], 'Option B');
    },
  );

  testWidgets(
    'selecting an empty option as correct blocks submission instead of '
    'silently accepting it',
    (tester) async {
      final repo = _CapturingLocationRepository();
      await tester.pumpWidget(buildTestable(repo));
      await tester.pumpAndSettle();

      final screenContext = tester.element(
        find.byType(KnowledgeBaseEditorScreen),
      );
      final l10n = AppL10n.of(screenContext);
      // KnowledgeBaseEditorScreen only ref.reads appUserProvider (inside
      // _save, on tap) rather than ref.watching it during build, so in
      // isolation nothing has triggered/awaited it yet. In the real app
      // some earlier screen has already watched it by the time a guide
      // reaches this screen; here we prime it explicitly so _save's
      // ref.read(appUserProvider).valueOrNull isn't still AsyncLoading
      // (with a null orgId) on the very first save attempt.
      await ProviderScope.containerOf(screenContext)
          .read(appUserProvider.future);

      await tester.tap(find.widgetWithText(TextButton, l10n.addQuizQuestion));
      await tester.pumpAndSettle();

      // Fill only slots 0 and 2; leave slot 1 (a non-trailing slot) empty
      // and select IT as the correct answer.
      await fillAndSubmitDialog(
        tester,
        question: 'Which one?',
        options: ['Option A', null, 'Option C', null],
        correctSlot: 1,
      );

      // Validation must fail: the dialog stays open and no question is
      // added, rather than silently dropping the guide's selection.
      expect(find.byType(AlertDialog), findsOneWidget);
      expect(find.text(l10n.quizNeedTwoOptions), findsOneWidget);
    },
  );
}
