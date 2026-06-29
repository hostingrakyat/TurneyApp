import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/demo_store_provider.dart';
import '../../core/supabase.dart';
import '../../shared/models/competition.dart';
import '../../shared/widgets/brand.dart';
import '../auth/auth_controller.dart';
import '../competitions/widgets/competition_card.dart';

final myRegistrationsProvider =
    FutureProvider<List<Competition>>((ref) async {
  final user = ref.watch(authControllerProvider);
  if (user == null) return const [];
  final client = ref.watch(supabaseClientProvider);
  if (client == null) {
    return ref.watch(demoStoreProvider).registrationsFor(user.id);
  }
  final rows = await client
      .from('registrations')
      .select('competitions(*)')
      .eq('user_id', user.id);
  return (rows as List)
      .map((r) => (r as Map<String, dynamic>)['competitions'])
      .whereType<Map<String, dynamic>>()
      .map(Competition.fromMap)
      .toList();
});

class MyRegistrationsScreen extends ConsumerWidget {
  const MyRegistrationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final regs = ref.watch(myRegistrationsProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('My registrations')),
      body: regs.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => EmptyState(title: 'Could not load', subtitle: '$e'),
        data: (list) => list.isEmpty
            ? const EmptyState(
                title: 'No registrations yet',
                subtitle: 'Join a competition from the Compete tab.',
                icon: Icons.emoji_events_outlined,
              )
            : ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: list.length,
                separatorBuilder: (_, __) => const SizedBox(height: 14),
                itemBuilder: (_, i) => CompetitionCard(
                  competition: list[i],
                  onTap: () => context.push('/competition/${list[i].id}'),
                ),
              ),
      ),
    );
  }
}
