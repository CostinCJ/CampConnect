import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:camp_connect/features/leaderboard/data/leaderboard_repository.dart';

void main() {
  test(
    'revertPointsEntry removes the entry and restores the team total',
    () async {
      final firestore = FakeFirebaseFirestore();
      final repo = LeaderboardRepository(firestore: firestore);

      await firestore
          .collection('camps')
          .doc('camp-1')
          .collection('teams')
          .doc('blue')
          .set({'points': 10, 'name': 'Blue', 'colorHex': '#1565C0'});

      final result = await repo.addPoints(
        campId: 'camp-1',
        team: 'blue',
        amount: 50,
        reason: 'Game',
        addedBy: 'Ana',
        teamName: 'Blue',
        teamColorHex: '#1565C0',
      );
      expect(result.appliedAmount, 50);

      await repo.revertPointsEntry(campId: 'camp-1', entryId: result.entryId);

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
    },
  );

  test('reverting a missing entry is a no-op', () async {
    final firestore = FakeFirebaseFirestore();
    final repo = LeaderboardRepository(firestore: firestore);
    await repo.revertPointsEntry(campId: 'camp-1', entryId: 'nope');
  });

  test('addPoints returns the clamped applied amount, not the raw request, '
      'when the request would take a team below zero', () async {
    final firestore = FakeFirebaseFirestore();
    final repo = LeaderboardRepository(firestore: firestore);

    await firestore
        .collection('camps')
        .doc('camp-1')
        .collection('teams')
        .doc('red')
        .set({'points': 20, 'name': 'Red', 'colorHex': '#E53935'});

    final result = await repo.addPoints(
      campId: 'camp-1',
      team: 'red',
      amount: -50,
      reason: 'Penalty',
      addedBy: 'Ana',
      teamName: 'Red',
      teamColorHex: '#E53935',
    );

    // The team only had 20 points, so the applied delta is clamped to -20
    // even though -50 was requested — the undo snackbar must show this
    // clamped value, not the raw request.
    expect(result.appliedAmount, -20);

    final teamDoc = await firestore
        .collection('camps')
        .doc('camp-1')
        .collection('teams')
        .doc('red')
        .get();
    expect(teamDoc.data()!['points'], 0);
  });
}
