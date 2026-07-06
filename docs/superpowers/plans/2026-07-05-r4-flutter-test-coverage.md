# R4 — Flutter Test Coverage Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Close the six QA findings in the Dart/Flutter layer: camp-end lockout boundary logic,
unbounded bulk code generation, the kid FCM-subscription ordering guarantee, the emergency-overlay
duplicate-dialog guard, journal (Hive) corrupted-entry/erasure handling, and points-clamping
boundaries.

**Architecture:** Where the current code is structurally untestable (`CampSession`'s
`DateTime.now()`-calling getters), refactor to accept an injectable "now" before writing the
boundary tests. Everywhere else, add tests directly against the existing repository/widget code
using the test doubles already in the project (`fake_cloud_firestore`, `firebase_auth_mocks`) plus
`mocktail` for the services those packages don't cover (FCM, local storage).

**Tech Stack:** `flutter_test`, `fake_cloud_firestore`, `firebase_auth_mocks`, `mocktail` (new),
`hive`/`hive_flutter` (already a dependency, used directly in tests via a temp directory).

**Branch:** `remediation/r4-flutter-test-coverage`.

---

### Task 1: Injectable clock for `CampSession` + boundary tests

**Files:**
- Modify: `lib/features/auth/domain/camp_session.dart` (currently lines 24-29: `isActive`,
  `hasEnded` getters)
- Test: `test/features/auth/camp_session_test.dart` (new)
- Modify: every call site of `.isActive`/`.hasEnded` (found via grep in Step 1)

- [ ] **Step 1: Find every call site before changing anything**

Run:
```bash
grep -rn "\.isActive\b" lib/ | grep -v "\.isActive("
grep -rn "\.hasEnded\b" lib/ | grep -v "\.hasEnded("
```
Record every file:line this returns — each one needs `()` added after the change in Step 4.

- [ ] **Step 2: Write the failing boundary tests**

Create `test/features/auth/camp_session_test.dart`:
```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:camp_connect/features/auth/domain/camp_session.dart';

void main() {
  // Use whatever constructor/required fields CampSession actually has —
  // check camp_session.dart for the exact shape; only startDate/endDate
  // matter for these tests, fill other required fields with any valid
  // placeholder value (e.g. empty strings / a fixed id) since they don't
  // affect isActive/hasEnded.
  CampSession sessionEnding(DateTime endDate) => CampSession(
        id: 'camp-1',
        name: 'Test Camp',
        createdBy: 'guide-1',
        startDate: DateTime(2026, 7, 1),
        endDate: endDate,
      );

  group('isActive / hasEnded boundary', () {
    test('is active one second before endDate', () {
      final session = sessionEnding(DateTime(2026, 7, 10, 23, 59, 59));
      final now = DateTime(2026, 7, 10, 23, 59, 58);
      expect(session.isActive(now: now), isTrue);
      expect(session.hasEnded(now: now), isFalse);
    });

    test('has ended exactly at endDate', () {
      final session = sessionEnding(DateTime(2026, 7, 10, 23, 59, 59));
      final now = DateTime(2026, 7, 10, 23, 59, 59);
      expect(session.isActive(now: now), isFalse);
      expect(session.hasEnded(now: now), isTrue);
    });

    test('has ended one second after endDate', () {
      final session = sessionEnding(DateTime(2026, 7, 10, 23, 59, 59));
      final now = DateTime(2026, 7, 11, 0, 0, 0);
      expect(session.isActive(now: now), isFalse);
      expect(session.hasEnded(now: now), isTrue);
    });

    test('is not active before startDate', () {
      final session = sessionEnding(DateTime(2026, 7, 10, 23, 59, 59));
      final now = DateTime(2026, 6, 30, 12, 0, 0);
      expect(session.isActive(now: now), isFalse);
    });

    test('defaults to DateTime.now() when now is not supplied', () {
      final farFuture = sessionEnding(DateTime(2099, 1, 1));
      expect(farFuture.isActive(), isTrue);
      final farPast = sessionEnding(DateTime(2000, 1, 1));
      expect(farPast.hasEnded(), isTrue);
    });
  });
}
```

