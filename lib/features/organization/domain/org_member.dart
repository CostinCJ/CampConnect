import 'package:cloud_firestore/cloud_firestore.dart';

class OrgMember {
  final String uid;
  final String role; // 'owner' | 'guide'
  final String displayName;
  final DateTime? joinedAt; // null for members created before this field existed

  const OrgMember({
    required this.uid,
    required this.role,
    required this.displayName,
    this.joinedAt,
  });

  factory OrgMember.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return OrgMember(
      uid: doc.id,
      role: data['role'] as String? ?? 'guide',
      displayName: data['displayName'] as String? ?? '',
      joinedAt: (data['joinedAt'] as Timestamp?)?.toDate(),
    );
  }
}
