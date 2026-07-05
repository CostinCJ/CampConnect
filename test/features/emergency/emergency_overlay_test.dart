import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:camp_connect/features/emergency/presentation/emergency_overlay.dart';
import 'package:camp_connect/features/emergency/domain/emergency_alert.dart';
import 'package:camp_connect/features/auth/domain/app_user.dart';
import 'package:camp_connect/l10n/app_localizations.g.dart';
import 'package:camp_connect/shared/providers/providers.dart';

void main() {
  EmergencyAlert alert(String id, {String senderId = 'other-guide'}) =>
      EmergencyAlert(
        id: id,
        message: 'Test alert',
        senderId: senderId,
        senderName: 'Other Guide',
        acknowledgedBy: const [],
        timestamp: DateTime(2026, 7, 5),
      );

  Widget buildTestable(StreamController<List<EmergencyAlert>> controller) {
    return ProviderScope(
      overrides: [
        emergencyAlertsProvider.overrideWith((ref) => controller.stream),
        appUserProvider.overrideWith((ref) async => AppUser(
              uid: 'me',
              role: 'guide',
              displayName: 'Me',
              createdAt: DateTime(2026, 7, 5),
            )),
      ],
      child: MaterialApp(
        localizationsDelegates: AppL10n.localizationsDelegates,
        supportedLocales: AppL10n.supportedLocales,
        // Consumer keeps appUserProvider watched/alive for the lifetime of
        // the widget tree, mirroring the real app: app.dart / SplashScreen
        // always watch appUserProvider above any guide screen, so by the
        // time EmergencyAlertListener is reachable it's already resolved
        // and kept alive. Without an ancestor watcher here, the provider
        // would be recreated (and reset to AsyncLoading) on every ref.read
        // inside EmergencyAlertListener's listener callback.
        home: Consumer(
          builder: (context, ref, _) {
            ref.watch(appUserProvider);
            return const Scaffold(
              body: EmergencyAlertListener(child: SizedBox()),
            );
          },
        ),
      ),
    );
  }

  testWidgets(
    'the same alert id does not stack a second dialog on repeated stream emissions',
    (tester) async {
      final controller = StreamController<List<EmergencyAlert>>();
      await tester.pumpWidget(buildTestable(controller));
      await tester.pump(); // let appUserProvider's Future resolve

      controller.add([alert('alert-1')]);
      await tester.pump();
      await tester.pump();
      expect(find.byType(Dialog), findsOneWidget);
      // Capture the dialog route's Element identity so a "pop the old one,
      // push a fresh one" implementation (which would also end up with
      // findsOneWidget) is distinguishable from a genuine no-op skip.
      final firstDialogElement = tester.element(find.byType(Dialog));

      controller.add([alert('alert-1')]); // same alert re-emitted
      await tester.pump();
      await tester.pump();

      expect(find.byType(Dialog), findsOneWidget);
      expect(
        tester.element(find.byType(Dialog)),
        same(firstDialogElement),
        reason: 'the duplicate-guard must be a true no-op skip, not a '
            'pop-and-reshow of the same alert id (which would also satisfy '
            'findsOneWidget but is a different, unnecessary dialog instance)',
      );
      await controller.close();
    },
  );

  testWidgets('an alert sent by the current user is never shown to themselves',
      (tester) async {
    final controller = StreamController<List<EmergencyAlert>>();
    await tester.pumpWidget(buildTestable(controller));
    await tester.pump();

    controller.add([alert('alert-2', senderId: 'me')]);
    await tester.pump();
    await tester.pump();

    expect(find.byType(Dialog), findsNothing);
    await controller.close();
  });

  testWidgets(
    'a new alert after an old one is shown replaces it rather than stacking',
    (tester) async {
      final controller = StreamController<List<EmergencyAlert>>();
      await tester.pumpWidget(buildTestable(controller));
      await tester.pump();

      controller.add([alert('alert-3')]);
      await tester.pump();
      await tester.pump();
      expect(find.byType(Dialog), findsOneWidget);

      controller.add([alert('alert-4'), alert('alert-3')]);
      await tester.pump();
      await tester.pump();
      expect(find.byType(Dialog), findsOneWidget); // still exactly one, not stacked

      await controller.close();
    },
  );
}
