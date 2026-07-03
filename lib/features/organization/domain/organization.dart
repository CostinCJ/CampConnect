import 'package:cloud_firestore/cloud_firestore.dart';

class Organization {
  final String id;
  final String name;
  final String ownerUid;
  final String inviteCode;

  const Organization({
    required this.id,
    required this.name,
    required this.ownerUid,
    required this.inviteCode,
  });

  factory Organization.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Organization(
      id: doc.id,
      name: data['name'] as String? ?? '',
      ownerUid: data['ownerUid'] as String? ?? '',
      inviteCode: data['inviteCode'] as String? ?? '',
    );
  }

  Map<String, dynamic> toFirestore() => {
        'name': name,
        'ownerUid': ownerUid,
        'inviteCode': inviteCode,
      };
}
