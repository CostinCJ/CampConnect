import 'package:cloud_firestore/cloud_firestore.dart';

class OrgMember {
  final String uid;
  final String role; // 'owner' | 'guide'
  final String displayName;

  const OrgMember({
    required this.uid,
    required this.role,
    required this.displayName,
  });

  factory OrgMember.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return OrgMember(
      uid: doc.id,
      role: data['role'] as String? ?? 'guide',
      displayName: data['displayName'] as String? ?? '',
    );
  }
}
