import 'package:cloud_firestore/cloud_firestore.dart';

class CampSession {
  final String id;
  final String name;
  final DateTime startDate;
  final DateTime endDate;
  final List<String> teams;
  final String createdBy;
  final String orgId;
  final String language;

  const CampSession({
    required this.id,
    required this.name,
    required this.startDate,
    required this.endDate,
    required this.teams,
    required this.createdBy,
    required this.orgId,
    this.language = 'ro',
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
      orgId: data['orgId'] as String? ?? '',
      language: data['language'] as String? ?? 'ro',
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'startDate': Timestamp.fromDate(startDate),
      'endDate': Timestamp.fromDate(endDate),
      'teams': teams,
      'createdBy': createdBy,
      'orgId': orgId,
      'language': language,
    };
  }

  CampSession copyWith({
    String? id,
    String? name,
    DateTime? startDate,
    DateTime? endDate,
    List<String>? teams,
    String? createdBy,
    String? orgId,
    String? language,
  }) {
    return CampSession(
      id: id ?? this.id,
      name: name ?? this.name,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      teams: teams ?? this.teams,
      createdBy: createdBy ?? this.createdBy,
      orgId: orgId ?? this.orgId,
      language: language ?? this.language,
    );
  }
}
