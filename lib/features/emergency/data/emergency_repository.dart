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

  /// Real-time stream of emergency alerts, newest first.
  Stream<List<EmergencyAlert>> watchAlerts(String campId) {
    return _alertsRef(campId)
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map(EmergencyAlert.fromFirestore).toList());
  }

  Future<void> createAlert(String campId, EmergencyAlert alert) async {
    await _alertsRef(campId).add(alert.toFirestore());
  }

  /// Adds the guide's UID to the acknowledgedBy array.
  Future<void> acknowledgeAlert(
      String campId, String alertId, String guideUid) async {
    await _alertsRef(campId).doc(alertId).update({
      'acknowledgedBy': FieldValue.arrayUnion([guideUid]),
    });
  }
}
