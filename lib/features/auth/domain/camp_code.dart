import 'package:cloud_firestore/cloud_firestore.dart';

class CampCode {
  final String code;
  final String campId;
  final String orgId;
  final String team;
  final String displayName;
  final bool used;
  final String? usedBy;
  final String createdBy;

  const CampCode({
    required this.code,
    required this.campId,
    required this.orgId,
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
      campId: data['campId'] as String? ?? '',
      orgId: data['orgId'] as String? ?? '',
      team: data['team'] as String,
      displayName: data['displayName'] as String,
      used: data['used'] as bool? ?? false,
      usedBy: data['usedBy'] as String?,
      createdBy: data['createdBy'] as String,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'campId': campId,
      'orgId': orgId,
      'team': team,
      'displayName': displayName,
      'used': used,
      'usedBy': usedBy,
      'createdBy': createdBy,
    };
  }

  CampCode copyWith({
    String? code,
    String? campId,
    String? orgId,
    String? team,
    String? displayName,
    bool? used,
    String? usedBy,
    String? createdBy,
  }) {
    return CampCode(
      code: code ?? this.code,
      campId: campId ?? this.campId,
      orgId: orgId ?? this.orgId,
      team: team ?? this.team,
      displayName: displayName ?? this.displayName,
      used: used ?? this.used,
      usedBy: usedBy ?? this.usedBy,
      createdBy: createdBy ?? this.createdBy,
    );
  }
}
