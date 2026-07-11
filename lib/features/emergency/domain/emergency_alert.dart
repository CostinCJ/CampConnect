import 'package:cloud_firestore/cloud_firestore.dart';

class EmergencyAlert {
  final String id;
  final String message;
  final String senderId;
  final String senderName;
  final List<String> acknowledgedBy;
  final DateTime timestamp;

  /// 'custom' | 'missingChild' | 'medical' | 'weather' | 'gather' — drives
  /// the icon on cards/overlay; presets set it, free-text stays 'custom'.
  final String type;

  /// One-shot sender coordinates, only when the guide opted in on send.
  /// Never included in FCM payloads (notification bodies are public).
  final double? latitude;
  final double? longitude;

  const EmergencyAlert({
    required this.id,
    required this.message,
    required this.senderId,
    required this.senderName,
    required this.acknowledgedBy,
    required this.timestamp,
    this.type = 'custom',
    this.latitude,
    this.longitude,
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
      type: data['type'] as String? ?? 'custom',
      latitude: (data['latitude'] as num?)?.toDouble(),
      longitude: (data['longitude'] as num?)?.toDouble(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'message': message,
      'senderId': senderId,
      'senderName': senderName,
      'acknowledgedBy': acknowledgedBy,
      'timestamp': FieldValue.serverTimestamp(),
      'type': type,
      if (latitude != null) 'latitude': latitude,
      if (longitude != null) 'longitude': longitude,
    };
  }

  bool isAcknowledgedBy(String uid) => acknowledgedBy.contains(uid);

  bool get hasLocation => latitude != null && longitude != null;
}
