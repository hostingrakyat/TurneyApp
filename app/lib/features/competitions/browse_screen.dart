import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/app_settings.dart';
import '../../shared/widgets/app_logo.dart';
import '../../shared/widgets/brand.dart';
import 'competitions_controller.dart';
import 'widgets/competition_card.dart';

class BrowseScreen extends ConsumerWidget {
  const BrowseScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final comps = ref.watch(competitionsControllerProvider);
    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async =>
              ref.invalidate(competitionsControllerProvider),
          child: CustomScrollView(
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                sliver: SliverToBoxAdapter(
                  child: Row(
                    children: [
                      const AppLogo(size: 30, full: true),
                      const Spacer(),
                      if (ref.watch(appSettingsProvider).demoMode)
                        const TagPill('Demo', color: Color(0xFFF59E0B)),
                    ],
                  ),
                ),
              ),
              const SliverPadding(
                padding: EdgeInsets.fromLTRB(16, 16, 16, 4),
                sliver: SliverToBoxAdapter(child: _Hero()),
              ),
              const SliverPadding(
                padding: EdgeInsets.fromLTRB(16, 12, 16, 8),
                sliver: SliverToBoxAdapter(
                  child: Text('Open competitions',
                      style: TextStyle(
                          fontSize: 18, fontWeight: FontWeight.w800)),
                ),
              ),
              comps.when(
                loading: () => const SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(child: CircularProgressIndicator()),
                ),
                error: (e, _) => SliverFillRemaining(
                  hasScrollBody: false,
                  child: EmptyState(title: 'Could not load', subtitle: '$e'),
                ),
                data: (list) {
                  if (list.isEmpty) {
                    return const SliverFillRemaining(
                      hasScrollBody: false,
                      child: EmptyState(
                        title: 'No competitions yet',
                        subtitle: 'Be the first to organize one.',
                        icon: Icons.emoji_events_outlined,
                      ),
                    );
                  }
                  return SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                    sliver: SliverList.separated(
                      itemCount: list.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 14),
                      itemBuilder: (_, i) => CompetitionCard(
                        competition: list[i],
                        onTap: () =>
                            context.push('/competition/${list[i].id}'),
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Hero extends StatelessWidget {
  const _Hero();

  @override
  Widget build(BuildContext context) {
    return GradientPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Compete. Organize. Win.',
            style: TextStyle(
                fontSize: 22, fontWeight: FontWeight.w900, color: Colors.white),
          ),
          const SizedBox(height: 6),
          Text(
            'Join tournaments with secure QRIS entry, or run your own — '
            'we handle the bracket, you keep 90% of every entry.',
            style: TextStyle(color: Colors.white.withValues(alpha: 0.9)),
          ),
          const SizedBox(height: 14),
          FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: const Color(0xFF6D28D9),
              minimumSize: const Size(0, 46),
            ),
            onPressed: () => context.push('/competition/new'),
            icon: const Icon(Icons.add),
            label: const Text('Create a competition'),
          ),
        ],
      ),
    );
  }
}
