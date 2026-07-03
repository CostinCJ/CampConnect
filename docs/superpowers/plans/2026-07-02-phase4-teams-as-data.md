# Phase 4 — Teams-as-Data Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace hard-coded color-key teams with guide-managed `camps/{campId}/teams/{teamId}` documents holding `{ name, colorHex, points }`, so guides can add/rename/recolor/remove teams per camp (like master locations). This also deletes the triple-duplicated team-name maps and fixes the sweep bug where codes could be generated for teams that don't exist.

**Architecture:** `Team` becomes a rich model (`id`, `name`, `colorHex`, `points`). `TeamColors` shrinks to a preset palette + hex helpers (no more name maps). Everywhere that stored a team *color-key* now stores a team *id* — `AppUser.team`, `CampCode.team`, `PointsEntry.team` are unchanged in type (still a string key), they just reference `teamId`. A new Teams management UI mirrors `master_locations_screen.dart`. The create-session sheet pre-fills the 4 classic teams as editable rows. The Cloud Function reads each team's `name`/`colorHex` from its doc instead of a hard-coded map. Guard rails prevent orphaning kids when deleting a populated team.

**Tech Stack:** Flutter, Riverpod, Firestore, `flutter_colorpicker` (new, for custom colors), Cloud Functions, `fake_cloud_firestore` (test).

**Branch:** `phase4-teams-as-data`.

**Prerequisites:** Phase 1 merged. **Phase 2 strongly recommended first** — this phase writes to the `teams` subcollection, and Phase 2's rules already allow guide writes there. If Phase 2 is not done, the writes still work under the open rules, but re-verify against Phase 2's rules when it lands.

---

### Task 1: Branch + color-picker dependency

**Files:**
- Modify: `pubspec.yaml`

- [ ] **Step 1: Branch**

Run:
```bash
cd /d/CampConnect && git checkout -b phase4-teams-as-data
```

- [ ] **Step 2: Add the color picker**

In `pubspec.yaml` under Utilities:
```yaml
  flutter_colorpicker: ^1.1.0
```
Run:
```bash
flutter pub get
```
Expected: resolves.

- [ ] **Step 3: Commit**

```bash
git add pubspec.yaml pubspec.lock
git commit -m "chore: add flutter_colorpicker for custom team colors"
```

---

### Task 2: Enrich the `Team` model

**Files:**
- Modify: `lib/features/leaderboard/domain/team.dart`
- Test: `test/features/leaderboard/team_test.dart`

- [ ] **Step 1: Write the failing test**

Create `test/features/leaderboard/team_test.dart`:
```dart
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:camp_connect/features/leaderboard/domain/team.dart';

void main() {
  test('Team round-trips id, name, colorHex, points', () async {
    final firestore = FakeFirebaseFirestore();
    final ref = firestore.collection('camps').doc('c1').collection('teams').doc('t1');
    await ref.set(const Team(
      id: 't1', name: 'Vulturii', colorHex: '#E53935', points: 5,
    ).toFirestore());

    final doc = await ref.get();
    final team = Team.fromFirestore(doc);
    expect(team.id, 't1');
    expect(team.name, 'Vulturii');
    expect(team.colorHex, '#E53935');
    expect(team.points, 5);
  });

  test('Team.color parses colorHex to an ARGB int', () {
    const team = Team(id: 't', name: 'X', colorHex: '#E53935', points: 0);
    expect(team.color.toARGB32() & 0xFFFFFF, 0xE53935);
  });
}
```

- [ ] **Step 2: Run — expect FAIL (compile)**

Run:
```bash
flutter test test/features/leaderboard/team_test.dart
```
Expected: FAIL — `name`/`colorHex`/`color` not defined.

- [ ] **Step 3: Rewrite `Team`**

Replace `team.dart`:
```dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class Team {
  final String id;
  final String name;
  final String colorHex; // e.g. "#E53935"
  final int points;

  const Team({
    required this.id,
    required this.name,
    required this.colorHex,
    required this.points,
  });

  /// Parses [colorHex] (with or without leading '#') to a [Color].
  Color get color {
    final hex = colorHex.replaceFirst('#', '');
    final value = int.tryParse('FF$hex', radix: 16) ?? 0xFF9E9E9E; // grey fallback
    return Color(value);
  }

  Color get onColor =>
      color.computeLuminance() > 0.5 ? Colors.black : Colors.white;

  factory Team.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Team(
      id: doc.id,
      name: data['name'] as String? ?? doc.id,
      colorHex: data['colorHex'] as String? ?? '#9E9E9E',
      points: (data['points'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'colorHex': colorHex,
      'points': points,
    };
  }

  Team copyWith({String? id, String? name, String? colorHex, int? points}) {
    return Team(
      id: id ?? this.id,
      name: name ?? this.name,
      colorHex: colorHex ?? this.colorHex,
      points: points ?? this.points,
    );
  }
}
```

- [ ] **Step 4: Run — expect PASS**

