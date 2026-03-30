// lib/features/map/data/location_repository.dart
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/constants/app_constants.dart';
import '../domain/location.dart';

class LocationRepository {
  final FirebaseFirestore _firestore;

  LocationRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> _locationsRef(String campId) =>
      _firestore
          .collection(AppConstants.campsCollection)
          .doc(campId)
          .collection(AppConstants.locationsSubcollection);

  /// Real-time stream of all locations for a camp session.
  Stream<List<Location>> watchLocations(String campId) {
    return _locationsRef(campId)
        .orderBy('name')
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map(Location.fromFirestore).toList());
  }

  /// Get a single location by ID.
  Future<Location?> getLocation(String campId, String locationId) async {
    final doc = await _locationsRef(campId).doc(locationId).get();
    if (!doc.exists) return null;
    return Location.fromFirestore(doc);
  }

  /// Add a new location. Returns the new document ID.
  Future<String> addLocation(String campId, Location location) async {
    final docRef = await _locationsRef(campId).add(location.toFirestore());
    return docRef.id;
  }

  /// Update an existing location.
  Future<void> updateLocation(String campId, Location location) async {
    await _locationsRef(campId).doc(location.id).update(location.toFirestore());
  }

  /// Delete a location.
  Future<void> deleteLocation(String campId, String locationId) async {
    await _locationsRef(campId).doc(locationId).delete();
  }
}
