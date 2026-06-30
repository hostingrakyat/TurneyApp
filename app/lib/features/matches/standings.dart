import '../../shared/models/match.dart';
import '../../shared/models/participant.dart';

/// A single row in a round-robin standings table. Computed from completed
/// matches only — every match has exactly one winner, so there are no draws
/// and `points` is simply `3 * wins`.
class StandingRow {
  const StandingRow({
    required this.playerId,
    required this.name,
    required this.wins,
    required this.losses,
  });

  final String playerId;
  final String name;
  final int wins;
  final int losses;

  int get played => wins + losses;
  int get points => wins * 3;
}

/// Ranks players in a (group of) round-robin matches.
///
/// Order: points ↓, then **head-to-head** wins between the two tied players,
/// then fewer losses, then name. Only completed matches with a winner count;
/// scheduled/pending matches and byes are ignored.
List<StandingRow> computeStandings(Iterable<GameMatch> matches) {
  final names = <String, String>{};
  final wins = <String, int>{};
  final losses = <String, int>{};
  // head-to-head[a][b] = number of times a beat b.
  final h2h = <String, Map<String, int>>{};

  void seen(String? id, String? name) {
    if (id == null) return;
    names[id] = name ?? 'Player';
    wins.putIfAbsent(id, () => 0);
    losses.putIfAbsent(id, () => 0);
  }

  for (final m in matches) {
    seen(m.player1Id, m.player1Name);
    seen(m.player2Id, m.player2Name);
    if (m.status != MatchStatus.completed || m.winnerId == null) continue;
    final winner = m.winnerId!;
    final loser = winner == m.player1Id ? m.player2Id : m.player1Id;
    if (loser == null) continue; // bye / incomplete pairing
    wins[winner] = (wins[winner] ?? 0) + 1;
    losses[loser] = (losses[loser] ?? 0) + 1;
    (h2h[winner] ??= {})[loser] = ((h2h[winner] ??= {})[loser] ?? 0) + 1;
  }

  final rows = [
    for (final id in names.keys)
      StandingRow(
        playerId: id,
        name: names[id]!,
        wins: wins[id] ?? 0,
        losses: losses[id] ?? 0,
      )
  ];

  rows.sort((a, b) {
    if (a.points != b.points) return b.points.compareTo(a.points);
    final aOverB = h2h[a.playerId]?[b.playerId] ?? 0;
    final bOverA = h2h[b.playerId]?[a.playerId] ?? 0;
    if (aOverB != bOverA) return bOverA.compareTo(aOverB);
    if (a.losses != b.losses) return a.losses.compareTo(b.losses);
    return a.name.toLowerCase().compareTo(b.name.toLowerCase());
  });
  return rows;
}

/// The qualifiers that advance from a group stage into the playoff, seeded
/// A1, B1, A2, B2, … — the top [perGroup] of each group interleaved by rank so
/// group winners are spread across the bracket.
List<Participant> topQualifiers(
    Iterable<GameMatch> groupMatches, int perGroup) {
  final byGroup = <int, List<GameMatch>>{};
  for (final m in groupMatches) {
    byGroup.putIfAbsent(m.group, () => []).add(m);
  }
  final groups = byGroup.keys.toList()..sort();
  final perGroupRows = [
    for (final g in groups) computeStandings(byGroup[g]!).take(perGroup).toList()
  ];

  final out = <Participant>[];
  for (var rank = 0; rank < perGroup; rank++) {
    for (final rows in perGroupRows) {
      if (rank < rows.length) {
        out.add(Participant(id: rows[rank].playerId, name: rows[rank].name));
      }
    }
  }
  return out;
}
