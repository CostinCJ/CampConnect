// lib/features/map/domain/session_location.dart
import 'package:cloud_firestore/cloud_firestore.dart';

class SessionLocation {
  final String id;
  final String masterLocationId;
  final String? photoUrl;
  final String addedBy;
  final DateTime visitedAt;

  const SessionLocation({
    required this.id,
    required this.masterLocationId,
    this.photoUrl,
    required this.addedBy,
    required this.visitedAt,
  });

  factory SessionLocation.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return SessionLocation(
      id: doc.id,
      masterLocationId: data['masterLocationId'] as String? ?? '',
      photoUrl: data['photoUrl'] as String?,
      addedBy: data['addedBy'] as String? ?? '',
      visitedAt: (data['visitedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'masterLocationId': masterLocationId,
      'photoUrl': photoUrl,
      'addedBy': addedBy,
      'visitedAt': FieldValue.serverTimestamp(),
    };
  }

  SessionLocation copyWith({
    String? id,
    String? masterLocationId,
    String? photoUrl,
    String? addedBy,
    DateTime? visitedAt,
  }) {
    return SessionLocation(
      id: id ?? this.id,
      masterLocationId: masterLocationId ?? this.masterLocationId,
      photoUrl: photoUrl ?? this.photoUrl,
      addedBy: addedBy ?? this.addedBy,
      visitedAt: visitedAt ?? this.visitedAt,
    );
  }
}