Run:
```bash
flutter test test/features/leaderboard/team_test.dart
```
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/features/leaderboard/domain/team.dart test/features/leaderboard/team_test.dart
git commit -m "feat: enrich Team model with id, name, and colorHex"
```

---

### Task 3: Reduce `TeamColors` to a preset palette (remove name maps)

**Files:**
- Modify: `lib/core/theme/team_colors.dart`

- [ ] **Step 1: Replace `team_colors.dart` with a palette-only helper**

```dart
import 'package:flutter/material.dart';

/// Preset colors offered when creating/editing a team. Teams now store their own
/// `colorHex`, so this is only the palette + hex helpers — no name maps.
class TeamColors {
  TeamColors._();

  /// Ordered preset palette (hex strings) shown in the team color picker.
  static const List<String> presetHexes = [
    '#E53935', // red
    '#1E88E5', // blue
    '#43A047', // green
    '#FDD835', // yellow
    '#FB8C00', // orange
    '#8E24AA', // purple
    '#D81B60', // pink
    '#00897B', // teal
  ];

  static Color colorFromHex(String hex) {
    final h = hex.replaceFirst('#', '');
    return Color(int.tryParse('FF$h', radix: 16) ?? 0xFF9E9E9E);
  }

  static String hexFromColor(Color color) {
    // toARGB32 gives 0xAARRGGBB; drop alpha.
    return '#${(color.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase()}';
  }

  static Color onColor(Color color) =>
      color.computeLuminance() > 0.5 ? Colors.black : Colors.white;
}
```

- [ ] **Step 2: Find every caller of the removed methods**

Run:
```bash
grep -rn "TeamColors\." lib
```
Expected callers to update: `getColor`, `getOnColor`, `localizedName`, `displayName`, `colors`, `defaultTeams`. These are fixed in Tasks 5–8. For now the project will NOT compile — that is expected mid-refactor. Proceed to Task 4.

- [ ] **Step 3: Commit**

```bash
git add lib/core/theme/team_colors.dart
git commit -m "refactor: reduce TeamColors to preset palette and hex helpers"
```

---

### Task 4: Teams repository (CRUD + guard) + default-team seeding

**Files:**
- Create: `lib/features/leaderboard/data/teams_repository.dart`
- Modify: `lib/features/auth/data/camp_repository.dart` (create default teams as docs)
- Modify: `lib/shared/providers/providers.dart` (provider)
- Test: `test/features/leaderboard/teams_repository_test.dart`

- [ ] **Step 1: Write the failing repository test**

Create `test/features/leaderboard/teams_repository_test.dart`:
```dart
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:camp_connect/features/leaderboard/data/teams_repository.dart';
import 'package:camp_connect/features/leaderboard/domain/team.dart';

void main() {
  test('addTeam creates a team with 0 points and returns its id', () async {
    final fs = FakeFirebaseFirestore();
    final repo = TeamsRepository(firestore: fs);
    final id = await repo.addTeam('c1', name: 'Vulturii', colorHex: '#E53935');
    final doc = await fs.collection('camps').doc('c1').collection('teams').doc(id).get();
    expect(doc.exists, true);
    expect(Team.fromFirestore(doc).points, 0);
  });

  test('deleteTeam throws if the team has kids assigned', () async {
    final fs = FakeFirebaseFirestore();
    final repo = TeamsRepository(firestore: fs);
    final id = await repo.addTeam('c1', name: 'Red', colorHex: '#E53935');
    await fs.collection('users').doc('kid1').set({'campId': 'c1', 'team': id, 'role': 'kid'});
    expect(() => repo.deleteTeam('c1', id), throwsA(isA<TeamInUseException>()));
  });

  test('deleteTeam succeeds when no kids reference it', () async {
    final fs = FakeFirebaseFirestore();
    final repo = TeamsRepository(firestore: fs);
    final id = await repo.addTeam('c1', name: 'Red', colorHex: '#E53935');
    await repo.deleteTeam('c1', id);
    final doc = await fs.collection('camps').doc('c1').collection('teams').doc(id).get();
    expect(doc.exists, false);
  });
}
```

- [ ] **Step 2: Run — expect FAIL (compile)**

Run:
```bash
flutter test test/features/leaderboard/teams_repository_test.dart
```
Expected: FAIL — `TeamsRepository` not defined.

- [ ] **Step 3: Create the repository**

Create `lib/features/leaderboard/data/teams_repository.dart`:
```dart
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/constants/app_constants.dart';
import '../domain/team.dart';

class TeamInUseException implements Exception {
  final int kidCount;
  TeamInUseException(this.kidCount);
  @override
  String toString() => 'Team has $kidCount kids assigned.';
}

class TeamsRepository {
  final FirebaseFirestore _firestore;

  TeamsRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> _teamsRef(String campId) =>
      _firestore
          .collection(AppConstants.campsCollection)
          .doc(campId)
          .collection(AppConstants.teamsSubcollection);

