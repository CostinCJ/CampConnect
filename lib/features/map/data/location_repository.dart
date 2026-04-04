// lib/features/map/data/location_repository.dart
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/constants/app_constants.dart';
import '../domain/location.dart';

class LocationRepository {
  final FirebaseFirestore _firestore;

  LocationRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _locationsRef =>
      _firestore.collection(AppConstants.locationsCollection);

  /// Real-time stream of all master locations.
  Stream<List<Location>> watchAllLocations() {
    return _locationsRef
        .orderBy('name')
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map(Location.fromFirestore).toList());
  }

  /// Get a single location by ID.
  Future<Location?> getLocation(String locationId) async {
    final doc = await _locationsRef.doc(locationId).get();
    if (!doc.exists) return null;
    return Location.fromFirestore(doc);
  }

  /// Get multiple locations by IDs.
  Future<List<Location>> getLocationsByIds(List<String> ids) async {
    if (ids.isEmpty) return [];
    // Firestore whereIn supports max 30 items per query
    final locations = <Location>[];
    for (var i = 0; i < ids.length; i += 30) {
      final batch = ids.sublist(i, i + 30 > ids.length ? ids.length : i + 30);
      final snapshot = await _locationsRef
          .where(FieldPath.documentId, whereIn: batch)
          .get();
      locations.addAll(snapshot.docs.map(Location.fromFirestore));
    }
    return locations;
  }

  /// Add a new master location. Returns the new document ID.
  Future<String> addLocation(Location location) async {
    final docRef = await _locationsRef.add(location.toFirestore());
    return docRef.id;
  }

  /// Update an existing master location.
  Future<void> updateLocation(Location location) async {
    await _locationsRef.doc(location.id).update(location.toFirestore());
  }

  /// Update only the knowledge base for a location.
  Future<void> updateKnowledgeBase(String locationId, Map<String, dynamic> knowledgeBase) async {
    await _locationsRef.doc(locationId).update({
      'knowledgeBase': knowledgeBase,
    });
  }

  /// Delete a master location.
  Future<void> deleteLocation(String locationId) async {
    await _locationsRef.doc(locationId).delete();
  }
}
