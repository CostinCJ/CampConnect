# R7 — Design & Accessibility Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Fix the implementation slips the product-designer review found against CampConnect's own
already-good, already-documented design system (`DESIGN.md`) — hardcoded colors bypassing the
emergency-red token, undersized/unresponsive map markers, the kid-nav label spec being silently
unmet, an unconfirmed irreversible photo delete, and a set of the highest-priority missing
accessibility labels.

**Architecture:** These are all Flutter widget-level fixes against the existing design tokens
(`app_theme.dart`, `colorScheme.error`) — no new design system or visual language is being
introduced, just correcting places where the implementation drifted from the already-established
one.

**Tech Stack:** Flutter/Dart, `flutter_test` widget tests.

**Branch:** `remediation/r7-design-accessibility`.

---

### Task 1: Replace hardcoded `Colors.red` with the theme's emergency-red token

**Files:**
- Modify: `lib/features/emergency/presentation/emergency_screen.dart` (10 occurrences)
- Modify: `lib/features/emergency/presentation/emergency_overlay.dart` (3 occurrences)
- Modify: `lib/features/auth/presentation/camp_session_screen.dart` (1 occurrence, line ~119)
- Test: `test/features/emergency/emergency_theme_test.dart` (new)

- [ ] **Step 1: Confirm the exact occurrence count before editing**

Run:
```bash
grep -n "Colors\.red" lib/features/emergency/presentation/emergency_screen.dart lib/features/emergency/presentation/emergency_overlay.dart lib/features/auth/presentation/camp_session_screen.dart
```
Expected: 10 matches in the first file, 3 in the second, 1 in the third (per the design review) —
if the count differs, that's fine, just note the real count so Step 4's verification grep is
checking against the true starting state.

- [ ] **Step 2: Write a regression test that fails against the current code**

Create `test/features/emergency/emergency_theme_test.dart`:
```dart
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('emergency screens contain no hardcoded Colors.red — use colorScheme.error instead', () {
    final files = [
      'lib/features/emergency/presentation/emergency_screen.dart',
      'lib/features/emergency/presentation/emergency_overlay.dart',
      'lib/features/auth/presentation/camp_session_screen.dart',
    ];
    for (final path in files) {
      final content = File(path).readAsStringSync();
      expect(
        content.contains('Colors.red'),
        isFalse,
        reason: '$path still contains a hardcoded Colors.red reference',
      );
    }
  });
}
```
(This is a source-text regression test, not a widget test — appropriate here since the fix is
specifically "stop using this literal," and a text-level check is the most direct way to prove that
and prevent it silently creeping back in.)

- [ ] **Step 3: Run and confirm it fails**

Run:
```bash
flutter test test/features/emergency/emergency_theme_test.dart
```
Expected: FAIL, listing all three files as still containing `Colors.red`.

- [ ] **Step 4: Replace each occurrence with the appropriate theme token**

For each of the three files, replace every `Colors.red` / `Colors.red.shade900` with
`Theme.of(context).colorScheme.error` (for icons, borders, and most text/foreground uses) or
`Theme.of(context).colorScheme.errorContainer` (for any solid-fill background use, mirroring how
the rest of the app's destructive-action UI already uses `colorScheme.error`/`errorContainer` per
the design review's own observation about `points_management_screen.dart` and
`leaderboard_screen.dart` already doing this correctly). Read each occurrence's surrounding context
before choosing between `error`/`errorContainer`/`onError` so dark mode renders with correct
contrast in every case, not just a mechanical find-replace.

- [ ] **Step 5: Run the regression test again and confirm it passes**

Run:
```bash
flutter test test/features/emergency/emergency_theme_test.dart
```
Expected: PASS.

- [ ] **Step 6: Run the full suite and analyze**

Run:
```bash
flutter test && flutter analyze
```

- [ ] **Step 7: Manually verify in both light and dark mode**

