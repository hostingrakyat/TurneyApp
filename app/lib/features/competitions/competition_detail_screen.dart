import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../../shared/widgets/app_loader.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/app_settings.dart';
import '../../core/demo_store_provider.dart';
import '../../core/formatters.dart';
import '../../core/i18n.dart';
import '../../core/supabase.dart';
import '../../core/theme.dart';
import '../../shared/models/competition.dart';
import '../../shared/widgets/brand.dart';
import '../auth/auth_controller.dart';
import '../matches/tournament_board.dart';
import '../payments/qris_checkout_screen.dart';
import 'competitions_controller.dart';

class CompetitionDetailScreen extends ConsumerWidget {
  const CompetitionDetailScreen({super.key, required this.competitionId});

  final String competitionId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    final comps = ref.watch(competitionsControllerProvider);
    return comps.when(
      loading: () =>
          const Scaffold(body: AppLoading()),
      error: (e, _) => Scaffold(
        appBar: AppBar(),
        body: EmptyState(title: s.t('detail.loadError'), subtitle: '$e'),
      ),
      data: (list) {
        Competition? c;
        for (final item in list) {
          if (item.id == competitionId) c = item;
        }
        if (c == null) {
          return Scaffold(
            appBar: AppBar(),
            body: EmptyState(title: s.t('common.notFound')),
          );
        }
        return _DetailView(competition: c);
      },
    );
  }
}

class _DetailView extends ConsumerWidget {
  const _DetailView({required this.competition});
  final Competition competition;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    final c = competition;
    final user = ref.watch(authControllerProvider);
    final isManager =
        user != null && (user.isAdmin || c.organizerId == user.id);
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 200,
            pinned: true,
            actions: [
              if (isManager)
                IconButton(
                  icon: const Icon(Icons.settings),
                  tooltip: s.t('detail.manage'),
                  onPressed: () => context.push('/competition/${c.id}/manage'),
                ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: c.bannerBytes != null
                  ? Image.memory(c.bannerBytes!, fit: BoxFit.cover)
                  : (c.bannerUrl != null && c.bannerUrl!.isNotEmpty)
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
                    TagPill(
                        s
                            .t('detail.playersCount')
                            .replaceFirst('{a}', '${c.participantCount}')
                            .replaceFirst('{b}', '${c.maxParticipants}'),
                        icon: Icons.group,
                        color: AppColors.cyan),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: _StatBox(
                        label: s.t('detail.entryFee'),
                        value: Format.rupiah(c.entryFee),
                        color: c.entryFee == 0 ? AppColors.success : Colors.white,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _StatBox(
                        label: s.t('detail.prizePool'),
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
                    label: s.t('detail.starts'),
                    value: Format.dateTime(c.startsAt!),
                  ),
                ],
                if (c.registrationDeadline != null) ...[
                  const SizedBox(height: 12),
                  _InfoRow(
                    icon: Icons.how_to_reg_outlined,
                    label: s.t(c.registrationClosed
                        ? 'detail.regClosed'
                        : 'detail.regCloses'),
                    value: Format.dateTime(c.registrationDeadline!),
                  ),
                ],
                if (c.techMeetingUrl != null &&
                    c.techMeetingUrl!.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  _InfoRow(
                    icon: Icons.forum_outlined,
                    label: s
                        .t('detail.meeting')
                        .replaceFirst('{x}', c.techMeetingType.label),
                    value: c.techMeetingUrl!,
                  ),
                ],
                const SizedBox(height: 12),
                _ShareRow(
                    url: c.shareUrlFor(ref.watch(appSettingsProvider).domain),
                    strings: s),
                const SizedBox(height: 20),
                Text(s.t('detail.about'),
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.w800)),
                const SizedBox(height: 8),
                Text(
                  c.description.isEmpty
                      ? s.t('detail.noDescription')
                      : c.description,
                  style: const TextStyle(color: Colors.white70, height: 1.5),
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Text(s.t('detail.bracket'),
                        style: const TextStyle(
                            fontSize: 18, fontWeight: FontWeight.w800)),
                    const Spacer(),
                    if (isManager)
                      TextButton.icon(
                        onPressed: () =>
                            context.push('/competition/${c.id}/manage'),
                        icon: const Icon(Icons.settings, size: 18),
                        label: Text(s.t('detail.manage')),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                TournamentSection(competition: c),
              ],
            ),
          ),
        ],
      ),
      bottomSheet: _RegisterBar(competition: c),
    );
  }
}

class _RegisterBar extends ConsumerWidget {
  const _RegisterBar({required this.competition});
  final Competition competition;

  /// Players may leave only while registration is still open (before the
  /// bracket is generated); after that a withdrawal would break the draw.
  bool get _canWithdraw => competition.status == CompetitionStatus.open;

  Future<void> _withdraw(BuildContext context, WidgetRef ref) async {
    final s = ref.read(stringsProvider);
    final user = ref.read(authControllerProvider);
    if (user == null) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(s.t('detail.withdrawTitle')),
        content: Text(s.t('detail.withdrawBody')),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(s.t('common.cancel'))),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(s.t('detail.withdraw'))),
        ],
      ),
    );
    if (ok != true) return;
    final client = ref.read(supabaseClientProvider);
    if (client == null) {
      ref.read(demoStoreProvider).withdraw(competition.id, user.id);
    } else {
      await client
          .from('registrations')
          .delete()
          .eq('competition_id', competition.id)
          .eq('user_id', user.id);
    }
    ref.invalidate(competitionsControllerProvider);
    ref.invalidate(isRegisteredProvider(competition.id));
    if (context.mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(s.t('detail.withdrawn'))));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    final c = competition;
    final registered = ref.watch(isRegisteredProvider(c.id)).valueOrNull ?? false;
    final disabled = c.isFull ||
        c.status != CompetitionStatus.open ||
        c.registrationClosed;
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
              Text(s.t('detail.entry'),
                  style: const TextStyle(color: Colors.white54)),
              Text(Format.rupiah(c.entryFee),
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.w800)),
            ],
          ),
          const SizedBox(width: 16),
          Expanded(
            child: registered
                ? Row(
                    children: [
                      const Icon(Icons.check_circle, color: AppColors.success),
                      const SizedBox(width: 8),
                      Text(s.t('detail.registered'),
                          style: const TextStyle(
                              fontWeight: FontWeight.w700)),
                      const Spacer(),
                      if (_canWithdraw)
                        TextButton(
                          onPressed: () => _withdraw(context, ref),
                          style: TextButton.styleFrom(
                              foregroundColor: AppColors.danger),
                          child: Text(s.t('detail.withdraw')),
                        ),
                    ],
                  )
                : FilledButton.icon(
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
                        ? (c.isFull
                            ? s.t('detail.full')
                            : s.t('detail.closed'))
                        : (c.entryFee == 0
                            ? s.t('detail.joinFree')
                            : s.t('detail.register'))),
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
  const _ShareRow({required this.url, required this.strings});
  final String url;
  final AppStrings strings;

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
            tooltip: strings.t('detail.share'),
            onPressed: () {
              Clipboard.setData(ClipboardData(text: url));
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(strings.t('detail.linkCopied'))),
              );
            },
          ),
        ],
      ),
    );
  }
}
