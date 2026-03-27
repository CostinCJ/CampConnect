import 'package:cloud_firestore/cloud_firestore.dart';

class CampCode {
  final String code;
  final String team;
  final String displayName;
  final bool used;
  final String? usedBy;
  final String createdBy;

  const CampCode({
    required this.code,
    required this.team,
    required this.displayName,
    this.used = false,
    this.usedBy,
    required this.createdBy,
  });

  factory CampCode.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return CampCode(
      code: doc.id,
      team: data['team'] as String,
      displayName: data['displayName'] as String,
      used: data['used'] as bool? ?? false,
      usedBy: data['usedBy'] as String?,
      createdBy: data['createdBy'] as String,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'team': team,
      'displayName': displayName,
      'used': used,
      'usedBy': usedBy,
      'createdBy': createdBy,
    };
  }
}
