# Phase 3 — Critical Bug Batch Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Fix the 12 correctness bugs from the deep code sweep that will bite real users at a real camp — last-day lockout, kid-lockout-on-logout, duplicate emergency overlays, orphaned session deletes, batch-limit crashes, unclearable schedule end times, cross-user journal leakage, missing forgot-password, undisplayed foreground notifications, hangable splash, and missing input validation.

**Architecture:** Each bug is an independent, small fix in its own task with its own commit. Where a fix has automatable logic (date normalization, copyWith clearing, journal namespacing) it gets a unit test with `fake_cloud_firestore`/plain Dart; where it is pure UI wiring it gets a documented manual verification. Fixes are ordered simplest-first.

**Tech Stack:** Flutter, Riverpod, Firebase (Auth, Firestore, Messaging), Hive, `flutter_local_notifications` (new), `fake_cloud_firestore` + `flutter_test` (test-only).

**Branch:** `phase3-bug-batch` (do NOT commit to `main`; do NOT push unless the user asks).

**Ordering note vs. other phases:**
- Assumes **Phase 1 (LLM removal) is already merged** (Task references assume the LLM error string was already changed to `somethingWentWrong`).
- Three fixes overlap **Phase 2 (security)**: the kid-login block (Task 3), the camp-end-date check (Task 1), and session-delete authorization (Task 5). Each task has a **"If Phase 2 already landed"** note telling you which version to apply. If Phase 2 is NOT yet done, apply the version written here against the current client code.

---

### Task 0: Branch + test dependencies

**Files:**
- Modify: `pubspec.yaml` (dev_dependencies)

- [ ] **Step 1: Create the branch**

Run:
```bash
cd /d/CampConnect && git checkout -b phase3-bug-batch
```
Expected: `Switched to a new branch`.

- [ ] **Step 2: Add test-only dependencies**

In `pubspec.yaml` under `dev_dependencies:` add:
```yaml
  fake_cloud_firestore: ^3.1.0
  firebase_auth_mocks: ^0.14.1
```
Run:
```bash
flutter pub get
```
Expected: resolves.

- [ ] **Step 3: Commit**

```bash
git add pubspec.yaml pubspec.lock
git commit -m "chore: add fake_cloud_firestore and firebase_auth_mocks for repo tests"
```

---

### Task 1: Fix last-day lockout (store camp end date as end-of-day)

**Root cause:** `showDatePicker` returns midnight. `CampSession.hasEnded => now.isAfter(endDate)` (`camp_session.dart:27`) and the kid-login end check (`auth_repository.dart:134`) therefore treat a camp "ending July 10" as over at July 10 00:00 — the whole final day is locked out. Fix at the write choke point so both the model getter and the claim check work unchanged.

**Files:**
- Modify: `lib/features/auth/data/camp_repository.dart`
- Test: `test/features/auth/camp_repository_test.dart`

- [ ] **Step 1: Write the failing test**

Create `test/features/auth/camp_repository_test.dart`:
```dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:camp_connect/features/auth/data/camp_repository.dart';

void main() {
  test('createCampSession stores endDate at end of the chosen day', () async {
    final firestore = FakeFirebaseFirestore();
    final repo = CampRepository(firestore: firestore);

    final session = await repo.createCampSession(
      name: 'Camp',
      startDate: DateTime(2026, 7, 1),
      endDate: DateTime(2026, 7, 10), // midnight from the picker
      teams: ['red'],
      createdBy: 'g1',
    );

    final doc = await firestore.collection('camps').doc(session.id).get();
    final stored = (doc.data()!['endDate'] as Timestamp).toDate();
    // Must be the LAST moment of July 10, not the first.
    expect(stored.year, 2026);
    expect(stored.month, 7);
    expect(stored.day, 10);
    expect(stored.hour, 23);
    expect(stored.minute, 59);
  });
}
```

- [ ] **Step 2: Run — expect FAIL**

Run:
```bash
flutter test test/features/auth/camp_repository_test.dart
```
Expected: FAIL — stored hour is 0, not 23.

- [ ] **Step 3: Normalize end date in `createCampSession`**

In `camp_repository.dart`, inside `createCampSession`, before constructing the `CampSession`, add:
```dart
    // Normalize the end date to the last moment of the chosen day so the final
    // camp day is not locked out (pickers return midnight).
    final normalizedEnd = DateTime(
      endDate.year,
      endDate.month,
      endDate.day,
      23,
      59,
      59,
    );
```
Then change the `CampSession(...)` construction and the `docRef.set` to use `normalizedEnd` in place of `endDate` for the `endDate` field. Specifically, pass `endDate: normalizedEnd` to the `CampSession` constructor.

- [ ] **Step 4: Run — expect PASS**

