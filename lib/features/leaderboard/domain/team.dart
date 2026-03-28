import 'package:cloud_firestore/cloud_firestore.dart';

class Team {
  final String color;
  final int points;

  const Team({
    required this.color,
    required this.points,
  });

  factory Team.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Team(
      color: doc.id,
      points: (data['points'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'points': points,
    };
  }

  Team copyWith({
    String? color,
    int? points,
  }) {
    return Team(
      color: color ?? this.color,
      points: points ?? this.points,
    );
  }
}
