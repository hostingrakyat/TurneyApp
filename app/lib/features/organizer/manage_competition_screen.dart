import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/demo_store.dart';
import '../../core/demo_store_provider.dart';
import '../../core/env.dart';
import '../../core/i18n.dart';
import '../../core/supabase.dart';
import '../../core/theme.dart';
import '../../shared/models/competition.dart';
import '../../shared/models/match.dart';
import '../../shared/widgets/brand.dart';
import '../auth/auth_controller.dart';
import '../competitions/competitions_controller.dart';
import '../matches/bracket_view.dart';
import '../matches/matches_controller.dart';

final participantsProvider =
    FutureProvider.family<List<ParticipantContact>, String>((ref, compId) async {
  final client = ref.watch(supabaseClientProvider);
  if (client == null) {
    return ref.watch(demoStoreProvider).participantsFor(compId);
  }
  final regs = await client
      .from('registrations')
      .select('user_id, phone')
      .eq('competition_id', compId)
      .eq('status', 'paid');
  final ids = regs.map((r) => r['user_id'] as String).toList();
  final profs = ids.isEmpty
      ? const []
      : await client
          .from('profiles')
          .select('id, display_name')
          .inFilter('id', ids);
  final names = {
    for (final p in profs)
      p['id'] as String: (p['display_name'] ?? 'Player') as String
  };
  return regs
      .map((r) => ParticipantContact(
            r['user_id'] as String,
            names[r['user_id']] ?? 'Player',
            r['phone'] as String?,
          ))
      .toList();
});

class ManageCompetitionScreen extends ConsumerWidget {
  const ManageCompetitionScreen({super.key, required this.competitionId});
  final String competitionId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    final comps = ref.watch(competitionsControllerProvider).valueOrNull ??
        const <Competition>[];
    Competition? comp;
    for (final c in comps) {
      if (c.id == competitionId) comp = c;
    }
    if (comp == null) {
      return Scaffold(body: EmptyState(title: s.t('common.notFound')));
    }
    final competition = comp;
    final matches = ref.watch(matchesProvider(competitionId));
    final hasBracket = (matches.valueOrNull ?? const []).isNotEmpty;

    return Scaffold(
      appBar: AppBar(title: Text(s.t('manage.title'))),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(competition.title,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
          const SizedBox(height: 4),
          Row(
            children: [
              TagPill(competition.format.label, icon: Icons.account_tree),
              const SizedBox(width: 8),
              TagPill(
                  s
                      .t('manage.registered')
                      .replaceFirst('{n}', '${competition.participantCount}'),
                  icon: Icons.group,
                  color: AppColors.cyan),
              const SizedBox(width: 8),
              TagPill(competition.status.label, color: AppColors.gold),
            ],
          ),
          const SizedBox(height: 20),
          if (!hasBracket)
            _GenerateCard(competition: competition)
          else ...[
            Text(s.t('manage.bracket'),
                style: const TextStyle(
                    fontSize: 18, fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            _Hint(s.t('manage.bracketHint')),
            const SizedBox(height: 8),
            BracketView(competition: competition),
            if (competition.format == CompetitionFormat.roundRobin &&
                competition.hasPlayoff) ...[
              const SizedBox(height: 16),
              _PlayoffCard(competition: competition),
            ],
          ],
          const SizedBox(height: 24),
          _ParticipantsSection(competitionId: competitionId),
          const SizedBox(height: 24),
          if (competition.status != CompetitionStatus.completed &&
              competition.status != CompetitionStatus.cancelled)
            _CancelButton(competition: competition),
        ],
      ),
    );
  }
}

class _ParticipantsSection extends ConsumerWidget {
  const _ParticipantsSection({required this.competitionId});
  final String competitionId;

  Future<void> _whatsApp(
      BuildContext context, WidgetRef ref, String? phone) async {
    if (phone == null || phone.trim().isEmpty) return;
    final digits = phone.replaceAll(RegExp(r'[^0-9]'), '');
    final ok = await launchUrl(Uri.parse('https://wa.me/$digits'),
        mode: LaunchMode.externalApplication);
    if (!ok && context.mounted) {
      final s = ref.read(stringsProvider);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(s.t('manage.waOpenError'))));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    final participants = ref.watch(participantsProvider(competitionId));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(s.t('manage.participants'),
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
        const SizedBox(height: 4),
        _Hint(s.t('manage.participantsHint')),
        const SizedBox(height: 8),
        participants.when(
          loading: () => const LinearProgressIndicator(),
          error: (e, _) => Text('$e'),
          data: (list) => list.isEmpty
              ? _Hint(s.t('manage.noParticipants'))
              : Column(
                  children: [
                    for (final p in list)
                      Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor:
                                AppColors.violet.withValues(alpha: 0.2),
                            child: Text(
                                p.name.isNotEmpty
                                    ? p.name[0].toUpperCase()
                                    : '?',
                                style: const TextStyle(
                                    fontWeight: FontWeight.w800)),
                          ),
                          title: Text(p.name,
                              style:
                                  const TextStyle(fontWeight: FontWeight.w700)),
                          subtitle: Text(p.phone?.isNotEmpty == true
                              ? p.phone!
                              : s.t('manage.noPhone')),
                          trailing: p.phone?.isNotEmpty == true
                              ? Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      tooltip: 'WhatsApp',
                                      icon: const Icon(Icons.chat,
                                          color: AppColors.success),
                                      onPressed: () =>
                                          _whatsApp(context, ref, p.phone),
                                    ),
                                    IconButton(
                                      tooltip: 'Copy',
                                      icon: const Icon(Icons.copy, size: 18),
                                      onPressed: () {
                                        Clipboard.setData(
                                            ClipboardData(text: p.phone!));
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(SnackBar(
                                                content: Text(s
                                                    .t('manage.numberCopied'))));
                                      },
                                    ),
                                  ],
                                )
                              : null,
                        ),
                      ),
                  ],
                ),
        ),
      ],
    );
  }
}