Run:
```bash
flutter test test/features/auth/camp_repository_test.dart
```
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/features/auth/data/camp_repository.dart test/features/auth/camp_repository_test.dart
git commit -m "fix: store camp end date as end-of-day to prevent final-day lockout"
```

> **If Phase 2 already landed:** the `claimCampCode` Cloud Function also checks `endDate`. No change
> needed there — it reads the stored value, which is now end-of-day. The client `auth_repository`
> end check no longer exists (moved to the function), so only this repository fix is required.

---

### Task 2: Fix `_parseTime` crash + schedule date-range validation

**Root cause:** `_parseTime` (`announcement_management_screen.dart:826`) does `int.parse(parts[0])` — a malformed stored value (e.g. `"9"` with no colon already guarded, but `"9:xx"`) throws. And the create-session sheet accepts an end date before the start date.

**Files:**
- Modify: `lib/features/announcements/presentation/announcement_management_screen.dart`
- Modify: `lib/features/auth/presentation/camp_session_screen.dart`

- [ ] **Step 1: Harden `_parseTime`**

Replace the method (~826):
```dart
  TimeOfDay? _parseTime(String? time) {
    if (time == null || !time.contains(':')) return null;
    final parts = time.split(':');
    return TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
  }
```
With:
```dart
  TimeOfDay? _parseTime(String? time) {
    if (time == null || !time.contains(':')) return null;
    final parts = time.split(':');
    if (parts.length != 2) return null;
    final hour = int.tryParse(parts[0]);
    final minute = int.tryParse(parts[1]);
    if (hour == null || minute == null) return null;
    if (hour < 0 || hour > 23 || minute < 0 || minute > 59) return null;
    return TimeOfDay(hour: hour, minute: minute);
  }
```

- [ ] **Step 2: Add end-after-start validation in the create-session sheet**

In `camp_session_screen.dart`, in the create button's `onPressed` (after the `_startDate == null || _endDate == null` guard, before the `_selectedTeams.isEmpty` guard), add:
```dart
                if (_endDate!.isBefore(_startDate!)) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(l10n.endDateBeforeStart)),
                  );
                  return;
                }
```

- [ ] **Step 3: Add the `endDateBeforeStart` string to all three locales**

In `lib/core/l10n/app_localizations.dart`, add the getter near the other session strings:
```dart
  String get endDateBeforeStart => _t('endDateBeforeStart');
```
And add to each map:
- `_ro`: `'endDateBeforeStart': 'Data de sfârșit nu poate fi înaintea celei de început.',`
- `_hu`: `'endDateBeforeStart': 'A befejezés dátuma nem lehet korábbi a kezdésnél.',`
- `_en`: `'endDateBeforeStart': 'End date cannot be before the start date.',`

- [ ] **Step 4: Analyze**

Run:
```bash
flutter analyze lib/features/announcements/presentation/announcement_management_screen.dart lib/features/auth/presentation/camp_session_screen.dart lib/core/l10n/app_localizations.dart
```
Expected: no issues.

- [ ] **Step 5: Commit**

```bash
git add lib/features/announcements/presentation/announcement_management_screen.dart lib/features/auth/presentation/camp_session_screen.dart lib/core/l10n/app_localizations.dart
git commit -m "fix: harden schedule time parsing and validate camp end-after-start"
```

---

### Task 3: Fix kid team-topic subscription race (null team)

**Root cause:** `kid_login_screen.dart:58-66` reads `appUserProvider.future` *before* invalidating it, so the cached value is the pre-claim `null`, and the `camp_X_team_Y` subscription is skipped — kids never get points notifications.

**Files:**
- Modify: `lib/features/auth/presentation/kid_login_screen.dart`

- [ ] **Step 1: Reorder invalidate-before-read in `_submit`**

Replace this block (lines ~53–66):
```dart
      // Sign in anonymously with the camp code
      final authRepository = ref.read(authRepositoryProvider);
      await authRepository.signInWithCode(code: code, campId: campId);

      // Subscribe to FCM topics (including team-specific)
      final loggedInUser = await ref.read(appUserProvider.future);
      await ref.read(fcmServiceProvider).subscribeToTopics(
            campId: campId,
            role: 'kid',
            team: loggedInUser?.team,
          );

      // Refresh user state after auth
      ref.invalidate(appUserProvider);
```
With:
```dart
      // Sign in anonymously with the camp code
      final authRepository = ref.read(authRepositoryProvider);
      final claimedUser =
          await authRepository.signInWithCode(code: code, campId: campId);

      // Refresh user state, THEN subscribe using the freshly-claimed team so
      // the team-specific points topic is not skipped on a stale null value.
      ref.invalidate(appUserProvider);
      await ref.read(fcmServiceProvider).subscribeToTopics(
            campId: claimedUser.campId ?? campId,
            role: 'kid',
            team: claimedUser.team,
          );
