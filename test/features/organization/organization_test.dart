import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:camp_connect/features/organization/domain/organization.dart';

void main() {
  test('Organization round-trips', () async {
    final fs = FakeFirebaseFirestore();
    final ref = fs.collection('organizations').doc('o1');
    await ref.set(const Organization(
      id: 'o1', name: 'Tabăra X', ownerUid: 'g1', inviteCode: 'JOIN-1234',
    ).toFirestore());
    final org = Organization.fromFirestore(await ref.get());
    expect(org.name, 'Tabăra X');
    expect(org.ownerUid, 'g1');
    expect(org.inviteCode, 'JOIN-1234');
  });
}
