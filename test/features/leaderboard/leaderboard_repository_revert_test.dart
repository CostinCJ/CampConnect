import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:camp_connect/features/leaderboard/data/leaderboard_repository.dart';

void main() {
  test('revertPointsEntry removes the entry and restores the team total',
      () async {
    final firestore = FakeFirebaseFirestore();
    final repo = LeaderboardRepository(firestore: firestore);

    await firestore
        .collection('camps')
        .doc('camp-1')
        .collection('teams')
        .doc('blue')
        .set({'points': 10, 'name': 'Blue', 'colorHex': '#1565C0'});

    final entryId = await repo.addPoints(
      campId: 'camp-1',
      team: 'blue',
      amount: 50,
      reason: 'Game',
      addedBy: 'Ana',
      teamName: 'Blue',
      teamColorHex: '#1565C0',
    );

    await repo.revertPointsEntry(campId: 'camp-1', entryId: entryId);

    final teamDoc = await firestore
        .collection('camps')
        .doc('camp-1')
        .collection('teams')
        .doc('blue')
        .get();
    expect(teamDoc.data()!['points'], 10);

    final history = await firestore
        .collection('camps')
        .doc('camp-1')
        .collection('pointsHistory')
        .get();
    expect(history.docs, isEmpty);
  });

  test('reverting a missing entry is a no-op', () async {
    final firestore = FakeFirebaseFirestore();
    final repo = LeaderboardRepository(firestore: firestore);
    await repo.revertPointsEntry(campId: 'camp-1', entryId: 'nope');
  });
}
