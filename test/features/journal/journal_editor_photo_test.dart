// test/features/journal/journal_editor_photo_test.dart
//
// NOTE on approach: JournalEditorScreen only touches journalProvider inside
// button callbacks (_pickImage/_removePhotoWithUndo/_save) -- never in
// build(). Its initial photo list comes straight from the `existingEntry`
// constructor argument (see initState, which does
// `_photos.addAll(existingEntry.photos)`). That means we can pump the real
// JournalEditorScreen (unlike MapScreen in Task 2, which needed a native
// FMTC/ObjectBox backend and forced extracting a sub-widget) as long as we
// wrap it in:
//   - a ProviderScope (it's a ConsumerStatefulWidget)
//   - a MaterialApp with AppL10n's localizationsDelegates/supportedLocales,
//     since build() calls AppL10n.of(context) directly
//
// journalProvider's real implementation resolves through
// journalLocalStorageProvider -> appUserProvider -> Firebase auth state,
// none of which is available/initialized in a plain flutter_test widget
// test. Rather than stand up a fake Firebase/Hive backend (a much bigger
// architectural lift, mirroring the FMTC blocker Task 2 hit with
// MapScreen), this test overrides journalProvider directly with a fake
// JournalNotifier subclass that records deletePhoto/savePhoto calls
// in-memory. This lets the test observe -- precisely and deterministically
// -- *when* the on-disk delete is actually requested (immediately vs. after
// the undo window elapses vs. never, if Undo is tapped), which is exactly
// the behavior this task changes, without needing a real file-backed
// storage layer.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker_platform_interface/image_picker_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'package:camp_connect/features/journal/domain/journal_entry.dart';
import 'package:camp_connect/features/journal/presentation/journal_editor_screen.dart';
import 'package:camp_connect/l10n/app_localizations.g.dart';
import 'package:camp_connect/shared/providers/providers.dart';

class _FakeJournalNotifier extends JournalNotifier {
  final List<String> deletedPhotoPaths = [];

  _FakeJournalNotifier() : super(null) {
    // Base constructor already set state via loadEntries(); force to data
    // immediately so the editor screen isn't stuck on AsyncValue.loading.
    state = const AsyncValue.data([]);
  }

  @override
  Future<String> savePhoto(String sourcePath) async => sourcePath;

  @override
  Future<void> deletePhoto(String photoPath) async {
    deletedPhotoPaths.add(photoPath);
  }
}

