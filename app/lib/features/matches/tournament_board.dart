import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/i18n.dart';
import '../../core/theme.dart';
import '../../shared/models/competition.dart';
import '../../shared/models/match.dart';
import '../../shared/widgets/brand.dart';
import 'bracket_view.dart';
import 'matches_controller.dart';
import 'standings.dart';

/// Tournament results with a **List / Bracket** toggle. "List" is the existing
/// card + standings view ([BracketView]); "Bracket" is the visual
/// connector-line tree / round-robin table ([TournamentBoard]). Defaults to
/// List so the familiar view is what loads first.
class TournamentSection extends ConsumerStatefulWidget {
  const TournamentSection(
      {super.key, required this.competition, this.readOnly = false});
  final Competition competition;
  final bool readOnly;

  @override
  ConsumerState<TournamentSection> createState() => _TournamentSectionState();
}

class _TournamentSectionState extends ConsumerState<TournamentSection> {
  bool _bracket = false;

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(stringsProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: SegmentedButton<bool>(
            segments: [
              ButtonSegment(
                  value: false,
                  label: Text(s.t('board.list')),
                  icon: const Icon(Icons.view_list, size: 18)),
              ButtonSegment(
                  value: true,
                  label: Text(s.t('board.bracket')),
                  icon: const Icon(Icons.account_tree, size: 18)),
            ],
            selected: {_bracket},
            onSelectionChanged: (v) => setState(() => _bracket = v.first),
          ),
        ),
        const SizedBox(height: 12),
        _bracket
            ? TournamentBoard(
                competition: widget.competition, readOnly: widget.readOnly)
            : BracketView(
                competition: widget.competition, readOnly: widget.readOnly),
      ],
    );
  }
}

/// The "Bracket" view of a tournament: a connector-line elimination tree and,
/// for round-robin, a standings table + head-to-head grid. Companion to the
/// card-based [BracketView] ("List" view) — both read from `matchesProvider`.
class TournamentBoard extends ConsumerWidget {
  const TournamentBoard(
      {super.key, required this.competition, this.readOnly = false});
  final Competition competition;
  final bool readOnly;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    ref.watch(liveMatchesProvider(competition.id)); // live updates (backend)
    final async = ref.watch(matchesProvider(competition.id));
    return async.when(
      loading: () => const Center(child: CircularProgressIndicator()),
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
        final groupMatches = matches.where((m) => m.stage == 'group').toList();
        final elimMatches = matches.where((m) => m.stage == 'elim').toList();
        final children = <Widget>[];

        if (groupMatches.isNotEmpty) {
          final byGroup = <int, List<GameMatch>>{};
          for (final m in groupMatches) {
            byGroup.putIfAbsent(m.group, () => []).add(m);
          }
          final keys = byGroup.keys.toList()..sort();
          final multi = keys.length > 1;
          for (final g in keys) {
            if (multi) {
              children.add(_sectionLabel(
                  '${s.t('bracket.group')} ${String.fromCharCode(65 + g)}',
                  AppColors.cyan));
            }
            children.add(_StandingsTable(matches: byGroup[g]!, strings: s));
            children.add(const SizedBox(height: 10));
            children.add(_HeadToHead(matches: byGroup[g]!, strings: s));
            children.add(const SizedBox(height: 20));
          }
        }

        if (elimMatches.isNotEmpty) {
          if (groupMatches.isNotEmpty) {
            children.add(_sectionLabel(s.t('bracket.playoffs'), AppColors.gold));
          }
          children.add(_BracketTree(
              matches: elimMatches, strings: s, readOnly: readOnly));
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: children,
        );
      },
    );
  }

  Widget _sectionLabel(String text, Color color) => Padding(
        padding: const EdgeInsets.only(top: 6, bottom: 8),
        child: Text(text,
            style: TextStyle(
                fontWeight: FontWeight.w900, fontSize: 16, color: color)),
      );
}

// ── Elimination tree with connector lines ─────────────────────────
class _BracketTree extends StatelessWidget {
  const _BracketTree(
      {required this.matches, required this.strings, required this.readOnly});
  final List<GameMatch> matches;
  final AppStrings strings;
  final bool readOnly;

  static const double _cellW = 168;
  static const double _cellH = 58;
  static const double _hGap = 40;
  static const double _vGap = 18;

