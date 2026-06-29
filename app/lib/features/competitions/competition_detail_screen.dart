import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/formatters.dart';
import '../../core/theme.dart';
import '../../shared/models/competition.dart';
import '../../shared/widgets/brand.dart';
import '../payments/qris_checkout_screen.dart';
import 'competitions_controller.dart';

class CompetitionDetailScreen extends ConsumerWidget {
  const CompetitionDetailScreen({super.key, required this.competitionId});

  final String competitionId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final comps = ref.watch(competitionsControllerProvider);
    return comps.when(
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, _) => Scaffold(
        appBar: AppBar(),
        body: EmptyState(title: 'Could not load', subtitle: '$e'),
      ),
      data: (list) {
        Competition? c;
        for (final item in list) {
          if (item.id == competitionId) c = item;
        }
        if (c == null) {
          return Scaffold(
            appBar: AppBar(),
            body: const EmptyState(title: 'Competition not found'),
          );
        }
        return _DetailView(competition: c);
      },
    );
  }
}

class _DetailView extends StatelessWidget {
  const _DetailView({required this.competition});
  final Competition competition;

  @override
  Widget build(BuildContext context) {
    final c = competition;
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 200,
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              background: (c.bannerUrl != null && c.bannerUrl!.isNotEmpty)
                  ? CachedNetworkImage(
                      imageUrl: c.bannerUrl!,
                      fit: BoxFit.cover,
                      errorWidget: (_, __, ___) => const _GradientHeader(),
                    )
                  : const _GradientHeader(),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
            sliver: SliverList.list(
              children: [
                Text(c.title,
                    style: const TextStyle(
                        fontSize: 24, fontWeight: FontWeight.w900)),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    TagPill(c.format.label, icon: Icons.account_tree),
                    TagPill(c.status.label, color: AppColors.gold),
                    TagPill('${c.participantCount}/${c.maxParticipants} players',
                        icon: Icons.group, color: AppColors.cyan),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: _StatBox(
                        label: 'Entry fee',
                        value: Format.rupiah(c.entryFee),
                        color: c.entryFee == 0 ? AppColors.success : Colors.white,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _StatBox(
                        label: 'Prize pool',
                        value: c.prizePool > 0
                            ? Format.rupiah(c.prizePool)
                            : '—',
                        color: AppColors.gold,
                      ),
                    ),
                  ],
                ),
                if (c.startsAt != null) ...[
                  const SizedBox(height: 12),
                  _InfoRow(
                    icon: Icons.event,
                    label: 'Starts',
                    value: Format.dateTime(c.startsAt!),
                  ),
                ],
                if (c.techMeetingUrl != null &&
                    c.techMeetingUrl!.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  _InfoRow(
                    icon: Icons.forum_outlined,
                    label: '${c.techMeetingType.label} meeting',
                    value: c.techMeetingUrl!,
                  ),
                ],
                const SizedBox(height: 12),
                _ShareRow(url: c.shareUrl),
                const SizedBox(height: 20),
                const Text('About',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                const SizedBox(height: 8),
                Text(
                  c.description.isEmpty
                      ? 'No description provided.'
                      : c.description,
                  style: const TextStyle(color: Colors.white70, height: 1.5),
                ),
              ],
            ),
          ),
        ],
      ),
      bottomSheet: _RegisterBar(competition: c),
    );
  }
}

class _RegisterBar extends StatelessWidget {
  const _RegisterBar({required this.competition});
  final Competition competition;

  @override
  Widget build(BuildContext context) {
    final c = competition;
    final disabled = c.isFull || c.status != CompetitionStatus.open;
    return Container(
      padding: EdgeInsets.fromLTRB(
          16, 12, 16, 12 + MediaQuery.of(context).padding.bottom),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: Colors.white.withValues(alpha: 0.06))),
      ),
      child: Row(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Entry', style: TextStyle(color: Colors.white54)),
              Text(Format.rupiah(c.entryFee),
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.w800)),
            ],
          ),
          const SizedBox(width: 16),
          Expanded(
            child: FilledButton.icon(
              onPressed: disabled
                  ? null
                  : () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) =>
                              QrisCheckoutScreen(competition: c),
                        ),
                      ),
              icon: const Icon(Icons.qr_code_2),
              label: Text(disabled
                  ? (c.isFull ? 'Full' : 'Closed')
                  : (c.entryFee == 0 ? 'Join free' : 'Register & pay')),
            ),
          ),
        ],
      ),
    );
  }
}

class _GradientHeader extends StatelessWidget {
  const _GradientHeader();
  @override
  Widget build(BuildContext context) => Container(
        decoration: const BoxDecoration(gradient: AppColors.brand),
        child: const Center(
          child: Icon(Icons.emoji_events, color: Colors.white24, size: 64),
        ),
      );
}

class _StatBox extends StatelessWidget {
  const _StatBox(
      {required this.label, required this.value, this.color = Colors.white});
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(color: Colors.white54)),
          const SizedBox(height: 4),
          Text(value,
              style: TextStyle(
                  fontSize: 18, fontWeight: FontWeight.w800, color: color)),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow(
      {required this.icon, required this.label, required this.value});
  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: AppColors.cyan),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(color: Colors.white54)),
              Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      ],
    );
  }
}

class _ShareRow extends StatelessWidget {
  const _ShareRow({required this.url});
  final String url;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 10, 6, 10),
      decoration: BoxDecoration(
        color: AppColors.surfaceHigh,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Icon(Icons.link, size: 18, color: Colors.white54),
          const SizedBox(width: 8),
          Expanded(
            child: Text(url,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Colors.white70)),
          ),
          IconButton(
            icon: const Icon(Icons.copy, size: 18),
            tooltip: 'Copy share link',
            onPressed: () {
              Clipboard.setData(ClipboardData(text: url));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Share link copied')),
              );
            },
          ),
        ],
      ),
    );
  }
}
