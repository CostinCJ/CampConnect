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
}
