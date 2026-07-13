import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:camp_connect/features/auth/domain/app_user.dart';
import 'package:camp_connect/features/home/presentation/kid_onboarding_card.dart';
import 'package:camp_connect/l10n/app_localizations.g.dart';
import 'package:camp_connect/shared/providers/providers.dart';

void main() {
  AppUser kid(String uid) => AppUser(
    uid: uid,
    role: 'kid',
    displayName: 'X',
    orgId: 'org-1',
    createdAt: DateTime(2026, 7, 1),
  );

  Future<Widget> buildTestable({
    required String uid,
    Map<String, Object> initialPrefs = const {},
  }) async {
    SharedPreferences.setMockInitialValues(initialPrefs);
    final prefs = await SharedPreferences.getInstance();

    return ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        appUserProvider.overrideWith((ref) => Future.value(kid(uid))),
      ],
      child: const MaterialApp(
        localizationsDelegates: AppL10n.localizationsDelegates,
        supportedLocales: AppL10n.supportedLocales,
        home: Scaffold(body: KidOnboardingCard()),
      ),
    );
  }

  testWidgets('shows the onboarding card on first visit', (tester) async {
    await tester.pumpWidget(await buildTestable(uid: 'kid-1'));
    await tester.pumpAndSettle();

    final l10n = AppL10n.of(tester.element(find.byType(KidOnboardingCard)));
    expect(find.text(l10n.onboardingTitle), findsOneWidget);
    expect(find.text(l10n.onboardingBody), findsOneWidget);
  });

  testWidgets('dismiss hides the card', (tester) async {
    await tester.pumpWidget(await buildTestable(uid: 'kid-1'));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.close));
    await tester.pumpAndSettle();

    expect(find.byType(Card), findsNothing);
  });

  testWidgets('stays hidden on a fresh widget tree if already dismissed',
      (tester) async {
    await tester.pumpWidget(await buildTestable(
      uid: 'kid-1',
      initialPrefs: {'kid_onboarding_dismissed_kid-1': true},
    ));
    await tester.pumpAndSettle();

    expect(find.byType(Card), findsNothing);
  });
}