```

> **If Phase 2 already landed:** `signInWithCode` now returns the claimed `AppUser` and the local
> `campId` variable comes from `claimedUser.campId` (Phase 2 removed the pre-scan). The block above
> is already written to use the returned `claimedUser`, so it is compatible with the Phase 2 version —
> just ensure `campId` is derived from `claimedUser.campId` as Phase 2 sets up.

- [ ] **Step 2: Analyze**

Run:
```bash
flutter analyze lib/features/auth/presentation/kid_login_screen.dart
```
Expected: no issues (if `signInWithCode` still returns `AppUser` — it does in both pre- and post-Phase-2 code).

- [ ] **Step 3: Manual verification**

With a device + a camp that has teams and codes: log in a kid with a code, then from the guide account add points to that kid's team. The kid should receive a points push notification. (Requires deployed functions; if functions aren't deployed, verify the subscription call receives a non-null `team` via a `debugPrint`.)

- [ ] **Step 4: Commit**

```bash
git add lib/features/auth/presentation/kid_login_screen.dart
git commit -m "fix: subscribe kid to team topic after invalidate so team is not null"
```

---

### Task 4: Stop duplicate emergency overlays stacking

**Root cause:** `EmergencyAlertListener` (`emergency_overlay.dart:20`) calls `showDialog` on every stream emission while an alert is unacknowledged; an ack by another guide re-emits and stacks a second identical dialog.

**Files:**
- Modify: `lib/features/emergency/presentation/emergency_overlay.dart`

- [ ] **Step 1: Add an "overlay currently shown" guard**

At the top of the file, add a second provider next to `_lastAcknowledgedAlertIdProvider`:
```dart
/// Tracks the alert id currently being shown as a full-screen overlay so the
/// same alert cannot stack multiple dialogs on repeated stream emissions.
final _shownOverlayAlertIdProvider = StateProvider<String?>((ref) => null);
```

- [ ] **Step 2: Guard the listener and clear on dismiss**

In `EmergencyAlertListener.build`, inside the `ref.listen` callback, after the existing early-returns and before `_showEmergencyOverlay`, add:
```dart
        // Do not stack: if we're already showing this alert, skip.
        if (ref.read(_shownOverlayAlertIdProvider) == unackedAlert.id) return;
        ref.read(_shownOverlayAlertIdProvider.notifier).state = unackedAlert.id;
```
Change `_showEmergencyOverlay` so it clears the guard when the dialog closes:
```dart
  void _showEmergencyOverlay(
      BuildContext context, WidgetRef ref, EmergencyAlert alert) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => _EmergencyOverlayDialog(alert: alert),
    ).whenComplete(() {
      ref.read(_shownOverlayAlertIdProvider.notifier).state = null;
    });
  }
```

- [ ] **Step 3: Analyze**

Run:
```bash
flutter analyze lib/features/emergency/presentation/emergency_overlay.dart
```
Expected: no issues.

- [ ] **Step 4: Manual verification**

Two guide devices (or one guide + emulator) in the same camp: send an emergency alert from a third guide. On a receiving guide, confirm exactly ONE full-screen red overlay appears and that when the *other* guide acknowledges (stream re-emits), no second overlay stacks. Acknowledge → overlay closes → guard clears.

- [ ] **Step 5: Commit**

```bash
git add lib/features/emergency/presentation/emergency_overlay.dart
git commit -m "fix: prevent duplicate emergency overlays stacking on stream re-emit"
```

---

### Task 5: Recursively delete camp subcollections on session delete + restrict to creator

**Root cause:** `_deleteSession` (`camp_session_screen.dart:139`) deletes only the camp doc, orphaning `codes`, `teams`, `pointsHistory`, `announcements`, `emergencyAlerts`, `sessionLocations` (GDPR retention breach), and leaves kids with a dangling `campId`. Also any guide can delete any camp.

**Files:**
- Modify: `lib/features/auth/data/camp_repository.dart`

- [ ] **Step 1: Add a full-delete method that clears subcollections**

In `camp_repository.dart`, replace `deleteCampSession` with:
```dart
  /// Deletes a camp and all of its subcollections (codes, teams, pointsHistory,
  /// announcements, emergencyAlerts, sessionLocations). Batched in chunks of 400
  /// to stay under Firestore's 500-op batch limit.
  Future<void> deleteCampSession(String campId) async {
    const subs = [
      AppConstants.codesSubcollection,
      AppConstants.teamsSubcollection,
      AppConstants.pointsHistorySubcollection,
      AppConstants.announcementsSubcollection,
      AppConstants.emergencyAlertsSubcollection,
      AppConstants.sessionLocationsSubcollection,
    ];

    for (final sub in subs) {
      final snap = await _campsRef.doc(campId).collection(sub).get();
      for (var i = 0; i < snap.docs.length; i += 400) {
        final batch = _firestore.batch();
        final end = (i + 400 < snap.docs.length) ? i + 400 : snap.docs.length;
        for (var j = i; j < end; j++) {
          batch.delete(snap.docs[j].reference);
        }
        await batch.commit();
      }
    }
    await _campsRef.doc(campId).delete();
  }
