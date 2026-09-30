import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/constants/app_constants.dart';
import '../domain/emergency_alert.dart';

class EmergencyRepository {
  final FirebaseFirestore _firestore;

  EmergencyRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> _alertsRef(String campId) =>
      _firestore
          .collection(AppConstants.campsCollection)
          .doc(campId)
          .collection(AppConstants.emergencyAlertsSubcollection);

  /// Real-time stream of emergency alerts, newest first. Capped so a listener
  /// attach never reads an unbounded collection; only recent alerts matter.
  Stream<List<EmergencyAlert>> watchAlerts(String campId) {
    return _alertsRef(campId)
        .orderBy('timestamp', descending: true)
        .limit(50)
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map(EmergencyAlert.fromFirestore).toList());
  }

  /// Creates the alert and returns its document id.
  Future<String> createAlert(String campId, EmergencyAlert alert) async {
    final doc = await _alertsRef(campId).add(alert.toFirestore());
    return doc.id;
  }

  /// Attaches coordinates to an alert that was already sent. Only the sender
  /// may do this (firestore.rules isValidAlertUpdate).
  Future<void> attachLocation(
      String campId, String alertId, double latitude, double longitude) async {
    await _alertsRef(campId).doc(alertId).update({
      'latitude': latitude,
      'longitude': longitude,
    });
  }

  /// Adds the guide's UID to the acknowledgedBy array.
  Future<void> acknowledgeAlert(
      String campId, String alertId, String guideUid) async {
    await _alertsRef(campId).doc(alertId).update({
      'acknowledgedBy': FieldValue.arrayUnion([guideUid]),
    });
  }
}
