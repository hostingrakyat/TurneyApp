import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../core/supabase.dart';
import '../../shared/models/competition.dart';

final competitionsControllerProvider =
    AsyncNotifierProvider<CompetitionsController, List<Competition>>(
        CompetitionsController.new);

/// Loads competitions from Supabase when available, otherwise serves in-memory
/// demo data so Browse/Create work offline.
class CompetitionsController extends AsyncNotifier<List<Competition>> {
  final _uuid = const Uuid();

  @override
  Future<List<Competition>> build() async {
    final client = ref.watch(supabaseClientProvider);
    if (client == null) return _demoSeed();
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
      final created = withSlug;
      state = AsyncData([created, ...(state.value ?? const [])]);
      return created;
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
      prizePool: c.prizePool,
      techMeetingUrl: c.techMeetingUrl,
      techMeetingType: c.techMeetingType,
      startsAt: c.startsAt,
      createdAt: DateTime.now(),
    );
  }

  List<Competition> _demoSeed() {
    final now = DateTime.now();
    return [
      Competition(
        id: 'demo-1',
        organizerId: 'demo-user',
        title: 'Mobile Legends Weekend Cup',
        description:
            'Open 1v1 bracket for the community. Best of 3 per match. '
            'Join the Discord for the technical meeting.',
        format: CompetitionFormat.singleElim,
        maxParticipants: 16,
        entryFee: 25000,
        prizePool: 300000,
        status: CompetitionStatus.open,
        slug: 'ml-weekend-cup-3f9a2c',
        techMeetingUrl: 'https://discord.gg/example',
        techMeetingType: TechMeetingType.discord,
        startsAt: now.add(const Duration(days: 3)),
        participantCount: 9,
        createdAt: now.subtract(const Duration(days: 1)),
      ),
      Competition(
        id: 'demo-2',
        organizerId: 'demo-user',
        title: 'FC Mobile League — Round Robin',
        description:
            'Everyone plays everyone. Standings by wins, then goal diff. '
            'Stream your matches for bonus visibility.',
        format: CompetitionFormat.roundRobin,
        maxParticipants: 8,
        entryFee: 15000,
        prizePool: 100000,
        status: CompetitionStatus.open,
        slug: 'fc-mobile-league-77b1de',
        techMeetingUrl: 'https://chat.whatsapp.com/example',
        techMeetingType: TechMeetingType.whatsapp,
        startsAt: now.add(const Duration(days: 7)),
        participantCount: 5,
        createdAt: now.subtract(const Duration(hours: 6)),
      ),
      Competition(
        id: 'demo-3',
        organizerId: 'demo-user',
        title: 'Free Community Scrims',
        description: 'No entry fee — practice bracket to warm up for the season.',
        format: CompetitionFormat.singleElim,
        maxParticipants: 32,
        entryFee: 0,
        prizePool: 0,
        status: CompetitionStatus.open,
        slug: 'community-scrims-9a0c41',
        startsAt: now.add(const Duration(days: 1)),
        participantCount: 21,
        createdAt: now.subtract(const Duration(days: 2)),
      ),
    ];
  }
}
