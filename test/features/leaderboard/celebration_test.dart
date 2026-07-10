import 'package:flutter_test/flutter_test.dart';
import 'package:camp_connect/features/leaderboard/domain/celebration.dart';
import 'package:camp_connect/features/leaderboard/domain/points_entry.dart';
import 'package:camp_connect/features/leaderboard/domain/team.dart';

void main() {
  Team team(String id, int points) =>
      Team(id: id, name: id, points: points, colorHex: '#FF0000');

  group('detectCelebration', () {
    test('returns null on unchanged standings', () {
      final teams = [team('red', 10), team('blue', 5)];
      expect(
        detectCelebration(previous: teams, current: teams, teamId: 'red'),
        isNull,
      );
    });

    test('detects a points gain without rank change', () {
      final prev = [team('red', 10), team('blue', 5)];
      final curr = [team('red', 15), team('blue', 5)];
      final c = detectCelebration(previous: prev, current: curr, teamId: 'red');
      expect(c, isNotNull);
      expect(c!.pointsDelta, 5);
      expect(c.isRankUp, isFalse);
    });

    test('detects a rank up', () {
      final prev = [team('blue', 10), team('red', 5)];
      final curr = [team('red', 12), team('blue', 10)];
      final c = detectCelebration(previous: prev, current: curr, teamId: 'red');
      expect(c, isNotNull);
      expect(c!.isRankUp, isTrue);
      expect(c.oldRank, 2);
      expect(c.newRank, 1);
    });

    test('rank up with unchanged own points still celebrates', () {
      final prev = [team('blue', 10), team('red', 5)];
      final curr = [team('red', 5), team('blue', 3)];
      final c = detectCelebration(previous: prev, current: curr, teamId: 'red');
      expect(c, isNotNull);
      expect(c!.isRankUp, isTrue);
      expect(c.pointsDelta, 0);
      expect(c.oldRank, 2);
      expect(c.newRank, 1);
    });

    test('rank up despite own points dropping still celebrates, delta clamped to 0', () {
      final prev = [team('blue', 20), team('red', 10)];
      final curr = [team('red', 8), team('blue', 5)];
      final c = detectCelebration(previous: prev, current: curr, teamId: 'red');
      expect(c, isNotNull);
      expect(c!.isRankUp, isTrue);
      expect(c.pointsDelta, 0); // clamped — never reports a negative delta
      expect(c.oldRank, 2);
      expect(c.newRank, 1);
    });

    test('never celebrates deductions or other teams', () {
      final prev = [team('red', 10), team('blue', 5)];
      final curr = [team('red', 7), team('blue', 5)];
      expect(
        detectCelebration(previous: prev, current: curr, teamId: 'red'),
        isNull,
      );
      expect(
        detectCelebration(previous: prev, current: curr, teamId: null),
        isNull,
      );
    });
  });

  group('pointsEarnedToday', () {
    PointsEntry entry(String teamId, int amount, DateTime ts) => PointsEntry(
          id: 'p',
          team: teamId,
          teamName: teamId,
          teamColorHex: '#FF0000',
          amount: amount,
          reason: 'test',
          addedBy: 'guide',
          timestamp: ts,
        );

    test('sums only own team, today, positive amounts', () {
      final now = DateTime(2026, 7, 10, 15, 0);
      final history = [
        entry('red', 10, DateTime(2026, 7, 10, 9, 0)),
        entry('red', -5, DateTime(2026, 7, 10, 10, 0)), // deduction ignored
        entry('blue', 20, DateTime(2026, 7, 10, 11, 0)), // other team
        entry('red', 5, DateTime(2026, 7, 9, 12, 0)), // yesterday
      ];
      expect(pointsEarnedToday(history, 'red', now), 10);
      expect(pointsEarnedToday(history, null, now), 0);
    });
  });
}
