import 'package:cloud_firestore/cloud_firestore.dart';

class AppUser {
  final String uid;
  final String role; // 'guide' or 'kid'
  final String? email;
  final String displayName;
  final String? campId;
  final String? team;
  final DateTime createdAt;

  const AppUser({
    required this.uid,
    required this.role,
    this.email,
    required this.displayName,
    this.campId,
    this.team,
    required this.createdAt,
  });

  bool get isGuide => role == 'guide';
  bool get isKid => role == 'kid';

  factory AppUser.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return AppUser(
      uid: doc.id,
      role: data['role'] as String,
      email: data['email'] as String?,
      displayName: data['displayName'] as String? ?? '',
      campId: data['campId'] as String?,
      team: data['team'] as String?,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'role': role,
      if (email != null) 'email': email,
      'displayName': displayName,
      if (campId != null) 'campId': campId,
      if (team != null) 'team': team,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  AppUser copyWith({
    String? uid,
    String? role,
    String? email,
    String? displayName,
    String? campId,
    String? team,
    DateTime? createdAt,
  }) {
    return AppUser(
      uid: uid ?? this.uid,
      role: role ?? this.role,
      email: email ?? this.email,
      displayName: displayName ?? this.displayName,
      campId: campId ?? this.campId,
      team: team ?? this.team,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