class _CancelButton extends ConsumerWidget {
  const _CancelButton({required this.competition});
  final Competition competition;

  Future<void> _cancel(BuildContext context, WidgetRef ref) async {
    final s = ref.read(stringsProvider);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(s.t('manage.cancelTitle')),
        content: Text(s.t('manage.cancelBody')),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(s.t('manage.keep'))),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(s.t('manage.cancelIt'))),
        ],
      ),
    );
    if (confirmed != true) return;

    final client = ref.read(supabaseClientProvider);
    if (client == null) {
      ref.read(demoStoreProvider).cancelCompetition(competition.id);
    } else {
      await client.from('registrations').update({'status': 'refunded'}).eq(
          'competition_id', competition.id);
      await client
          .from('competitions')
          .update({'status': 'cancelled'}).eq('id', competition.id);
      ref.invalidate(competitionsControllerProvider);
      ref.invalidate(matchesProvider(competition.id));
    }
    if (context.mounted) Navigator.of(context).maybePop();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    return OutlinedButton.icon(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size.fromHeight(50),
        foregroundColor: AppColors.danger,
        side: const BorderSide(color: AppColors.danger),
      ),
      onPressed: () => _cancel(context, ref),
      icon: const Icon(Icons.cancel_outlined),
      label: Text(s.t('manage.cancelButton')),
    );
  }
}

class _GenerateCard extends ConsumerStatefulWidget {
  const _GenerateCard({required this.competition});
  final Competition competition;

  @override
  ConsumerState<_GenerateCard> createState() => _GenerateCardState();
}

class _GenerateCardState extends ConsumerState<_GenerateCard> {
  bool _busy = false;

  Future<void> _generate() async {
    final user = ref.read(authControllerProvider);
    if (user == null) return;
    setState(() => _busy = true);
    try {
      await ref
          .read(matchesServiceProvider)
          .generateBracket(widget.competition, user.id);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('$e')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(stringsProvider);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(s.t('manage.closeStart'),
                style: const TextStyle(
                    fontSize: 18, fontWeight: FontWeight.w800)),
            const SizedBox(height: 6),
            Text(
              s
                  .t('manage.generateInfo')
                  .replaceFirst('{fmt}', widget.competition.format.label)
                  .replaceFirst('{min}', '${Env.matchAutoResolveMinutes}'),
              style: const TextStyle(color: Colors.white70),
            ),
            const SizedBox(height: 8),
            _Hint(s.t('manage.demoPad')),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _busy ? null : _generate,
              icon: _busy
                  ? const SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.account_tree),
              label: Text(s.t('manage.generateBracket')),
            ),
          ],
        ),
      ),
    );
  }
}

class _PlayoffCard extends ConsumerStatefulWidget {
  const _PlayoffCard({required this.competition});
  final Competition competition;

  @override
  ConsumerState<_PlayoffCard> createState() => _PlayoffCardState();
}

class _PlayoffCardState extends ConsumerState<_PlayoffCard> {
  bool _busy = false;

  Future<void> _generate() async {
    setState(() => _busy = true);
    try {
      await ref
          .read(matchesServiceProvider)
          .generatePlayoffs(widget.competition);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('$e')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(stringsProvider);
    final matches =
        ref.watch(matchesProvider(widget.competition.id)).valueOrNull ??
            const <GameMatch>[];
    final groupMatches = matches.where((m) => m.stage == 'group').toList();
    final elimExists = matches.any((m) => m.stage == 'elim');
    final groupComplete = groupMatches.isNotEmpty &&
        groupMatches.every((m) => m.status == MatchStatus.completed);
    final canGenerate = groupComplete && !elimExists;

    return Card(
      color: AppColors.surfaceHigh,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.emoji_events, color: AppColors.gold),
                const SizedBox(width: 8),
                Text(s.t('manage.playoffsTitle'),
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.w800)),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              elimExists
                  ? s.t('manage.playoffsLive').replaceFirst(
                      '{n}', '${widget.competition.advancePerGroup}')
                  : groupComplete
                      ? s.t('manage.playoffsReady')
                      : s.t('manage.playoffsLocked'),
              style: const TextStyle(color: Colors.white70),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: (canGenerate && !_busy) ? _generate : null,
              icon: _busy
                  ? const SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.account_tree),
              label: Text(elimExists
                  ? s.t('manage.playoffsDone')
                  : s.t('manage.generatePlayoffs')),
            ),
          ],
        ),
      ),
    );
  }
}

class _Hint extends StatelessWidget {
  const _Hint(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline, size: 16, color: AppColors.cyan),
          const SizedBox(width: 8),
          Expanded(
            child: Text(text, style: const TextStyle(color: Colors.white54)),
          ),
        ],
      );
}
