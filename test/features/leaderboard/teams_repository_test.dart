import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:camp_connect/features/leaderboard/data/teams_repository.dart';
import 'package:camp_connect/features/leaderboard/data/leaderboard_repository.dart';
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

  test('addPoints preserves team name and colorHex', () async {
    final fs = FakeFirebaseFirestore();
    final teamsRepo = TeamsRepository(firestore: fs);
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
    final teamsRepo = TeamsRepository(firestore: fs);
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
    final teamsRepo = TeamsRepository(firestore: fs);
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
    final teamsRepo = TeamsRepository(firestore: fs);
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
