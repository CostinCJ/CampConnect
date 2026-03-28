import 'package:cloud_firestore/cloud_firestore.dart';

class PointsEntry {
  final String id;
  final String team;
  final int amount;
  final String reason;
  final String addedBy;
  final DateTime timestamp;

  const PointsEntry({
    required this.id,
    required this.team,
    required this.amount,
    required this.reason,
    required this.addedBy,
    required this.timestamp,
  });

  factory PointsEntry.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return PointsEntry(
      id: doc.id,
      team: data['team'] as String,
      amount: (data['amount'] as num).toInt(),
      reason: data['reason'] as String? ?? '',
      addedBy: data['addedBy'] as String? ?? '',
      timestamp: (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'team': team,
      'amount': amount,
      'reason': reason,
      'addedBy': addedBy,
      'timestamp': Timestamp.fromDate(timestamp),
    };
  }
}