```

- [ ] **Step 2: Write a test proving subcollections are cleared**

Add to `test/features/auth/camp_repository_test.dart`:
```dart
  test('deleteCampSession removes the camp and its subcollections', () async {
    final firestore = FakeFirebaseFirestore();
    final repo = CampRepository(firestore: firestore);
    final camp = firestore.collection('camps').doc('c1');
    await camp.set({'name': 'C', 'createdBy': 'g1'});
    await camp.collection('codes').doc('CAMP-AAAA').set({'used': false});
    await camp.collection('teams').doc('red').set({'points': 0});
    await camp.collection('announcements').doc('a1').set({'title': 'x'});

    await repo.deleteCampSession('c1');

    expect((await camp.get()).exists, false);
    expect((await camp.collection('codes').get()).docs, isEmpty);
    expect((await camp.collection('teams').get()).docs, isEmpty);
    expect((await camp.collection('announcements').get()).docs, isEmpty);
  });
```
Run:
```bash
flutter test test/features/auth/camp_repository_test.dart
```
Expected: PASS.

- [ ] **Step 3: Restrict the delete button to the camp creator (UI guard)**

In `camp_session_screen.dart`, the `_SessionCard` shows a delete `IconButton` unconditionally. Wrap it so it only renders when the current user created the session. In `_CampSessionScreenState.build`, the `itemBuilder` already has `user` access via `ref`; pass a `canDelete` flag to `_SessionCard`:

In the `itemBuilder`, compute:
```dart
              final currentUid = ref.read(appUserProvider).valueOrNull?.uid;
              final canDelete = session.createdBy == currentUid;
```
Add `canDelete: canDelete,` to the `_SessionCard(...)` call, add `final bool canDelete;` to `_SessionCard`'s fields + constructor, and wrap the delete `IconButton` in:
```dart
                  if (canDelete)
                    IconButton(
                      icon: Icon(Icons.delete_outline,
                          size: 20, color: theme.colorScheme.error),
                      onPressed: onDelete,
                      visualDensity: VisualDensity.compact,
                    ),
```

> **If Phase 2 already landed:** the Firestore rules already deny `delete` unless
> `resource.data.createdBy == request.auth.uid`, so a non-creator's delete would fail server-side
> anyway. This UI guard is still worth adding (don't show a button that will always error), but it
> is defense-in-depth, not the primary control.

- [ ] **Step 4: Analyze + test**

Run:
```bash
flutter analyze lib/features/auth
flutter test test/features/auth/camp_repository_test.dart
```
Expected: no issues; tests PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/features/auth/data/camp_repository.dart lib/features/auth/presentation/camp_session_screen.dart test/features/auth/camp_repository_test.dart
git commit -m "fix: recursively delete camp subcollections and gate delete to creator"
```

---

### Task 6: Cap bulk code generation to avoid the 500-op batch crash

**Root cause:** `generateBulkCodes` (`camp_repository.dart:210`) writes all codes in one batch (500-op cap) and the dialog has no upper bound (`code_management_screen.dart:313`).

**Files:**
- Modify: `lib/features/auth/data/camp_repository.dart`
- Modify: `lib/features/auth/presentation/code_management_screen.dart`

- [ ] **Step 1: Chunk the batch writes**

In `generateBulkCodes`, replace the single-batch commit block:
```dart
    // Atomic batch write, listeners see all new codes in a single emission,
    // avoiding N rebuilds of the UI during bulk generation.
    final batch = _firestore.batch();
    final collection = _campsRef
        .doc(campId)
        .collection(AppConstants.codesSubcollection);
    for (final code in codes) {
      batch.set(collection.doc(code.code), code.toFirestore());
    }
    await batch.commit();
```
With:
```dart
    // Write in chunks of 400 to stay under Firestore's 500-op batch limit.
    final collection = _campsRef
        .doc(campId)
        .collection(AppConstants.codesSubcollection);
    for (var i = 0; i < codes.length; i += 400) {
      final batch = _firestore.batch();
      final end = (i + 400 < codes.length) ? i + 400 : codes.length;
      for (var j = i; j < end; j++) {
        batch.set(collection.doc(codes[j].code), codes[j].toFirestore());
      }
      await batch.commit();
    }
```

- [ ] **Step 2: Bound the count in the dialog**

In `code_management_screen.dart`, in `_GenerateCodesDialogState`'s FilledButton `onPressed`, replace:
```dart
            final count = int.tryParse(_countController.text) ?? 5;
            if (count <= 0) return;
```
With:
```dart
            final count = int.tryParse(_countController.text) ?? 5;
            if (count <= 0) return;
            final capped = count > 200 ? 200 : count;
```
And change the `Navigator.of(context).pop((team: _selectedTeam, count: count));` to use `capped`:
```dart
            Navigator.of(context).pop((team: _selectedTeam, count: capped));
```

- [ ] **Step 3: Write a test for large-batch generation**

Add to `test/features/auth/camp_repository_test.dart`:
```dart
  test('generateBulkCodes handles counts over the 500 batch limit', () async {
    final firestore = FakeFirebaseFirestore();
    final repo = CampRepository(firestore: firestore);
    await firestore.collection('camps').doc('c1').set({'name': 'C'});

    final codes = await repo.generateBulkCodes(
      campId: 'c1',
      team: 'red',
      count: 600,
      createdBy: 'g1',
    );

    expect(codes.length, 600);
    final stored =
        await firestore.collection('camps').doc('c1').collection('codes').get();
    expect(stored.docs.length, 600);
  });
```
Run:
```bash
flutter test test/features/auth/camp_repository_test.dart
```
Expected: PASS (600 > 500 no longer crashes).