  Stream<List<Team>> watchTeams(String campId) {
    return _teamsRef(campId).snapshots().map((snap) {
      final teams = snap.docs.map(Team.fromFirestore).toList();
      teams.sort((a, b) => b.points.compareTo(a.points));
      return teams;
    });
  }

  Future<String> addTeam(String campId,
      {required String name, required String colorHex}) async {
    final docRef = _teamsRef(campId).doc();
    await docRef.set(Team(
      id: docRef.id,
      name: name,
      colorHex: colorHex,
      points: 0,
    ).toFirestore());
    return docRef.id;
  }

  Future<void> updateTeam(String campId, Team team) async {
    await _teamsRef(campId).doc(team.id).update({
      'name': team.name,
      'colorHex': team.colorHex,
    });
  }

  /// Deletes a team only if no kid references it. Throws [TeamInUseException]
  /// otherwise so the UI can offer reassignment.
  Future<void> deleteTeam(String campId, String teamId) async {
    final kids = await _firestore
        .collection(AppConstants.usersCollection)
        .where('campId', isEqualTo: campId)
        .where('team', isEqualTo: teamId)
        .limit(1)
        .get();
    if (kids.docs.isNotEmpty) {
      // Count for the message (bounded read).
      final all = await _firestore
          .collection(AppConstants.usersCollection)
          .where('campId', isEqualTo: campId)
          .where('team', isEqualTo: teamId)
          .get();
      throw TeamInUseException(all.docs.length);
    }
    await _teamsRef(campId).doc(teamId).delete();
  }
}
```

- [ ] **Step 4: Add the provider**

In `providers.dart`, add near the leaderboard providers:
```dart
final teamsRepositoryProvider = Provider<TeamsRepository>((ref) {
  return TeamsRepository(firestore: ref.watch(firestoreProvider));
});
```
Add the import at the top:
```dart
import '../../features/leaderboard/data/teams_repository.dart';
```
Change `leaderboardProvider` to source teams from the new repo (it already returns `List<Team>`):
```dart
final leaderboardProvider = StreamProvider<List<Team>>((ref) {
  final campId = ref.watch(activeCampIdProvider);
  if (campId == null) return Stream.value([]);
  return ref.watch(teamsRepositoryProvider).watchTeams(campId);
});
```
(Leave `leaderboardRepositoryProvider` for `addPoints`/points history.)

- [ ] **Step 5: Seed default teams as docs in `createCampSession`**

In `camp_repository.dart`, the current `createCampSession` writes `teams` subcollection docs keyed by color string with `{points: 0}`. Change its signature so callers pass full team specs, and write name+colorHex+points. Replace the `teams` parameter handling:

Change the method signature parameter from `required List<String> teams,` to:
```dart
    required List<({String name, String colorHex})> teams,
```
And replace the team-doc batch loop:
```dart
    // Create team subcollection documents with points: 0
    final batch = _firestore.batch();
    for (final team in teams) {
      batch.set(docRef.collection(AppConstants.teamsSubcollection).doc(team), {
        'points': 0,
      });
    }
    await batch.commit();
```
With:
```dart
    // Create team documents with a generated id, name, colorHex, points: 0.
    final batch = _firestore.batch();
    for (final team in teams) {
      final teamRef = docRef.collection(AppConstants.teamsSubcollection).doc();
      batch.set(teamRef, {
        'name': team.name,
        'colorHex': team.colorHex,
        'points': 0,
      });
    }
    await batch.commit();
```
Also update the `CampSession` model: the `teams` field currently stores `List<String>` of color keys. Change `CampSession.teams` to store the *count* only is insufficient (used for display). Simplest: keep `teams` as `List<String>` but store team **names** for display in overview cards. Update `createCampSession` to pass `teams: teams.map((t) => t.name).toList()` into the `CampSession`. (Team docs are the source of truth; the array is a denormalized display convenience.)

- [ ] **Step 6: Run — expect PASS**

Run:
```bash
flutter test test/features/leaderboard/teams_repository_test.dart
```
Expected: PASS.

- [ ] **Step 7: Commit**

```bash
git add lib/features/leaderboard/data/teams_repository.dart lib/features/auth/data/camp_repository.dart lib/shared/providers/providers.dart test/features/leaderboard/teams_repository_test.dart
git commit -m "feat: teams repository with in-use guard; seed default teams as docs"
```

---

### Task 5: Create-session sheet — editable team rows

**Files:**
- Modify: `lib/features/auth/presentation/camp_session_screen.dart`
- Modify: `lib/core/constants/app_constants.dart`

- [ ] **Step 1: Replace `defaultTeams` string list with default team specs**

In `app_constants.dart`, replace:
```dart
  // Default teams
  static const List<String> defaultTeams = ['red', 'blue', 'green', 'yellow'];
