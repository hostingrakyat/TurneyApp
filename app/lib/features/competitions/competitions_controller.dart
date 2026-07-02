import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../core/demo_store_provider.dart';
import '../../core/supabase.dart';
import '../../shared/models/competition.dart';
import '../auth/auth_controller.dart';

final competitionsControllerProvider =
    AsyncNotifierProvider<CompetitionsController, List<Competition>>(
        CompetitionsController.new);

/// Public lookup by share-link slug — powers the anonymous tournament page.
/// Works offline (DemoStore) and against Supabase (anon-readable competitions).
final competitionBySlugProvider =
    FutureProvider.family<Competition?, String>((ref, slug) async {
  final client = ref.watch(supabaseClientProvider);
  if (client == null) {
    for (final c in ref.watch(demoStoreProvider).competitions) {
      if (c.slug == slug) return c;
    }
    return null;
  }
  final row =
      await client.from('competitions').select().eq('slug', slug).maybeSingle();
  return row == null ? null : Competition.fromMap(row);
});

/// Whether the current user has an active registration in a competition —
/// drives the "Registered / Withdraw" state on the register bar (both modes).
final isRegisteredProvider =
    FutureProvider.family<bool, String>((ref, compId) async {
  final user = ref.watch(authControllerProvider);
  if (user == null) return false;
  final client = ref.watch(supabaseClientProvider);
  if (client == null) {
    return ref.watch(demoStoreProvider).isRegistered(compId, user.id);
  }
  final row = await client
      .from('registrations')
      .select('id')
      .eq('competition_id', compId)
      .eq('user_id', user.id)
      .maybeSingle();
  return row != null;
});

/// Loads competitions from Supabase when available, otherwise serves the
/// in-memory [DemoStore] so the whole flow works offline.
class CompetitionsController extends AsyncNotifier<List<Competition>> {
  final _uuid = const Uuid();

  @override
  Future<List<Competition>> build() async {
    final client = ref.watch(supabaseClientProvider);
    if (client == null) {
      return ref.watch(demoStoreProvider).competitions;
    }
    final rows = await client
        .from('competitions')
        .select('*, registrations(count)')
        .order('created_at', ascending: false);
    return (rows as List)
        .map((r) => Competition.fromMap(_flattenCount(r as Map<String, dynamic>)))
        .toList();
  }

  Map<String, dynamic> _flattenCount(Map<String, dynamic> row) {
    // Supabase returns nested `registrations: [{count: n}]` for count aggregates.
    final regs = row['registrations'];
    if (regs is List && regs.isNotEmpty && regs.first is Map) {
      row['participant_count'] = (regs.first as Map)['count'] ?? 0;
    }
    return row;
  }

  Future<Competition> create(Competition draft) async {
    final client = ref.read(supabaseClientProvider);
    final withSlug = _withGeneratedSlug(draft);
    if (client == null) {
      ref.read(demoStoreProvider).addCompetition(withSlug);
      return withSlug;
    }
    final inserted = await client
        .from('competitions')
        .insert(withSlug.toInsert())
        .select()
        .single();
    final created = Competition.fromMap(inserted);
    ref.invalidateSelf();
    return created;
  }

  Competition _withGeneratedSlug(Competition c) {
    final base = c.title
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
        .replaceAll(RegExp(r'^-+|-+$'), '');
    final suffix = _uuid.v4().substring(0, 6);
    final slug = base.isEmpty ? suffix : '$base-$suffix';
    return Competition(
      id: c.id.isEmpty ? _uuid.v4() : c.id,
      organizerId: c.organizerId,
      title: c.title,
      description: c.description,
      format: c.format,
      maxParticipants: c.maxParticipants,
      entryFee: c.entryFee,
      status: c.status,
      slug: slug,
      bannerUrl: c.bannerUrl,
      bannerBytes: c.bannerBytes,
      prizePool: c.prizePool,
      techMeetingUrl: c.techMeetingUrl,
      techMeetingType: c.techMeetingType,
      startsAt: c.startsAt,
      registrationDeadline: c.registrationDeadline,
      createdAt: DateTime.now(),
      groupSize: c.groupSize,
      advancePerGroup: c.advancePerGroup,
      hasPlayoff: c.hasPlayoff,
    );
  }
}
