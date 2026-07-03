import 'package:cloud_firestore/cloud_firestore.dart';

import '../domain/organization.dart';
import '../domain/org_member.dart';

/// Read-only: all organisation WRITES happen server-side in registerGuide.
class OrganizationRepository {
  final FirebaseFirestore _firestore;

  OrganizationRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  Future<Organization?> getOrganization(String orgId) async {
    final doc =
        await _firestore.collection('organizations').doc(orgId).get();
    return doc.exists ? Organization.fromFirestore(doc) : null;
  }

  Stream<List<OrgMember>> watchMembers(String orgId) {
    return _firestore
        .collection('organizations')
        .doc(orgId)
        .collection('members')
        .snapshots()
        .map((snap) => snap.docs.map(OrgMember.fromFirestore).toList());
  }
}