```
With:
```dart
  // Default teams pre-filled when creating a camp (name + colorHex). Guides can
  // rename, recolor, add, or remove them before creating the session.
  static const List<({String name, String colorHex})> defaultTeams = [
    (name: 'Roșu', colorHex: '#E53935'),
    (name: 'Albastru', colorHex: '#1E88E5'),
    (name: 'Verde', colorHex: '#43A047'),
    (name: 'Galben', colorHex: '#FDD835'),
  ];
```

- [ ] **Step 2: Rework the create-session sheet team selector**

In `camp_session_screen.dart`, `_CreateSessionSheetState` currently holds `Set<String> _selectedTeams` of color keys and renders `FilterChip`s. Replace with an editable list of `({String name, String colorHex})` rows:

Rows need **stable identity + controllers** — a plain record list with `TextFormField(initialValue:)`
would show stale text after a row is removed (widget reuse by index). Use a small row class holding
its own controller:
```dart
class _TeamRow {
  final TextEditingController nameCtrl;
  String colorHex;
  _TeamRow(String name, this.colorHex)
      : nameCtrl = TextEditingController(text: name);
}
```
Change the state fields and lifecycle:
```dart
  late final List<_TeamRow> _teams;

  @override
  void initState() {
    super.initState();
    _teams = AppConstants.defaultTeams
        .map((t) => _TeamRow(t.name, t.colorHex))
        .toList();
  }

  @override
  void dispose() {
    _nameController.dispose();
    for (final t in _teams) {
      t.nameCtrl.dispose();
    }
    super.dispose();
  }
```
Replace the `Wrap(... FilterChip ...)` teams UI with keyed rows (color swatch → picker, name field,
remove button) plus an "Add team" button:
```dart
            Text(l10n.teams, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            ..._teams.map((row) {
              return Padding(
                key: ObjectKey(row),
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    GestureDetector(
                      onTap: () async {
                        final picked = await _pickColor(TeamColors.colorFromHex(row.colorHex));
                        if (picked != null) {
                          setState(() =>
                              row.colorHex = TeamColors.hexFromColor(picked));
                        }
                      },
                      child: CircleAvatar(
                          radius: 14,
                          backgroundColor: TeamColors.colorFromHex(row.colorHex)),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: row.nameCtrl,
                        decoration: InputDecoration(
                          isDense: true,
                          border: const OutlineInputBorder(),
                          hintText: l10n.teamName,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.remove_circle_outline,
                          color: Theme.of(context).colorScheme.error),
                      onPressed: _teams.length <= 1
                          ? null
                          : () => setState(() {
                                row.nameCtrl.dispose();
                                _teams.remove(row);
                              }),
                    ),
                  ],
                ),
              );
            }),
            TextButton.icon(
              onPressed: () => setState(() =>
                  _teams.add(_TeamRow('', TeamColors.presetHexes.first))),
              icon: const Icon(Icons.add),
              label: Text(l10n.addTeam),
            ),
```
Add a color-picker helper method to the state class:
```dart
  Future<Color?> _pickColor(Color initial) async {
    Color selected = initial;
    return showDialog<Color>(
      context: context,
      builder: (ctx) => AlertDialog(
        content: SingleChildScrollView(
          child: BlockPicker(
            pickerColor: initial,
            availableColors:
                TeamColors.presetHexes.map(TeamColors.colorFromHex).toList(),
            onColorChanged: (c) => selected = c,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, selected),
            child: Text(AppLocalizations.of(ctx).ok),
          ),
        ],
      ),
    );
  }
```
Add imports:
```dart
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:camp_connect/core/theme/team_colors.dart';
```

- [ ] **Step 3: Validate + pass team specs on create**

In the create button `onPressed`, replace the `_selectedTeams.isEmpty` guard and the `createCampSession(... teams: _selectedTeams.toList() ...)` call:
```dart
                final cleaned = _teams
                    .where((t) => t.nameCtrl.text.trim().isNotEmpty)
                    .map((t) =>
                        (name: t.nameCtrl.text.trim(), colorHex: t.colorHex))
                    .toList();
                if (cleaned.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(l10n.selectAtLeastOneTeam)),
                  );
                  return;
                }
