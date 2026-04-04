// lib/features/map/data/session_location_repository.dart
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/constants/app_constants.dart';
import '../domain/session_location.dart';

class SessionLocationRepository {
  final FirebaseFirestore _firestore;

  SessionLocationRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> _sessionLocationsRef(String campId) =>
      _firestore
          .collection(AppConstants.campsCollection)
          .doc(campId)
          .collection(AppConstants.sessionLocationsSubcollection);

  /// Real-time stream of all session locations for a camp.
  Stream<List<SessionLocation>> watchSessionLocations(String campId) {
    return _sessionLocationsRef(campId)
        .orderBy('visitedAt', descending: true)
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map(SessionLocation.fromFirestore).toList());
  }

  /// Add a visited location to the session.
  Future<String> addSessionLocation(String campId, SessionLocation sessionLocation) async {
    final docRef = await _sessionLocationsRef(campId).add(sessionLocation.toFirestore());
    return docRef.id;
  }

  /// Update a session location (e.g., change photo).
  Future<void> updateSessionLocation(String campId, SessionLocation sessionLocation) async {
    await _sessionLocationsRef(campId).doc(sessionLocation.id).update(sessionLocation.toFirestore());
  }

  /// Remove a visited location from the session.
  Future<void> deleteSessionLocation(String campId, String sessionLocationId) async {
    await _sessionLocationsRef(campId).doc(sessionLocationId).delete();
  }

  /// Check if a master location is already added to this session.
  Future<bool> isLocationInSession(String campId, String masterLocationId) async {
    final snapshot = await _sessionLocationsRef(campId)
        .where('masterLocationId', isEqualTo: masterLocationId)
        .limit(1)
        .get();
    return snapshot.docs.isNotEmpty;
  }
}
