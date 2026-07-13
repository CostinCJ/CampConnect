// test/features/announcements/announcement_form_dirty_guard_test.dart
//
// Regression coverage for a code-review finding on commit 551e3cd (Task 9 of
// the UI/UX remediation plan): the guide announcement form's dirty-guard
// (_AnnouncementFormSheetState._isDirty) originally only compared the title
// and body text fields against the saved announcement, ignoring the pinned
// and question-of-the-day (isPrompt) SwitchListTiles even though both are
// persisted on submit. That let a guide flip either switch, back out via the
// (correctly PopScope-guarded) system-back/barrier-tap path, and have the
// change silently reverted with no discard-confirmation prompt.
//
// This test drives the real AnnouncementManagementScreen (rather than the
// private _AnnouncementFormSheet directly, which isn't reachable from
// outside its library) because the sheet's own build() never touches a
// Riverpod provider -- only its host screen and the callbacks that open it
// do. So the same "override just enough providers, pump the real widget"
// approach used in journal_editor_photo_test.dart applies here: override
// appUserProvider (to avoid touching real Firebase) and announcementsProvider
// (to seed one fixed announcement) and everything else needed to reach the
// edit sheet is already exercised through the real widget tree.
//
// NOTE on scope: this covers Finding 2 (the extended _isDirty). Finding 1
// (disabling drag-to-dismiss via `enableDrag: false` on the sheet's
// showModalBottomSheet call sites) is a code-level fix only -- driving an
// actual drag-to-dismiss gesture on a modal bottom sheet in a widget test is
// known to be flaky/unreliable in this codebase's test setup (there is no
// existing precedent for it anywhere in test/), so per the task instructions
// that assertion is intentionally not attempted here.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:camp_connect/features/announcements/domain/announcement.dart';
import 'package:camp_connect/features/announcements/presentation/announcement_management_screen.dart';
import 'package:camp_connect/features/auth/domain/app_user.dart';
import 'package:camp_connect/l10n/app_localizations.g.dart';
import 'package:camp_connect/shared/providers/providers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const campId = 'camp-1';

  final existing = Announcement(
    id: 'a1',
    title: 'Campfire tonight',
    body: 'Bring marshmallows',
    type: 'announcement',
    pinned: false,
    createdBy: 'guide-1',
    createdByName: 'Guide One',
    timestamp: DateTime(2026, 7, 1),
  );

  // orgId is deliberately left null: AnnouncementManagementScreen's initState
  // seeds default announcement templates for a signed-in guide's org, which
  // would otherwise reach through to the real (uninitialized-in-tests)
  // Firestore instance. Leaving orgId null keeps that side effect a no-op.
  final guide = AppUser(
    uid: 'guide-1',
    role: 'guide',
    displayName: 'Guide One',
    campId: campId,
    createdAt: DateTime(2026, 7, 1),
  );

  Widget buildTestable() => ProviderScope(
        overrides: [
          appUserProvider.overrideWith((ref) => Future.value(guide)),
          announcementsProvider.overrideWith(
            (ref) => Stream.value([existing]),
          ),
        ],
        child: const MaterialApp(
          localizationsDelegates: AppL10n.localizationsDelegates,
          supportedLocales: AppL10n.supportedLocales,
          home: AnnouncementManagementScreen(),
        ),
      );

  testWidgets(
    'flipping only the pinned switch (title/body untouched) still triggers '
    'the discard-confirmation dialog on back-out (Finding 2 regression)',
    (tester) async {
      await tester.pumpWidget(buildTestable());
      await tester.pumpAndSettle();

      final l10n = AppL10n.of(
        tester.element(find.byType(AnnouncementManagementScreen)),
      );

      // Open the edit sheet for the existing announcement.
      await tester.tap(find.text(existing.title));
      await tester.pumpAndSettle();
      expect(find.text(l10n.editAnnouncement), findsOneWidget);

      // Dirty ONLY the "pinned" toggle -- text fields stay untouched. Before
      // the fix, _isDirty ignored this field entirely.
      await tester.tap(
        find.widgetWithText(SwitchListTile, l10n.pinnedAnnouncement),
      );
      await tester.pumpAndSettle();

      // Simulate the system back button / barrier-tap path: both route
      // through Navigator.maybePop(), which is exactly what the sheet's
      // PopScope(canPop: false, onPopInvokedWithResult: ...) intercepts.
      // Deliberately not awaited: onPopInvokedWithResult awaits
      // showDialog(), whose Future only resolves once a dialog action is
      // tapped below, so awaiting it here would deadlock the test.
      final sheetContext = tester.element(find.text(l10n.editAnnouncement));
      Navigator.of(sheetContext).maybePop();
      await tester.pumpAndSettle();

      // The discard-confirmation dialog must appear even though only a
      // switch -- not the title or body -- was changed.
      expect(find.text(l10n.discardEntryTitle), findsOneWidget);

      // Clean up: choose "keep writing" so the pop is cancelled, the pending
      // Future above resolves, and the sheet is still on screen afterward.
      await tester.tap(find.text(l10n.keepWriting));
      await tester.pumpAndSettle();
      expect(find.text(l10n.editAnnouncement), findsOneWidget);
    },
  );

  testWidgets(
    'editing only text with no changes at all pops without any dialog '
    '(sanity check that the extended _isDirty is not over-eager)',
    (tester) async {
      await tester.pumpWidget(buildTestable());
      await tester.pumpAndSettle();

      final l10n = AppL10n.of(
        tester.element(find.byType(AnnouncementManagementScreen)),
      );

      await tester.tap(find.text(existing.title));
      await tester.pumpAndSettle();
      expect(find.text(l10n.editAnnouncement), findsOneWidget);

      final sheetContext = tester.element(find.text(l10n.editAnnouncement));
      Navigator.of(sheetContext).maybePop();
      await tester.pumpAndSettle();

      // Nothing was changed, so the sheet should have closed immediately
      // with no discard-confirmation dialog.
      expect(find.text(l10n.editAnnouncement), findsNothing);
      expect(find.text(l10n.discardEntryTitle), findsNothing);
    },
  );
}
