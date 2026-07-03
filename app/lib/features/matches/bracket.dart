import 'package:uuid/uuid.dart';

import '../../shared/models/competition.dart';
import '../../shared/models/match.dart';
import '../../shared/models/participant.dart';

/// Generates the initial set of matches for a competition.
///
/// - **Single elimination:** standard seeding into the next power of two with
///   byes distributed to top seeds; byes auto-advance. Each match links to the
///   next via [GameMatch.nextMatchId]/[GameMatch.nextSlot].
/// - **Round robin:** circle method — everyone plays everyone once.
class BracketBuilder {
  static const _uuid = Uuid();

  static List<GameMatch> generate({
    required String competitionId,
    required CompetitionFormat format,
    required List<Participant> players,
    int groupSize = 0,
    int lobbySize = 8,
  }) {
    if (players.length < 2) return const [];
    return switch (format) {
      CompetitionFormat.singleElim => singleElim(competitionId, players),
      CompetitionFormat.roundRobin =>
        roundRobin(competitionId, players, groupSize: groupSize),
      CompetitionFormat.freeForAll =>
        freeForAll(competitionId, players, lobbySize: lobbySize),
    };
  }

  // ── Free-for-all (lobbies of N) ──────────────────────────────
  /// Splits players into lobbies of [lobbySize]; each lobby is a single match
  /// holding all its players. The winner of each lobby is picked on report;
  /// when several lobbies exist, the organizer generates the next round from
  /// the winners (see [ffaRound]) until one lobby remains → champion.
  static List<GameMatch> freeForAll(
          String competitionId, List<Participant> players,
          {int lobbySize = 8}) =>
      ffaRound(competitionId, players, 1, lobbySize: lobbySize);

  /// One round of FFA lobbies (round [round]) from the given players.
  static List<GameMatch> ffaRound(
      String competitionId, List<Participant> players, int round,
      {int lobbySize = 8}) {
    final size = lobbySize < 2 ? players.length : lobbySize;
    final matches = <GameMatch>[];
    var pos = 0;
    for (var i = 0; i < players.length; i += size) {
      final end = (i + size) > players.length ? players.length : i + size;
      final lobby = players.sublist(i, end);
      if (lobby.length < 2) {
        // A lone leftover auto-advances (already "won" their empty lobby).
        matches.add(GameMatch(
          id: _uuid.v4(),
          competitionId: competitionId,
          round: round,
          position: pos++,
          stage: 'ffa',
          players: lobby,
          status: MatchStatus.completed,
          winnerId: lobby.isEmpty ? null : lobby.first.id,
        ));
        continue;
      }
      matches.add(GameMatch(
        id: _uuid.v4(),
        competitionId: competitionId,
        round: round,
        position: pos++,
        stage: 'ffa',
        players: lobby,
      ));
    }
    return matches;
  }

  /// Final single-elimination playoff seeded from group qualifiers.
  static List<GameMatch> playoff(
          String competitionId, List<Participant> qualifiers) =>
      qualifiers.length < 2
          ? const []
          : singleElim(competitionId, qualifiers, stage: 'elim');

  // ── Single elimination ──────────────────────────────────────
  static List<GameMatch> singleElim(
      String competitionId, List<Participant> players,
      {String stage = 'elim'}) {
    final size = _nextPow2(players.length);
    final rounds = _log2(size);
    final slots = _seedOrder(size); // seed number (1..size) per slot

    // Pre-allocate match ids per round so we can wire next-match links.
    final ids = <List<String>>[];
    for (var r = 0; r < rounds; r++) {
      final count = size >> (r + 1);
      ids.add(List.generate(count, (_) => _uuid.v4()));
    }

    final matches = <GameMatch>[];

    for (var r = 0; r < rounds; r++) {
      final count = size >> (r + 1);
      for (var pos = 0; pos < count; pos++) {
        final isLast = r == rounds - 1;
        var match = GameMatch(
          id: ids[r][pos],
          competitionId: competitionId,
          round: r + 1,
          position: pos,
          nextMatchId: isLast ? null : ids[r + 1][pos ~/ 2],
          nextSlot: isLast ? null : (pos.isEven ? 1 : 2),
          stage: stage,
        );

        if (r == 0) {
          final p1 = _playerForSlot(slots, players, pos * 2);
          final p2 = _playerForSlot(slots, players, pos * 2 + 1);
          match = match.copyWith(
            player1Id: p1?.id,
            player1Name: p1?.name,
            player2Id: p2?.id,
            player2Name: p2?.name,
          );
        }
        matches.add(match);
      }
    }

    // Resolve round-1 byes (one side missing) → auto-advance the present player.
    final byId = {for (final m in matches) m.id: m};
    for (final m in matches.where((m) => m.round == 1)) {
      if (m.isBye) {
        final winnerId = m.player1Id ?? m.player2Id;
        final winnerName = m.player1Name ?? m.player2Name;
        byId[m.id] =
            m.copyWith(status: MatchStatus.completed, winnerId: winnerId);
        _advance(byId, m.nextMatchId, m.nextSlot, winnerId!, winnerName!);
      }
    }
    return byId.values.toList()
      ..sort((a, b) =>
          a.round != b.round ? a.round - b.round : a.position - b.position);
  }

