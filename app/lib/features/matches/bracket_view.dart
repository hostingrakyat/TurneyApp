import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme.dart';
import '../../shared/models/competition.dart';
import '../../shared/models/match.dart';
import '../../shared/widgets/brand.dart';
import 'matches_controller.dart';

/// Read-only bracket / standings for a competition. Tapping a match opens it.
class BracketView extends ConsumerWidget {
  const BracketView({super.key, required this.competition});
  final Competition competition;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final matchesAsync = ref.watch(matchesProvider(competition.id));
    return matchesAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => EmptyState(title: 'Could not load bracket', subtitle: '$e'),
      data: (matches) {
        if (matches.isEmpty) {
          return const EmptyState(
            title: 'No bracket yet',
            subtitle: 'The organizer generates it once registration closes.',
            icon: Icons.account_tree_outlined,
          );
        }
        final rounds = <int, List<GameMatch>>{};
        for (final m in matches) {
          rounds.putIfAbsent(m.round, () => []).add(m);
        }
        final roundKeys = rounds.keys.toList()..sort();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (competition.format == CompetitionFormat.roundRobin) ...[
              _Standings(matches: matches),
              const SizedBox(height: 16),
            ],
            for (final r in roundKeys) ...[
              Padding(
                padding: const EdgeInsets.only(top: 6, bottom: 8),
                child: Text(
                  _roundLabel(competition.format, r, roundKeys.length),
                  style: const TextStyle(
                      fontWeight: FontWeight.w800, color: Colors.white70),
                ),
              ),
              ...rounds[r]!.map((m) => _MatchRow(match: m)),
            ],
          ],
        );
      },
    );
  }

  String _roundLabel(CompetitionFormat f, int round, int total) {
    if (f == CompetitionFormat.roundRobin) return 'Round $round';
    final fromEnd = total - round;
    return switch (fromEnd) {
      0 => 'Final',
      1 => 'Semifinals',
      2 => 'Quarterfinals',
      _ => 'Round $round',
    };
  }
}

class _MatchRow extends StatelessWidget {
  const _MatchRow({required this.match});
  final GameMatch match;

  @override
  Widget build(BuildContext context) {
    final color = switch (match.status) {
      MatchStatus.completed => AppColors.success,
      MatchStatus.disputed => AppColors.danger,
      MatchStatus.awaitingReports || MatchStatus.autoResolving => AppColors.gold,
      MatchStatus.scheduled => Colors.white24,
    };
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: () => context.push('/match/${match.id}'),
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Container(width: 4, height: 40, color: color),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _side(match.player1Name, match.winnerId == match.player1Id),
                    const SizedBox(height: 4),
                    _side(match.player2Name, match.winnerId == match.player2Id),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                match.status == MatchStatus.completed
                    ? Icons.check_circle
                    : Icons.chevron_right,
                size: 18,
                color: color,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _side(String? name, bool isWinner) {
    return Row(
      children: [
        Expanded(
          child: Text(
            name ?? 'TBD',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontWeight: isWinner ? FontWeight.w800 : FontWeight.w500,
              color: isWinner ? Colors.white : Colors.white70,
            ),
          ),
        ),
        if (isWinner)
          const Icon(Icons.emoji_events, size: 14, color: AppColors.gold),
      ],
    );
  }
}

class _Standings extends StatelessWidget {
  const _Standings({required this.matches});
  final List<GameMatch> matches;

  @override
  Widget build(BuildContext context) {
    final names = <String, String>{};
    final wins = <String, int>{};
    final played = <String, int>{};
    for (final m in matches) {
      if (m.player1Id != null) names[m.player1Id!] = m.player1Name ?? 'Player';
      if (m.player2Id != null) names[m.player2Id!] = m.player2Name ?? 'Player';
      if (m.status == MatchStatus.completed && m.winnerId != null) {
        wins[m.winnerId!] = (wins[m.winnerId!] ?? 0) + 1;
        for (final pid in [m.player1Id, m.player2Id]) {
          if (pid != null) played[pid] = (played[pid] ?? 0) + 1;
        }
      }
    }
    final rows = names.keys.toList()
      ..sort((a, b) => (wins[b] ?? 0).compareTo(wins[a] ?? 0));

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Standings',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            Row(
              children: const [
                Expanded(child: Text('Player', style: _h)),
                SizedBox(width: 40, child: Text('W', style: _h, textAlign: TextAlign.center)),
                SizedBox(width: 40, child: Text('P', style: _h, textAlign: TextAlign.center)),
              ],
            ),
            const Divider(),
            ...rows.map((id) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      Expanded(
                          child: Text(names[id] ?? 'Player',
                              maxLines: 1, overflow: TextOverflow.ellipsis)),
                      SizedBox(
                          width: 40,
                          child: Text('${wins[id] ?? 0}',
                              textAlign: TextAlign.center,
                              style: const TextStyle(fontWeight: FontWeight.w800))),
                      SizedBox(
                          width: 40,
                          child: Text('${played[id] ?? 0}',
                              textAlign: TextAlign.center,
                              style: const TextStyle(color: Colors.white54))),
                    ],
                  ),
                )),
          ],
        ),
      ),
    );
  }

  static const _h = TextStyle(
      color: Colors.white54, fontWeight: FontWeight.w700, fontSize: 12);
}
