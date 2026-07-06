import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';

import '../../../core/constants/app_constants.dart';
import '../domain/camp_code.dart';
import '../domain/camp_session.dart';

class CampRepository {
  final FirebaseFirestore _firestore;
  // Resolved lazily in deleteCamp so merely constructing the repository (as the
  // unit tests do, with only a fake Firestore) doesn't eagerly touch
  // FirebaseFunctions.instance, which throws when no Firebase app is running.
  final FirebaseFunctions? _functions;

  CampRepository({FirebaseFirestore? firestore, FirebaseFunctions? functions})
    : _firestore = firestore ?? FirebaseFirestore.instance,
      _functions = functions;

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

  /// Deletes a camp via the `deleteCamp` Cloud Function, which cascades
  /// server-side to the camp's Storage photos, all Firestore subcollections,
  /// and its top-level `codes`. This must go through the callable: the old
  /// client-side version deleted only the (long-empty) legacy per-camp `codes`
  /// subcollection and left the real top-level codes plus every Storage photo
  /// orphaned forever. Firestore rules now deny a direct client camp delete.
  Future<void> deleteCamp(String campId) async {
    final functions = _functions ?? FirebaseFunctions.instance;
    await functions.httpsCallable('deleteCamp').call({'campId': campId});
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

  // Session cleanup (60 days after end date) runs server-side on a schedule
  // (cleanupExpiredCamps in functions/index.js) using recursiveDelete.

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
    if (count > AppConstants.maxBulkCodeGeneration) {
      throw ArgumentError(
        'count must not exceed ${AppConstants.maxBulkCodeGeneration}',
      );
    }

    // Fetch existing codes for this camp once so we can:
    //  - determine starting kid number for this team
    //  - check collisions locally (no per-code round trip)
    // The orgId filter is required: the security rules only permit a codes list
    // query that is provably constrained to the caller's own org.
    final allExistingSnap = await _codesRef
        .where('orgId', isEqualTo: orgId)
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

  Stream<List<CampCode>> getCodesForCamp(String campId, String orgId) {
    // The orgId filter is required by the security rules (a codes list query
    // must be constrained to the caller's own org); campId narrows to this camp.
    return _codesRef
        .where('orgId', isEqualTo: orgId)
        .where('campId', isEqualTo: campId)
        .snapshots()
        .map((snapshot) => snapshot.docs.map(CampCode.fromFirestore).toList());
  }
}
