import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/env.dart';
import '../../core/theme.dart';
import '../../shared/models/competition.dart';
import '../../shared/widgets/brand.dart';
import '../auth/auth_controller.dart';
import '../competitions/competitions_controller.dart';
import '../matches/bracket_view.dart';
import '../matches/matches_controller.dart';

class ManageCompetitionScreen extends ConsumerWidget {
  const ManageCompetitionScreen({super.key, required this.competitionId});
  final String competitionId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final comps = ref.watch(competitionsControllerProvider).valueOrNull ??
        const <Competition>[];
    Competition? comp;
    for (final c in comps) {
      if (c.id == competitionId) comp = c;
    }
    if (comp == null) {
      return const Scaffold(body: EmptyState(title: 'Competition not found'));
    }
    final competition = comp;
    final matches = ref.watch(matchesProvider(competitionId));
    final hasBracket = (matches.valueOrNull ?? const []).isNotEmpty;

    return Scaffold(
      appBar: AppBar(title: const Text('Manage')),
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
              TagPill('${competition.participantCount} registered',
                  icon: Icons.group, color: AppColors.cyan),
              const SizedBox(width: 8),
              TagPill(competition.status.label, color: AppColors.gold),
            ],
          ),
          const SizedBox(height: 20),
          if (!hasBracket)
            _GenerateCard(competition: competition)
          else ...[
            const Text('Bracket',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            const _Hint(
                'Tap a match to view streams, reports, or resolve it. Results '
                'auto-confirm 5 minutes after a report (or use Resolve now).'),
            const SizedBox(height: 8),
            BracketView(competition: competition),
          ],
        ],
      ),
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
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Close registration & start',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
            const SizedBox(height: 6),
            Text(
              'Generates the ${widget.competition.format.label} bracket from the '
              'paid participants. The 5-minute auto-resolve window is '
              '${Env.matchAutoResolveMinutes} min.',
              style: const TextStyle(color: Colors.white70),
            ),
            const SizedBox(height: 8),
            const _Hint(
                'Demo mode pads with practice opponents so you can play through '
                'a full bracket on your own.'),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _busy ? null : _generate,
              icon: _busy
                  ? const SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.account_tree),
              label: const Text('Generate bracket'),
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
