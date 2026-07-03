import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/constants/app_constants.dart';
import '../domain/team.dart';

class TeamInUseException implements Exception {
  final int kidCount;
  TeamInUseException(this.kidCount);
  @override
  String toString() => 'Team has $kidCount kids assigned.';
}

class TeamsRepository {
  final FirebaseFirestore _firestore;

  TeamsRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> _teamsRef(String campId) =>
      _firestore
          .collection(AppConstants.campsCollection)
          .doc(campId)
          .collection(AppConstants.teamsSubcollection);

  Stream<List<Team>> watchTeams(String campId) {
    return _teamsRef(campId).snapshots().map((snap) {
      final teams = snap.docs.map(Team.fromFirestore).toList();
      teams.sort((a, b) => b.points.compareTo(a.points));
      return teams;
    });
  }

  Future<String> addTeam(String campId,
      {required String name, required String colorHex}) async {
    final docRef = _teamsRef(campId).doc();
    await docRef.set(Team(
      id: docRef.id,
      name: name,
      colorHex: colorHex,
      points: 0,
    ).toFirestore());
    return docRef.id;
  }

  Future<void> updateTeam(String campId, Team team) async {
    await _teamsRef(campId).doc(team.id).update({
      'name': team.name,
      'colorHex': team.colorHex,
    });
  }

  /// Deletes a team only if no kid references it. Throws [TeamInUseException]
  /// otherwise so the UI can offer reassignment.
  Future<void> deleteTeam(String campId, String teamId) async {
    final kids = await _firestore
        .collection(AppConstants.usersCollection)
        .where('campId', isEqualTo: campId)
        .where('team', isEqualTo: teamId)
        .limit(1)
        .get();
    if (kids.docs.isNotEmpty) {
      // Count for the message (bounded read).
      final all = await _firestore
          .collection(AppConstants.usersCollection)
          .where('campId', isEqualTo: campId)
          .where('team', isEqualTo: teamId)
          .get();
      throw TeamInUseException(all.docs.length);
    }
    await _teamsRef(campId).doc(teamId).delete();
  }

  /// Moves all kids from [fromTeamId] to [toTeamId], then deletes the old team.
  Future<void> reassignAndDelete(
      String campId, String fromTeamId, String toTeamId) async {
    final kids = await _firestore
        .collection(AppConstants.usersCollection)
        .where('campId', isEqualTo: campId)
        .where('team', isEqualTo: fromTeamId)
        .get();
    for (var i = 0; i < kids.docs.length; i += 400) {
      final batch = _firestore.batch();
      final end = (i + 400 < kids.docs.length) ? i + 400 : kids.docs.length;
      for (var j = i; j < end; j++) {
        batch.update(kids.docs[j].reference, {'team': toTeamId});
      }
      await batch.commit();
    }
    await _teamsRef(campId).doc(fromTeamId).delete();
  }
}
