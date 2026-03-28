import 'package:cloud_firestore/cloud_firestore.dart';

class Announcement {
  final String id;
  final String title;
  final String body;
  final String type; // 'schedule' or 'announcement'
  final bool pinned;
  final String createdBy;
  final String createdByName;
  final DateTime timestamp;

  // Schedule-specific fields
  final DateTime? scheduledDate;
  final String? startTime; // "HH:mm" format
  final String? endTime; // "HH:mm" format

  const Announcement({
    required this.id,
    required this.title,
    required this.body,
    required this.type,
    required this.pinned,
    required this.createdBy,
    required this.createdByName,
    required this.timestamp,
    this.scheduledDate,
    this.startTime,
    this.endTime,
  });

  factory Announcement.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Announcement(
      id: doc.id,
      title: data['title'] as String? ?? '',
      body: data['body'] as String? ?? '',
      type: data['type'] as String? ?? 'announcement',
      pinned: data['pinned'] as bool? ?? false,
      createdBy: data['createdBy'] as String? ?? '',
      createdByName: data['createdByName'] as String? ?? '',
      timestamp: (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
      scheduledDate: (data['scheduledDate'] as Timestamp?)?.toDate(),
      startTime: data['startTime'] as String?,
      endTime: data['endTime'] as String?,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'title': title,
      'body': body,
      'type': type,
      'pinned': pinned,
      'createdBy': createdBy,
      'createdByName': createdByName,
      'timestamp': FieldValue.serverTimestamp(),
      if (scheduledDate != null)
        'scheduledDate': Timestamp.fromDate(scheduledDate!),
      if (startTime != null) 'startTime': startTime,
      if (endTime != null) 'endTime': endTime,
    };
  }

  Announcement copyWith({
    String? id,
    String? title,
    String? body,
    String? type,
    bool? pinned,
    String? createdBy,
    String? createdByName,
    DateTime? timestamp,
    DateTime? scheduledDate,
    String? startTime,
    String? endTime,
  }) {
    return Announcement(
      id: id ?? this.id,
      title: title ?? this.title,
      body: body ?? this.body,
      type: type ?? this.type,
      pinned: pinned ?? this.pinned,
      createdBy: createdBy ?? this.createdBy,
      createdByName: createdByName ?? this.createdByName,
      timestamp: timestamp ?? this.timestamp,
      scheduledDate: scheduledDate ?? this.scheduledDate,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
    );
  }

  bool get isSchedule => type == 'schedule';

  /// Display time range as "08:00 - 12:00"
  String get timeRange {
    if (startTime == null) return '';
    if (endTime == null) return startTime!;
    return '$startTime - $endTime';
  }
}
