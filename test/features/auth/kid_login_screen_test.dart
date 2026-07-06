import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';

import 'package:camp_connect/features/auth/data/auth_repository.dart';
import 'package:camp_connect/features/auth/domain/app_user.dart';
import 'package:camp_connect/features/auth/presentation/kid_login_screen.dart';
import 'package:camp_connect/l10n/app_localizations.g.dart';
import 'package:camp_connect/shared/providers/providers.dart';
import 'package:camp_connect/shared/services/fcm_service.dart';

class MockAuthRepository extends Mock implements AuthRepository {}

class MockFcmService extends Mock implements FcmService {}

void main() {
  late MockAuthRepository authRepository;
  late MockFcmService fcmService;

  setUp(() {
    authRepository = MockAuthRepository();
    fcmService = MockFcmService();

    // Stub authStateChanges: KidLoginScreen doesn't watch appUserProvider
    // itself, but ref.invalidate(appUserProvider) can cause it to be rebuilt
    // by other watchers in the tree, which reads authStateChanges.
    when(() => authRepository.authStateChanges)
        .thenAnswer((_) => const Stream.empty());
  });

  Widget buildTestable() {
    final router = GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(path: '/', builder: (context, state) => const KidLoginScreen()),
        GoRoute(
          path: '/role-selection',
          builder: (context, state) => const Scaffold(body: Text('role-selection')),
        ),
        GoRoute(
          path: '/kid-name',
          builder: (context, state) => const Scaffold(body: Text('kid-name')),
        ),
      ],
    );

    return ProviderScope(
      overrides: [
        authRepositoryProvider.overrideWithValue(authRepository),
        fcmServiceProvider.overrideWithValue(fcmService),
      ],
      child: MaterialApp.router(
        routerConfig: router,
        localizationsDelegates: AppL10n.localizationsDelegates,
        supportedLocales: AppL10n.supportedLocales,
      ),
    );
  }

  testWidgets(
    'after a successful code claim, subscribeToTopics is called with the claimed team',
    (tester) async {
      when(
        () => authRepository.signInWithCode(
          code: any(named: 'code'),
          campId: any(named: 'campId'),
        ),
      ).thenAnswer(
        (_) async => AppUser(
          uid: 'kid-1',
          role: 'kid',
          displayName: 'Campist',
          campId: 'camp-1',
          team: 'red',
          createdAt: DateTime(2026, 7, 5),
        ),
      );
      when(
        () => fcmService.subscribeToTopics(
          campId: any(named: 'campId'),
          role: any(named: 'role'),
          team: any(named: 'team'),
        ),
      ).thenAnswer((_) async {});

      await tester.pumpWidget(buildTestable());
      await tester.enterText(find.byType(TextFormField), 'CAMP-TEST');
      await tester.tap(find.byType(FilledButton));
      await tester.pumpAndSettle();

      verify(
        () => fcmService.subscribeToTopics(
          campId: 'camp-1',
          role: 'kid',
          team: 'red',
        ),
      ).called(1);
    },
  );

  testWidgets('on claim failure, subscribeToTopics is never called', (
    tester,
  ) async {
    when(
      () => authRepository.signInWithCode(
        code: any(named: 'code'),
        campId: any(named: 'campId'),
      ),
    ).thenThrow(AuthFailure(code: 'invalid-code', message: 'invalid-code'));

    await tester.pumpWidget(buildTestable());
    // Must satisfy the client-side CAMP-XXXX format validator so the
    // repository call is actually reached (the point of this test is a
    // *server-side* claim failure, not a client-side validation failure).
    await tester.enterText(find.byType(TextFormField), 'CAMP-BAD1');
    await tester.tap(find.byType(FilledButton));
    await tester.pumpAndSettle();

    verifyNever(
      () => fcmService.subscribeToTopics(
        campId: any(named: 'campId'),
        role: any(named: 'role'),
        team: any(named: 'team'),
      ),
    );
  });
}