```
And pass `teams: cleaned,` to `createCampSession`.

- [ ] **Step 4: Add `teamName`, `addTeam` strings to all locales**

In `app_localizations.dart`, add getters `teamName`, `addTeam` and:
- `_ro`: `'teamName': 'Numele echipei', 'addTeam': 'Adaugă echipă',`
- `_hu`: `'teamName': 'Csapat neve', 'addTeam': 'Csapat hozzáadása',`
- `_en`: `'teamName': 'Team name', 'addTeam': 'Add team',`

- [ ] **Step 5: Analyze**

Run:
```bash
flutter analyze lib/features/auth/presentation/camp_session_screen.dart lib/core/constants/app_constants.dart lib/core/l10n/app_localizations.dart
```
Expected: no issues.

- [ ] **Step 6: Commit**

```bash
git add lib/features/auth/presentation/camp_session_screen.dart lib/core/constants/app_constants.dart lib/core/l10n/app_localizations.dart
git commit -m "feat: editable custom team rows in create-session sheet"
```

---

### Task 6: Teams management screen (add/edit/delete existing camp)

**Files:**
- Create: `lib/features/leaderboard/presentation/teams_management_screen.dart`
- Modify: `lib/core/router/app_router.dart` (route)
- Modify: `lib/features/settings/presentation/guide_settings_screen.dart` (link)
- Modify: `lib/shared/providers/providers.dart` (camp teams stream already = leaderboardProvider)

- [ ] **Step 1: Build the management screen**

Create `lib/features/leaderboard/presentation/teams_management_screen.dart` modeled on `master_locations_screen.dart`: a list of the active camp's teams (from `leaderboardProvider`), each row a color swatch + name + points + edit + delete; an "Add team" FAB opening a name+color dialog. On delete, call `teamsRepository.deleteTeam`; catch `TeamInUseException` and show a dialog offering to **reassign** kids to another team before deleting (update each kid's `team` field), or cancel.

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';

import 'package:camp_connect/core/l10n/app_localizations.dart';
import 'package:camp_connect/core/theme/team_colors.dart';
import 'package:camp_connect/features/leaderboard/data/teams_repository.dart';
import 'package:camp_connect/features/leaderboard/domain/team.dart';
import 'package:camp_connect/shared/providers/providers.dart';

class TeamsManagementScreen extends ConsumerWidget {
  const TeamsManagementScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final campId = ref.watch(activeCampIdProvider);
    final teamsAsync = ref.watch(leaderboardProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.teams)),
      floatingActionButton: campId == null
          ? null
          : FloatingActionButton.extended(
              onPressed: () => _showTeamDialog(context, ref, campId, null),
              icon: const Icon(Icons.add),
              label: Text(l10n.addTeam),
            ),
      body: campId == null
          ? Center(child: Text(l10n.noActiveSession))
          : teamsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (_, _) => Center(child: Text(l10n.somethingWentWrong)),
              data: (teams) => ListView(
                padding: const EdgeInsets.all(16),
                children: teams
                    .map((t) => Card(
                          child: ListTile(
                            leading: CircleAvatar(backgroundColor: t.color),
                            title: Text(t.name),
                            subtitle: Text('${t.points} ${l10n.pts}'),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.edit_outlined),
                                  onPressed: () =>
                                      _showTeamDialog(context, ref, campId, t),
                                ),
                                IconButton(
                                  icon: Icon(Icons.delete_outline,
                                      color: theme.colorScheme.error),
                                  onPressed: () =>
                                      _confirmDelete(context, ref, campId, t, teams),
                                ),
                              ],
                            ),
                          ),
                        ))
                    .toList(),
              ),
            ),
    );
  }

  Future<void> _showTeamDialog(
      BuildContext context, WidgetRef ref, String campId, Team? existing) async {
    final l10n = AppLocalizations.of(context);
    final nameCtrl = TextEditingController(text: existing?.name ?? '');
    String colorHex = existing?.colorHex ?? TeamColors.presetHexes.first;

    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: Text(existing == null ? l10n.addTeam : l10n.editTeam),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                decoration: InputDecoration(labelText: l10n.teamName),
              ),
              const SizedBox(height: 16),
              BlockPicker(
                pickerColor: TeamColors.colorFromHex(colorHex),
                availableColors:
                    TeamColors.presetHexes.map(TeamColors.colorFromHex).toList(),
                onColorChanged: (c) =>
                    setState(() => colorHex = TeamColors.hexFromColor(c)),
              ),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: Text(l10n.cancel)),
            FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: Text(l10n.ok)),
          ],
        ),
      ),
    );

    if (saved != true || nameCtrl.text.trim().isEmpty) return;
    final repo = ref.read(teamsRepositoryProvider);
    if (existing == null) {
      await repo.addTeam(campId, name: nameCtrl.text.trim(), colorHex: colorHex);
    } else {
      await repo.updateTeam(
          campId, existing.copyWith(name: nameCtrl.text.trim(), colorHex: colorHex));
    }
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref, String campId,
      Team team, List<Team> allTeams) async {
    final l10n = AppLocalizations.of(context);
    // Confirm before ANY delete, even when no kids are affected.
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.deleteTeamTitle),
        content: Text(l10n.deleteTeamConfirm(team.name)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(l10n.cancel)),
          FilledButton(
              style: FilledButton.styleFrom(
                  backgroundColor: Theme.of(ctx).colorScheme.error),
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(l10n.delete)),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    try {
      await ref.read(teamsRepositoryProvider).deleteTeam(campId, team.id);
    } on TeamInUseException catch (e) {
      if (!context.mounted) return;
      // Offer reassignment to another team.
      final others = allTeams.where((t) => t.id != team.id).toList();
      if (others.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.cannotDeleteLastTeam)),
        );
        return;
      }
      final target = await showDialog<Team>(
        context: context,
        builder: (ctx) => SimpleDialog(
          title: Text(l10n.reassignKidsPrompt(e.kidCount)),
          children: others
              .map((t) => SimpleDialogOption(
                    onPressed: () => Navigator.pop(ctx, t),
                    child: Text(t.name),
                  ))
              .toList(),
        ),
      );
      if (target == null) return;
      await ref
          .read(teamsRepositoryProvider)
          .reassignAndDelete(campId, team.id, target.id);
    }
  }
}
```