  @override
  Widget build(BuildContext context) {
    // Group by round; sort cells within a round by bracket position.
    final byRound = <int, List<GameMatch>>{};
    for (final m in matches) {
      byRound.putIfAbsent(m.round, () => []).add(m);
    }
    final rounds = byRound.keys.toList()..sort();
    for (final r in rounds) {
      byRound[r]!.sort((a, b) => a.position - b.position);
    }

    // Vertical centre of every cell: round 0 evenly stacked, later rounds sit
    // at the midpoint of their two feeder cells.
    final centers = <int, List<double>>{};
    final unit = _cellH + _vGap;
    for (var ri = 0; ri < rounds.length; ri++) {
      final r = rounds[ri];
      final count = byRound[r]!.length;
      if (ri == 0) {
        centers[r] = [for (var i = 0; i < count; i++) i * unit + _cellH / 2];
      } else {
        final prev = centers[rounds[ri - 1]]!;
        final list = <double>[];
        for (var i = 0; i < count; i++) {
          final i1 = 2 * i < prev.length ? 2 * i : prev.length - 1;
          final i2 = 2 * i + 1 < prev.length ? 2 * i + 1 : prev.length - 1;
          list.add((prev[i1] + prev[i2]) / 2);
        }
        centers[r] = list;
      }
    }

    final firstCount = byRound[rounds.first]!.length;
    final totalHeight = firstCount * unit;
    final totalWidth = rounds.length * (_cellW + _hGap);

    final positioned = <Widget>[
      Positioned.fill(
        child: CustomPaint(
          painter: _ConnectorPainter(
            rounds: rounds,
            counts: {for (final r in rounds) r: byRound[r]!.length},
            centers: centers,
            cellW: _cellW,
            hGap: _hGap,
          ),
        ),
      ),
    ];
    for (var ri = 0; ri < rounds.length; ri++) {
      final r = rounds[ri];
      final cells = byRound[r]!;
      for (var i = 0; i < cells.length; i++) {
        positioned.add(Positioned(
          left: ri * (_cellW + _hGap),
          top: centers[r]![i] - _cellH / 2,
          width: _cellW,
          height: _cellH,
          child: _TreeCell(
              match: cells[i], strings: strings, readOnly: readOnly),
        ));
      }
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: SizedBox(
        width: totalWidth,
        height: totalHeight,
        child: Stack(children: positioned),
      ),
    );
  }
}

class _ConnectorPainter extends CustomPainter {
  _ConnectorPainter({
    required this.rounds,
    required this.counts,
    required this.centers,
    required this.cellW,
    required this.hGap,
  });
  final List<int> rounds;
  final Map<int, int> counts;
  final Map<int, List<double>> centers;
  final double cellW;
  final double hGap;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white24
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    for (var ri = 1; ri < rounds.length; ri++) {
      final r = rounds[ri];
      final prev = rounds[ri - 1];
      final childCount = counts[r]!;
      final prevRight = (ri - 1) * (cellW + hGap) + cellW;
      final childLeft = ri * (cellW + hGap);
      final midX = prevRight + hGap / 2;

      final prevCenters = centers[prev]!;
      for (var i = 0; i < childCount; i++) {
        final cy = centers[r]![i];
        final f1 = 2 * i < prevCenters.length ? 2 * i : prevCenters.length - 1;
        final f2 = 2 * i + 1 < prevCenters.length
            ? 2 * i + 1
            : prevCenters.length - 1;
        final y1 = prevCenters[f1];
        final y2 = prevCenters[f2];
        // feeders → vertical bus
        canvas.drawLine(Offset(prevRight, y1), Offset(midX, y1), paint);
        canvas.drawLine(Offset(prevRight, y2), Offset(midX, y2), paint);
        canvas.drawLine(Offset(midX, y1), Offset(midX, y2), paint);
        // bus → child
        canvas.drawLine(Offset(midX, cy), Offset(childLeft, cy), paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _ConnectorPainter old) =>
      old.centers != centers || old.rounds != rounds;
}

class _TreeCell extends StatelessWidget {
  const _TreeCell(
      {required this.match, required this.strings, required this.readOnly});
  final GameMatch match;
  final AppStrings strings;
  final bool readOnly;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: InkWell(
        onTap: readOnly ? null : () => context.push('/match/${match.id}'),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _row(match.player1Name, match.winnerId == match.player1Id),
              const Divider(height: 8),
              _row(match.player2Name, match.winnerId == match.player2Id),
            ],
          ),
        ),
      ),
    );
  }

  Widget _row(String? name, bool isWinner) => Row(
        children: [
          Expanded(
            child: Text(
              name ?? strings.t('common.tbd'),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 13,
                fontWeight: isWinner ? FontWeight.w800 : FontWeight.w500,
                color: isWinner ? Colors.white : Colors.white60,
              ),
            ),
          ),
          if (isWinner)
            const Icon(Icons.emoji_events, size: 13, color: AppColors.gold),
        ],
      );
}

