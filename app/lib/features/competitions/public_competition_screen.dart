import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/app_settings.dart';
import '../../core/calendar.dart';
import '../../core/formatters.dart';
import '../../core/i18n.dart';
import '../../core/theme.dart';
import '../../shared/models/competition.dart';
import '../../shared/widgets/app_logo.dart';
import '../../shared/widgets/brand.dart';
import '../auth/auth_controller.dart';
import '../matches/bracket_view.dart';
import 'competitions_controller.dart';

/// Anonymous, read-only tournament page reachable from a share link
/// (`/c/:slug`). No login required — anyone can follow the bracket. A CTA
/// invites viewers to sign in to register (or open the full app if signed in).
class PublicCompetitionScreen extends ConsumerWidget {
  const PublicCompetitionScreen({super.key, required this.slug});
  final String slug;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    final async = ref.watch(competitionBySlugProvider(slug));
    return Scaffold(
      appBar: AppBar(title: const AppLogo(size: 26)),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => EmptyState(
            title: s.t('public.notFound'), subtitle: '$e'),
        data: (c) => c == null
            ? EmptyState(
                title: s.t('public.notFound'),
                subtitle: s.t('public.notFoundSub'),
                icon: Icons.link_off,
              )
            : _PublicView(competition: c),
      ),
    );
  }
}

class _PublicView extends ConsumerWidget {
  const _PublicView({required this.competition});
  final Competition competition;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    final c = competition;
    final loggedIn = ref.watch(authControllerProvider) != null;
    final domain = ref.watch(appSettingsProvider).domain;

    return Scaffold(
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 120),
        children: [
          _Banner(competition: c),
          const SizedBox(height: 16),
          Row(
            children: [
              const Icon(Icons.public, size: 14, color: Colors.white38),
              const SizedBox(width: 6),
              Expanded(
                child: Text(s.t('public.viewerNote'),
                    style:
                        const TextStyle(color: Colors.white38, fontSize: 12)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(c.title,
              style:
                  const TextStyle(fontSize: 24, fontWeight: FontWeight.w900)),
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
                  value: c.prizePool > 0 ? Format.rupiah(c.prizePool) : '—',
                  color: AppColors.gold,
                ),
              ),
            ],
          ),
          if (c.startsAt != null) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                const Icon(Icons.event, size: 18, color: AppColors.cyan),
                const SizedBox(width: 10),
                Expanded(
                  child: Text('${s.t('detail.starts')}: '
                      '${Format.dateTime(c.startsAt!)}'),
                ),
                TextButton.icon(
                  onPressed: () => openCalendar(
                    title: c.title,
                    start: c.startsAt!,
                    details: c.shareUrlFor(domain),
                  ),
                  icon: const Icon(Icons.calendar_month, size: 18),
                  label: Text(s.t('public.addToCalendar')),
                ),
              ],
            ),
          ],
          const SizedBox(height: 12),
          _ShareRow(url: c.shareUrlFor(domain), strings: s),
          const SizedBox(height: 20),
          Text(s.t('detail.about'),
              style:
                  const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          Text(
            c.description.isEmpty ? s.t('detail.noDescription') : c.description,
            style: const TextStyle(color: Colors.white70, height: 1.5),
          ),
          const SizedBox(height: 20),
          Text(s.t('detail.bracket'),
              style:
                  const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          BracketView(competition: c, readOnly: true),
        ],
      ),
      bottomSheet: Container(
        padding: EdgeInsets.fromLTRB(
            16, 12, 16, 12 + MediaQuery.of(context).padding.bottom),
        decoration: BoxDecoration(
          color: AppColors.surface,
          border: Border(
              top: BorderSide(color: Colors.white.withValues(alpha: 0.06))),
        ),
        child: FilledButton.icon(
          onPressed: () => loggedIn
              ? context.go('/competition/${c.id}')
              : context.go('/login'),
          icon: Icon(loggedIn ? Icons.open_in_new : Icons.login),
          label: Text(loggedIn
              ? s.t('public.openInApp')
              : s.t('public.signInToRegister')),
        ),
      ),
    );
  }
}

class _Banner extends StatelessWidget {
  const _Banner({required this.competition});
  final Competition competition;

  @override
  Widget build(BuildContext context) {
    final c = competition;
    Widget child;
    if (c.bannerBytes != null) {
      child = Image.memory(c.bannerBytes!, fit: BoxFit.cover);
    } else if (c.bannerUrl != null && c.bannerUrl!.isNotEmpty) {
      child = CachedNetworkImage(imageUrl: c.bannerUrl!, fit: BoxFit.cover);
    } else {
      child = const DecoratedBox(
        decoration: BoxDecoration(gradient: AppColors.brand),
        child: Center(
          child: Icon(Icons.emoji_events, color: Colors.white24, size: 56),
        ),
      );
    }
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(bottom: Radius.circular(20)),
      child: SizedBox(height: 170, width: double.infinity, child: child),
    );
  }
}

class _StatBox extends StatelessWidget {
  const _StatBox({required this.label, required this.value, required this.color});
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceHigh,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(color: Colors.white54)),
          const SizedBox(height: 6),
          Text(value,
              style: TextStyle(
                  fontSize: 20, fontWeight: FontWeight.w900, color: color)),
        ],
      ),
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