- [ ] **Step 4: Commit**

```bash
git add lib/features/auth/data/camp_repository.dart lib/features/auth/presentation/code_management_screen.dart test/features/auth/camp_repository_test.dart
git commit -m "fix: chunk bulk code writes under batch limit and cap dialog count"
```

---

### Task 7: Make copyWith able to clear optional fields (schedule end time)

**Root cause:** `Announcement.copyWith` (`announcement.dart:89`) uses `x ?? this.x`, so passing `endTime: null` keeps the old value — a guide cannot remove a schedule entry's end time.

**Files:**
- Modify: `lib/features/announcements/domain/announcement.dart`
- Modify: `lib/features/announcements/presentation/announcement_management_screen.dart`
- Test: `test/features/announcements/announcement_test.dart`

- [ ] **Step 1: Write the failing test**

Create `test/features/announcements/announcement_test.dart`:
```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:camp_connect/features/announcements/domain/announcement.dart';

void main() {
  test('copyWith can clear endTime via a sentinel', () {
    final a = Announcement(
      id: '1', title: 't', body: 'b', type: 'schedule', pinned: false,
      createdBy: 'g', createdByName: 'G', timestamp: DateTime(2026),
      startTime: '09:00', endTime: '10:00',
    );
    final cleared = a.copyWith(clearEndTime: true);
    expect(cleared.endTime, isNull);
    // Unrelated fields preserved.
    expect(cleared.startTime, '09:00');
    // Without the flag, endTime is preserved.
    expect(a.copyWith(title: 'x').endTime, '10:00');
  });
}
```

- [ ] **Step 2: Run — expect FAIL (compile error: no `clearEndTime`)**

Run:
```bash
flutter test test/features/announcements/announcement_test.dart
```
Expected: FAIL to compile — `clearEndTime` not defined.

- [ ] **Step 3: Add a clear-sentinel to `copyWith`**

In `announcement.dart`, change the `copyWith` signature to add `bool clearEndTime = false, bool clearScheduledDate = false,` and update the field assignments:
```dart
  Announcement copyWith({
    String? id,
    String? title,
    String? body,
    String? type,
    bool? pinned,
    String? createdBy,
    String? createdByName,
    DateTime? timestamp,
    DateTime? scheduledDate,
    bool clearScheduledDate = false,
    String? startTime,
    String? endTime,
    bool clearEndTime = false,
  }) {
    return Announcement(
      id: id ?? this.id,
      title: title ?? this.title,
      body: body ?? this.body,
      type: type ?? this.type,
      pinned: pinned ?? this.pinned,
      createdBy: createdBy ?? this.createdBy,
      createdByName: createdByName ?? this.createdByName,
      timestamp: timestamp ?? this.timestamp,
      scheduledDate:
          clearScheduledDate ? null : (scheduledDate ?? this.scheduledDate),
      startTime: startTime ?? this.startTime,
      endTime: clearEndTime ? null : (endTime ?? this.endTime),
    );
  }
```

- [ ] **Step 4: Run — expect PASS**

Run:
```bash
flutter test test/features/announcements/announcement_test.dart
```
Expected: PASS.

- [ ] **Step 5: Use the sentinel when editing a schedule entry with no end time**

In `announcement_management_screen.dart`, in `_ScheduleFormSheetState._submit`, the editing branch builds `updated` with `endTime: _endTime != null ? _formatTime(_endTime!) : null`. Change it to pass the clear flag when `_endTime` is null:
```dart
        final updated = widget.existing!.copyWith(
          title: _titleCtrl.text.trim(),
          body: _descCtrl.text.trim(),
          type: 'schedule',
          scheduledDate: _selectedDate,
          startTime: _formatTime(_startTime!),
          endTime: _endTime != null ? _formatTime(_endTime!) : null,
          clearEndTime: _endTime == null,
        );
```
Also update `AnnouncementsRepository.updateAnnouncement` so a null end time removes the stored
field. In `announcements_repository.dart`, in the schedule branch, replace
`data['endTime'] = announcement.endTime;` with:
```dart
      data['endTime'] = announcement.endTime ?? FieldValue.delete();
```

- [ ] **Step 6: Analyze + test**

Run:
```bash
flutter analyze lib/features/announcements
flutter test test/features/announcements/announcement_test.dart
```
Expected: no issues; PASS.

- [ ] **Step 7: Commit**

```bash
git add lib/features/announcements/domain/announcement.dart lib/features/announcements/presentation/announcement_management_screen.dart lib/features/announcements/data/announcements_repository.dart test/features/announcements/announcement_test.dart
git commit -m "fix: allow clearing schedule end time via copyWith sentinel"
```

---

### Task 8: Namespace the journal Hive box + photos per user

