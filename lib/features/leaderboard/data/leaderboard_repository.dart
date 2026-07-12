import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/constants/app_constants.dart';
import '../domain/points_entry.dart';
import '../domain/team.dart';

class LeaderboardRepository {
  final FirebaseFirestore _firestore;

  LeaderboardRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> _teamsRef(String campId) =>
      _firestore
          .collection(AppConstants.campsCollection)
          .doc(campId)
          .collection(AppConstants.teamsSubcollection);

  CollectionReference<Map<String, dynamic>> _pointsHistoryRef(String campId) =>
      _firestore
          .collection(AppConstants.campsCollection)
          .doc(campId)
          .collection(AppConstants.pointsHistorySubcollection);

  /// Real-time stream of all teams sorted by points (highest first).
  Stream<List<Team>> watchTeams(String campId) {
    return _teamsRef(campId).snapshots().map((snapshot) {
      final teams = snapshot.docs.map(Team.fromFirestore).toList();
      teams.sort((a, b) => b.points.compareTo(a.points));
      return teams;
    });
  }

  /// Real-time stream of points history, newest first.
  Stream<List<PointsEntry>> watchPointsHistory(String campId) {
    return _pointsHistoryRef(campId)
        .orderBy('timestamp', descending: true)
        .limit(100)
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map(PointsEntry.fromFirestore).toList());
  }

  /// Atomically adds points to a team using a Firestore transaction.
  /// Clamps the resulting score to >= 0.
  /// Returns the id of the created points-history entry (used to support
  /// undo via [revertPointsEntry]).
  Future<String> addPoints({
    required String campId,
    required String team,
    required int amount,
    required String reason,
    required String addedBy,
    String teamName = '',
    String teamColorHex = '#9E9E9E',
  }) async {
    final teamDocRef = _teamsRef(campId).doc(team);
    final historyRef = _pointsHistoryRef(campId).doc();

    await _firestore.runTransaction((transaction) async {
      final teamDoc = await transaction.get(teamDocRef);

      final currentPoints =
          (teamDoc.data()?['points'] as num?)?.toInt() ?? 0;

      // Clamp to >= 0
      final newTotal = (currentPoints + amount).clamp(0, 999999);

      // The change actually applied after clamping — may differ from the
      // requested `amount` (e.g. removing 10 from a team that has 3 applies
      // only -3). Record THIS, not the request: the notification Cloud
      // Function reconstructs each team's previous score as `points - amount`
      // to detect rank changes, so a clamped-away request would otherwise make
      // it compute phantom rank movements.
      final appliedDelta = newTotal - currentPoints;

      // Update team points WITHOUT replacing name/colorHex. Using update()
      // rather than set(..., merge: true) — the team doc is guaranteed to
      // exist (points are only ever added to teams created via addTeam).
      transaction.update(teamDocRef, {'points': newTotal});

      // Record history entry
      final entry = PointsEntry(
        id: historyRef.id,
        team: team,
        amount: appliedDelta,
        reason: reason,
        addedBy: addedBy,
        timestamp: DateTime.now(),
        teamName: teamName,
        teamColorHex: teamColorHex,
      );
      transaction.set(historyRef, entry.toFirestore());
    });

    return historyRef.id;
  }

  /// Undo for a just-submitted points entry: atomically deletes the history
  /// doc and applies the inverse delta to the team total (clamped >= 0,
  /// mirroring addPoints). No-op when the entry no longer exists.
  ///
  /// Note: the points push notification may already have fired for the
  /// original entry — undo corrects the standings, not the notification.
  Future<void> revertPointsEntry({
    required String campId,
    required String entryId,
  }) async {
    final historyRef = _pointsHistoryRef(campId).doc(entryId);

    await _firestore.runTransaction((transaction) async {
      final entryDoc = await transaction.get(historyRef);
      if (!entryDoc.exists) return;

      final data = entryDoc.data()!;
      final team = data['team'] as String;
      final amount = (data['amount'] as num?)?.toInt() ?? 0;

      final teamDocRef = _teamsRef(campId).doc(team);
      final teamDoc = await transaction.get(teamDocRef);
      final currentPoints = (teamDoc.data()?['points'] as num?)?.toInt() ?? 0;

      transaction.update(teamDocRef, {
        'points': (currentPoints - amount).clamp(0, 999999),
      });
      transaction.delete(historyRef);
    });
  }
}
