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
  /// Returns the new total points.
  Future<int> addPoints({
    required String campId,
    required String team,
    required int amount,
    required String reason,
    required String addedBy,
  }) async {
    final teamDocRef = _teamsRef(campId).doc(team);
    final historyRef = _pointsHistoryRef(campId).doc();

    int newTotal = 0;

    await _firestore.runTransaction((transaction) async {
      final teamDoc = await transaction.get(teamDocRef);

      final currentPoints =
          (teamDoc.data()?['points'] as num?)?.toInt() ?? 0;

      // Clamp to >= 0
      newTotal = (currentPoints + amount).clamp(0, 999999);

      // Update team points
      transaction.set(teamDocRef, {'points': newTotal});

      // Record history entry
      final entry = PointsEntry(
        id: historyRef.id,
        team: team,
        amount: amount,
        reason: reason,
        addedBy: addedBy,
        timestamp: DateTime.now(),
      );
      transaction.set(historyRef, entry.toFirestore());
    });

    return newTotal;
  }
}
