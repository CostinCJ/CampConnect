import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:camp_connect/core/constants/app_constants.dart';
import 'package:camp_connect/features/auth/data/camp_repository.dart';

void main() {
  test('createCampSession stores endDate at end of the chosen day', () async {
    final firestore = FakeFirebaseFirestore();
    final repo = CampRepository(firestore: firestore);

    final session = await repo.createCampSession(
      name: 'Camp',
      startDate: DateTime(2026, 7, 1),
      endDate: DateTime(2026, 7, 10), // midnight from the picker
      teams: [(name: 'Roșu', colorHex: '#E53935')],
      createdBy: 'g1',
      orgId: 'org1',
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

  // Camp deletion moved server-side to the `deleteCamp` Cloud Function (it
  // cascades to Storage photos + top-level codes, which the old client version
  // orphaned). Its behavior is covered by functions/test/deleteCamp.test.js.

  test('generateBulkCodes throws ArgumentError when count exceeds the max', () async {
    final firestore = FakeFirebaseFirestore();
    final repo = CampRepository(firestore: firestore);
    await firestore.collection('camps').doc('c1').set({'name': 'C'});

    expect(
      () => repo.generateBulkCodes(
        campId: 'c1',
        orgId: 'org1',
        team: 'red',
        count: AppConstants.maxBulkCodeGeneration + 1,
        createdBy: 'g1',
      ),
      throwsArgumentError,
    );
  });

  test('generateBulkCodes succeeds at exactly the max', () async {
    final firestore = FakeFirebaseFirestore();
    final repo = CampRepository(firestore: firestore);
    await firestore.collection('camps').doc('c1').set({'name': 'C'});

    final codes = await repo.generateBulkCodes(
      campId: 'c1',
      orgId: 'org1',
      team: 'red',
      count: AppConstants.maxBulkCodeGeneration,
      createdBy: 'g1',
    );

    expect(codes.length, AppConstants.maxBulkCodeGeneration);
    final stored = await firestore
        .collection('codes')
        .where('campId', isEqualTo: 'c1')
        .get();
    expect(stored.docs.length, AppConstants.maxBulkCodeGeneration);
  });

  test('getCodesForCamp returns only codes of the given org + camp', () async {
    final firestore = FakeFirebaseFirestore();
    final repo = CampRepository(firestore: firestore);
    // Same campId across two orgs, plus another camp in org1.
    await firestore.collection('codes').doc('CAMP-AAAA').set({
      'orgId': 'org1',
      'campId': 'c1',
      'team': 't',
      'used': false,
      'displayName': 'Kid 1',
      'createdBy': 'g1',
    });
    await firestore.collection('codes').doc('CAMP-BBBB').set({
      'orgId': 'org2',
      'campId': 'c1',
      'team': 't',
      'used': false,
      'displayName': 'Kid 2',
      'createdBy': 'g2',
    });
    await firestore.collection('codes').doc('CAMP-CCCC').set({
      'orgId': 'org1',
      'campId': 'c2',
      'team': 't',
      'used': false,
      'displayName': 'Kid 3',
      'createdBy': 'g1',
    });

    final codes = await repo.getCodesForCamp('c1', 'org1').first;

    expect(codes.length, 1);
    expect(codes.single.code, 'CAMP-AAAA');
  });
}
