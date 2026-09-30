import 'points_entry.dart';
import 'team.dart';

/// A positive change for the kid's own team between two leaderboard
/// snapshots. Produced by [detectCelebration]; consumed by the kid-shell
/// celebration overlay.
class Celebration {
  final int pointsDelta;
  final int oldRank; // 1-based
  final int newRank; // 1-based

  const Celebration({
    required this.pointsDelta,
    required this.oldRank,
    required this.newRank,
  });

  bool get isRankUp => newRank < oldRank;
}

/// Standard competition rank ("1224") of [teamId]: 1 + the number of teams
/// with strictly more points, so tied teams share a rank instead of getting
/// different ones from their arbitrary list order. 0 when absent.
int competitionRank(List<Team> teams, String? teamId) {
  final team = teams.where((t) => t.id == teamId).firstOrNull;
  if (team == null) return 0;
  return 1 + teams.where((t) => t.points > team.points).length;
}

/// Compares two leaderboard emissions and returns a [Celebration] when the
/// kid's team GAINED points (possibly climbing a rank along the way).
/// Deductions and other teams' changes never celebrate — including another
/// team losing points and thereby "lifting" this one, which isn't something
/// the kid's team did.
Celebration? detectCelebration({
  required List<Team> previous,
  required List<Team> current,
  required String? teamId,
}) {
  if (teamId == null) return null;
  final before = previous.where((t) => t.id == teamId).firstOrNull;
  final after = current.where((t) => t.id == teamId).firstOrNull;
  if (before == null || after == null) return null;

  final delta = after.points - before.points;
  if (delta <= 0) return null;

  return Celebration(
    pointsDelta: delta,
    oldRank: competitionRank(previous, teamId),
    newRank: competitionRank(current, teamId),
  );
}

/// Sum of today's positive points entries for [teamId] (deductions are not
/// part of a "look what you earned" digest).
int pointsEarnedToday(List<PointsEntry> history, String? teamId, DateTime now) {
  if (teamId == null) return 0;
  return history
      .where((e) =>
          e.team == teamId &&
          e.amount > 0 &&
          e.timestamp.year == now.year &&
          e.timestamp.month == now.month &&
          e.timestamp.day == now.day)
      .fold(0, (sum, e) => sum + e.amount);
}