- [ ] **Step 2: Add `reassignAndDelete` to the repository**

In `teams_repository.dart`, add:
```dart
  /// Moves all kids from [fromTeamId] to [toTeamId], then deletes the old team.
  Future<void> reassignAndDelete(
      String campId, String fromTeamId, String toTeamId) async {
    final kids = await _firestore
        .collection(AppConstants.usersCollection)
        .where('campId', isEqualTo: campId)
        .where('team', isEqualTo: fromTeamId)
        .get();
    for (var i = 0; i < kids.docs.length; i += 400) {
      final batch = _firestore.batch();
      final end = (i + 400 < kids.docs.length) ? i + 400 : kids.docs.length;
      for (var j = i; j < end; j++) {
        batch.update(kids.docs[j].reference, {'team': toTeamId});
      }
      await batch.commit();
    }
    await _teamsRef(campId).doc(fromTeamId).delete();
  }
```

- [ ] **Step 3: Add the route + settings link**

In `app_router.dart` add under guide routes:
```dart
      GoRoute(
        path: '/guide/settings/teams',
        builder: (context, state) => const TeamsManagementScreen(),
      ),
```
Import the screen. In `guide_settings_screen.dart`, add a `ListTile` in the management card:
```dart
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.groups),
                  title: Text(l10n.teams),
                  subtitle: Text(l10n.teamsManagementSubtitle),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.push('/guide/settings/teams'),
                ),
```

- [ ] **Step 4: Add strings (`editTeam`, `cannotDeleteLastTeam`, `reassignKidsPrompt`, `teamsManagementSubtitle`, `pts` if missing)**

In `app_localizations.dart` add getters + a parameterized method:
```dart
  String get editTeam => _t('editTeam');
  String get deleteTeamTitle => _t('deleteTeamTitle');
  String deleteTeamConfirm(String name) => locale == 'hu'
      ? 'Biztosan törlöd a(z) $name csapatot?'
      : locale == 'en'
          ? 'Delete team $name?'
          : 'Sigur ștergi echipa $name?';
  String get cannotDeleteLastTeam => _t('cannotDeleteLastTeam');
  String get teamsManagementSubtitle => _t('teamsManagementSubtitle');
  String reassignKidsPrompt(int count) => locale == 'hu'
      ? '$count gyerek átsorolása ide:'
      : locale == 'en'
          ? 'Reassign $count kids to:'
          : 'Mută $count copii în echipa:';
```
Add to maps:
- `_ro`: `'editTeam': 'Editează echipa', 'deleteTeamTitle': 'Șterge echipa', 'cannotDeleteLastTeam': 'Nu poți șterge ultima echipă.', 'teamsManagementSubtitle': 'Adaugă, redenumește sau șterge echipe',`
- `_hu`: `'editTeam': 'Csapat szerkesztése', 'deleteTeamTitle': 'Csapat törlése', 'cannotDeleteLastTeam': 'Az utolsó csapat nem törölhető.', 'teamsManagementSubtitle': 'Csapatok hozzáadása, átnevezése, törlése',`
- `_en`: `'editTeam': 'Edit team', 'deleteTeamTitle': 'Delete team', 'cannotDeleteLastTeam': 'Cannot delete the last team.', 'teamsManagementSubtitle': 'Add, rename, or remove teams',`

- [ ] **Step 5: Analyze**

Run:
```bash
flutter analyze lib/features/leaderboard lib/core/router/app_router.dart lib/features/settings/presentation/guide_settings_screen.dart lib/core/l10n/app_localizations.dart
```
Expected: no issues.

- [ ] **Step 6: Commit**

```bash
git add lib/features/leaderboard/presentation/teams_management_screen.dart lib/features/leaderboard/data/teams_repository.dart lib/core/router/app_router.dart lib/features/settings/presentation/guide_settings_screen.dart lib/core/l10n/app_localizations.dart
git commit -m "feat: teams management screen with reassign-on-delete guard"
```

---

### Task 7: Update code generation + points + display to use team docs

**Files:**
- Modify: `lib/features/auth/presentation/code_management_screen.dart`
- Modify: `lib/features/leaderboard/presentation/points_management_screen.dart`
- Modify: `lib/features/leaderboard/presentation/leaderboard_screen.dart`
- Modify: `lib/features/home/presentation/kid_home_screen.dart`
- Modify: `lib/features/auth/domain/camp_code.dart` (unchanged type, but `team` now = teamId)

