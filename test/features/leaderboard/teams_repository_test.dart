import 'package:cloud_functions/cloud_functions.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:camp_connect/features/leaderboard/data/teams_repository.dart';
import 'package:camp_connect/features/leaderboard/data/leaderboard_repository.dart';
import 'package:camp_connect/features/leaderboard/domain/team.dart';

// TeamsRepository's constructor eagerly falls back to
// FirebaseFunctions.instanceFor when functions is omitted, which throws (no
// Firebase app initialized) in a plain unit test. None of the tests below
// exercise deleteTeam/reassignAndDelete (the only methods that touch
// _functions), so an unstubbed mock is only ever here to satisfy the
// constructor. implements (not extends) a Mock, so it never calls
// FirebaseFunctions' private constructor.
class _MockFirebaseFunctions extends Mock implements FirebaseFunctions {}

void main() {
  final mockFunctions = _MockFirebaseFunctions();

  test('addTeam creates a team with 0 points and returns its id', () async {
    final fs = FakeFirebaseFirestore();
    final repo = TeamsRepository(firestore: fs, functions: mockFunctions);
    final id = await repo.addTeam('c1', name: 'Vulturii', colorHex: '#E53935');
    final doc = await fs.collection('camps').doc('c1').collection('teams').doc(id).get();
    expect(doc.exists, true);
    expect(Team.fromFirestore(doc).points, 0);
  });

  // deleteTeam's "does any kid still belong to this team" check is a
  // cross-user Firestore query that client-side security rules never permit
  // (a guide may only read their OWN users/{uid} doc) — that's exactly why
  // deleteTeam now runs server-side via the `deleteTeam` callable instead of
  // querying FakeFirebaseFirestore directly. Its behavior (in-use detection,
  // reassignment, idempotent delete, org/guide authorization) is covered by
  // functions/test/teamManagement.test.js against the Cloud Functions
  // emulator, not here.

  test('addPoints preserves team name and colorHex', () async {
    final fs = FakeFirebaseFirestore();
    final teamsRepo = TeamsRepository(firestore: fs, functions: mockFunctions);
    final lbRepo = LeaderboardRepository(firestore: fs);
    final id = await teamsRepo.addTeam('c1', name: 'Vulturii', colorHex: '#E53935');

    await lbRepo.addPoints(
      campId: 'c1',
      team: id,
      amount: 10,
      reason: 'test',
      addedBy: 'G',
      teamName: 'Vulturii',
      teamColorHex: '#E53935',
    );

    final doc = await fs.collection('camps').doc('c1').collection('teams').doc(id).get();
    expect(doc.data()!['name'], 'Vulturii');
    expect(doc.data()!['colorHex'], '#E53935');
    expect(doc.data()!['points'], 10);
  });

  test('addPoints clamps to 0 when removing more than the team has', () async {
    final fs = FakeFirebaseFirestore();
    final teamsRepo = TeamsRepository(firestore: fs, functions: mockFunctions);
    final lbRepo = LeaderboardRepository(firestore: fs);
    final id = await teamsRepo.addTeam('c1', name: 'Red', colorHex: '#E53935');

    await lbRepo.addPoints(
      campId: 'c1',
      team: id,
      amount: 5,
      reason: 'seed',
      addedBy: 'G',
    );
    await lbRepo.addPoints(
      campId: 'c1',
      team: id,
      amount: -100,
      reason: 'penalty',
      addedBy: 'G',
    );

    final doc = await fs.collection('camps').doc('c1').collection('teams').doc(id).get();
    expect(Team.fromFirestore(doc).points, 0);
  });

  test('addPoints records the applied delta (not the request) when clamped', () async {
    final fs = FakeFirebaseFirestore();
    final teamsRepo = TeamsRepository(firestore: fs, functions: mockFunctions);
    final lbRepo = LeaderboardRepository(firestore: fs);
    final id = await teamsRepo.addTeam('c1', name: 'Red', colorHex: '#E53935');

    await lbRepo.addPoints(
        campId: 'c1', team: id, amount: 3, reason: 'seed', addedBy: 'G');
    // Requesting -10 from a team with only 3 applies just -3 (clamped at 0).
    await lbRepo.addPoints(
        campId: 'c1', team: id, amount: -10, reason: 'penalty', addedBy: 'G');

    final history = await fs
        .collection('camps')
        .doc('c1')
        .collection('pointsHistory')
        .get();
    final amounts =
        history.docs.map((d) => (d.data()['amount'] as num).toInt()).toList()
          ..sort();
    // The history must show the applied -3, never the requested -10.
    expect(amounts, [-3, 3]);
  });

  test('addPoints clamps at the 999999 ceiling', () async {
    final fs = FakeFirebaseFirestore();
    final teamsRepo = TeamsRepository(firestore: fs, functions: mockFunctions);
    final lbRepo = LeaderboardRepository(firestore: fs);
    final id = await teamsRepo.addTeam('c1', name: 'Red', colorHex: '#E53935');

    await lbRepo.addPoints(
      campId: 'c1',
      team: id,
      amount: 999990,
      reason: 'seed',
      addedBy: 'G',
    );
    await lbRepo.addPoints(
      campId: 'c1',
      team: id,
      amount: 100,
      reason: 'bonus',
      addedBy: 'G',
    );

    final doc = await fs.collection('camps').doc('c1').collection('teams').doc(id).get();
    expect(Team.fromFirestore(doc).points, 999999);
  });
}
