import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:camp_connect/features/auth/domain/app_user.dart';
import 'package:camp_connect/features/emergency/data/emergency_repository.dart';
import 'package:camp_connect/features/emergency/domain/emergency_alert.dart';
import 'package:camp_connect/features/emergency/presentation/emergency_screen.dart';
import 'package:camp_connect/l10n/app_localizations.g.dart';
import 'package:camp_connect/shared/providers/providers.dart';

/// Records created alerts; [gate] lets a test hold createAlert open to
/// simulate a slow network while the sheet is dismissed.
class _FakeEmergencyRepository extends Fake implements EmergencyRepository {
  final created = <(String, EmergencyAlert)>[];
  Completer<void>? gate;

  @override
  Stream<List<EmergencyAlert>> watchAlerts(String campId) =>
      Stream.value(const []);

  @override
  Future<String> createAlert(String campId, EmergencyAlert alert) async {
    await gate?.future;
    created.add((campId, alert));
    return 'alert-1';
  }
}

void main() {
  late _FakeEmergencyRepository repo;

  setUp(() => repo = _FakeEmergencyRepository());

  Widget buildTestable() {
    return ProviderScope(
      overrides: [
        emergencyRepositoryProvider.overrideWithValue(repo),
        orgMembersProvider.overrideWith((ref) => Stream.value(const [])),
        appUserProvider.overrideWith((ref) async => AppUser(
              uid: 'guide-1',
              role: 'guide',
              displayName: 'Ana',
              campId: 'camp-1',
              orgId: 'org-1',
              createdAt: DateTime(2026, 9, 30),
            )),
      ],
      child: MaterialApp(
        localizationsDelegates: AppL10n.localizationsDelegates,
        supportedLocales: AppL10n.supportedLocales,
        locale: const Locale('en'),
        // Keep appUserProvider alive like the real app shell does.
        home: Consumer(builder: (context, ref, _) {
          ref.watch(appUserProvider);
          ref.watch(activeCampIdProvider);
          return const EmergencyScreen();
        }),
      ),
    );
  }

  AppL10n l10nOf(WidgetTester tester) =>
      AppL10n.of(tester.element(find.byType(EmergencyScreen)));

  Future<void> openSheetAndConfirm(WidgetTester tester) async {
    final l10n = l10nOf(tester);
    await tester.tap(find.text(l10n.sendEmergencyAlert));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'Kid missing at lake');
    await tester.ensureVisible(find.text(l10n.send));
    await tester.tap(find.text(l10n.send));
    await tester.pumpAndSettle();
    // Confirmation dialog: its Send is the last one in the tree.
    await tester.tap(find.text(l10n.send).last);
  }

  testWidgets('sending creates the alert for the active camp and closes the sheet',
      (tester) async {
    await tester.pumpWidget(buildTestable());
    await tester.pumpAndSettle();

    await openSheetAndConfirm(tester);
    await tester.pumpAndSettle();

    expect(repo.created, hasLength(1));
    final (campId, alert) = repo.created.single;
    expect(campId, 'camp-1');
    expect(alert.senderId, 'guide-1');
    expect(alert.message, 'Kid missing at lake');
    expect(alert.hasLocation, isFalse);
    expect(find.text(l10nOf(tester).emergencyAlertSent), findsOneWidget);
  });

  testWidgets('dismissing the sheet while the send is in flight still sends it',
      (tester) async {
    repo.gate = Completer<void>();
    await tester.pumpWidget(buildTestable());
    await tester.pumpAndSettle();

    await openSheetAndConfirm(tester);
    await tester.pump(); // dialog closes; createAlert is now pending
    await tester.pump(const Duration(milliseconds: 300));

    // The guide swipes the sheet away before the write completes.
    Navigator.of(tester.element(find.byType(TextField).first)).pop();
    await tester.pumpAndSettle();

    repo.gate!.complete();
    await tester.pumpAndSettle();

    expect(repo.created, hasLength(1));
    expect(tester.takeException(), isNull);
  });
}
