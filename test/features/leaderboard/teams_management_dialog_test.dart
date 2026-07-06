// test/features/leaderboard/teams_management_dialog_test.dart
//
// Verifies the loading/disabled guard added to _showTeamDialog in
// teams_management_screen.dart, in particular the claim that dismissing the
// dialog while the addTeam/updateTeam future is still pending does not throw
// when that future later resolves (either successfully or with an error).
//
// TeamsRepository is a concrete class (not an interface) constructed
// directly from FirebaseFirestore, so rather than stand up a fake Firestore
// backend we override teamsRepositoryProvider with a subclass whose
// addTeam/updateTeam are gated by a Completer we control from the test,
// letting us pause "mid-save" deterministically.
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'dart:async';

import 'package:camp_connect/features/leaderboard/data/teams_repository.dart';
import 'package:camp_connect/features/leaderboard/presentation/teams_management_screen.dart';
import 'package:camp_connect/l10n/app_localizations.g.dart';
import 'package:camp_connect/shared/providers/providers.dart';

class _GatedTeamsRepository extends TeamsRepository {
  // TeamsRepository's constructor eagerly falls back to
  // FirebaseFirestore.instance if firestore is omitted, which throws
  // (no Firebase app initialized) in a plain widget test. addTeam/updateTeam
  // are fully overridden below and never touch `_firestore` either way, so a
  // FakeFirebaseFirestore is just there to satisfy the constructor safely.
  _GatedTeamsRepository() : super(firestore: FakeFirebaseFirestore());

  final addTeamGate = Completer<void>();
  int addTeamCalls = 0;
  bool shouldThrow = false;

  @override
  Future<String> addTeam(String campId,
      {required String name, required String colorHex}) async {
    addTeamCalls++;
    await addTeamGate.future;
    if (shouldThrow) {
      throw Exception('simulated failure');
    }
    return 'new-team-id';
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Widget buildTestable(_GatedTeamsRepository repo) => ProviderScope(
        overrides: [
          // activeCampIdProvider now seeds from (and listens to) appUserProvider,
          // so stub that to null to keep the real Firebase auth chain out of the
          // test, then pin the active camp explicitly via the notifier.
          appUserProvider.overrideWith((ref) => Future.value(null)),
          activeCampIdProvider
              .overrideWith((ref) => ActiveCampIdNotifier(ref)..select('camp-1')),
          teamsRepositoryProvider.overrideWithValue(repo),
        ],
        child: MaterialApp(
          localizationsDelegates: AppL10n.localizationsDelegates,
          supportedLocales: AppL10n.supportedLocales,
          home: const TeamsManagementScreen(),
        ),
      );

  testWidgets(
      'dismissing the dialog while addTeam is still pending does not throw '
      'once the save later resolves', (tester) async {
    final repo = _GatedTeamsRepository();
    await tester.pumpWidget(buildTestable(repo));
    await tester.pumpAndSettle();

    // Open the "add team" dialog via the FAB.
    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();

    expect(find.byType(AlertDialog), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'Red Falcons');

    // Tap OK to kick off the async addTeam call, which will hang on
    // repo.addTeamGate until we complete it below.
    await tester.tap(find.widgetWithText(FilledButton, 'OK'));
    await tester.pump();

    expect(repo.addTeamCalls, 1,
        reason: 'save must have started (repo call made) before we try to '
            'dismiss the dialog');

    // Confirm the spinner/disabled guard is visible while the save is
    // in-flight (the actual Task 6 behavior, not just the dismiss safety).
    expect(find.byType(CircularProgressIndicator), findsWidgets);

    // Now dismiss the dialog while the addTeam future is still pending, by
    // tapping the modal barrier -- exactly how a real user would dismiss it
    // (this dialog is not barrierDismissible: false), rather than invoking
    // Navigator.pop programmatically.
    await tester.tapAt(const Offset(5, 5));
    await tester.pump();
    // Let the dialog's exit transition finish (barrier tap triggers an
    // animated pop, not an instant removal from the tree).
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byType(AlertDialog), findsNothing,
        reason: 'dialog should be gone immediately after the pop');

    // Let the still-pending addTeam call resolve now that the dialog/its
    // BuildContext is unmounted.
    repo.addTeamGate.complete();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pumpAndSettle();

    // The critical assertion: resolving the future after the dialog context
    // was already unmounted must not throw (e.g. calling Navigator.pop or
    // setState on a disposed dialog element).
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'dismissing the dialog while addTeam is pending and the save then '
      'fails does not throw, and the screen is still usable', (tester) async {
    final repo = _GatedTeamsRepository()..shouldThrow = true;
    await tester.pumpWidget(buildTestable(repo));
    await tester.pumpAndSettle();

    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'Blue Wolves');
    await tester.tap(find.widgetWithText(FilledButton, 'OK'));
    await tester.pump();

    expect(repo.addTeamCalls, 1);

    await tester.tapAt(const Offset(5, 5));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byType(AlertDialog), findsNothing);

    // Resolve with the simulated failure after the dialog is already gone.
    repo.addTeamGate.complete();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);

    // The screen itself must still be alive/interactive (no crash bubbled up
    // to the app), confirmed by the FAB still being present and tappable.
    expect(find.byType(FloatingActionButton), findsOneWidget);
  });
}
