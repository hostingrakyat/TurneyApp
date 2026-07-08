import 'package:flutter/material.dart';
import '../../shared/widgets/app_loader.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/i18n.dart';
import '../../core/theme.dart';
import '../../shared/models/competition.dart';
import '../../shared/models/match.dart';
import '../../shared/widgets/brand.dart';
import 'ffa_lobby.dart';
import 'matches_controller.dart';
import 'standings.dart';

/// Read-only bracket / standings for a competition. Tapping a match opens it,
/// unless [readOnly] is set (e.g. the public/anonymous tournament page).
class BracketView extends ConsumerWidget {
  const BracketView(
      {super.key, required this.competition, this.readOnly = false});
  final Competition competition;
  final bool readOnly;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    ref.watch(liveMatchesProvider(competition.id)); // live updates (backend)
    final matchesAsync = ref.watch(matchesProvider(competition.id));
    return matchesAsync.when(
      loading: () => const AppLoading(),
      error: (e, _) =>
          EmptyState(title: s.t('bracket.loadError'), subtitle: '$e'),
      data: (matches) {
        if (matches.isEmpty) {
          return EmptyState(
            title: s.t('bracket.emptyTitle'),
            subtitle: s.t('bracket.emptySubtitle'),
            icon: Icons.account_tree_outlined,
          );
        }
        final groupMatches =
            matches.where((m) => m.stage == 'group').toList();
        final elimMatches = matches.where((m) => m.stage == 'elim').toList();
        final ffaMatches = matches.where((m) => m.stage == 'ffa').toList();
        final children = <Widget>[];

        if (ffaMatches.isNotEmpty) {
          children.addAll(ffaLobbySections(ffaMatches, s, readOnly));
        }

        if (groupMatches.isNotEmpty) {
          final byGroup = <int, List<GameMatch>>{};
          for (final m in groupMatches) {
            byGroup.putIfAbsent(m.group, () => []).add(m);
          }
          final groupKeys = byGroup.keys.toList()..sort();
          final multi = groupKeys.length > 1;
          for (final g in groupKeys) {
            if (multi) {
              children.add(Padding(
                padding: const EdgeInsets.only(top: 6, bottom: 8),
                child: Text(
                  '${s.t('bracket.group')} ${String.fromCharCode(65 + g)}',
                  style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 16,
                      color: AppColors.cyan),
                ),
              ));
            }
            children.add(_Standings(matches: byGroup[g]!, strings: s));
            children.add(const SizedBox(height: 8));
            children.addAll(_rounds(byGroup[g]!,
                elim: false, strings: s, readOnly: readOnly));
            children.add(const SizedBox(height: 16));
          }
        }

        if (elimMatches.isNotEmpty) {
          if (groupMatches.isNotEmpty) {
            children.add(Padding(
              padding: const EdgeInsets.only(top: 6, bottom: 8),
              child: Text(
                s.t('bracket.playoffs'),
                style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 16,
                    color: AppColors.gold),
              ),
            ));
          }
          children.addAll(_rounds(elimMatches,
              elim: true, strings: s, readOnly: readOnly));
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: children,
        );
      },
    );
  }

  /// Renders round headers + match rows for one phase (group or elim).
  List<Widget> _rounds(List<GameMatch> phase,
      {required bool elim,
      required AppStrings strings,
      required bool readOnly}) {
    final rounds = <int, List<GameMatch>>{};
    for (final m in phase) {
      rounds.putIfAbsent(m.round, () => []).add(m);
    }
    final roundKeys = rounds.keys.toList()..sort();
    final out = <Widget>[];
    for (final r in roundKeys) {
      out.add(Padding(
        padding: const EdgeInsets.only(top: 6, bottom: 8),
        child: Text(
          _roundLabel(elim, r, roundKeys.length, strings),
          style: const TextStyle(
              fontWeight: FontWeight.w800, color: Colors.white70),
        ),
      ));
      out.addAll(rounds[r]!
          .map((m) => _MatchRow(match: m, strings: strings, readOnly: readOnly)));
    }
    return out;
  }

  String _roundLabel(bool elim, int round, int total, AppStrings strings) {
    if (!elim) return '${strings.t('round.n')} $round';
    final fromEnd = total - round;
    return switch (fromEnd) {
      0 => strings.t('round.final'),
      1 => strings.t('round.semifinals'),
      2 => strings.t('round.quarterfinals'),
      _ => '${strings.t('round.n')} $round',
    };
  }
}

class _MatchRow extends StatelessWidget {
  const _MatchRow(
      {required this.match, required this.strings, this.readOnly = false});
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
            children: [
              Container(width: 4, height: 40, color: color),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _side(match.player1Name,
                        match.winnerId == match.player1Id),
                    const SizedBox(height: 4),
                    _side(match.player2Name,
                        match.winnerId == match.player2Id),
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
            name ?? strings.t('common.tbd'),
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
  const _Standings({required this.matches, required this.strings});
  final List<GameMatch> matches;
  final AppStrings strings;

  @override
  Widget build(BuildContext context) {
    final rows = computeStandings(matches);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(strings.t('standings.title'),
                style: const TextStyle(
                    fontSize: 16, fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(child: Text(strings.t('standings.player'), style: _h)),
                _cell(strings.t('standings.w'), header: true),
                _cell(strings.t('standings.l'), header: true),
                _cell(strings.t('standings.pts'), header: true),
              ],
            ),
            const Divider(),
            ...rows.map((r) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      Expanded(
                          child: Text(r.name,
                              maxLines: 1, overflow: TextOverflow.ellipsis)),
                      _cell('${r.wins}', bold: true),
                      _cell('${r.losses}', muted: true),
                      _cell('${r.points}', bold: true),
                    ],
                  ),
                )),
          ],
        ),
      ),
    );
  }

  Widget _cell(String text,
          {bool header = false, bool bold = false, bool muted = false}) =>
      SizedBox(
        width: 36,
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: header
              ? _h
              : TextStyle(
                  fontWeight: bold ? FontWeight.w800 : FontWeight.w500,
                  color: muted ? Colors.white54 : Colors.white),
        ),
      );

  static const _h = TextStyle(
      color: Colors.white54, fontWeight: FontWeight.w700, fontSize: 12);
}