**Root cause:** the journal box name is a constant `'journal_entries'` (`journal_local_storage.dart:10`), so two kids on the same phone share journals. The kid *name* is already namespaced (`kid_name_$uid`); the journal must be too.

**Files:**
- Modify: `lib/features/journal/data/journal_local_storage.dart`
- Modify: `lib/shared/providers/providers.dart`

- [ ] **Step 1: Make `JournalLocalStorage` take a uid**

In `journal_local_storage.dart`, change the class to accept a uid and derive per-user box + photo dir:
```dart
class JournalLocalStorage {
  final String _uid;

  JournalLocalStorage({required String uid}) : _uid = uid;

  String get _boxName => 'journal_entries_$_uid';

  Future<Box<String>> _openBox() async {
    if (Hive.isBoxOpen(_boxName)) {
      return Hive.box<String>(_boxName);
    }
    return Hive.openBox<String>(_boxName);
  }

  Future<Directory> _photosDir() async {
    final appDir = await getApplicationDocumentsDirectory();
    final dir = Directory('${appDir.path}/journal_photos/$_uid');
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }
```
Leave the rest of the methods unchanged (they use `_openBox()` / `_photosDir()`).

- [ ] **Step 2: Provide the uid from the provider**

In `providers.dart`, change `journalLocalStorageProvider` and `journalProvider` so the storage is recreated per signed-in uid:
```dart
final journalLocalStorageProvider = Provider<JournalLocalStorage?>((ref) {
  final uid = ref.watch(appUserProvider).valueOrNull?.uid;
  if (uid == null) return null;
  return JournalLocalStorage(uid: uid);
});

final journalProvider =
    StateNotifierProvider<JournalNotifier, AsyncValue<List<JournalEntry>>>((
      ref,
    ) {
      final storage = ref.watch(journalLocalStorageProvider);
      return JournalNotifier(storage);
    });
```
Update `JournalNotifier` to tolerate a null storage (logged-out state):
```dart
class JournalNotifier extends StateNotifier<AsyncValue<List<JournalEntry>>> {
  final JournalLocalStorage? _storage;

  JournalNotifier(this._storage) : super(const AsyncValue.loading()) {
    loadEntries();
  }

  Future<void> loadEntries() async {
    final storage = _storage;
    if (storage == null) {
      state = const AsyncValue.data([]);
      return;
    }
    try {
      final entries = await storage.getAllEntries();
      if (mounted) state = AsyncValue.data(entries);
    } catch (e, st) {
      if (mounted) state = AsyncValue.error(e, st);
    }
  }

  Future<void> saveEntry(JournalEntry entry) async {
    final storage = _storage;
    if (storage == null) return;
    await storage.saveEntry(entry);
    await loadEntries();
  }

  Future<void> deleteEntry(String id) async {
    final storage = _storage;
    if (storage == null) return;
    await storage.deleteEntry(id);
    await loadEntries();
  }

  Future<String> savePhoto(String sourcePath) async {
    final storage = _storage;
    if (storage == null) return sourcePath;
    return storage.savePhoto(sourcePath);
  }

  Future<void> deletePhoto(String photoPath) async {
    await _storage?.deletePhoto(photoPath);
  }

  Future<int> getEntryCount() async {
    final storage = _storage;
    if (storage == null) return 0;
    return storage.getEntryCount();
  }
}
```

- [ ] **Step 3: Check other `JournalLocalStorage()` constructions**

Run:
```bash
grep -rn "JournalLocalStorage(" lib test
```
Expected: only the provider constructs it now (with `uid:`). Fix any other call site to pass a uid.

- [ ] **Step 4: Analyze**

Run:
```bash
flutter analyze lib/features/journal lib/shared/providers/providers.dart
```
Expected: no issues.

- [ ] **Step 5: Manual verification**

