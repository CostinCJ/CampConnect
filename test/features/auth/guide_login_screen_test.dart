import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';

import 'package:camp_connect/features/auth/data/auth_repository.dart';
import 'package:camp_connect/features/auth/presentation/guide_login_screen.dart';
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
    when(
      () => authRepository.authStateChanges,
    ).thenAnswer((_) => const Stream.empty());
  });

  Widget buildTestable(GuideLoginMode mode) {
    final router = GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) => GuideLoginScreen(initialMode: mode),
        ),
        GoRoute(
          path: '/role-selection',
          builder: (context, state) =>
              const Scaffold(body: Text('role-selection')),
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

  AppL10n l10nOf(WidgetTester tester) =>
      AppL10n.of(tester.element(find.byType(GuideLoginScreen)));

  testWidgets(
    'create-org mode starts on the register form with org name field',
    (tester) async {
      await tester.pumpWidget(buildTestable(GuideLoginMode.createOrg));
      await tester.pumpAndSettle();

      final l10n = l10nOf(tester);
      expect(find.text(l10n.setupYourOrg), findsWidgets);
      expect(find.byKey(const ValueKey('newOrgName')), findsOneWidget);
      expect(find.byKey(const ValueKey('joinOrgCode')), findsNothing);
    },
  );

  testWidgets(
    'join-org mode starts on sign-in; register shows invite code field',
    (tester) async {
      await tester.pumpWidget(buildTestable(GuideLoginMode.joinOrg));
      await tester.pumpAndSettle();

      final l10n = l10nOf(tester);
      // Starts in sign-in mode.
      expect(find.text(l10n.welcomeBack), findsOneWidget);

      // Switch to register.
      await tester.tap(find.text(l10n.noAccount));
      await tester.pumpAndSettle();

      expect(find.text(l10n.joinYourOrg), findsWidgets);
      expect(find.byKey(const ValueKey('joinOrgCode')), findsOneWidget);
      expect(find.byKey(const ValueKey('newOrgName')), findsNothing);
    },
  );

  testWidgets('switch link flips between join and create fields', (
    tester,
  ) async {
    await tester.pumpWidget(buildTestable(GuideLoginMode.createOrg));
    await tester.pumpAndSettle();

    final l10n = l10nOf(tester);
    await tester.tap(find.text(l10n.switchToJoin));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('joinOrgCode')), findsOneWidget);
    expect(find.byKey(const ValueKey('newOrgName')), findsNothing);
  });

  testWidgets('back button and password toggle have tooltips', (
    tester,
  ) async {
    await tester.pumpWidget(buildTestable(GuideLoginMode.createOrg));
    await tester.pumpAndSettle();

    final l10n = l10nOf(tester);
    expect(find.byTooltip(l10n.back), findsOneWidget);
    expect(find.byTooltip(l10n.showPassword), findsOneWidget);
  });
}
