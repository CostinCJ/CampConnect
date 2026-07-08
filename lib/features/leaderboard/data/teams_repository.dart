import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';

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
  final FirebaseFunctions _functions;

  TeamsRepository({FirebaseFirestore? firestore, FirebaseFunctions? functions})
      : _firestore = firestore ?? FirebaseFirestore.instance,
        _functions = functions ??
            FirebaseFunctions.instanceFor(region: AppConstants.functionsRegion);

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

  /// Deletes a team, running server-side via the `deleteTeam` callable.
  /// Firestore rules only let a client read its OWN users/{uid} doc, so "does
  /// any kid still belong to this team" is a cross-user query the client can
  /// never run — it has to happen on the Admin SDK. Throws
  /// [TeamInUseException] if kids are still assigned, so the UI can offer
  /// reassignment.
  Future<void> deleteTeam(String campId, String teamId) async {
    try {
      await _functions.httpsCallable('deleteTeam').call({
        'campId': campId,
        'teamId': teamId,
      });
    } on FirebaseFunctionsException catch (e) {
      if (e.code == 'failed-precondition' && e.message == 'team-in-use') {
        final details = e.details;
        final kidCount = details is Map
            ? ((details['kidCount'] as num?)?.toInt() ?? 0)
            : 0;
        throw TeamInUseException(kidCount);
      }
      rethrow;
    }
  }

  /// Moves all kids from [fromTeamId] to [toTeamId], then deletes the old
  /// team — the same server-side `deleteTeam` callable as [deleteTeam], with
  /// the reassignment target supplied up front.
  Future<void> reassignAndDelete(
      String campId, String fromTeamId, String toTeamId) async {
    await _functions.httpsCallable('deleteTeam').call({
      'campId': campId,
      'teamId': fromTeamId,
      'reassignToTeamId': toTeamId,
    });
  }
}
