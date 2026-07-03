import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/constants/app_constants.dart';
import '../domain/camp_code.dart';
import '../domain/camp_session.dart';

class CampRepository {
  final FirebaseFirestore _firestore;

  CampRepository({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _campsRef =>
      _firestore.collection(AppConstants.campsCollection);

  CollectionReference<Map<String, dynamic>> get _codesRef =>
      _firestore.collection(AppConstants.codesSubcollection);

  // Camp Session CRUD

  Future<CampSession> createCampSession({
    required String name,
    required DateTime startDate,
    required DateTime endDate,
    required List<({String name, String colorHex})> teams,
    required String createdBy,
    required String orgId,
    String language = 'ro',
  }) async {
    final docRef = _campsRef.doc();

    // Normalize the end date to the last moment of the chosen day so the final
    // camp day is not locked out (pickers return midnight).
    final normalizedEnd = DateTime(
      endDate.year,
      endDate.month,
      endDate.day,
      23,
      59,
      59,
    );

    final session = CampSession(
      id: docRef.id,
      name: name,
      startDate: startDate,
      endDate: normalizedEnd,
      teams: teams.map((t) => t.name).toList(),
      createdBy: createdBy,
      orgId: orgId,
      language: language,
    );

    await docRef.set(session.toFirestore());

    // Create team documents with a generated id, name, colorHex, points: 0.
    final batch = _firestore.batch();
    for (final team in teams) {
      final teamRef = docRef.collection(AppConstants.teamsSubcollection).doc();
      batch.set(teamRef, {
        'name': team.name,
        'colorHex': team.colorHex,
        'points': 0,
      });
    }
    await batch.commit();

    return session;
  }

  Future<void> updateCampSession(CampSession session) async {
    await _campsRef.doc(session.id).update(session.toFirestore());
  }

  /// Deletes a camp and all of its subcollections (codes, teams, pointsHistory,
  /// announcements, emergencyAlerts, sessionLocations). Batched in chunks of 400
  /// to stay under Firestore's 500-op batch limit.
  Future<void> deleteCampSession(String campId) async {
    const subs = [
      AppConstants.codesSubcollection,
      AppConstants.teamsSubcollection,
      AppConstants.pointsHistorySubcollection,
      AppConstants.announcementsSubcollection,
      AppConstants.emergencyAlertsSubcollection,
      AppConstants.sessionLocationsSubcollection,
    ];

    for (final sub in subs) {
      final snap = await _campsRef.doc(campId).collection(sub).get();
      for (var i = 0; i < snap.docs.length; i += 400) {
        final batch = _firestore.batch();
        final end = (i + 400 < snap.docs.length) ? i + 400 : snap.docs.length;
        for (var j = i; j < end; j++) {
          batch.delete(snap.docs[j].reference);
        }
        await batch.commit();
      }
    }
    await _campsRef.doc(campId).delete();
  }

  Future<CampSession?> getCampSession(String campId) async {
    final doc = await _campsRef.doc(campId).get();
    if (!doc.exists) return null;
    return CampSession.fromFirestore(doc);
  }

  Stream<List<CampSession>> getCampSessionsForOrg(String orgId) {
    return _campsRef.where('orgId', isEqualTo: orgId).snapshots().map((snap) {
      final sessions = snap.docs.map(CampSession.fromFirestore).toList();
      sessions.sort((a, b) => b.startDate.compareTo(a.startDate));
      return sessions;
    });
  }

  // Session Cleanup (60 days after end date)

  Future<void> cleanupExpiredSessions(String guideId) async {
    final cutoff = DateTime.now().subtract(const Duration(days: 60));
    final snapshot = await _campsRef
        .where('createdBy', isEqualTo: guideId)
        .get();

    for (final campDoc in snapshot.docs) {
      final session = CampSession.fromFirestore(campDoc);
      if (!session.endDate.isBefore(cutoff)) continue;

      // Delete all codes for this session
      final codesSnapshot = await campDoc.reference
          .collection(AppConstants.codesSubcollection)
          .get();
      final batch = _firestore.batch();
      for (final codeDoc in codesSnapshot.docs) {
        batch.delete(codeDoc.reference);
      }

      // Delete all points history
      final historySnapshot = await campDoc.reference
          .collection(AppConstants.pointsHistorySubcollection)
          .get();
      for (final historyDoc in historySnapshot.docs) {
        batch.delete(historyDoc.reference);
      }

      // Delete team documents
      final teamsSnapshot = await campDoc.reference
          .collection(AppConstants.teamsSubcollection)
          .get();
      for (final teamDoc in teamsSnapshot.docs) {
        batch.delete(teamDoc.reference);
      }

      // Delete the session document itself
      batch.delete(campDoc.reference);

      await batch.commit();
    }
  }

  // Code Generation

  String _generateCode() {
    final random = Random.secure();
    final chars = List.generate(
      AppConstants.codeLength,
      (_) =>
          AppConstants.codeCharset[random.nextInt(
            AppConstants.codeCharset.length,
          )],
    );
    return '${AppConstants.codePrefix}-${chars.join()}';
  }

  Future<CampCode> generateCode({
    required String campId,
    required String orgId,
    required String team,
    required int kidNumber,
    required String createdBy,
  }) async {
    // Generate unique code with collision check
    String code;
    DocumentSnapshot doc;
    do {
      code = _generateCode();
      doc = await _codesRef.doc(code).get();
    } while (doc.exists);

    final displayName = 'Campist #$kidNumber';

    final campCode = CampCode(
      code: code,
      campId: campId,
      orgId: orgId,
      team: team,
      displayName: displayName,
      createdBy: createdBy,
    );

    await _codesRef.doc(code).set(campCode.toFirestore());

    return campCode;
  }

  Future<List<CampCode>> generateBulkCodes({
    required String campId,
    required String orgId,
    required String team,
    required int count,
    required String createdBy,
  }) async {
    // Fetch existing codes for this camp once so we can:
    //  - determine starting kid number for this team
    //  - check collisions locally (no per-code round trip)
    final allExistingSnap = await _codesRef
        .where('campId', isEqualTo: campId)
        .get();
    final existingIds = allExistingSnap.docs.map((d) => d.id).toSet();
    final startNumber =
        allExistingSnap.docs
            .where((d) => (d.data()['team'] as String?) == team)
            .length +
        1;

    final codes = <CampCode>[];
    for (var i = 0; i < count; i++) {
      String code;
      do {
        code = _generateCode();
      } while (existingIds.contains(code));
      existingIds.add(code);

      codes.add(
        CampCode(
          code: code,
          campId: campId,
          orgId: orgId,
          team: team,
          displayName: 'Campist #${startNumber + i}',
          createdBy: createdBy,
        ),
      );
    }

    // Write in chunks of 400 to stay under Firestore's 500-op batch limit.
    for (var i = 0; i < codes.length; i += 400) {
      final batch = _firestore.batch();
      final end = (i + 400 < codes.length) ? i + 400 : codes.length;
      for (var j = i; j < end; j++) {
        batch.set(_codesRef.doc(codes[j].code), codes[j].toFirestore());
      }
      await batch.commit();
    }

    return codes;
  }

  Stream<List<CampCode>> getCodesForCamp(String campId) {
    return _codesRef
        .where('campId', isEqualTo: campId)
        .snapshots()
        .map((snapshot) => snapshot.docs.map(CampCode.fromFirestore).toList());
  }
}
