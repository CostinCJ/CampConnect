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
