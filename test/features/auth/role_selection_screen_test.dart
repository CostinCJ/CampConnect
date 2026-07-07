import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:camp_connect/core/theme/app_theme.dart';
import 'package:camp_connect/features/auth/presentation/role_selection_screen.dart';
import 'package:camp_connect/l10n/app_localizations.g.dart';

void main() {
  Uri? capturedGuideLoginUri;

  Widget buildTestable() {
    final router = GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) => const RoleSelectionScreen(),
        ),
        GoRoute(
          path: '/guide-login',
          builder: (context, state) {
            capturedGuideLoginUri = state.uri;
            return const Scaffold(body: Text('guide-login'));
          },
        ),
        GoRoute(
          path: '/kid-login',
          builder: (context, state) => const Scaffold(body: Text('kid-login')),
        ),
      ],
    );

    return ProviderScope(
      child: MaterialApp.router(
        routerConfig: router,
        theme: AppTheme.light(),
        localizationsDelegates: AppL10n.localizationsDelegates,
        supportedLocales: AppL10n.supportedLocales,
      ),
    );
  }

  setUp(() => capturedGuideLoginUri = null);

  Future<void> pumpScreen(WidgetTester tester) async {
    // Tall logical viewport so all three role tiles fit on screen.
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(buildTestable());
    await tester.pumpAndSettle();
  }

  testWidgets('shows three role tiles', (tester) async {
    await pumpScreen(tester);

    final l10n = AppL10n.of(tester.element(find.byType(RoleSelectionScreen)));
    expect(find.text(l10n.imAKid), findsOneWidget);
    expect(find.text(l10n.imAGuide), findsOneWidget);
    expect(find.text(l10n.setupCampTile), findsOneWidget);
  });

  testWidgets('setup-camp tile navigates to guide-login with create-org mode', (
    tester,
  ) async {
    await pumpScreen(tester);

    final l10n = AppL10n.of(tester.element(find.byType(RoleSelectionScreen)));
    await tester.tap(find.text(l10n.setupCampTile));
    await tester.pumpAndSettle();

    expect(capturedGuideLoginUri?.queryParameters['mode'], 'create-org');
  });

  testWidgets('guide tile navigates to guide-login with join-org mode', (
    tester,
  ) async {
    await pumpScreen(tester);

    final l10n = AppL10n.of(tester.element(find.byType(RoleSelectionScreen)));
    await tester.tap(find.text(l10n.imAGuide));
    await tester.pumpAndSettle();

    expect(capturedGuideLoginUri?.queryParameters['mode'], 'join-org');
  });
}
