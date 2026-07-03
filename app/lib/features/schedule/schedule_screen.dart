import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/calendar.dart';
import '../../core/demo_store_provider.dart';
import '../../core/formatters.dart';
import '../../core/i18n.dart';
import '../../core/supabase.dart';
import '../../core/theme.dart';
import '../../shared/models/competition.dart';
import '../../shared/models/match.dart';
import '../../shared/widgets/brand.dart';
import '../auth/auth_controller.dart';
import '../competitions/widgets/competition_card.dart';
import '../profile/my_registrations_screen.dart';

/// Every match the signed-in user is a participant in — 1v1 matches where
/// they're player1/player2 plus free-for-all lobbies where they're in the
/// jsonb roster.
final myMatchesProvider = FutureProvider<List<GameMatch>>((ref) async {
  final user = ref.watch(authControllerProvider);
  if (user == null) return const [];
  final client = ref.watch(supabaseClientProvider);
  if (client == null) {
    return ref.watch(demoStoreProvider).matchesForUser(user.id);
  }
  final duelRows = await client
      .from('matches')
      .select()
      .or('player1_id.eq.${user.id},player2_id.eq.${user.id}')
      .order('round');
  final ffaRows = await client
      .from('matches')
      .select()
      .contains('players', [
        {'id': user.id}
      ]).order('round');
  final byId = <String, GameMatch>{};
  for (final r in [...duelRows as List, ...ffaRows as List]) {
    final m = GameMatch.fromMap(r as Map<String, dynamic>);
    byId[m.id] = m;
  }
  return byId.values.toList()
    ..sort((a, b) =>
        a.round != b.round ? a.round - b.round : a.position - b.position);
});

/// The personal hub: matches ready to play, upcoming competitions (with
/// add-to-calendar), and recent results. Replaces the buried "My registrations".
class ScheduleScreen extends ConsumerWidget {
  const ScheduleScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    final comps = ref.watch(myRegistrationsProvider);
    final matches = ref.watch(myMatchesProvider);

    return Scaffold(
      appBar: AppBar(title: Text(s.t('schedule.title'))),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(myRegistrationsProvider);
          ref.invalidate(myMatchesProvider);
        },
        child: comps.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) =>
              EmptyState(title: s.t('detail.loadError'), subtitle: '$e'),
          data: (compList) {
            final matchList = matches.valueOrNull ?? const <GameMatch>[];
            final playNow = matchList
                .where((m) =>
                    m.winnerId == null &&
                    (m.bothPlayersPresent ||
                        (m.isFfa && m.players.length > 1)) &&
                    (m.status == MatchStatus.scheduled ||
                        m.status == MatchStatus.awaitingReports))
                .toList();
            final results = matchList
                .where((m) => m.status == MatchStatus.completed)
                .toList()
                .reversed
                .toList();
            final upcoming = compList
                .where((c) =>
                    c.status != CompetitionStatus.completed &&
                    c.status != CompetitionStatus.cancelled)
                .toList();

            if (playNow.isEmpty && upcoming.isEmpty && results.isEmpty) {
              return ListView(children: [
                const SizedBox(height: 80),
                EmptyState(
                  title: s.t('schedule.emptyTitle'),
                  subtitle: s.t('schedule.emptySub'),
                  icon: Icons.calendar_month_outlined,
                ),
              ]);
            }

            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (playNow.isNotEmpty) ...[
                  _Header(
                      title: s.t('schedule.playNow'),
                      subtitle: s.t('schedule.playNowSub')),
                  for (final m in playNow)
                    _MatchTile(match: m, uid: _uid(ref), strings: s),
                  const SizedBox(height: 20),
                ],
                if (upcoming.isNotEmpty) ...[
                  _Header(title: s.t('schedule.upcoming')),
                  for (final c in upcoming)
                    _UpcomingCard(competition: c, strings: s),
                  const SizedBox(height: 20),
                ],
                if (results.isNotEmpty) ...[
                  _Header(title: s.t('schedule.results')),
                  for (final m in results.take(20))
                    _ResultTile(match: m, strings: s),
                ],
              ],
            );
          },
        ),
      ),
    );
  }

  String _uid(WidgetRef ref) => ref.read(authControllerProvider)?.id ?? '';
}

class _Header extends StatelessWidget {
  const _Header({required this.title, this.subtitle});
  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style:
                  const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
          if (subtitle != null)
            Text(subtitle!, style: const TextStyle(color: Colors.white54)),
        ],
      ),
    );
  }
}

class _MatchTile extends StatelessWidget {
  const _MatchTile(
      {required this.match, required this.uid, required this.strings});
  final GameMatch match;
  final String uid;
  final AppStrings strings;

  @override
  Widget build(BuildContext context) {
    final String title;
    if (match.isFfa) {
      title = '${strings.t('ffa.lobby').replaceFirst('{n}', '${match.position + 1}')}'
          ' · ${strings.t('ffa.players').replaceFirst('{n}', '${match.players.length}')}';
    } else {
      final mine =
          match.player1Id == uid ? match.player1Name : match.player2Name;
      final opp =
          match.player1Id == uid ? match.player2Name : match.player1Name;
      title = '${mine ?? '?'}  ${strings.t('schedule.vs')}  ${opp ?? '?'}';
    }
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: AppColors.surfaceHigh,
          child: Icon(match.isFfa ? Icons.groups : Icons.sports_esports,
              color: AppColors.cyan, size: 20),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
        subtitle: Text(match.status.label),
        trailing: FilledButton(
          onPressed: () => context.push('/match/${match.id}'),
          child: Text(strings.t('schedule.play')),
        ),
      ),
    );
  }
}

class _ResultTile extends StatelessWidget {
  const _ResultTile({required this.match, required this.strings});
  final GameMatch match;
  final AppStrings strings;

  @override
  Widget build(BuildContext context) {
    final winner = match.winnerName ?? '—';
    final title = match.isFfa
        ? '${strings.t('ffa.lobby').replaceFirst('{n}', '${match.position + 1}')}'
            ' · ${strings.t('ffa.players').replaceFirst('{n}', '${match.players.length}')}'
        : '${match.player1Name ?? '?'}  ${strings.t('schedule.vs')}  '
            '${match.player2Name ?? '?'}';
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: const Icon(Icons.emoji_events, color: AppColors.gold),
        title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
        subtitle: Text(strings.t('schedule.wonBy').replaceFirst('{x}', winner)),
        trailing: const Icon(Icons.check_circle, color: AppColors.success),
        onTap: () => context.push('/match/${match.id}'),
      ),
    );
  }
}

class _UpcomingCard extends StatelessWidget {
  const _UpcomingCard({required this.competition, required this.strings});
  final Competition competition;
  final AppStrings strings;

  @override
  Widget build(BuildContext context) {
    final c = competition;
    return Column(
      children: [
        CompetitionCard(
          competition: c,
          onTap: () => context.push('/competition/${c.id}'),
        ),
        if (c.startsAt != null)
          Padding(
            padding: const EdgeInsets.only(top: 2, bottom: 10),
            child: Row(
              children: [
                const Icon(Icons.event, size: 16, color: Colors.white38),
                const SizedBox(width: 8),
                Expanded(child: Text(Format.dateTime(c.startsAt!))),
                TextButton.icon(
                  onPressed: () => openCalendar(
                    title: c.title,
                    start: c.startsAt!,
                    details: c.shareUrl,
                  ),
                  icon: const Icon(Icons.calendar_month, size: 18),
                  label: Text(strings.t('public.addToCalendar')),
                ),
              ],
            ),
          )
        else
          const SizedBox(height: 8),
      ],
    );
  }
}
