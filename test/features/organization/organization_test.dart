import 'package:cloud_firestore/cloud_firestore.dart' show Timestamp;
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:camp_connect/features/organization/domain/organization.dart';
import 'package:camp_connect/features/organization/domain/org_member.dart';

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

  test('OrgMember parses optional joinedAt', () {
    // Existing members have no joinedAt — must stay null, not crash.
    const member = OrgMember(uid: 'u1', role: 'guide', displayName: 'G');
    expect(member.joinedAt, isNull);

    final withDate = OrgMember(
      uid: 'u2',
      role: 'guide',
      displayName: 'H',
      joinedAt: DateTime(2026, 7, 6),
    );
    expect(withDate.joinedAt, DateTime(2026, 7, 6));
  });

  test('OrgMember.fromFirestore round-trips joinedAt', () async {
    final fs = FakeFirebaseFirestore();
    final members =
        fs.collection('organizations').doc('o1').collection('members');

    // Doc with a Timestamp joinedAt parses back to the matching DateTime.
    await members.doc('u1').set({
      'role': 'guide',
      'displayName': 'G',
      'joinedAt': Timestamp.fromDate(DateTime(2026, 7, 6)),
    });
    final member = OrgMember.fromFirestore(await members.doc('u1').get());
    expect(member.uid, 'u1');
    expect(member.role, 'guide');
    expect(member.displayName, 'G');
    expect(member.joinedAt, DateTime(2026, 7, 6));

    // Pre-existing doc without joinedAt parses to null, not a crash.
    await members.doc('u2').set({
      'role': 'owner',
      'displayName': 'H',
    });
    final legacy = OrgMember.fromFirestore(await members.doc('u2').get());
    expect(legacy.joinedAt, isNull);
  });
}
