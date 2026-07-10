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

/// Compares two leaderboard emissions (both already sorted by rank, as
/// `leaderboardProvider` emits them) and returns a [Celebration] when the
/// kid's team gained points and/or climbed. Deductions and other teams'
/// changes never celebrate.
Celebration? detectCelebration({
  required List<Team> previous,
  required List<Team> current,
  required String? teamId,
}) {
  if (teamId == null) return null;
  final prevIndex = previous.indexWhere((t) => t.id == teamId);
  final currIndex = current.indexWhere((t) => t.id == teamId);
  if (prevIndex < 0 || currIndex < 0) return null;

  final delta = current[currIndex].points - previous[prevIndex].points;
  final rankUp = currIndex < prevIndex;
  if (delta <= 0 && !rankUp) return null;

  return Celebration(
    pointsDelta: delta > 0 ? delta : 0,
    oldRank: prevIndex + 1,
    newRank: currIndex + 1,
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
