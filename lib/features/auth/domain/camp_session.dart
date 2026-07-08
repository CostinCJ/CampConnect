import 'package:cloud_firestore/cloud_firestore.dart';

class CampSession {
  final String id;
  final String name;
  final DateTime startDate;
  final DateTime endDate;
  final List<String> teams;
  final String createdBy;
  final String orgId;

  /// Denormalized organiser name, stamped at creation. Kids can read the camp
  /// doc but not the org doc, so this is how the journal PDF export gets the
  /// organisation name.
  final String orgName;
  final String language;

  const CampSession({
    required this.id,
    required this.name,
    required this.startDate,
    required this.endDate,
    required this.teams,
    required this.createdBy,
    required this.orgId,
    this.orgName = '',
    this.language = 'ro',
  });

  /// Exclusive on both ends: a session isn't "active" at the exact instant
  /// it starts or ends.
  bool isActive({DateTime? now}) {
    final n = now ?? DateTime.now();
    return n.isAfter(startDate) && n.isBefore(endDate);
  }

  /// Returns true at and after [endDate] (inclusive), not just strictly
  /// after. Using `isAfter` here would leave a one-second gap at the exact
  /// [endDate] instant where neither `isActive` nor `hasEnded` is true —
  /// see the boundary tests in camp_session_test.dart.
  bool hasEnded({DateTime? now}) {
    final n = now ?? DateTime.now();
    return !n.isBefore(endDate);
  }

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
      orgName: data['orgName'] as String? ?? '',
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
      'orgName': orgName,
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
    String? orgName,
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
      orgName: orgName ?? this.orgName,
      language: language ?? this.language,
    );
  }
}
