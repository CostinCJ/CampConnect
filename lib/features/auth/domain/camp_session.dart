import 'package:cloud_firestore/cloud_firestore.dart';

class CampSession {
  final String id;
  final String name;
  final DateTime startDate;
  final DateTime endDate;
  final List<String> teams;
  final String createdBy;

  const CampSession({
    required this.id,
    required this.name,
    required this.startDate,
    required this.endDate,
    required this.teams,
    required this.createdBy,
  });

  bool get isActive {
    final now = DateTime.now();
    return now.isAfter(startDate) && now.isBefore(endDate);
  }

  bool get hasEnded => DateTime.now().isAfter(endDate);

  factory CampSession.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return CampSession(
      id: doc.id,
      name: data['name'] as String,
      startDate: (data['startDate'] as Timestamp).toDate(),
      endDate: (data['endDate'] as Timestamp).toDate(),
      teams: List<String>.from(data['teams'] as List),
      createdBy: data['createdBy'] as String,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'startDate': Timestamp.fromDate(startDate),
      'endDate': Timestamp.fromDate(endDate),
      'teams': teams,
      'createdBy': createdBy,
    };
  }

  CampSession copyWith({
    String? id,
    String? name,
    DateTime? startDate,
    DateTime? endDate,
    List<String>? teams,
    String? createdBy,
  }) {
    return CampSession(
      id: id ?? this.id,
      name: name ?? this.name,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      teams: teams ?? this.teams,
      createdBy: createdBy ?? this.createdBy,
    );
  }
}