  /// Places [winnerId]/[winnerName] into the [slot] of match [nextId].
  static void _advance(Map<String, GameMatch> byId, String? nextId, int? slot,
      String winnerId, String winnerName) {
    if (nextId == null || slot == null) return;
    final next = byId[nextId];
    if (next == null) return;
    byId[nextId] = slot == 1
        ? next.copyWith(player1Id: winnerId, player1Name: winnerName)
        : next.copyWith(player2Id: winnerId, player2Name: winnerName);
  }

  static Participant? _playerForSlot(
      List<int> slots, List<Participant> players, int slotIndex) {
    final seed = slots[slotIndex]; // 1-based
    final idx = seed - 1;
    return idx < players.length ? players[idx] : null;
  }

  /// Bracket seed order: for slot i, the seed number that belongs there so the
  /// top seed meets the bottom seed, etc. e.g. size 4 → [1, 4, 3, 2].
  static List<int> _seedOrder(int size) {
    var seeds = <int>[1, 2];
    while (seeds.length < size) {
      final sum = seeds.length * 2 + 1;
      final next = <int>[];
      for (final s in seeds) {
        next.add(s);
        next.add(sum - s);
      }
      seeds = next;
    }
    return seeds;
  }

  // ── Round robin (circle method), optionally split into groups ─
  static List<GameMatch> roundRobin(
      String competitionId, List<Participant> players,
      {int groupSize = 0}) {
    if (groupSize <= 1 || groupSize >= players.length) {
      return _groupMatches(competitionId, players, 0);
    }
    final matches = <GameMatch>[];
    var g = 0;
    for (var i = 0; i < players.length; i += groupSize) {
      final end = (i + groupSize) > players.length ? players.length : i + groupSize;
      final groupPlayers = players.sublist(i, end);
      if (groupPlayers.length < 2) continue; // a lone leftover plays nobody
      matches.addAll(_groupMatches(competitionId, groupPlayers, g));
      g++;
    }
    return matches;
  }

  static List<GameMatch> _groupMatches(
      String competitionId, List<Participant> players, int group) {
    final list = [...players];
    final hasBye = list.length.isOdd;
    if (hasBye) {
      list.add(const Participant(id: '__bye__', name: 'BYE', isBot: true));
    }
    final n = list.length;
    final rounds = n - 1;
    final half = n ~/ 2;
    final rotation = List<int>.generate(n, (i) => i);
    final matches = <GameMatch>[];

    for (var r = 0; r < rounds; r++) {
      for (var i = 0; i < half; i++) {
        final a = list[rotation[i]];
        final b = list[rotation[n - 1 - i]];
        if (a.id == '__bye__' || b.id == '__bye__') continue;
        matches.add(GameMatch(
          id: _uuid.v4(),
          competitionId: competitionId,
          round: r + 1,
          position: i,
          player1Id: a.id,
          player1Name: a.name,
          player2Id: b.id,
          player2Name: b.name,
          group: group,
          stage: 'group',
        ));
      }
      final last = rotation.removeLast();
      rotation.insert(1, last);
    }
    return matches;
  }

  // ── helpers ─────────────────────────────────────────────────
  static int _nextPow2(int n) {
    var p = 2;
    while (p < n) {
      p <<= 1;
    }
    return p;
  }

  static int _log2(int n) {
    var r = 0;
    var v = n;
    while (v > 1) {
      v >>= 1;
      r++;
    }
    return r;
  }
}