On one device: log in as kid A (code 1), create a journal entry, log out. Log in as kid B (code 2) — the journal must be **empty** (not showing A's entry). Log back in as A on the same device is not possible (anonymous), but the box separation is proven by B seeing an empty journal.

> **Accepted migration behavior:** entries written before this fix live in the legacy shared
> `journal_entries` box and will no longer appear for anyone. Since journals span a single camp and
> the app hasn't shipped yet, no migration is written; the legacy box is simply orphaned. If a
> pilot user's journal must be preserved, copy the legacy box's entries into
> `journal_entries_<their-uid>` once at startup before removing this note.

- [ ] **Step 6: Commit**

```bash
git add lib/features/journal/data/journal_local_storage.dart lib/shared/providers/providers.dart
git commit -m "fix: namespace journal box and photos per user to stop cross-user leakage"
```

---

### Task 9: Add guide forgot-password flow

**Root cause:** a guide who forgets their password is locked out; no reset affordance exists.

**Files:**
- Modify: `lib/features/auth/data/auth_repository.dart`
- Modify: `lib/features/auth/presentation/guide_login_screen.dart`
- Modify: `lib/core/l10n/app_localizations.dart`

- [ ] **Step 1: Add `sendPasswordReset` to the repository**

In `auth_repository.dart`, add:
```dart
  Future<void> sendPasswordReset(String email) async {
    await _auth.sendPasswordResetEmail(email: email.trim());
  }
```

- [ ] **Step 2: Add a "Forgot password?" action to the sign-in form**

In `guide_login_screen.dart`, in the build tree of the sign-in (non-registering) mode, below the password field and above the submit button, add (only when `!_isRegistering`):
```dart
                  if (!_isRegistering)
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: _isLoading ? null : _forgotPassword,
                        child: Text(l10n.forgotPassword),
                      ),
                    ),
```
Add the handler method to `_GuideLoginScreenState`:
```dart
  Future<void> _forgotPassword() async {
    final l10n = AppLocalizations.of(context);
    final email = _emailController.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.enterEmailForReset)),
      );
      return;
    }
    try {
      await ref.read(authRepositoryProvider).sendPasswordReset(email);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.resetEmailSent)),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.somethingWentWrong)),
        );
      }
    }
  }
```

- [ ] **Step 3: Add the three strings to all locales**

In `app_localizations.dart` add getters:
```dart
  String get forgotPassword => _t('forgotPassword');
  String get enterEmailForReset => _t('enterEmailForReset');
  String get resetEmailSent => _t('resetEmailSent');
```
And to each map:
- `_ro`: `'forgotPassword': 'Ai uitat parola?', 'enterEmailForReset': 'Introdu adresa de email pentru resetare.', 'resetEmailSent': 'Ți-am trimis un email de resetare.',`
- `_hu`: `'forgotPassword': 'Elfelejtetted a jelszót?', 'enterEmailForReset': 'Add meg az email-címed a visszaállításhoz.', 'resetEmailSent': 'Elküldtük a jelszó-visszaállító emailt.',`
- `_en`: `'forgotPassword': 'Forgot password?', 'enterEmailForReset': 'Enter your email to reset.', 'resetEmailSent': 'Password reset email sent.',`

- [ ] **Step 4: Analyze**

Run:
```bash
flutter analyze lib/features/auth lib/core/l10n/app_localizations.dart
```
Expected: no issues.

- [ ] **Step 5: Commit**

```bash
git add lib/features/auth/data/auth_repository.dart lib/features/auth/presentation/guide_login_screen.dart lib/core/l10n/app_localizations.dart
git commit -m "feat: add guide forgot-password reset flow"
```

---

### Task 10: Display foreground push notifications

**Root cause:** `FcmService.onForegroundMessage` exists but nothing calls it, and there is no local-notification plugin, so a push arriving while the app is open (common for emergencies) shows nothing.

**Files:**
- Modify: `pubspec.yaml`
- Modify: `lib/shared/services/fcm_service.dart`
- Modify: `lib/app.dart`

- [ ] **Step 1: Add the plugin**

In `pubspec.yaml` under Utilities, add:
```yaml
  flutter_local_notifications: ^18.0.1
```
Run:
```bash
flutter pub get
```
Expected: resolves.

- [ ] **Step 2: Initialize local notifications in `FcmService`**

In `fcm_service.dart`, add a `FlutterLocalNotificationsPlugin` and an init method that reuses the existing Android channels (`announcements`, `emergency` — already created natively in `MainActivity.kt`):
```dart
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
```
Add to the class:
```dart
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  Future<void> initLocalNotifications() async {
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    await _localNotifications.initialize(
      const InitializationSettings(android: android),
    );
    // iOS displays foreground FCM natively when presentation options are set —
    // no local-notification plumbing needed there.
    await _messaging.setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );
  }

  /// Android-only: iOS shows foreground notifications natively via the
  /// presentation options above.
  Future<void> showLocalNotification(RemoteMessage message) async {
    final notification = message.notification;
    if (notification == null) return;
    final type = message.data['type'] as String?;
    final channelId = type == 'emergency' ? 'emergency' : 'announcements';
    await _localNotifications.show(
      notification.hashCode,
      notification.title,
      notification.body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          channelId,
          channelId == 'emergency' ? 'Emergency' : 'Announcements',
          importance: channelId == 'emergency'
              ? Importance.max
              : Importance.defaultImportance,
          priority: channelId == 'emergency' ? Priority.max : Priority.defaultPriority,
        ),
        iOS: const DarwinNotificationDetails(),
      ),
      payload: type,
    );
  }
```

- [ ] **Step 3: Wire it in `app.dart`**

In `_CampConnectAppState._setupFcm`, after `await fcm.requestPermission();`, add (with
`import 'dart:io' show Platform;` at the top of `app.dart`):
```dart
    await fcm.initLocalNotifications();
    fcm.onForegroundMessage((message) {
      // iOS presents foreground notifications natively; Android needs a local one.
      if (Platform.isAndroid) {
        fcm.showLocalNotification(message);
      }
    });
```

- [ ] **Step 4: Analyze**

Run:
```bash
flutter analyze lib/shared/services/fcm_service.dart lib/app.dart
```
Expected: no issues.

- [ ] **Step 5: Manual verification**

With the app open in the foreground on a device, send an announcement (or emergency) from another account. A heads-up notification must now appear (previously nothing showed in foreground). Tapping routes as before via `onMessageOpenedApp`.

- [ ] **Step 6: Commit**

```bash
git add pubspec.yaml pubspec.lock lib/shared/services/fcm_service.dart lib/app.dart
git commit -m "feat: display foreground push notifications via local notifications"
```

---

### Task 11: Make the splash screen robust against a missing auth-state change

**Root cause:** navigation only happens inside `ref.listen` (`splash_screen.dart:16`), which fires on *changes*; if `appUserProvider` already resolved before the listener attaches, no change fires and the user is stuck on the spinner.

**Files:**
- Modify: `lib/features/auth/presentation/splash_screen.dart`

- [ ] **Step 1: Drive navigation from the current value, not only changes — with a re-entry guard**

Convert `SplashScreen` from `ConsumerWidget` to a `ConsumerStatefulWidget` with a `_routed` flag, so
(a) an already-resolved value routes via a post-frame callback, (b) a later change routes via
`ref.listen`, and (c) the two paths can never both fire (no double navigation / double side-effects):
```dart
class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> {
  bool _routed = false;

  void _route(AppUser? user) {
    if (_routed || !mounted) return;
    _routed = true;
    if (user == null) {
      context.go('/role-selection');
    } else if (user.isGuide) {
      ref.read(campRepositoryProvider).cleanupExpiredSessions(user.uid);
      if (user.campId != null) {
        ref.read(fcmServiceProvider).subscribeToTopics(
              campId: user.campId!,
              role: user.role,
            );
      }
      context.go('/guide');
    } else {
      if (user.campId != null) {
        ref.read(fcmServiceProvider).subscribeToTopics(
              campId: user.campId!,
              role: user.role,
              team: user.team,
            );
      }
      context.go('/kid');
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final appUser = ref.watch(appUserProvider);

    ref.listen(appUserProvider, (previous, next) {
      if (next is AsyncData<AppUser?>) _route(next.value);
    });

    // Handle the value being ALREADY resolved when this screen builds
    // (no change event fires for the listener above in that case).
    if (appUser is AsyncData<AppUser?>) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _route(appUser.value));
    }

    // ... keep the existing Scaffold/spinner/error UI below unchanged ...
```
Keep the existing `Scaffold` body (icon, app name, spinner, `AsyncError` retry column) as-is; the
retry button's `ref.invalidate(appUserProvider)` still works — reset `_routed = false;` inside the
retry `onPressed` before invalidating.
> Note: `cleanupExpiredSessions` is removed entirely in Phase 5 (server-side scheduled cleanup); if
> Phase 5 already landed, drop that line from `_route`.

- [ ] **Step 2: Analyze**

Run:
```bash
flutter analyze lib/features/auth/presentation/splash_screen.dart
```
Expected: no issues.

- [ ] **Step 3: Manual verification**

Cold-start the app while already logged in as a guide, and again as a kid: it must route past the splash to `/guide` or `/kid` without hanging on the spinner. Cold-start logged out: routes to `/role-selection`. Trigger an error (airplane mode during profile load): the retry button appears.

- [ ] **Step 4: Commit**

```bash
git add lib/features/auth/presentation/splash_screen.dart
git commit -m "fix: route from resolved auth value so splash cannot hang"
```

---

### Task 12: Full-phase verification

**Files:** none (verification only)

- [ ] **Step 1: Analyze the whole project**

Run:
```bash
flutter analyze
```
Expected: at most the single pre-existing `avoid_print` info in `add_session_location_screen.dart` (which is itself a candidate cleanup — remove that `print` if desired and re-run to reach 0 issues). No errors.

- [ ] **Step 2: Run the full test suite**

Run:
```bash
flutter test
```
Expected: all tests PASS (`camp_repository_test.dart`, `announcement_test.dart`).

- [ ] **Step 3: Build the app**

Run:
```bash
flutter build apk --debug
```
Expected: builds successfully.

- [ ] **Step 4: Final empty commit recording the verification**

```bash
git commit --allow-empty -m "test: phase 3 bug batch verified — analyze clean, tests pass, app builds"
```

---

## Notes for the implementer

- **`SettingsRepository.clear()`** (dead + dangerous) was noted in the sweep. It is intentionally
  NOT touched here because account-deletion (Phase 8) will define the correct wipe semantics; leaving
  it unused is harmless. If you remove it, confirm nothing calls it first.
- **The map bugs** (Romania-locked bounds, OSM tile policy) are deliberately excluded — they belong to
  Phase 7 (iOS/store) where the tile provider is swapped.
- **The "codes generated for non-existent teams" bug** is excluded — it is fixed structurally by
  Phase 4 (teams-as-data), which replaces the hard-coded team list in the generate dialog.
- After this phase merges, update `docs/superpowers/plans/00-campconnect-production-roadmap.md`:
  mark Phase 3 done.
