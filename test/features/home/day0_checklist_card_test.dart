import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:camp_connect/features/auth/domain/app_user.dart';
import 'package:camp_connect/features/auth/domain/camp_code.dart';
import 'package:camp_connect/features/auth/domain/camp_session.dart';
import 'package:camp_connect/features/home/presentation/day0_checklist_card.dart';
import 'package:camp_connect/features/organization/domain/organization.dart';
import 'package:camp_connect/features/organization/domain/org_member.dart';
import 'package:camp_connect/l10n/app_localizations.g.dart';
import 'package:camp_connect/shared/providers/providers.dart';

void main() {
  const org = Organization(
    id: 'org-1',
    name: 'Camp Falcon',
    ownerUid: 'owner-1',
    inviteCode: 'ABCDEFGHJK',
  );

  AppUser user(String uid) => AppUser(
    uid: uid,
    role: 'guide',
    displayName: 'X',
    orgId: 'org-1',
    createdAt: DateTime(2026, 7, 1),
  );

  Future<Widget> buildTestable({
    required String uid,
    List<CampSession> sessions = const [],
    List<OrgMember> members = const [
      OrgMember(uid: 'owner-1', role: 'owner', displayName: 'O'),
    ],
    List<CampCode> codes = const [],
  }) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    return ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        appUserProvider.overrideWith((ref) => Future.value(user(uid))),
        currentOrganizationProvider.overrideWith((ref) => Future.value(org)),
        guideCampSessionsProvider.overrideWith((ref) => Stream.value(sessions)),
        orgMembersProvider.overrideWith((ref) => Stream.value(members)),
        codesForActiveCampProvider.overrideWith((ref) => Stream.value(codes)),
      ],
      child: const MaterialApp(
        localizationsDelegates: AppL10n.localizationsDelegates,
        supportedLocales: AppL10n.supportedLocales,
        home: Scaffold(body: Day0ChecklistCard()),
      ),
    );
  }

  testWidgets('owner with nothing set up sees all three steps unchecked', (
    tester,
  ) async {
    await tester.pumpWidget(await buildTestable(uid: 'owner-1'));
    await tester.pumpAndSettle();

    final l10n = AppL10n.of(tester.element(find.byType(Day0ChecklistCard)));
    expect(find.text(l10n.day0Title), findsOneWidget);
    expect(find.text(l10n.stepCreateSession), findsOneWidget);
    expect(find.text(l10n.stepInviteGuides), findsOneWidget);
    expect(find.text(l10n.stepGenerateCodes), findsOneWidget);
    expect(find.byIcon(Icons.check_circle), findsNothing);
  });

  testWidgets('non-owner guide sees nothing', (tester) async {
    await tester.pumpWidget(
      await buildTestable(
        uid: 'guide-2',
        members: const [
          OrgMember(uid: 'owner-1', role: 'owner', displayName: 'O'),
          OrgMember(uid: 'guide-2', role: 'guide', displayName: 'G'),
        ],
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(Card), findsNothing);
  });

  testWidgets('card disappears when all three steps are complete', (
    tester,
  ) async {
    final session = CampSession(
      id: 'camp-1',
      name: 'Summer',
      startDate: DateTime(2026, 7, 10),
      endDate: DateTime(2026, 7, 20),
      teams: const ['red'],
      createdBy: 'owner-1',
      orgId: 'org-1',
    );
    await tester.pumpWidget(
      await buildTestable(
        uid: 'owner-1',
        sessions: [session],
        members: const [
          OrgMember(uid: 'owner-1', role: 'owner', displayName: 'O'),
          OrgMember(uid: 'guide-2', role: 'guide', displayName: 'G'),
        ],
        codes: const [
          CampCode(
            code: 'CAMP-0001',
            campId: 'camp-1',
            orgId: 'org-1',
            team: 'red',
            displayName: 'Kid',
            createdBy: 'owner-1',
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(Card), findsNothing);
  });

  testWidgets('dismiss hides the card', (tester) async {
    await tester.pumpWidget(await buildTestable(uid: 'owner-1'));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.close));
    await tester.pumpAndSettle();

    expect(find.byType(Card), findsNothing);
  });
}
