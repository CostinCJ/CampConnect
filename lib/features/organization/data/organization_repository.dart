import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';

import '../domain/organization.dart';
import '../domain/org_member.dart';

/// Reads are direct Firestore queries; all organisation WRITES happen
/// server-side (registerGuide, removeMember, rotateInviteCode,
/// joinOrganization callables).
class OrganizationRepository {
  final FirebaseFirestore _firestore;
  final FirebaseFunctions _functions;

  OrganizationRepository({
    FirebaseFirestore? firestore,
    FirebaseFunctions? functions,
  }) : _firestore = firestore ?? FirebaseFirestore.instance,
       _functions = functions ?? FirebaseFunctions.instance;

  Future<Organization?> getOrganization(String orgId) async {
    final doc = await _firestore.collection('organizations').doc(orgId).get();
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

  /// Owner-only (enforced server-side): removes [memberUid] from the org.
  Future<void> removeMember(String memberUid) async {
    await _functions.httpsCallable('removeMember').call({
      'memberUid': memberUid,
    });
  }

  /// Owner-only (enforced server-side): replaces the org invite code.
  /// Returns the new code.
  Future<String> rotateInviteCode() async {
    final result = await _functions.httpsCallable('rotateInviteCode').call();
    final data = Map<String, dynamic>.from(result.data as Map);
    return data['inviteCode'] as String;
  }

  /// Joins the signed-in, org-less guide to the org matching [inviteCode]
  /// (server-side validation; see joinOrganization callable).
  Future<void> joinOrganization(String inviteCode) async {
    await _functions.httpsCallable('joinOrganization').call({
      'inviteCode': inviteCode,
    });
  }
}
