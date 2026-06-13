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

  // Camp Session CRUD

  Future<CampSession> createCampSession({
    required String name,
    required DateTime startDate,
    required DateTime endDate,
    required List<String> teams,
    required String createdBy,
    String language = 'ro',
  }) async {
    final docRef = _campsRef.doc();

    final session = CampSession(
      id: docRef.id,
      name: name,
      startDate: startDate,
      endDate: endDate,
      teams: teams,
      createdBy: createdBy,
      language: language,
    );

    await docRef.set(session.toFirestore());

    // Create team subcollection documents with points: 0
    final batch = _firestore.batch();
    for (final team in teams) {
      batch.set(docRef.collection(AppConstants.teamsSubcollection).doc(team), {
        'points': 0,
      });
    }
    await batch.commit();

    return session;
  }

  Future<void> updateCampSession(CampSession session) async {
    await _campsRef.doc(session.id).update(session.toFirestore());
  }

  Future<void> deleteCampSession(String campId) async {
    await _campsRef.doc(campId).delete();
  }

  Future<CampSession?> getCampSession(String campId) async {
    final doc = await _campsRef.doc(campId).get();
    if (!doc.exists) return null;
    return CampSession.fromFirestore(doc);
  }

  Stream<List<CampSession>> getAllCampSessions() {
    return _campsRef.snapshots().map((snapshot) {
      final sessions = snapshot.docs.map(CampSession.fromFirestore).toList();
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
    required String team,
    required int kidNumber,
    required String createdBy,
  }) async {
    // Generate unique code with collision check
    String code;
    DocumentSnapshot doc;
    do {
      code = _generateCode();
      doc = await _campsRef
          .doc(campId)
          .collection(AppConstants.codesSubcollection)
          .doc(code)
          .get();
    } while (doc.exists);

    final displayName = 'Campist #$kidNumber';

    final campCode = CampCode(
      code: code,
      team: team,
      displayName: displayName,
      createdBy: createdBy,
    );

    await _campsRef
        .doc(campId)
        .collection(AppConstants.codesSubcollection)
        .doc(code)
        .set(campCode.toFirestore());

    return campCode;
  }

  Future<List<CampCode>> generateBulkCodes({
    required String campId,
    required String team,
    required int count,
    required String createdBy,
  }) async {
    // Fetch ALL existing codes once so we can:
    //  - determine starting kid number for this team
    //  - check collisions locally (no per-code round trip)
    final allExistingSnap = await _campsRef
        .doc(campId)
        .collection(AppConstants.codesSubcollection)
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
          team: team,
          displayName: 'Campist #${startNumber + i}',
          createdBy: createdBy,
        ),
      );
    }

    // Atomic batch write, listeners see all new codes in a single emission,
    // avoiding N rebuilds of the UI during bulk generation.
    final batch = _firestore.batch();
    final collection = _campsRef
        .doc(campId)
        .collection(AppConstants.codesSubcollection);
    for (final code in codes) {
      batch.set(collection.doc(code.code), code.toFirestore());
    }
    await batch.commit();

    return codes;
  }

  Stream<List<CampCode>> getCodesForCamp(String campId) {
    return _campsRef
        .doc(campId)
        .collection(AppConstants.codesSubcollection)
        .snapshots()
        .map((snapshot) => snapshot.docs.map(CampCode.fromFirestore).toList());
  }

  // Find camp by code (for kid login)

  Future<String?> findCampIdByCode(String code) async {
    // Query all camps for this code
    final campsSnapshot = await _campsRef.get();
    for (final campDoc in campsSnapshot.docs) {
      final codeDoc = await campDoc.reference
          .collection(AppConstants.codesSubcollection)
          .doc(code)
          .get();
      if (codeDoc.exists) {
        return campDoc.id;
      }
    }
    return null;
  }
}
