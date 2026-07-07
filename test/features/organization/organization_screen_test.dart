import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mocktail/mocktail.dart';

import 'package:camp_connect/features/auth/domain/app_user.dart';
import 'package:camp_connect/features/organization/data/organization_repository.dart';
import 'package:camp_connect/features/organization/domain/organization.dart';
import 'package:camp_connect/features/organization/domain/org_member.dart';
import 'package:camp_connect/features/organization/presentation/organization_screen.dart';
import 'package:camp_connect/l10n/app_localizations.g.dart';
import 'package:camp_connect/shared/providers/providers.dart';

class MockOrganizationRepository extends Mock
    implements OrganizationRepository {}

void main() {
  const org = Organization(
    id: 'org-1',
    name: 'Camp Falcon',
    ownerUid: 'owner-1',
    inviteCode: 'ABCDEFGHJK',
  );

  final members = [
    const OrgMember(uid: 'owner-1', role: 'owner', displayName: 'Olivia Owner'),
    const OrgMember(uid: 'guide-1', role: 'guide', displayName: 'Gabi Guide'),
  ];

  AppUser user(String uid) => AppUser(
    uid: uid,
    role: 'guide',
    displayName: 'X',
    orgId: 'org-1',
    createdAt: DateTime(2026, 7, 1),
  );

  Widget buildTestable({required String uid}) {
    return ProviderScope(
      overrides: [
        organizationRepositoryProvider.overrideWithValue(
          MockOrganizationRepository(),
        ),
        appUserProvider.overrideWith((ref) => Future.value(user(uid))),
        currentOrganizationProvider.overrideWith((ref) => Future.value(org)),
        orgMembersProvider.overrideWith((ref) => Stream.value(members)),
      ],
      child: const MaterialApp(
        localizationsDelegates: AppL10n.localizationsDelegates,
        supportedLocales: AppL10n.supportedLocales,
        home: OrganizationScreen(),
      ),
    );
  }

  testWidgets(
    'owner sees invite code, rotate action, and remove on non-owner members',
    (tester) async {
      await tester.pumpWidget(buildTestable(uid: 'owner-1'));
      await tester.pumpAndSettle();

      expect(find.text('Camp Falcon'), findsWidgets);
      expect(find.text('ABCDEFGHJK'), findsOneWidget);
      expect(find.text('Olivia Owner'), findsOneWidget);
      expect(find.text('Gabi Guide'), findsOneWidget);
      final l10n = AppL10n.of(tester.element(find.byType(OrganizationScreen)));
      expect(find.text(l10n.rotateInviteCodeAction), findsOneWidget);
      // Exactly one remove button: for Gabi, not for the owner row.
      expect(find.byIcon(Icons.person_remove_outlined), findsOneWidget);
    },
  );

  testWidgets('non-owner sees members but no invite code or owner actions', (
    tester,
  ) async {
    await tester.pumpWidget(buildTestable(uid: 'guide-1'));
    await tester.pumpAndSettle();

    expect(find.text('Olivia Owner'), findsOneWidget);
    expect(find.text('ABCDEFGHJK'), findsNothing);
    expect(find.byIcon(Icons.person_remove_outlined), findsNothing);
  });
}