- [ ] **Step 3: Run and confirm it fails (getters don't accept arguments yet)**

Run:
```bash
flutter test test/features/auth/camp_session_test.dart
```
Expected: FAIL to compile — `isActive`/`hasEnded` are getters, not callable with `(now: ...)`.

- [ ] **Step 4: Convert the getters to methods with an optional injectable `now`**

In `lib/features/auth/domain/camp_session.dart`, change:
```dart
bool get isActive => DateTime.now().isAfter(startDate) && DateTime.now().isBefore(endDate);
bool get hasEnded => DateTime.now().isAfter(endDate);
```
to:
```dart
bool isActive({DateTime? now}) {
  final n = now ?? DateTime.now();
  return n.isAfter(startDate) && n.isBefore(endDate);
}

bool hasEnded({DateTime? now}) {
  final n = now ?? DateTime.now();
  return !n.isBefore(endDate);
}
```
(Note the `hasEnded` fix also closes the exact-boundary ambiguity the review called out: the old
`isAfter(endDate)` was `false` at the exact `endDate` instant, while `isActive`'s `isBefore(endDate)`
was *also* `false` at that instant — meaning the exact boundary second was neither active nor
ended. `!n.isBefore(endDate)` makes `hasEnded` `true` at and after the exact boundary, closing that
gap.)

- [ ] **Step 5: Update every call site found in Step 1**

For each file:line, change `session.isActive` → `session.isActive()` and
`session.hasEnded` → `session.hasEnded()` (no `now:` argument at real call sites — production code
always wants the real current time; only tests pass an explicit `now`).

- [ ] **Step 6: Run the new tests and confirm they pass**

Run:
```bash
flutter test test/features/auth/camp_session_test.dart
```
Expected: PASS, 5/5.

- [ ] **Step 7: Run the full Dart suite to catch any missed call site**

Run:
```bash
flutter test && flutter analyze
```
Expected: no new failures, no new analyzer errors (a missed call site shows up as a compile error
here, not a silent bug).

- [ ] **Step 8: Commit**

```bash
cd /d/CampConnect
git add lib/features/auth/domain/camp_session.dart test/features/auth/camp_session_test.dart $(grep -rl "\.isActive(\|\.hasEnded(" lib/)
git commit -m "fix: make CampSession.isActive/hasEnded testable via an injectable clock; add boundary tests"
```

---

### Task 2: Enforce a real upper bound on bulk code generation

**Files:**
- Modify: `lib/core/constants/app_constants.dart` (add the shared constant)
- Modify: `lib/features/auth/data/camp_repository.dart` (`generateBulkCodes`, currently ~lines
  166-220)
- Modify: `lib/features/auth/presentation/code_management_screen.dart` (currently references a
  bare `200` literal at line 365 — change it to reference the same constant)
- Modify: `test/features/auth/camp_repository_test.dart` (the existing test asserting 600 codes
  succeed needs to change, since that's exactly the behavior being fixed)

- [ ] **Step 1: Add the shared constant**

In `lib/core/constants/app_constants.dart`, add:
```dart
  static const int maxBulkCodeGeneration = 200;
```
(matching whatever the class/naming convention already used in this file is — add it alongside
the other `AppConstants` static members.)

- [ ] **Step 2: Write the failing test**

In `test/features/auth/camp_repository_test.dart`, replace the existing test that asserts 600 codes
succeed with:
```dart
test('generateBulkCodes throws ArgumentError when count exceeds the max', () async {
  expect(
    () => repository.generateBulkCodes(campId: 'camp-1', team: 'red', count: AppConstants.maxBulkCodeGeneration + 1),
    throwsArgumentError,
  );
});

test('generateBulkCodes succeeds at exactly the max', () async {
  final codes = await repository.generateBulkCodes(campId: 'camp-1', team: 'red', count: AppConstants.maxBulkCodeGeneration);
  expect(codes.length, AppConstants.maxBulkCodeGeneration);
});
```
(Adjust the exact parameter names/shape to match `generateBulkCodes`'s real signature — read the
method before writing the call.)

- [ ] **Step 3: Run and confirm the exceeds-max test fails**

Run:
```bash
flutter test test/features/auth/camp_repository_test.dart
```
Expected: FAIL — today's `generateBulkCodes` has no upper-bound check, so 201 codes currently
succeed instead of throwing.

- [ ] **Step 4: Add the enforcement**

At the top of `generateBulkCodes` in `camp_repository.dart`, before any Firestore batch-write logic
runs:
```dart
if (count > AppConstants.maxBulkCodeGeneration) {
  throw ArgumentError('count must not exceed ${AppConstants.maxBulkCodeGeneration}');
}
```

- [ ] **Step 5: Run the tests again and confirm they pass**

Run:
```bash
flutter test test/features/auth/camp_repository_test.dart
```
Expected: PASS.

- [ ] **Step 6: Point the dialog at the same constant instead of a duplicated literal**

In `code_management_screen.dart`, change the `count > 200 ? 200 : count` line to reference
`AppConstants.maxBulkCodeGeneration` instead of the bare `200`, so the UI cap and the enforced
repository cap can never drift apart again.

- [ ] **Step 7: Run the full suite and analyze**

Run:
```bash
flutter test && flutter analyze
```

- [ ] **Step 8: Commit**

```bash
cd /d/CampConnect
git add lib/core/constants/app_constants.dart lib/features/auth/data/camp_repository.dart lib/features/auth/presentation/code_management_screen.dart test/features/auth/camp_repository_test.dart
git commit -m "fix: enforce a real upper bound on bulk code generation, not just a UI-level cap"
```

---

### Task 3: Kid team-topic FCM subscription — widget test

**Files:**
- Modify: `pubspec.yaml` (add `mocktail` dev dependency)
- Create: `test/features/auth/kid_login_screen_test.dart`

- [ ] **Step 1: Add mocktail**

Run:
```bash
flutter pub add --dev mocktail
```

- [ ] **Step 2: Write the widget test**

Create `test/features/auth/kid_login_screen_test.dart`:
```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mocktail/mocktail.dart';
import 'package:camp_connect/features/auth/presentation/kid_login_screen.dart';
import 'package:camp_connect/features/auth/domain/app_user.dart';
import 'package:camp_connect/shared/providers/providers.dart';

class MockAuthRepository extends Mock implements AuthRepository {}
class MockFcmService extends Mock implements FcmService {}

void main() {
  late MockAuthRepository authRepository;
  late MockFcmService fcmService;

  setUp(() {
    authRepository = MockAuthRepository();
    fcmService = MockFcmService();
    registerFallbackValue(''); // if subscribeToTopics args need a fallback for mocktail matchers
  });

  Widget buildTestable() => ProviderScope(
        overrides: [
          authRepositoryProvider.overrideWithValue(authRepository),
          fcmServiceProvider.overrideWithValue(fcmService),
        ],
        child: const MaterialApp(home: KidLoginScreen()),
      );

  testWidgets('after a successful code claim, subscribeToTopics is called with the claimed team', (tester) async {
    when(() => authRepository.signInWithCode(code: any(named: 'code'), campId: any(named: 'campId')))
        .thenAnswer((_) async => const AppUser(
              uid: 'kid-1',
              role: 'kid',
              displayName: 'Campist',
              campId: 'camp-1',
              team: 'red',
            ));
    when(() => fcmService.subscribeToTopics(campId: any(named: 'campId'), team: any(named: 'team')))
        .thenAnswer((_) async {});

    await tester.pumpWidget(buildTestable());
    await tester.enterText(find.byType(TextField).first, 'CAMP-TEST');
    await tester.tap(find.byType(ElevatedButton));
    await tester.pumpAndSettle();

    verify(() => fcmService.subscribeToTopics(campId: 'camp-1', team: 'red')).called(1);
  });

  testWidgets('on claim failure, subscribeToTopics is never called', (tester) async {
    when(() => authRepository.signInWithCode(code: any(named: 'code'), campId: any(named: 'campId')))
        .thenThrow(Exception('invalid-code'));

    await tester.pumpWidget(buildTestable());
    await tester.enterText(find.byType(TextField).first, 'CAMP-BAD');
    await tester.tap(find.byType(ElevatedButton));
    await tester.pumpAndSettle();

    verifyNever(() => fcmService.subscribeToTopics(campId: any(named: 'campId'), team: any(named: 'team')));
  });
}
```
(This test's exact widget finders (`TextField`, `ElevatedButton`) and provider names
(`authRepositoryProvider`, `fcmServiceProvider`) must be checked against the real
`kid_login_screen.dart` and `providers.dart` before running — adjust finders/provider names/method
signatures to match what's actually there; the behavior being asserted, not the exact widget tree
shape, is the point of this test.)

- [ ] **Step 3: Run and iterate until it accurately reflects the real widget/provider shape**

Run:
```bash
flutter test test/features/auth/kid_login_screen_test.dart
```
Fix compile errors by matching real provider/finder names first — a test that fails to compile
tells you nothing about the actual FCM-subscription behavior yet. Once it compiles, both tests
should PASS against the current (already-correct, per the review) implementation.

- [ ] **Step 4: Commit**

```bash
cd /d/CampConnect
git add pubspec.yaml pubspec.lock test/features/auth/kid_login_screen_test.dart
git commit -m "test: verify FCM team-topic subscription ordering after a kid code claim"
```

---

### Task 4: Emergency-overlay duplicate-dialog guard — widget tests

**Files:**
- Create: `test/features/emergency/emergency_overlay_test.dart`

- [ ] **Step 1: Write the widget tests**

Create `test/features/emergency/emergency_overlay_test.dart`:
```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:camp_connect/features/emergency/presentation/emergency_overlay.dart';
import 'package:camp_connect/features/emergency/domain/emergency_alert.dart';
import 'package:camp_connect/shared/providers/providers.dart';

void main() {
  EmergencyAlert alert(String id, {String senderId = 'other-guide'}) => EmergencyAlert(
        id: id,
        senderId: senderId,
        message: 'Test alert',
        campId: 'camp-1',
        createdAt: DateTime(2026, 7, 5),
      );

  testWidgets('the same alert id does not stack a second dialog on repeated stream emissions', (tester) async {
    final controller = StreamController<List<EmergencyAlert>>();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          emergencyAlertsProvider.overrideWith((ref) => controller.stream),
          currentUserProvider.overrideWithValue(const AppUser(uid: 'me', role: 'guide', displayName: 'Me')),
        ],
        child: const MaterialApp(home: Scaffold(body: EmergencyOverlay(child: SizedBox()))),
      ),
    );

    controller.add([alert('alert-1')]);
    await tester.pump();
    controller.add([alert('alert-1')]); // same alert re-emitted (e.g. metadata-only change)
    await tester.pump();

    expect(find.byType(Dialog), findsOneWidget);
    await controller.close();
  });

  testWidgets('an alert sent by the current user is never shown to themselves', (tester) async {
    final controller = StreamController<List<EmergencyAlert>>();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          emergencyAlertsProvider.overrideWith((ref) => controller.stream),
          currentUserProvider.overrideWithValue(const AppUser(uid: 'me', role: 'guide', displayName: 'Me')),
        ],
        child: const MaterialApp(home: Scaffold(body: EmergencyOverlay(child: SizedBox()))),
      ),
    );

    controller.add([alert('alert-2', senderId: 'me')]);
    await tester.pump();

    expect(find.byType(Dialog), findsNothing);
    await controller.close();
  });

  testWidgets('a new alert after an old one is shown replaces it rather than stacking', (tester) async {
    final controller = StreamController<List<EmergencyAlert>>();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          emergencyAlertsProvider.overrideWith((ref) => controller.stream),
          currentUserProvider.overrideWithValue(const AppUser(uid: 'me', role: 'guide', displayName: 'Me')),
        ],
        child: const MaterialApp(home: Scaffold(body: EmergencyOverlay(child: SizedBox()))),
      ),
    );

    controller.add([alert('alert-3')]);
    await tester.pump();
    expect(find.byType(Dialog), findsOneWidget);

    controller.add([alert('alert-4')]);
    await tester.pump();
    expect(find.byType(Dialog), findsOneWidget); // still exactly one, not stacked

    await controller.close();
  });
}
```
(As with Task 3: the provider names `emergencyAlertsProvider`/`currentUserProvider`, the
`EmergencyAlert`/`AppUser` constructor shapes, and the `EmergencyOverlay` widget's constructor
(`child:` parameter assumed here) must be checked against the real files and adjusted before this
compiles. `import 'dart:async';` is needed for `StreamController`.)

- [ ] **Step 2: Run and iterate until it compiles and accurately reflects the real widget/provider shape**

Run:
```bash
flutter test test/features/emergency/emergency_overlay_test.dart
```

- [ ] **Step 3: Commit**

```bash
cd /d/CampConnect
git add test/features/emergency/emergency_overlay_test.dart
git commit -m "test: verify emergency-overlay duplicate-dialog guard and self-alert suppression"
```

---

### Task 5: Journal (Hive) — corrupted-entry handling and `clearAll` erasure tests

**Files:**
- Create: `test/features/journal/journal_local_storage_test.dart`

- [ ] **Step 1: Write the tests**

Create `test/features/journal/journal_local_storage_test.dart`:
```dart
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:camp_connect/features/journal/data/journal_local_storage.dart';

void main() {
  late Directory tempDir;
  late JournalLocalStorage storage;
  const uid = 'test-uid';

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('journal_test_');
    Hive.init(tempDir.path);
    storage = JournalLocalStorage(uid: uid); // adjust to the real constructor signature
  });

  tearDown(() async {
    await Hive.deleteFromDisk();
    await tempDir.delete(recursive: true);
  });

  test('getAllEntries skips a corrupted entry but returns all valid ones', () async {
    await storage.saveEntry(/* construct a valid JournalEntry per its real fields */);
    final box = await Hive.openBox<String>('journal_entries_$uid');
    await box.put('corrupted-key', 'not valid json{{{');
    await box.close();

    final entries = await storage.getAllEntries();
    expect(entries.length, 1);
  });

  test('clearAll deletes every entry and every photo file on disk', () async {
    final photoPath = '${tempDir.path}/photo1.jpg';
    await File(photoPath).writeAsBytes([0, 1, 2]);
    await storage.saveEntry(/* a valid JournalEntry whose photoPath == photoPath */);

    await storage.clearAll();

    final box = await Hive.openBox<String>('journal_entries_$uid');
    expect(box.length, 0);
    expect(File(photoPath).existsSync(), isFalse);
  });

  test('deleteEntry removes the entry even if its photo file is already missing', () async {
    final missingPhotoPath = '${tempDir.path}/already-gone.jpg';
    await storage.saveEntry(/* a valid JournalEntry whose photoPath == missingPhotoPath, file never created */);

    await expectLater(storage.deleteEntry(/* the entry's id */), completes);
  });
}
```
(This file's constructor and `JournalEntry` shape must be filled in from the real
`journal_local_storage.dart` and its domain model before running — the point of this test is the
three behaviors named in each test's title, not the exact fixture shape.)

- [ ] **Step 2: Run and iterate until it compiles and reflects real behavior**

Run:
```bash
flutter test test/features/journal/journal_local_storage_test.dart
```
If the corrupted-entry test fails because `getAllEntries` currently throws instead of skipping,
that's a real bug the test just caught — fix `getAllEntries`'s catch block to continue past a
malformed entry rather than aborting the whole read, then re-run.

- [ ] **Step 3: Commit**

```bash
cd /d/CampConnect
git add test/features/journal/journal_local_storage_test.dart
git commit -m "test: verify journal corrupted-entry handling and clearAll erasure completeness"
```

---

### Task 6: Points clamping boundary tests

**Files:**
- Modify: `test/features/leaderboard/teams_repository_test.dart`

- [ ] **Step 1: Write the failing tests**

Append to `test/features/leaderboard/teams_repository_test.dart`:
```dart
test('addPoints clamps to 0 when removing more than the team has', () async {
  await repository.addPoints(teamId: 'red', amount: 5); // starting balance via existing helper pattern
  await repository.addPoints(teamId: 'red', amount: -100);
  final team = await repository.getTeam('red');
  expect(team.points, 0);
});

test('addPoints clamps at the 999999 ceiling', () async {
  await repository.addPoints(teamId: 'red', amount: 999990);
  await repository.addPoints(teamId: 'red', amount: 100);
  final team = await repository.getTeam('red');
  expect(team.points, 999999);
});
```
(Match the exact existing helper pattern already used in this file for seeding a team's starting
balance — the file's existing `addPoints preserves team name and colorHex` test shows the shape to
copy.)

- [ ] **Step 2: Run and confirm current behavior**

Run:
```bash
flutter test test/features/leaderboard/teams_repository_test.dart
```
Expected: both PASS, since the review confirmed the `.clamp(0, 999999)` call already exists in
`leaderboard_repository.dart:68` — this task is adding proof for already-correct behavior, not
fixing a bug. If either fails, that's new information — the clamp isn't actually wired the way the
review assumed; fix `leaderboard_repository.dart`'s `addPoints` to clamp before persisting.

- [ ] **Step 3: Commit**

```bash
cd /d/CampConnect
git add test/features/leaderboard/teams_repository_test.dart
git commit -m "test: add points-clamping boundary coverage (0 floor, 999999 ceiling)"
```

---

### Task 7: Remove the unused `integration_test` dev dependency

**Files:**
- Modify: `pubspec.yaml`

- [ ] **Step 1: Confirm it's still unused after all of R4's new tests**

Run:
```bash
grep -rln "integration_test" test/ lib/
```
Expected: no output (all of R4's new tests are ordinary `flutter_test` widget/unit tests, not
`integration_test`-driven device tests).

- [ ] **Step 2: Remove the dependency**

In `pubspec.yaml`, delete the `integration_test:` block under `dev_dependencies`.

- [ ] **Step 3: Verify**

Run:
```bash
flutter pub get && flutter test && flutter analyze
```

- [ ] **Step 4: Commit**

```bash
cd /d/CampConnect
git add pubspec.yaml pubspec.lock
git commit -m "chore: remove unused integration_test dependency"
```

---

## Post-phase verification

- [ ] `flutter test` passes end to end, including all six new test files.
- [ ] `flutter analyze` stays clean.
- [ ] Re-run `flutter test --coverage` and compare `coverage/lcov.info` against the pre-R4 baseline
  (1.5% true line coverage) — this phase doesn't aim for 80% blanket coverage (out of scope per the
  original review's own proportionality guidance), just closes the specific named risk areas; note
  the new percentage in the R4 branch's PR description for visibility, don't chase a number.
