import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';

import 'package:camp_connect/features/organization/data/organization_repository.dart';
import 'package:camp_connect/features/organization/presentation/join_organization_screen.dart';
import 'package:camp_connect/l10n/app_localizations.g.dart';
import 'package:camp_connect/shared/providers/providers.dart';
import 'package:camp_connect/features/auth/data/auth_repository.dart';

class MockOrganizationRepository extends Mock
    implements OrganizationRepository {}

class MockAuthRepository extends Mock implements AuthRepository {}

void main() {
  late MockOrganizationRepository orgRepository;
  late MockAuthRepository authRepository;
  String? lastLocation;

  setUp(() {
    orgRepository = MockOrganizationRepository();
    authRepository = MockAuthRepository();
    lastLocation = null;
    when(
      () => authRepository.authStateChanges,
    ).thenAnswer((_) => const Stream.empty());
  });

  Widget buildTestable() {
    final router = GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) => const JoinOrganizationScreen(),
        ),
        GoRoute(
          path: '/guide',
          builder: (context, state) {
            lastLocation = '/guide';
            return const Scaffold(body: Text('guide-home'));
          },
        ),
        GoRoute(
          path: '/role-selection',
          builder: (context, state) {
            lastLocation = '/role-selection';
            return const Scaffold(body: Text('role-selection'));
          },
        ),
      ],
    );

    return ProviderScope(
      overrides: [
        organizationRepositoryProvider.overrideWithValue(orgRepository),
        authRepositoryProvider.overrideWithValue(authRepository),
      ],
      child: MaterialApp.router(
        routerConfig: router,
        localizationsDelegates: AppL10n.localizationsDelegates,
        supportedLocales: AppL10n.supportedLocales,
      ),
    );
  }

  testWidgets('successful join refreshes the ID token then navigates home', (
    tester,
  ) async {
    when(() => orgRepository.joinOrganization(any())).thenAnswer((_) async {});
    when(() => authRepository.refreshIdToken()).thenAnswer((_) async {});

    await tester.pumpWidget(buildTestable());
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextFormField), 'ABCDEFGHJK');
    await tester.tap(find.byType(FilledButton));
    await tester.pumpAndSettle();

    verify(() => orgRepository.joinOrganization('ABCDEFGHJK')).called(1);
    // Claims changed server-side — the cached token must be force-refreshed
    // or every org-scoped read is denied until the ~hourly auto-refresh.
    verify(() => authRepository.refreshIdToken()).called(1);
    expect(lastLocation, '/guide');
  });

  testWidgets('failed join shows error and stays', (tester) async {
    when(
      () => orgRepository.joinOrganization(any()),
    ).thenThrow(Exception('invalid-invite-code'));

    await tester.pumpWidget(buildTestable());
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextFormField), 'WRONG');
    await tester.tap(find.byType(FilledButton));
    await tester.pumpAndSettle();

    final l10n = AppL10n.of(
      tester.element(find.byType(JoinOrganizationScreen)),
    );
    expect(find.text(l10n.invalidInviteCode), findsOneWidget);
    expect(lastLocation, isNull);
  });

  testWidgets('sign out returns to role selection', (tester) async {
    when(() => authRepository.signOut()).thenAnswer((_) async {});

    await tester.pumpWidget(buildTestable());
    await tester.pumpAndSettle();

    final l10n = AppL10n.of(
      tester.element(find.byType(JoinOrganizationScreen)),
    );
    await tester.tap(find.text(l10n.logout));
    await tester.pumpAndSettle();

    verify(() => authRepository.signOut()).called(1);
    expect(lastLocation, '/role-selection');
  });
}
