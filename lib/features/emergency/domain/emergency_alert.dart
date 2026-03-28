import 'package:cloud_firestore/cloud_firestore.dart';

class EmergencyAlert {
  final String id;
  final String message;
  final String senderId;
  final String senderName;
  final List<String> acknowledgedBy;
  final DateTime timestamp;

  const EmergencyAlert({
    required this.id,
    required this.message,
    required this.senderId,
    required this.senderName,
    required this.acknowledgedBy,
    required this.timestamp,
  });

  factory EmergencyAlert.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return EmergencyAlert(
      id: doc.id,
      message: data['message'] as String? ?? '',
      senderId: data['senderId'] as String? ?? '',
      senderName: data['senderName'] as String? ?? '',
      acknowledgedBy: List<String>.from(data['acknowledgedBy'] ?? []),
      timestamp: (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'message': message,
      'senderId': senderId,
      'senderName': senderName,
      'acknowledgedBy': acknowledgedBy,
      'timestamp': FieldValue.serverTimestamp(),
    };
  }

  bool isAcknowledgedBy(String uid) => acknowledgedBy.contains(uid);
}