// ── Round-robin standings table ───────────────────────────────────
class _StandingsTable extends StatelessWidget {
  const _StandingsTable({required this.matches, required this.strings});
  final List<GameMatch> matches;
  final AppStrings strings;

  @override
  Widget build(BuildContext context) {
    final rows = computeStandings(matches);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Row(children: [
              SizedBox(
                  width: 24,
                  child: Text('#', style: _h, textAlign: TextAlign.center)),
              Expanded(child: Text(strings.t('standings.player'), style: _h)),
              _cell(strings.t('standings.w'), head: true),
              _cell(strings.t('standings.l'), head: true),
              _cell(strings.t('standings.pts'), head: true),
            ]),
            const Divider(),
            for (var i = 0; i < rows.length; i++)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 5),
                child: Row(children: [
                  SizedBox(
                      width: 24,
                      child: Text('${i + 1}',
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.white38))),
                  Expanded(
                      child: Text(rows[i].name,
                          maxLines: 1, overflow: TextOverflow.ellipsis)),
                  _cell('${rows[i].wins}', bold: true),
                  _cell('${rows[i].losses}', muted: true),
                  _cell('${rows[i].points}', bold: true),
                ]),
              ),
          ],
        ),
      ),
    );
  }

  Widget _cell(String t,
          {bool head = false, bool bold = false, bool muted = false}) =>
      SizedBox(
        width: 34,
        child: Text(t,
            textAlign: TextAlign.center,
            style: head
                ? _h
                : TextStyle(
                    fontWeight: bold ? FontWeight.w800 : FontWeight.w500,
                    color: muted ? Colors.white54 : Colors.white)),
      );

  static const _h = TextStyle(
      color: Colors.white54, fontWeight: FontWeight.w700, fontSize: 12);
}

// ── Head-to-head grid (who beat whom) ─────────────────────────────
class _HeadToHead extends StatelessWidget {
  const _HeadToHead({required this.matches, required this.strings});
  final List<GameMatch> matches;
  final AppStrings strings;

  @override
  Widget build(BuildContext context) {
    // Ordered players (by standings) + result lookup.
    final order = computeStandings(matches);
    if (order.length < 2) return const SizedBox.shrink();
    final ids = [for (final r in order) r.playerId];
    final label = {for (final r in order) r.playerId: _initials(r.name)};
    // result[a][b] = 'W' if a beat b, 'L' if a lost to b.
    final res = <String, Map<String, String>>{};
    for (final m in matches) {
      if (m.status != MatchStatus.completed || m.winnerId == null) continue;
      final a = m.player1Id, b = m.player2Id;
      if (a == null || b == null) continue;
      final aWon = m.winnerId == a;
      (res[a] ??= {})[b] = aWon ? 'W' : 'L';
      (res[b] ??= {})[a] = aWon ? 'L' : 'W';
    }

    Widget head(String t) => Container(
          width: 34,
          height: 30,
          alignment: Alignment.center,
          child: Text(t,
              style: const TextStyle(
                  fontSize: 11,
                  color: Colors.white54,
                  fontWeight: FontWeight.w700)),
        );

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(strings.t('board.headToHead'),
                style: const TextStyle(
                    fontWeight: FontWeight.w800, fontSize: 13)),
            const SizedBox(height: 8),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Column(
                children: [
                  Row(children: [
                    const SizedBox(width: 90),
                    for (final id in ids) head(label[id]!),
                  ]),
                  for (final a in ids)
                    Row(children: [
                      SizedBox(
                        width: 90,
                        child: Text(label[a]!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontSize: 12, fontWeight: FontWeight.w600)),
                      ),
                      for (final b in ids)
                        _resCell(a == b ? null : res[a]?[b]),
                    ]),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _resCell(String? r) {
    final (bg, fg, text) = switch (r) {
      'W' => (AppColors.success.withValues(alpha: 0.25), AppColors.success, 'W'),
      'L' => (AppColors.danger.withValues(alpha: 0.20), AppColors.danger, 'L'),
      _ => (Colors.transparent, Colors.white24, r == null ? '·' : '–'),
    };
    return Container(
      width: 34,
      height: 30,
      margin: const EdgeInsets.all(1),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(text,
          style: TextStyle(
              fontSize: 12, fontWeight: FontWeight.w800, color: fg)),
    );
  }

  String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.length == 1) {
      return parts.first.length <= 4
          ? parts.first
          : parts.first.substring(0, 4);
    }
    return (parts[0].isNotEmpty ? parts[0][0] : '') +
        (parts[1].isNotEmpty ? parts[1][0] : '');
  }
}