/// Fakes the image_picker plugin so tapping "Add Photo" -> "Choose from
/// Gallery" deterministically returns a fixed fake path, without touching
/// any real platform channel, file picker UI, or the file system.
class _FakeImagePickerPlatform extends ImagePickerPlatform
    with MockPlatformInterfaceMixin {
  final String imagePath;

  _FakeImagePickerPlatform(this.imagePath);

  @override
  Future<XFile?> getImageFromSource({
    required ImageSource source,
    ImagePickerOptions options = const ImagePickerOptions(),
  }) async {
    return XFile(imagePath);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const photoPath = '/fake/pictures/existing_photo.jpg';

  JournalEntry buildEntryWithPhoto() => JournalEntry(
        id: 'entry-1',
        date: DateTime(2026, 7, 1),
        title: 'Test entry',
        body: 'Body text',
        photos: const [photoPath],
        createdAt: DateTime(2026, 7, 1),
        updatedAt: DateTime(2026, 7, 1),
      );

  Widget buildTestable({
    JournalEntry? entry,
    required _FakeJournalNotifier notifier,
  }) =>
      ProviderScope(
        overrides: [
          journalProvider.overrideWith((ref) => notifier),
        ],
        child: MaterialApp(
          localizationsDelegates: AppL10n.localizationsDelegates,
          supportedLocales: AppL10n.supportedLocales,
          home: JournalEditorScreen(existingEntry: entry),
        ),
      );

  testWidgets('the photo-remove control meets the 48dp minimum touch target',
      (tester) async {
    await tester.pumpWidget(buildTestable(
      entry: buildEntryWithPhoto(),
      notifier: _FakeJournalNotifier(),
    ));
    await tester.pumpAndSettle();

    final removeButtonFinder =
        find.byKey(const ValueKey('remove-photo-button'));
    expect(removeButtonFinder, findsOneWidget);
    final size = tester.getSize(removeButtonFinder);
    expect(size.width, greaterThanOrEqualTo(48));
    expect(size.height, greaterThanOrEqualTo(48));
  });

  group('newly-added photo removal', () {
    // These two tests exercise a photo added *during this editing session*
    // (via the real "Add Photo" -> "Choose from Gallery" flow, with
    // image_picker faked) rather than a photo from an existing saved entry.
    // That distinction matters: _deletePhotoFile only ever calls
    // deletePhoto() for newly-added photos -- photos already part of a
    // saved entry are intentionally left on disk until _save() decides to
    // clean them up, a separate pre-existing code path untouched by this
    // task. So only newly-added photos can demonstrate "deferred delete
    // after the undo window."
    const newPhotoPath = '/fake/pictures/newly_added_photo.jpg';
    late ImagePickerPlatform originalPlatform;

    setUp(() {
      originalPlatform = ImagePickerPlatform.instance;
      ImagePickerPlatform.instance = _FakeImagePickerPlatform(newPhotoPath);
    });

    tearDown(() {
      ImagePickerPlatform.instance = originalPlatform;
    });

    Future<_FakeJournalNotifier> addPhotoViaGallery(WidgetTester tester) async {
      final notifier = _FakeJournalNotifier();
      await tester.pumpWidget(buildTestable(notifier: notifier));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Add Photo'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Choose from Gallery'));
      await tester.pumpAndSettle();

      expect(find.byType(Image), findsOneWidget);
      return notifier;
    }

    testWidgets(
        'removing a photo shows an Undo snackbar instead of deleting silently',
        (tester) async {
      final notifier = await addPhotoViaGallery(tester);

      await tester.tap(find.byKey(const ValueKey('remove-photo-button')));
      await tester.pump();

      expect(find.byType(SnackBar), findsOneWidget);
      expect(find.text('Undo'), findsOneWidget);

      // The photo should already be gone from the visible list...
      expect(find.byType(Image), findsNothing);
      // ...but the on-disk delete must not fire yet (undo window still open).
      expect(notifier.deletedPhotoPaths, isEmpty);

      // Let the finalize timer run its full course (undo window + the
      // safety margin past the SnackBar's actual dismissal -- see
      // _deleteFinalizeDelay in journal_editor_screen.dart) without tapping
      // Undo.
      await tester.pump(const Duration(seconds: 4, milliseconds: 500));
      await tester.pump(const Duration(milliseconds: 100));

      expect(notifier.deletedPhotoPaths, [newPhotoPath]);
    });

    testWidgets(
        'tapping Undo restores the photo and skips the on-disk delete',
        (tester) async {
      final notifier = await addPhotoViaGallery(tester);

      await tester.tap(find.byKey(const ValueKey('remove-photo-button')));
      await tester.pump();
      // Let the SnackBar's entrance animation finish so its action button
      // is actually hit-testable (it animates up from off-screen).
      await tester.pump(const Duration(milliseconds: 300));

      await tester.tap(find.widgetWithText(SnackBarAction, 'Undo'));
      await tester.pump();

      expect(find.byType(Image), findsOneWidget);

      // Give any lingering timer a chance to fire; delete must never happen.
      await tester.pump(const Duration(seconds: 4, milliseconds: 500));
      await tester.pump(const Duration(milliseconds: 100));
      expect(notifier.deletedPhotoPaths, isEmpty);
    });

    testWidgets(
        'the on-disk delete does not fire while the Undo button would still '
        'be visible, but does fire once the SnackBar has actually gone away '
        '(Bug 2 regression)', (tester) async {
      final notifier = await addPhotoViaGallery(tester);

      await tester.tap(find.byKey(const ValueKey('remove-photo-button')));
      await tester.pump();

      // The SnackBar is declared with `duration: _undoWindow` (4s), but its
      // own auto-dismiss timer doesn't start counting until its ~250ms
      // entrance transition finishes -- so the Undo action is realistically
      // reachable until ~250ms + 4s after showSnackBar() was called. Advance
      // to just past that 4s nominal duration (but comfortably before the
      // app-level finalize delay of 4.5s) and confirm the delete has NOT
      // fired yet, i.e. there is no window where the file is gone while
      // Undo could still plausibly be tapped.
      await tester.pump(const Duration(seconds: 4, milliseconds: 50));
      expect(notifier.deletedPhotoPaths, isEmpty,
          reason:
              'file must not be deleted before the SnackBar (and its Undo '
              'action) has actually had a chance to dismiss');

      // Now advance past the full safety-margined finalize delay
      // (undoWindow + 500ms margin) and confirm the delete does fire.
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump(const Duration(milliseconds: 50));
      expect(notifier.deletedPhotoPaths, [newPhotoPath]);
    });

    testWidgets(
        'disposing the screen while an Undo timer is still pending finalizes '
        'the delete without throwing (Bug 1 regression)', (tester) async {
      final notifier = await addPhotoViaGallery(tester);

      await tester.tap(find.byKey(const ValueKey('remove-photo-button')));
      await tester.pump();

      // The undo window (and the wider finalize delay) is still open here --
      // no delete has happened yet.
      expect(notifier.deletedPhotoPaths, isEmpty);

      // Replace the screen with an empty widget, which disposes
      // JournalEditorScreen (and, with it, State.dispose()) while
      // _pendingPhotoDeletes still has a live entry/Timer for newPhotoPath.
      // Before the Bug 1 fix, dispose() called _deletePhotoFile(), which
      // called `ref.read(journalProvider.notifier)` -- but by the time
      // dispose()'s body runs, Element.unmount() has already run and
      // invalidated `ref`, so that call threw:
      //   Bad state: Cannot use "ref" after the widget was disposed.
      // This `pumpWidget` call would surface that exception via
      // tester.takeException()/pumpWidget's synchronous rethrow. Reaching
      // the expectations below at all is the regression check.
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();

      // No exception should have been thrown/recorded during disposal.
      expect(tester.takeException(), isNull);

      // dispose() finalizes any still-pending delete immediately rather
      // than leaking the timer, so the notifier should already show the
      // photo as deleted.
      expect(notifier.deletedPhotoPaths, [newPhotoPath]);

      // The Timer that was still pending at dispose time must have been
      // cancelled (not left to fire later against a disposed notifier) --
      // pumping well past the original finalize delay should not add a
      // second/duplicate delete call.
      await tester.pump(const Duration(seconds: 5));
      expect(notifier.deletedPhotoPaths, [newPhotoPath]);
    });
  });
}
