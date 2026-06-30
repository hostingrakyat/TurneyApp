import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/formatters.dart';
import '../../core/theme.dart';
import '../../shared/models/competition.dart';
import '../../shared/widgets/brand.dart';
import '../auth/auth_controller.dart';
import '../competitions/competitions_controller.dart';
import '../competitions/widgets/competition_card.dart';

class OrganizerScreen extends ConsumerWidget {
  const OrganizerScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authControllerProvider);
    final comps = ref.watch(competitionsControllerProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Organizer'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: 'New competition',
            onPressed: () => context.push('/competition/new'),
          ),
        ],
      ),
      body: comps.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => EmptyState(title: 'Could not load', subtitle: '$e'),
        data: (all) {
          final mine =
              all.where((c) => c.organizerId == user?.id).toList();
          final gross = mine.fold<int>(
              0, (s, c) => s + c.participantCount * c.entryFee);
          final net = (gross * 0.9).round();
          final fees = gross - net;

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            children: [
              GradientPanel(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Your earnings',
                        style: TextStyle(
                            color: Colors.white70,
                            fontWeight: FontWeight.w600)),
                    const SizedBox(height: 6),
                    Text(Format.rupiah(net),
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 30,
                            fontWeight: FontWeight.w900)),
                    const SizedBox(height: 4),
                    Text(
                      'Gross ${Format.rupiah(gross)} · platform fee '
                      '${Format.rupiah(fees)} (10%)',
                      style: const TextStyle(color: Colors.white70),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  const Text('Your competitions',
                      style: TextStyle(
                          fontSize: 18, fontWeight: FontWeight.w800)),
                  const Spacer(),
                  Text('${mine.length}',
                      style: const TextStyle(color: Colors.white54)),
                ],
              ),
              const SizedBox(height: 12),
              if (mine.isEmpty)
                const EmptyState(
                  title: 'No competitions yet',
                  subtitle: 'Tap + to create your first one.',
                  icon: Icons.dashboard_outlined,
                )
              else
                ...mine.map((c) => Padding(
                      padding: const EdgeInsets.only(bottom: 14),
                      child: _OrganizerCompTile(competition: c),
                    )),
            ],
          );
        },
      ),
    );
  }
}

class _OrganizerCompTile extends StatelessWidget {
  const _OrganizerCompTile({required this.competition});
  final Competition competition;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        CompetitionCard(
          competition: competition,
          onTap: () => context.push('/competition/${competition.id}'),
        ),
        Positioned(
          top: 8,
          right: 8,
          child: TagPill(competition.status.label, color: AppColors.gold),
        ),
      ],
    );
  }
}
