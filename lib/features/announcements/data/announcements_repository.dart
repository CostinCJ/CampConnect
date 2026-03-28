import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/constants/app_constants.dart';
import '../domain/announcement.dart';

class AnnouncementsRepository {
  final FirebaseFirestore _firestore;

  AnnouncementsRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> _announcementsRef(String campId) =>
      _firestore
          .collection(AppConstants.campsCollection)
          .doc(campId)
          .collection(AppConstants.announcementsSubcollection);

  /// Real-time stream of announcements: pinned first, then newest first.
  Stream<List<Announcement>> watchAnnouncements(String campId) {
    return _announcementsRef(campId)
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snapshot) {
      final announcements =
          snapshot.docs.map(Announcement.fromFirestore).toList();
      // Sort: pinned first, then by timestamp descending
      announcements.sort((a, b) {
        if (a.pinned && !b.pinned) return -1;
        if (!a.pinned && b.pinned) return 1;
        return b.timestamp.compareTo(a.timestamp);
      });
      return announcements;
    });
  }

  Future<void> createAnnouncement(
      String campId, Announcement announcement) async {
    await _announcementsRef(campId).add(announcement.toFirestore());
  }

  Future<void> updateAnnouncement(
      String campId, Announcement announcement) async {
    final data = <String, dynamic>{
      'title': announcement.title,
      'body': announcement.body,
      'type': announcement.type,
      'pinned': announcement.pinned,
    };
    if (announcement.isSchedule) {
      if (announcement.scheduledDate != null) {
        data['scheduledDate'] =
            Timestamp.fromDate(announcement.scheduledDate!);
      }
      data['startTime'] = announcement.startTime;
      data['endTime'] = announcement.endTime;
    }
    await _announcementsRef(campId).doc(announcement.id).update(data);
  }

  Future<void> deleteAnnouncement(String campId, String announcementId) async {
    await _announcementsRef(campId).doc(announcementId).delete();
  }
}
