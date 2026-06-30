import 'package:flutter_test/flutter_test.dart';
import 'package:turneyapp/features/matches/standings.dart';
import 'package:turneyapp/shared/models/match.dart';

/// A completed group match where [winner] beat the other player.
GameMatch played(String p1, String p2, String winner, {int group = 0}) =>
    GameMatch(
      id: '$group-$p1-$p2',
      competitionId: 'c',
      round: 1,
      position: 0,
      player1Id: p1,
      player1Name: p1.toUpperCase(),
      player2Id: p2,
      player2Name: p2.toUpperCase(),
      status: MatchStatus.completed,
      winnerId: winner,
      group: group,
      stage: 'group',
    );

void main() {
  group('computeStandings', () {
    test('tallies wins/losses/points and orders by points', () {
      final rows = computeStandings([
        played('a', 'b', 'a'),
        played('a', 'c', 'a'),
        played('b', 'c', 'b'),
      ]);
      expect(rows.map((r) => r.playerId).toList(), ['a', 'b', 'c']);
      expect(rows[0].wins, 2);
      expect(rows[0].losses, 0);
      expect(rows[0].points, 6);
      expect(rows[1].wins, 1);
      expect(rows[1].losses, 1);
      expect(rows[2].points, 0);
    });

    test('ignores matches that are not completed', () {
      final scheduled = GameMatch(
        id: 'x',
        competitionId: 'c',
        round: 1,
        position: 0,
        player1Id: 'a',
        player1Name: 'A',
        player2Id: 'b',
        player2Name: 'B',
      );
      final rows = computeStandings([scheduled]);
      expect(rows.length, 2);
      expect(rows.every((r) => r.played == 0), isTrue);
    });

    test('breaks point ties by head-to-head', () {
      // a & b both finish 2-1; a beat b head-to-head → a ranks first.
      // c & d both finish 1-2; c beat d head-to-head → c ranks third.
      final rows = computeStandings([
        played('a', 'b', 'a'),
        played('a', 'c', 'a'),
        played('d', 'a', 'd'),
        played('b', 'd', 'b'),
        played('b', 'c', 'b'),
        played('c', 'd', 'c'),
      ]);
      expect(rows.map((r) => r.playerId).toList(), ['a', 'b', 'c', 'd']);
      expect(rows[0].points, 6);
      expect(rows[1].points, 6);
      expect(rows[2].points, 3);
      expect(rows[3].points, 3);
    });
  });

  group('topQualifiers', () {
    test('seeds A1, B1, A2, B2 across groups', () {
      final matches = [
        played('a1', 'a2', 'a1', group: 0),
        played('b1', 'b2', 'b1', group: 1),
      ];
      final qs = topQualifiers(matches, 2);
      expect(qs.map((p) => p.id).toList(), ['a1', 'b1', 'a2', 'b2']);
    });

    test('takes only the top N per group', () {
      final matches = [
        played('a1', 'a2', 'a1', group: 0),
        played('a1', 'a3', 'a1', group: 0),
        played('a2', 'a3', 'a2', group: 0),
      ];
      final qs = topQualifiers(matches, 2);
      expect(qs.map((p) => p.id).toList(), ['a1', 'a2']);
    });
  });
}
