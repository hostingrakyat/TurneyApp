import 'package:flutter_test/flutter_test.dart';
import 'package:turneyapp/features/matches/bracket.dart';
import 'package:turneyapp/shared/models/competition.dart';
import 'package:turneyapp/shared/models/match.dart';
import 'package:turneyapp/shared/models/participant.dart';

List<Participant> players(int n) =>
    List.generate(n, (i) => Participant(id: 'p$i', name: 'Player $i'));

void main() {
  group('single elimination', () {
    test('power-of-two has size-1 matches, final is TBD', () {
      final m = BracketBuilder.singleElim('c', players(4));
      expect(m.length, 3); // 2 + 1
      final finalMatch = m.firstWhere((x) => x.round == 2);
      expect(finalMatch.player1Id, isNull);
      expect(finalMatch.player2Id, isNull);
      // round-1 matches both have two real players
      for (final r1 in m.where((x) => x.round == 1)) {
        expect(r1.bothPlayersPresent, isTrue);
      }
    });

    test('8 players → 7 matches', () {
      expect(BracketBuilder.singleElim('c', players(8)).length, 7);
    });

    test('non-power-of-two seeds byes that auto-advance', () {
      final m = BracketBuilder.singleElim('c', players(3));
      expect(m.length, 3); // size 4 → 2 + 1
      final byes =
          m.where((x) => x.round == 1 && x.status == MatchStatus.completed);
      expect(byes.length, 1);
      // the bye winner is placed into the final
      final finalMatch = m.firstWhere((x) => x.round == 2);
      expect(finalMatch.player1Id ?? finalMatch.player2Id, isNotNull);
    });

    test('every round-1 match has at least one real player', () {
      final m = BracketBuilder.singleElim('c', players(5));
      expect(m.length, 7); // size 8
      for (final r1 in m.where((x) => x.round == 1)) {
        expect(r1.player1Id != null || r1.player2Id != null, isTrue);
      }
    });
  });

  group('round robin', () {
    test('n players → n*(n-1)/2 matches', () {
      expect(BracketBuilder.roundRobin('c', players(4)).length, 6);
      expect(BracketBuilder.roundRobin('c', players(3)).length, 3);
      expect(BracketBuilder.roundRobin('c', players(6)).length, 15);
    });

    test('everyone plays everyone exactly once', () {
      final m = BracketBuilder.roundRobin('c', players(4));
      final pairs = m
          .map((x) => ([x.player1Id, x.player2Id]..sort()).join('-'))
          .toSet();
      expect(pairs.length, 6);
    });

    test('all matches are stage=group', () {
      final m = BracketBuilder.roundRobin('c', players(4));
      expect(m.every((x) => x.stage == 'group'), isTrue);
    });
  });

  group('groups + playoff', () {
    test('groupSize splits players into sequential groups', () {
      // 8 players, groups of 4 → 2 groups × C(4,2)=6 = 12 matches.
      final m = BracketBuilder.roundRobin('c', players(8), groupSize: 4);
      expect(m.length, 12);
      final groupIds = m.map((x) => x.group).toSet();
      expect(groupIds, {0, 1});
      // each group plays its own 6 matches
      expect(m.where((x) => x.group == 0).length, 6);
      expect(m.where((x) => x.group == 1).length, 6);
    });

    test('a leftover lone player forms no match', () {
      // 5 players, groups of 4 → group 0 (4 players, 6 matches), leftover alone.
      final m = BracketBuilder.roundRobin('c', players(5), groupSize: 4);
      expect(m.length, 6);
      expect(m.map((x) => x.group).toSet(), {0});
    });

    test('playoff seeds a single-elim tagged stage=elim', () {
      final m = BracketBuilder.playoff('c', players(4));
      expect(m.length, 3);
      expect(m.every((x) => x.stage == 'elim'), isTrue);
    });

    test('playoff with fewer than two qualifiers is empty', () {
      expect(BracketBuilder.playoff('c', players(1)), isEmpty);
    });
  });

  group('free-for-all', () {
    test('splits players into lobbies of N', () {
      // 10 players, lobbies of 4 → [4, 4, 2] = 3 single-match lobbies.
      final m = BracketBuilder.freeForAll('c', players(10), lobbySize: 4);
      expect(m.length, 3);
      expect(m.every((x) => x.stage == 'ffa'), isTrue);
      expect(m.map((x) => x.players.length).toList(), [4, 4, 2]);
    });

    test('one lobby when everyone fits', () {
      final m = BracketBuilder.freeForAll('c', players(6), lobbySize: 8);
      expect(m.length, 1);
      expect(m.first.players.length, 6);
    });

    test('a lone leftover auto-wins their lobby', () {
      // 9 players, lobbies of 4 → [4, 4, 1]; the solo lobby is pre-completed.
      final m = BracketBuilder.freeForAll('c', players(9), lobbySize: 4);
      expect(m.length, 3);
      final solo = m.firstWhere((x) => x.players.length == 1);
      expect(solo.status, MatchStatus.completed);
      expect(solo.winnerId, solo.players.first.id);
    });
  });

  test('dispatcher routes by format and guards tiny fields', () {
    expect(
      BracketBuilder.generate(
        competitionId: 'c',
        format: CompetitionFormat.singleElim,
        players: players(1),
      ),
      isEmpty,
    );
    expect(
      BracketBuilder.generate(
        competitionId: 'c',
        format: CompetitionFormat.roundRobin,
        players: players(4),
      ).length,
      6,
    );
  });
}
