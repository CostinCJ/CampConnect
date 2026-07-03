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