Start the app (`flutter run`), navigate to the emergency screen/overlay and the delete-session
dialog in both light and dark theme, and confirm the red now matches the rest of the app's
emergency/destructive-action styling instead of standing out as a different shade.

- [ ] **Step 8: Commit**

```bash
cd /d/CampConnect
git add lib/features/emergency/presentation/emergency_screen.dart lib/features/emergency/presentation/emergency_overlay.dart lib/features/auth/presentation/camp_session_screen.dart test/features/emergency/emergency_theme_test.dart
git commit -m "fix(design): replace hardcoded Colors.red with colorScheme.error/errorContainer tokens"
```

---

### Task 2: Map marker touch target, tap feedback, and accessibility label

**Files:**
- Modify: `lib/features/map/presentation/map_screen.dart` (marker `GestureDetector`, currently
  ~lines 121-136)
- Test: `test/features/map/map_marker_test.dart` (new)

- [ ] **Step 1: Write the failing tests**

Create `test/features/map/map_marker_test.dart`:
```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:camp_connect/features/map/presentation/map_screen.dart';
import 'package:camp_connect/features/map/domain/location.dart';
import 'package:camp_connect/shared/providers/providers.dart';

void main() {
  final testLocation = Location(
    id: 'loc-1',
    name: 'Campfire',
    latitude: 45.0,
    longitude: 25.0,
    // fill any other required fields with valid placeholder values
  );

  Widget buildTestable() => ProviderScope(
        overrides: [
          locationsProvider.overrideWith((ref) => Stream.value([testLocation])),
        ],
        child: const MaterialApp(home: MapScreen()),
      );

  testWidgets('map markers meet the 48dp minimum touch target', (tester) async {
    await tester.pumpWidget(buildTestable());
    await tester.pumpAndSettle();

    final markerFinder = find.byKey(ValueKey('map-marker-${testLocation.id}'));
    expect(markerFinder, findsOneWidget);
    final size = tester.getSize(markerFinder);
    expect(size.width, greaterThanOrEqualTo(48));
    expect(size.height, greaterThanOrEqualTo(48));
  });

  testWidgets('map markers have a semantic label matching the location name', (tester) async {
    await tester.pumpWidget(buildTestable());
    await tester.pumpAndSettle();

    expect(find.bySemanticsLabel(testLocation.name), findsOneWidget);
  });
}
```
(`locationsProvider`'s real name/shape and `Location`'s real required fields must be checked against
`lib/features/map/data/location_repository.dart` and `lib/features/map/domain/location.dart` before
this compiles.)

- [ ] **Step 2: Run and confirm both fail**

Run:
```bash
flutter test test/features/map/map_marker_test.dart
```
Expected: FAIL — no widget currently has the key `map-marker-loc-1`, and no `Semantics` label
exists on the marker.

- [ ] **Step 3: Fix the marker widget**

In `map_screen.dart`, wrap each marker's existing `GestureDetector` + `Icon` in a `Semantics` label
and give it a real 48x48 tappable area with visible feedback:
```dart
Semantics(
  label: location.name,
  button: true,
  child: SizedBox(
    width: 48,
    height: 48,
    child: Material(
      color: Colors.transparent,
      shape: const CircleBorder(),
      child: InkWell(
        key: ValueKey('map-marker-${location.id}'),
        customBorder: const CircleBorder(),
        onTap: () => /* existing marker tap handler, unchanged */,
        child: Center(
          child: Icon(/* existing icon + size + color, unchanged */),
        ),
      ),
    ),
  ),
),
```
Keep the existing icon choice, size, and color, and the existing `onTap` handler body exactly as
they are — only the touch-target wrapper, the `Semantics` label, and the `InkWell` feedback are
new.

- [ ] **Step 4: Run the tests again and confirm both pass**

Run:
```bash
flutter test test/features/map/map_marker_test.dart
```
Expected: PASS, 2/2.

- [ ] **Step 5: Run the full suite and analyze**

