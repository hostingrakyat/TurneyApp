import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/i18n.dart';
import '../../core/theme.dart';
import '../../shared/models/match.dart';
import '../../shared/models/participant.dart';

/// Free-for-all lobby cards (a match holds N players). Shared by the List view
/// ([BracketView]), the Bracket view ([TournamentBoard]) and match detail.
List<Widget> ffaLobbySections(
    List<GameMatch> ffa, AppStrings s, bool readOnly) {
  final byRound = <int, List<GameMatch>>{};
  for (final m in ffa) {
    byRound.putIfAbsent(m.round, () => []).add(m);
  }
  final rounds = byRound.keys.toList()..sort();
  final out = <Widget>[];
  for (final r in rounds) {
    final lobbies = byRound[r]!..sort((a, b) => a.position - b.position);
    out.add(Padding(
      padding: const EdgeInsets.only(top: 6, bottom: 8),
      child: Text(
        rounds.length > 1
            ? '${s.t('round.n')} $r'
            : s.t('ffa.lobbies'),
        style: const TextStyle(
            fontWeight: FontWeight.w800, color: Colors.white70),
      ),
    ));
    for (final m in lobbies) {
      out.add(FfaLobbyCard(match: m, strings: s, readOnly: readOnly));
    }
  }
  return out;
}

class FfaLobbyCard extends StatelessWidget {
  const FfaLobbyCard(
      {super.key,
      required this.match,
      required this.strings,
      this.readOnly = false});
  final GameMatch match;
  final AppStrings strings;
  final bool readOnly;

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
        onTap: readOnly ? null : () => context.push('/match/${match.id}'),
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(width: 4, height: 44, color: color),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          strings
                              .t('ffa.lobby')
                              .replaceFirst('{n}', '${match.position + 1}'),
                          style: const TextStyle(
                              fontWeight: FontWeight.w800, fontSize: 13),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          strings
                              .t('ffa.players')
                              .replaceFirst('{n}', '${match.players.length}'),
                          style: const TextStyle(
                              color: Colors.white38, fontSize: 12),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        for (final p in _displayOrder())
                          _chip(p.name, match.placeOf(p.id)),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                match.status == MatchStatus.completed
                    ? Icons.emoji_events
                    : Icons.chevron_right,
                size: 18,
                color: match.status == MatchStatus.completed
                    ? AppColors.gold
                    : color,
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Ranked finishers first (in podium order), then the rest of the lobby.
  List<Participant> _displayOrder() {
    if (match.rankings.isEmpty) return match.players;
    final rankedIds = match.rankings.map((p) => p.id).toSet();
    return [
      ...match.rankings,
      ...match.players.where((p) => !rankedIds.contains(p.id)),
    ];
  }

  Widget _chip(String name, int place) {
    final ranked = place >= 0;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: ranked
            ? AppColors.gold.withValues(alpha: place == 0 ? 0.22 : 0.12)
            : AppColors.surfaceHigh,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (ranked)
            Padding(
              padding: const EdgeInsets.only(right: 4),
              child: place == 0
                  ? const Icon(Icons.emoji_events, size: 12, color: AppColors.gold)
                  : Text('${place + 1}.',
                      style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                          color: AppColors.gold)),
            ),
          Text(name,
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: ranked ? FontWeight.w800 : FontWeight.w500,
                  color: ranked ? Colors.white : Colors.white70)),
        ],
      ),
    );
  }
}
