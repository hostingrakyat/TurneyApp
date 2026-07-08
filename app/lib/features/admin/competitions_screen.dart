import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/formatters.dart';
import '../../core/i18n.dart';
import '../../core/theme.dart';
import '../../shared/models/competition.dart';
import '../../shared/widgets/animate.dart';
import '../../shared/widgets/app_loader.dart';
import '../../shared/widgets/brand.dart';
import '../competitions/competitions_controller.dart';

/// Admin moderation of every competition on the platform: open it, cancel &
/// refund, or delete it outright. Organizers only see their own — this is the
/// platform-wide view.
class AdminCompetitionsScreen extends ConsumerWidget {
  const AdminCompetitionsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    final comps = ref.watch(competitionsControllerProvider);
    return Scaffold(
      appBar: AppBar(title: Text(s.t('mod.title'))),
      body: RefreshIndicator(
        onRefresh: () async =>
            ref.invalidate(competitionsControllerProvider),
        child: comps.when(
          loading: () => const AppLoading(),
          error: (e, _) =>
              EmptyState(title: s.t('detail.loadError'), subtitle: '$e'),
          data: (list) {
            if (list.isEmpty) {
              return ListView(children: [
                const SizedBox(height: 80),
                EmptyState(
                  title: s.t('mod.empty'),
                  icon: Icons.emoji_events_outlined,
                ),
              ]);
            }
            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                for (final (i, c) in list.indexed)
                  FadeSlideIn(
                      delay: stagger(i), child: _ModCard(competition: c)),
              ],
            );
          },
        ),
      ),
    );
  }
}

Color _statusColor(CompetitionStatus st) => switch (st) {
      CompetitionStatus.open => AppColors.success,
      CompetitionStatus.ongoing => AppColors.gold,
      CompetitionStatus.completed => AppColors.cyan,
      CompetitionStatus.cancelled => AppColors.danger,
      CompetitionStatus.draft => Colors.white38,
    };

class _ModCard extends ConsumerStatefulWidget {
  const _ModCard({required this.competition});
  final Competition competition;
  @override
  ConsumerState<_ModCard> createState() => _ModCardState();
}

class _ModCardState extends ConsumerState<_ModCard> {
  bool _busy = false;

  Future<void> _cancel() async {
    final s = ref.read(stringsProvider);
    final ok = await _confirm(
        s.t('mod.cancelTitle'), s.t('mod.cancelBody'), s.t('mod.cancel'));
    if (ok != true) return;
    setState(() => _busy = true);
    try {
      await ref
          .read(competitionsControllerProvider.notifier)
          .adminCancel(widget.competition.id);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _delete() async {
    final s = ref.read(stringsProvider);
    final ok = await _confirm(
        s.t('mod.deleteTitle'), s.t('mod.deleteBody'), s.t('mod.delete'),
        danger: true);
    if (ok != true) return;
    setState(() => _busy = true);
    try {
      await ref
          .read(competitionsControllerProvider.notifier)
          .adminDelete(widget.competition.id);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<bool?> _confirm(String title, String body, String action,
      {bool danger = false}) {
    final s = ref.read(stringsProvider);
    return showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(title),
        content: Text(body),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(s.t('common.cancel'))),
          FilledButton(
            style: danger
                ? FilledButton.styleFrom(backgroundColor: AppColors.danger)
                : null,
            onPressed: () => Navigator.pop(context, true),
            child: Text(action),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(stringsProvider);
    final c = widget.competition;
    final done = c.status == CompetitionStatus.completed ||
        c.status == CompetitionStatus.cancelled;
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(c.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontWeight: FontWeight.w800, fontSize: 15)),
                ),
                const SizedBox(width: 8),
                TagPill(c.status.label, color: _statusColor(c.status)),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                const Icon(Icons.group, size: 14, color: Colors.white38),
                const SizedBox(width: 6),
                Text('${c.participantCount}/${c.maxParticipants}',
                    style:
                        const TextStyle(color: Colors.white54, fontSize: 12)),
                const SizedBox(width: 14),
                const Icon(Icons.payments, size: 14, color: Colors.white38),
                const SizedBox(width: 6),
                Text(Format.rupiah(c.entryFee),
                    style:
                        const TextStyle(color: Colors.white54, fontSize: 12)),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () =>
                        context.push('/competition/${c.id}/manage'),
                    icon: const Icon(Icons.settings, size: 16),
                    label: Text(s.t('mod.manage')),
                  ),
                ),
                const SizedBox(width: 8),
                if (!done)
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _busy ? null : _cancel,
                      style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.gold),
                      icon: const Icon(Icons.cancel_outlined, size: 16),
                      label: Text(s.t('mod.cancel')),
                    ),
                  ),
                if (!done) const SizedBox(width: 8),
                IconButton(
                  onPressed: _busy ? null : _delete,
                  tooltip: s.t('mod.delete'),
                  icon: const Icon(Icons.delete_outline,
                      color: AppColors.danger),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