Run:
```bash
flutter test && flutter analyze
```

- [ ] **Step 6: Commit**

```bash
cd /d/CampConnect
git add lib/features/map/presentation/map_screen.dart test/features/map/map_marker_test.dart
git commit -m "fix(design): map markers meet 48dp touch target, show tap feedback, and have a semantic label"
```

---

### Task 3: Highest-priority accessibility labels (scoped, not a full app-wide pass)

A complete accessibility pass across every icon-only control and color-only indicator in the app is
real, valuable, but open-ended work better suited to ongoing follow-up than one bite-sized phase —
this task closes the two *specific* instances the design review named (team-color-only indicators
with no text alternative) and adds one grep-based check so new icon-only buttons don't silently
regress. Remaining broader coverage is logged as a decision, not silently dropped.

**Files:**
- Modify: `lib/features/leaderboard/presentation/leaderboard_screen.dart`
  (`_PointsHistoryTile`'s team-color dot)
- Modify: `lib/features/auth/presentation/code_management_screen.dart` (team-color `CircleAvatar`)
- Create: `docs/superpowers/plans/r7-decision-log.md`

- [ ] **Step 1: Add a semantic label to the points-history team-color dot**

In `leaderboard_screen.dart`'s `_PointsHistoryTile`, find the team-color `Container`/circle and wrap
it:
```dart
Semantics(
  label: teamName, // whatever the local variable holding the team's display name is called here
  child: Container(/* existing team-color dot, unchanged */),
),
```

- [ ] **Step 2: Add the same to the code-management team-color avatar**

In `code_management_screen.dart`, wrap the team-color `CircleAvatar` the same way:
```dart
Semantics(
  label: teamName,
  child: CircleAvatar(/* existing, unchanged */),
),
```

- [ ] **Step 3: Run the full suite**

Run:
```bash
flutter test && flutter analyze
```

- [ ] **Step 4: Record the scoping decision**

Create `docs/superpowers/plans/r7-decision-log.md`:
```markdown
# R7 Decision Log

## Accessibility semantics — scope of this phase

The verify-team design review found a systemic absence of `Semantics`/accessibility labels across
`lib/features/{emergency,leaderboard,map,journal,auth,announcements}` and `lib/shared/widgets`.
This phase closes the map markers (R7 Task 2) and the two color-only team indicators named
explicitly in the review (this task). A full pass over every icon-only `IconButton` and custom-
drawn widget in the app is real, proportionate follow-up work — **not done in this phase** — and
should be scheduled as its own dedicated task before or shortly after the first store submission,
scoped screen-by-screen rather than attempted all at once.
```

- [ ] **Step 5: Commit**

```bash
cd /d/CampConnect
git add lib/features/leaderboard/presentation/leaderboard_screen.dart lib/features/auth/presentation/code_management_screen.dart docs/superpowers/plans/r7-decision-log.md
git commit -m "fix(design): add semantic labels to team-color-only indicators; log remaining a11y scope"
```

---

### Task 4: Reconcile kid nav label visibility with DESIGN.md; de-densify the guide nav

**Files:**
- Modify: `lib/core/theme/app_theme.dart` (currently `labelBehavior:
  NavigationDestinationLabelBehavior.alwaysHide` at ~line 263)
- Modify: `lib/shared/widgets/kid_navigation_shell.dart`
- Modify: `lib/shared/widgets/guide_navigation_shell.dart` (currently 7 destinations, ~lines 56-85)

- [ ] **Step 1: Give the kid shell its own label-visible nav bar theme**

In `kid_navigation_shell.dart`, wrap the `NavigationBar` in a `Theme` override so only the kid shell
shows labels always, matching `DESIGN.md`'s "labels always shown (kids)" spec, without changing the
app-wide default the guide shell still relies on:
```dart
Theme(
  data: Theme.of(context).copyWith(
    navigationBarTheme: Theme.of(context).navigationBarTheme.copyWith(
          labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        ),
  ),
  child: NavigationBar(/* existing destinations/logic, unchanged */),
),
```

- [ ] **Step 2: Move "Codes" out of the guide bottom nav**

In `guide_navigation_shell.dart`, remove the "Codes" `NavigationDestination` from the persistent
bottom nav (bringing it from 7 destinations down to 6), and add an equivalent entry point instead:
a `ListTile`/shortcut on the guide home screen (`lib/features/home/presentation/guide_home_screen.dart`)
or an action in `guide_settings_screen.dart` — pick whichever the existing home screen's layout
makes the more natural fit, since generating join codes is an infrequent, pre-camp setup task, not
a per-session action that justifies permanent bottom-nav real estate.

- [ ] **Step 3: Run the full suite and analyze**

Run:
```bash
flutter test && flutter analyze
```

- [ ] **Step 4: Manually verify on both languages**

Run the app with the device locale set to Romanian and then Hungarian, and confirm: the kid nav
shows all labels without wrapping/truncating, and the guide nav (now 6 destinations, still
icon-only) has visibly more breathing room per icon than before.

- [ ] **Step 5: Commit**

```bash
cd /d/CampConnect
git add lib/core/theme/app_theme.dart lib/shared/widgets/kid_navigation_shell.dart lib/shared/widgets/guide_navigation_shell.dart lib/features/home/presentation/guide_home_screen.dart
git commit -m "fix(design): show labels on the kid nav per DESIGN.md; move Codes out of the guide nav"
```

---

### Task 5: Fix the journal photo-remove control

**Files:**
- Modify: `lib/features/journal/presentation/journal_editor_screen.dart` (`_removePhoto`, currently
  ~lines 327-345)
- Test: `test/features/journal/journal_editor_photo_test.dart` (new)

- [ ] **Step 1: Write the failing test**

Create `test/features/journal/journal_editor_photo_test.dart`:
```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:camp_connect/features/journal/presentation/journal_editor_screen.dart';

void main() {
  testWidgets('the photo-remove control meets the 48dp minimum touch target', (tester) async {
    // Build JournalEditorScreen with at least one photo already attached,
    // using whatever provider-override/fixture pattern the existing journal
    // tests in this repo already use.
    await tester.pumpWidget(const MaterialApp(home: JournalEditorScreen()));
    await tester.pumpAndSettle();

    final removeButtonFinder = find.byKey(const ValueKey('remove-photo-button'));
    expect(removeButtonFinder, findsOneWidget);
    final size = tester.getSize(removeButtonFinder);
    expect(size.width, greaterThanOrEqualTo(48));
    expect(size.height, greaterThanOrEqualTo(48));
  });

  testWidgets('removing a photo shows an Undo snackbar instead of deleting silently', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: JournalEditorScreen()));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('remove-photo-button')));
    await tester.pump();

    expect(find.byType(SnackBar), findsOneWidget);
    expect(find.text('Undo'), findsOneWidget);
  });
}
```
(Fill in the actual setup needed to get `JournalEditorScreen` into a state with an existing photo —
match whatever fixture/provider-override pattern this repo's other journal tests already use.)

- [ ] **Step 2: Run and confirm both fail**

Run:
```bash
flutter test test/features/journal/journal_editor_photo_test.dart
```
Expected: FAIL — no `remove-photo-button` key exists yet, and removal is currently immediate with
no snackbar.

- [ ] **Step 3: Fix the control**

In `journal_editor_screen.dart`'s `_removePhoto` widget, replace the small `GestureDetector` with a
properly-sized tappable area plus an undo path:
```dart
SizedBox(
  width: 48,
  height: 48,
  child: Material(
    color: Colors.transparent,
    shape: const CircleBorder(),
    child: InkWell(
      key: const ValueKey('remove-photo-button'),
      customBorder: const CircleBorder(),
      onTap: () => _removePhotoWithUndo(photoPath),
      child: const Center(child: Icon(Icons.close, size: 20)),
    ),
  ),
),
```
Add a new method alongside the existing `_removePhoto`:
```dart
void _removePhotoWithUndo(String photoPath) {
  final removedIndex = _photoPaths.indexOf(photoPath);
  setState(() => _photoPaths.remove(photoPath));

  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(AppLocalizations.of(context).photoRemoved),
      action: SnackBarAction(
        label: AppLocalizations.of(context).undo,
        onPressed: () => setState(() => _photoPaths.insert(removedIndex, photoPath)),
      ),
    ),
  );
}
```
(Match `_photoPaths`'s real field name/type in this file — this shows the shape of the fix: defer
the actual file deletion until the snackbar's duration elapses without an Undo tap, rather than
deleting immediately. If the existing `_removePhoto` already separates "remove from the in-memory
list" from "delete the file on disk," only the in-memory removal should happen immediately; wire
the on-disk delete to fire only after the snackbar dismisses without Undo, e.g. via the SnackBar's
`onVisible`/a `Future.delayed` guarded by an `_undone` flag.)

- [ ] **Step 4: Add the two new localization keys**

Add `photoRemoved` ("Photo removed" / "Poză eliminată" / "Fénykép eltávolítva") and `undo` ("Undo" /
"Anulează" / "Visszavonás") to `app_en.arb`, `app_ro.arb`, `app_hu.arb`. Run `flutter gen-l10n`.

- [ ] **Step 5: Run the tests again and confirm they pass**

Run:
```bash
flutter test test/features/journal/journal_editor_photo_test.dart
```
Expected: PASS, 2/2.

- [ ] **Step 6: Run the full suite and analyze**

Run:
```bash
flutter test && flutter analyze
```

- [ ] **Step 7: Commit**

```bash
cd /d/CampConnect
git add lib/features/journal/presentation/journal_editor_screen.dart lib/l10n/*.arb test/features/journal/journal_editor_photo_test.dart
git commit -m "fix(design): enlarge photo-remove touch target and add an Undo path before deleting"
```

---

### Task 6: Loading/disabled guard on the teams-management dialog

**Files:**
- Modify: `lib/features/leaderboard/presentation/teams_management_screen.dart` (`_showTeamDialog`,
  currently ~lines 114-123)

- [ ] **Step 1: Bring the dialog in line with the app's established async-form pattern**

In `_showTeamDialog`, introduce a local `_isSubmitting` flag (via `StatefulBuilder` inside the
dialog, matching how `PointsManagementScreen`/`JournalEditorScreen`/`_AnnouncementFormSheet` already
do this) so the flow becomes: disable the button and show a spinner while the save is in flight,
keep the dialog open until the awaited `repo.addTeam`/`repo.updateTeam` call resolves, and show an
error `SnackBar` on failure instead of failing silently:
```dart
StatefulBuilder(
  builder: (context, setDialogState) {
    return AlertDialog(
      // existing dialog content, unchanged
      actions: [
        TextButton(
          onPressed: _isSubmitting ? null : () => Navigator.pop(ctx),
          child: Text(AppLocalizations.of(context).cancel),
        ),
        FilledButton(
          onPressed: _isSubmitting
              ? null
              : () async {
                  setDialogState(() => _isSubmitting = true);
                  try {
                    await repo.addTeam(/* existing args, unchanged */);
                    if (context.mounted) Navigator.pop(ctx, true);
                  } catch (e) {
                    setDialogState(() => _isSubmitting = false);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(AppLocalizations.of(context).somethingWentWrong)),
                      );
                    }
                  }
                },
          child: _isSubmitting
              ? const SizedBox(
                  width: 16, height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(AppLocalizations.of(context).ok),
        ),
      ],
    );
  },
),
```
(`_isSubmitting` needs to be declared as a local variable captured by the `StatefulBuilder`'s
closure, e.g. `bool isSubmitting = false;` declared just before the `showDialog` call, referenced
as `isSubmitting`/`setDialogState(() => isSubmitting = ...)` inside — adjust naming to fit this
file's existing conventions.)

- [ ] **Step 2: Run the full suite and analyze**

Run:
```bash
flutter test && flutter analyze
```

- [ ] **Step 3: Manually verify**

Run the app, open the team create/edit dialog, and confirm the button shows a spinner and is
disabled while saving, and that a simulated failure (e.g. temporarily disconnect from the emulator)
shows an error snackbar rather than failing silently.

- [ ] **Step 4: Commit**

```bash
cd /d/CampConnect
git add lib/features/leaderboard/presentation/teams_management_screen.dart
git commit -m "fix(design): add loading/disabled guard and error handling to the team dialog"
```

---

### Task 7: Document the spinner-vs-skeleton decision

**Files:**
- Modify: `docs/superpowers/plans/r7-decision-log.md`

- [ ] **Step 1: Append the decision**

```markdown
## Spinner-only loading states vs. skeleton screens

The design review noted the app uses `CircularProgressIndicator` everywhere rather than skeleton
screens. **Decision:** no change. At this app's actual scale (small camps, fast Firestore reads),
skeleton screens would be disproportionate effort for a marginal perceived-speed gain, and the
current approach is at least applied consistently everywhere. Revisit only if a specific screen's
load time becomes a real user complaint.
```

- [ ] **Step 2: Commit**

```bash
cd /d/CampConnect
git add docs/superpowers/plans/r7-decision-log.md
git commit -m "docs: record R7 decision on spinner-only loading states (no change)"
```

---

### Task 8: Encrypt the journal Hive box at rest

**Files:**
- Modify: `pubspec.yaml` (add `flutter_secure_storage`)
- Modify: `lib/features/journal/data/journal_local_storage.dart` (`_openBox`, currently ~line 20)
- Test: `test/features/journal/journal_encryption_test.dart` (new)

This closes the Security-LOW finding: the kid's personal journal (Hive box + on-disk photos) is
currently unencrypted. Narrow threat model (device-local only, never uploaded — see
`docs/privacy-policy.md`), so this was correctly scored LOW/backlog rather than urgent, but it's
included here since the goal of this remediation pass is to close everything the review found, not
just the high-severity items.

- [ ] **Step 1: Add `flutter_secure_storage`**

Run:
```bash
flutter pub add flutter_secure_storage
```
(Used to store the Hive encryption key in the Android Keystore / iOS Keychain — not to store
journal content itself, which stays in the encrypted Hive box as before.)

- [ ] **Step 2: Write the failing test**

Create `test/features/journal/journal_encryption_test.dart`:
```dart
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:camp_connect/features/journal/data/journal_local_storage.dart';

void main() {
  test('the journal Hive box is opened with an AES encryption cipher', () async {
    final tempDir = await Directory.systemTemp.createTemp('journal_enc_test_');
    Hive.init(tempDir.path);

    final storage = JournalLocalStorage(uid: 'test-uid');
    await storage.ready; // or whatever the real init/ready future is called

    // Reading the raw box file's bytes should NOT contain an obviously-plaintext
    // entry string, proving encryption is active rather than asserting on a
    // private implementation detail.
    await storage.saveEntry(/* a valid JournalEntry with a distinctive, greppable
      text field, e.g. text: "UNIQUE_PLAINTEXT_MARKER_12345" */);

    final boxFile = File('${tempDir.path}/journal_entries_test-uid.hive');
    final rawBytes = await boxFile.readAsString(encoding: const _LatinCodec());
    expect(rawBytes.contains('UNIQUE_PLAINTEXT_MARKER_12345'), isFalse);

    await Hive.deleteFromDisk();
    await tempDir.delete(recursive: true);
  });
}

class _LatinCodec extends Encoding {
  const _LatinCodec();
  @override
  String get name => 'latin1-lenient';
  @override
  Converter<List<int>, String> get decoder => const Latin1Decoder(allowInvalid: true);
  @override
  Converter<String, List<int>> get encoder => const Latin1Encoder();
}
```
(Import `dart:convert` for `Encoding`/`Latin1Decoder`/`Latin1Encoder`. Adjust `JournalLocalStorage`'s
constructor/`ready` future and `JournalEntry`'s fields to the real shapes.)

- [ ] **Step 3: Run and confirm it fails**

Run:
```bash
flutter test test/features/journal/journal_encryption_test.dart
```
Expected: FAIL — today's box is unencrypted, so the plaintext marker IS found in the raw file
bytes.

- [ ] **Step 4: Add a key-management helper**

Create `lib/features/journal/data/journal_encryption_key.dart`:
```dart
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:hive/hive.dart';

const _secureStorage = FlutterSecureStorage();

Future<List<int>> journalEncryptionKey(String uid) async {
  final storageKey = 'journal_hive_key_$uid';
  final existing = await _secureStorage.read(key: storageKey);
  if (existing != null) {
    return existing.split(',').map(int.parse).toList();
  }
  final newKey = Hive.generateSecureKey();
  await _secureStorage.write(key: storageKey, value: newKey.join(','));
  return newKey;
}
```

- [ ] **Step 5: Wire the cipher into `_openBox`**

In `journal_local_storage.dart`, import the new helper and change `_openBox` to pass an
`encryptionCipher`:
```dart
import 'journal_encryption_key.dart';

Future<Box<String>> _openBox() async {
  final key = await journalEncryptionKey(_uid);
  return Hive.openBox<String>(
    _boxName,
    encryptionCipher: HiveAesCipher(key),
  );
}
```
(Keep every other line of `_openBox` and the rest of the file unchanged — this is the same box name
and same `Box<String>` type, just encrypted at rest now.)

- [ ] **Step 6: Handle existing unencrypted installs — a one-time migration guard**

Since real devices may already have an unencrypted box on disk from before this change, wrap the
open in a fallback that migrates old plaintext data into the new encrypted box once:
```dart
Future<Box<String>> _openBox() async {
  final key = await journalEncryptionKey(_uid);
  try {
    return await Hive.openBox<String>(_boxName, encryptionCipher: HiveAesCipher(key));
  } catch (_) {
    // Existing unencrypted box on disk from before this change — read it
    // plaintext once, then re-save under encryption.
    final legacyBox = await Hive.openBox<String>(_boxName);
    final entries = Map<String, String>.from(legacyBox.toMap());
    await legacyBox.deleteFromDisk();
    final encryptedBox = await Hive.openBox<String>(_boxName, encryptionCipher: HiveAesCipher(key));
    await encryptedBox.putAll(entries);
    return encryptedBox;
  }
}
```

- [ ] **Step 7: Run the test again and confirm it passes**

Run:
```bash
flutter test test/features/journal/journal_encryption_test.dart
```
Expected: PASS.

- [ ] **Step 8: Run the full suite and analyze**

Run:
```bash
flutter test && flutter analyze
```

- [ ] **Step 9: Commit**

```bash
cd /d/CampConnect
git add pubspec.yaml pubspec.lock lib/features/journal/data/journal_local_storage.dart lib/features/journal/data/journal_encryption_key.dart test/features/journal/journal_encryption_test.dart
git commit -m "fix(security): encrypt the on-device journal Hive box at rest"
```

---

## Post-phase verification

- [ ] `grep -rn "Colors.red" lib/features/emergency lib/features/auth/presentation/camp_session_screen.dart` returns nothing.
- [ ] `flutter test && flutter analyze` both clean.
- [ ] Manually walk through: emergency screen (light+dark), map screen, kid nav (RO+HU), guide nav,
  journal photo removal, teams dialog — on a running emulator/device, not just reading the diff.
- [ ] Update the master remediation checklist (`00-verify-team-remediation-roadmap.md`).