- [ ] **Step 1: Code generation dialog uses the camp's real teams**

In `code_management_screen.dart`, `_GenerateCodesDialog` currently iterates `AppConstants.defaultTeams`. Change it to read `ref.watch(leaderboardProvider)` (the camp's team docs) and render a `ChoiceChip` per real `Team`, using `team.color` and `team.name`, with `_selectedTeamId` storing `team.id`. Pass `team: _selectedTeamId` to `generateBulkCodes`. This structurally fixes sweep bug #11 (codes for non-existent teams become impossible).

Replace the `AppConstants.defaultTeams.map(...)` chip block with a builder over the teams list, and change `_selectedTeam` (a color key) to the first team's id once teams load. Where the success snackbar builds `teamLabel`, use the selected `Team.name` instead of `TeamColors.localizedName`.

**Also update the grouped code LIST rendering in the same file:** the list groups by `code.team`
(now a teamId) and renders `TeamColors.getColor(team)` + `TeamColors.localizedName(team, ...)` for
the group headers — both methods no longer exist. Resolve each group's `Team` by id from
`ref.watch(leaderboardProvider).valueOrNull` and use `team.color` / `team.name`, falling back to
`Colors.grey` / the raw id for codes whose team was deleted.

- [ ] **Step 2: Points management uses team docs**

In `points_management_screen.dart`, remove all `TeamColors.localizedName(...)` / `team.color[0].toUpperCase()...` usages. The team selector already iterates `teams` (now `List<Team>` with `.name`, `.color`). Replace:
- `team.color` (color-key) → `team.id` for selection identity,
- display name → `team.name`,
- `TeamColors.getColor(team.color)` → `team.color`,
- `TeamColors.getOnColor(team.color)` → `team.onColor`.
In `_AuditHistoryTile`, replace `TeamColors.getColor(entry.team)` — but `entry.team` is a teamId now; look up the team from the passed `teams` list, or store team name/color at write time (see Step 4). For history rows, resolve color/name by finding the team in `ref.watch(leaderboardProvider).valueOrNull` by id, falling back to grey/`entry.team`.

- [ ] **Step 3: Leaderboard + kid home use `team.name`/`team.color`**

In `leaderboard_screen.dart` `_TeamRankCard`, replace `TeamColors.localizedName(team.color, language)` with `team.name` and `TeamColors.getColor(...)` with `team.color`. In `kid_home_screen.dart`, the kid's team is `appUser.team` (a teamId); resolve the `Team` from `leaderboardProvider` by id to get `name`/`color`, falling back to a neutral label if not found. Remove the `language` params that were only used for team-name localization.

- [ ] **Step 3b: CRITICAL — stop `addPoints` from wiping team name/color**

`LeaderboardRepository.addPoints` currently writes the team doc with a bare
`transaction.set(teamDocRef, {'points': newTotal});` — a full-document replace that, under the new
model, would **erase `name` and `colorHex` on every points change**. In
`lib/features/leaderboard/data/leaderboard_repository.dart`, change it to a merge:
```dart
      // Update team points WITHOUT replacing name/colorHex.
      transaction.set(
        teamDocRef,
        {'points': newTotal},
        SetOptions(merge: true),
      );
```
Also add a regression test to `test/features/leaderboard/teams_repository_test.dart` — note it uses
the `teamName`/`teamColorHex` parameters that Step 4 (below) adds to `addPoints`, so **write it now
but run it after completing Step 4**:
```dart
  test('addPoints preserves team name and colorHex', () async {
    final fs = FakeFirebaseFirestore();
    final teamsRepo = TeamsRepository(firestore: fs);
    final lbRepo = LeaderboardRepository(firestore: fs);
    final id = await teamsRepo.addTeam('c1', name: 'Vulturii', colorHex: '#E53935');

    await lbRepo.addPoints(
      campId: 'c1', team: id, amount: 10, reason: 'test', addedBy: 'G',
      teamName: 'Vulturii', teamColorHex: '#E53935',
    );

    final doc = await fs.collection('camps').doc('c1').collection('teams').doc(id).get();
    expect(doc.data()!['name'], 'Vulturii');
    expect(doc.data()!['colorHex'], '#E53935');
    expect(doc.data()!['points'], 10);
  });
```
(Run `flutter test test/features/leaderboard/teams_repository_test.dart` after Step 4 — expected PASS.)

- [ ] **Step 4: Store team name + colorHex on each points entry (denormalize for history)**

Because points history rows show the team after a team may be renamed/deleted, denormalize at write time. In `leaderboard_repository.dart` `addPoints`, the `PointsEntry` currently stores `team` (now teamId). Add `teamName` and `teamColorHex` to `PointsEntry` (model + `toFirestore`/`fromFirestore`) and pass them from the caller (which has the selected `Team`). Update `points_management_screen._submitPoints` to pass the selected team's `name` and `colorHex`. History tiles then render `entry.teamName`/`entry.teamColorHex` directly — no live lookup needed.

Add to `PointsEntry`:
```dart
  final String teamName;
  final String teamColorHex;
```
with matching constructor params (defaulted to `''`), `toFirestore` keys, and `fromFirestore` reads (`data['teamName'] as String? ?? ''`, `data['teamColorHex'] as String? ?? '#9E9E9E'`). Update `LeaderboardRepository.addPoints` signature to accept `teamName` + `teamColorHex` and write them.

- [ ] **Step 5: Analyze**

Run:
```bash
flutter analyze lib
```
Expected: no issues. If any `TeamColors.getColor`/`localizedName`/`displayName`/`getOnColor` reference remains, fix it now — those methods no longer exist.

- [ ] **Step 6: Commit**

```bash
git add lib
git commit -m "refactor: use per-camp team docs for codes, points, leaderboard, and kid home"
```

---

### Task 8: Cloud Function reads team name/color from docs

**Files:**
- Modify: `functions/index.js`

- [ ] **Step 1: Replace the hard-coded `teamNames` map with a Firestore read**

In `onPointsChanged`, the current code uses `tn[changedTeam]` from the hard-coded `teamNames`. Replace it with the team's stored `name`. Since the function already reads all team docs into `currentTeams`, extend that read to capture `name`:
```javascript
    const currentTeams = [];
    teamsSnapshot.forEach((doc) => {
      currentTeams.push({
        id: doc.id,
        name: doc.data().name || doc.id,
        points: doc.data().points || 0,
      });
    });
```
Change `changedTeam` handling: `data.team` is now a teamId. Resolve its name:
```javascript
    const changed = currentTeams.find((t) => t.id === changedTeam);
    const teamDisplayName = changed ? changed.name : changedTeam;
```
Replace every `tn[team.color]`/`tn[changedTeam]` with the resolved `.name`. In the rank loop, iterate by `id` and use `team.name`. Delete the top-of-file `teamNames` constant entirely and remove `const tn = teamNames[...]`.

- [ ] **Step 2: Point topics at team ids consistently**

Topics are `camp_${campId}_team_${changedTeam}` where `changedTeam` is now a teamId — this matches the client subscription (`fcm_service.dart` subscribes to `camp_X_team_<team>` where `team` = `appUser.team` = teamId). No change needed beyond ensuring both sides use the id (they do after Phase-4 client changes).

- [ ] **Step 3: Lint**

Run:
```bash
cd /d/CampConnect/functions && npx eslint index.js || true
```
Expected: no fatal errors.

- [ ] **Step 4: Commit**

```bash
cd /d/CampConnect
git add functions/index.js
git commit -m "refactor: notifications read team name from Firestore instead of hard-coded map"
```

---

### Task 9: Full-phase verification

**Files:** none

- [ ] **Step 1: Analyze + test**

Run:
```bash
flutter analyze && flutter test
```
Expected: no errors; all tests pass.

- [ ] **Step 2: Confirm no dead team-name maps remain**

Run:
```bash
grep -rn "localizedName\|teamNames\|defaultTeams\|getOnColor\|TeamColors.getColor\|TeamColors.colors" lib functions
```
Expected: only `AppConstants.defaultTeams` (the new record list) and `TeamColors.presetHexes`/`colorFromHex`/`hexFromColor`/`onColor` remain. No `localizedName`, no `teamNames`.

- [ ] **Step 3: Build**

Run:
```bash
flutter build apk --debug
```
Expected: builds.

- [ ] **Step 4: Manual verification**

1. Create a camp with custom team names + colors (rename "Roșu"→"Vulturii", add a 5th team).
2. Generate codes — the team chooser shows exactly the camp's teams (not the 4 hard-coded).
3. Add points to a team → the affected kid gets a notification showing the guide-typed team name.
4. Rename a team, then open points history → old entries still show the name captured at write time.
5. Delete a team with kids → prompted to reassign; after reassigning, deletion succeeds and those kids show the new team.

- [ ] **Step 5: Final commit**

```bash
git commit --allow-empty -m "test: phase 4 teams-as-data verified end to end"
```

---

## Notes for the implementer

- Teams are **per-session** by design (stored under each camp). Do not add a global org-level palette —
  that decision was made to avoid another shared-data surface in Phase 5.
- **Phase-3 test update:** `test/features/auth/camp_repository_test.dart` (from Phase 3) calls
  `createCampSession(teams: ['red'], ...)`. After Task 4's signature change, update those calls to
  `teams: [(name: 'Roșu', colorHex: '#E53935')]` and re-run the suite — do this inside Task 4
  before its commit so the tree stays green.
- After merge, update the roadmap checklist: Phase 4 done.
- **Handoff to Phase 5:** team docs live under `camps/{campId}/teams` and are already covered by
  Phase-2 rules (guide writes, member reads). Phase 5's org-scoping applies to the parent camp, so
  teams inherit isolation automatically.
