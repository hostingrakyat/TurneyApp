import 'dart:math';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/demo_store_provider.dart';
import '../../core/env.dart';
import '../../core/supabase.dart';
import '../../shared/models/competition.dart';
import '../../shared/models/match.dart';
import '../../shared/models/match_report.dart';
import '../../shared/models/match_stream.dart';
import '../../shared/models/participant.dart';
import 'bracket.dart';
import 'standings.dart';

/// Matches for a competition (bracket).
final matchesProvider =
    FutureProvider.family<List<GameMatch>, String>((ref, compId) async {
  final client = ref.watch(supabaseClientProvider);
  if (client == null) {
    return ref.watch(demoStoreProvider).matchesFor(compId);
  }
  final rows = await client
      .from('matches')
      .select()
      .eq('competition_id', compId)
      .order('round')
      .order('bracket_position');
  return (rows as List)
      .map((r) => GameMatch.fromMap(r as Map<String, dynamic>))
      .toList();
});

/// Live bracket updates. Subscribes to Supabase Realtime for `matches` rows of
/// a competition and invalidates the cached queries so brackets, standings and
/// match detail refresh the moment a result lands — for players and spectators
/// (incl. the anonymous public page). Offline mode is already reactive via
/// [DemoStore], so this is a no-op there. `autoDispose` closes the channel when
/// no screen is watching it.
final liveMatchesProvider =
    Provider.autoDispose.family<void, String>((ref, compId) {
  final client = ref.watch(supabaseClientProvider);
  if (client == null) return;
  final channel = client
      .channel('matches:$compId')
      .onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'matches',
        filter: PostgresChangeFilter(
          type: PostgresChangeFilterType.eq,
          column: 'competition_id',
          value: compId,
        ),
        callback: (payload) {
          ref.invalidate(matchesProvider(compId));
          final row =
              payload.newRecord.isNotEmpty ? payload.newRecord : payload.oldRecord;
          final id = row['id'];
          if (id is String) {
            ref.invalidate(singleMatchProvider(id));
            ref.invalidate(matchReportsProvider(id));
          }
        },
      )
      .subscribe();
  ref.onDispose(() {
    client.removeChannel(channel);
  });
});

final singleMatchProvider =
    FutureProvider.family<GameMatch?, String>((ref, matchId) async {
  final client = ref.watch(supabaseClientProvider);
  if (client == null) {
    return ref.watch(demoStoreProvider).matchById(matchId);
  }
  final row = await client
      .from('matches')
      .select()
      .eq('id', matchId)
      .maybeSingle();
  return row == null ? null : GameMatch.fromMap(row);
});

final matchStreamsProvider =
    FutureProvider.family<List<MatchStreamEntry>, String>((ref, matchId) async {
  final client = ref.watch(supabaseClientProvider);
  if (client == null) {
    return ref.watch(demoStoreProvider).streamsFor(matchId);
  }
  final rows =
      await client.from('match_streams').select().eq('match_id', matchId);
  return (rows as List)
      .map((r) => MatchStreamEntry.fromMap(r as Map<String, dynamic>))
      .toList();
});

final matchReportsProvider =
    FutureProvider.family<List<MatchReport>, String>((ref, matchId) async {
  final client = ref.watch(supabaseClientProvider);
  if (client == null) {
    return ref.watch(demoStoreProvider).reportsFor(matchId);
  }
  final rows =
      await client.from('match_reports').select().eq('match_id', matchId);
  return (rows as List)
      .map((r) => MatchReport.fromMap(r as Map<String, dynamic>))
      .toList();
});

/// All matches currently in dispute (admin/organizer review queue).
final disputedMatchesProvider = FutureProvider<List<GameMatch>>((ref) async {
  final client = ref.watch(supabaseClientProvider);
  if (client == null) {
    return ref.watch(demoStoreProvider).disputedMatches;
  }
  final rows =
      await client.from('matches').select().eq('status', 'disputed');
  return (rows as List)
      .map((r) => GameMatch.fromMap(r as Map<String, dynamic>))
      .toList();
});

final matchesServiceProvider = Provider<MatchesService>((ref) {
  return MatchesService(ref);
});

class MatchesService {
  MatchesService(this._ref);
  final Ref _ref;

  SupabaseClient? get _client => _ref.read(supabaseClientProvider);

  void _refresh(String compId, [String? matchId]) {
    _ref.invalidate(matchesProvider(compId));
    if (matchId != null) {
      _ref.invalidate(singleMatchProvider(matchId));
      _ref.invalidate(matchReportsProvider(matchId));
      _ref.invalidate(matchStreamsProvider(matchId));
    }
  }

  // ── Generate bracket ─────────────────────────────────────────
  Future<void> generateBracket(Competition comp, String organizerId) async {
    final client = _client;
    if (client == null) {
      _ref.read(demoStoreProvider).closeAndGenerate(comp.id, organizerId);
      return;
    }
    final regRows = await client
        .from('registrations')
        .select('user_id')
        .eq('competition_id', comp.id)
        .eq('status', 'paid');
    final ids = (regRows as List).map((r) => r['user_id'] as String).toList();
    if (ids.length < 2) {
      throw Exception('Need at least 2 paid participants to start.');
    }
    final profRows = await client
        .from('profiles')
        .select('id, display_name')
        .inFilter('id', ids);
    final names = {
      for (final p in (profRows as List))
        p['id'] as String: (p['display_name'] ?? 'Player') as String
    };
    final players = [
      for (final id in ids) Participant(id: id, name: names[id] ?? 'Player')
    ];
    final matches = BracketBuilder.generate(
      competitionId: comp.id,
      format: comp.format,
      players: players,
      groupSize: comp.groupSize,
      lobbySize: comp.lobbySize,
    );
    await client.from('matches').insert([for (final m in matches) m.toInsert()]);
    await client
        .from('competitions')
        .update({'status': 'ongoing'}).eq('id', comp.id);
    _refresh(comp.id);
    _ref.invalidate(matchesProvider(comp.id));
  }

  // ── Generate the final playoff from group standings ──────────
  Future<void> generatePlayoffs(Competition comp) async {
    final client = _client;
    if (client == null) {
      _ref.read(demoStoreProvider).generatePlayoffs(comp.id);
      return;
    }
    final rows = await client
        .from('matches')
        .select()
        .eq('competition_id', comp.id)
        .eq('stage', 'group');
    final groupMatches = (rows as List)
        .map((r) => GameMatch.fromMap(r as Map<String, dynamic>))
        .toList();
    if (groupMatches.isEmpty ||
        groupMatches.any((m) => m.status != MatchStatus.completed)) {
      throw Exception('Finish all group matches first.');
    }
    final existing = await client
        .from('matches')
        .select('id')
        .eq('competition_id', comp.id)
        .eq('stage', 'elim')
        .limit(1);
    if ((existing as List).isNotEmpty) return;

    final qualifiers = _qualifiers(groupMatches, comp.advancePerGroup);
    if (qualifiers.length < 2) throw Exception('Not enough qualifiers.');
    final playoff = BracketBuilder.playoff(comp.id, qualifiers);
    await client
        .from('matches')
        .insert([for (final m in playoff) m.toInsert()]);
    _refresh(comp.id);
  }

  List<Participant> _qualifiers(List<GameMatch> groupMatches, int topN) =>
      topQualifiers(groupMatches, topN);

  // ── Free-for-all: set a lobby winner + advance ───────────────
  Future<void> setFfaWinner(GameMatch match, String winnerId) async {
    final client = _client;
    if (client == null) {
      _ref.read(demoStoreProvider).setFfaWinner(match.id, winnerId);
      return;
    }
    await client
        .from('matches')
        .update({'status': 'completed', 'winner_id': winnerId})
        .eq('id', match.id);
    await _advanceFfa(client, match.competitionId);
    _refresh(match.competitionId, match.id);
  }

  Future<void> _advanceFfa(SupabaseClient client, String compId) async {
    final rows = await client
        .from('matches')
        .select()
        .eq('competition_id', compId)
        .eq('stage', 'ffa');
    final ffa = (rows as List)
        .map((r) => GameMatch.fromMap(r as Map<String, dynamic>))
        .toList();
    if (ffa.isEmpty) return;
    final maxRound = ffa.map((m) => m.round).reduce(max);
    final current = ffa.where((m) => m.round == maxRound).toList();
    if (current.any((m) => m.status != MatchStatus.completed)) return;

    final winners = [
      for (final m in current)
        if (m.winnerId != null)
          Participant(id: m.winnerId!, name: m.winnerName ?? 'Player')
    ];

    // One lobby left → champion.
    if (current.length == 1) {
      await client
          .from('competitions')
          .update({'status': 'completed'}).eq('id', compId);
      final comp = await client
          .from('competitions')
          .select('prize_pool')
          .eq('id', compId)
          .single();
      final prize = (comp['prize_pool'] ?? 0) as int;
      if (prize > 0 && winners.isNotEmpty) {
        await client.from('payouts').insert({
          'user_id': winners.first.id,
          'competition_id': compId,
          'amount': prize,
          'status': 'owed',
        });
      }
      return;
    }

    // Otherwise seed the next round from the lobby winners (once).
    if (ffa.any((m) => m.round == maxRound + 1)) return;
    final comp = await client
        .from('competitions')
        .select('lobby_size')
        .eq('id', compId)
        .single();
    final lobbySize = (comp['lobby_size'] ?? 8) as int;
    final next = BracketBuilder.ffaRound(compId, winners, maxRound + 1,
        lobbySize: lobbySize);
    if (next.isNotEmpty) {
      await client.from('matches').insert([for (final m in next) m.toInsert()]);
    }
  }

  // ── Pre-match stream link ────────────────────────────────────
  Future<void> addStream(GameMatch match, String userId,
      StreamPlatform platform, String url) async {
    final client = _client;
    if (client == null) {
      _ref.read(demoStoreProvider).addStream(match.id, userId, platform, url);
      return;
    }
    await client.from('match_streams').insert({
      'match_id': match.id,
      'user_id': userId,
      'platform': platform.name,
      'url': url,
    });
    _refresh(match.competitionId, match.id);
  }

  // ── Post-match report ────────────────────────────────────────
  Future<void> reportResult({
    required GameMatch match,
    required String reporterId,
    required String reporterName,
    required String claimedWinnerId,
    Uint8List? screenshot,
    bool simulateDispute = false,
  }) async {
    final client = _client;
    if (client == null) {
      _ref.read(demoStoreProvider).reportResult(
            matchId: match.id,
            reporterId: reporterId,
            reporterName: reporterName,
            claimedWinnerId: claimedWinnerId,
            screenshot: screenshot,
            simulateDispute: simulateDispute,
          );
      return;
    }

    String? screenshotUrl;
    if (screenshot != null) {
      final path = '${match.id}/$reporterId.png';
      await client.storage.from('screenshots').uploadBinary(
            path,
            screenshot,
            fileOptions: const FileOptions(upsert: true, contentType: 'image/png'),
          );
      screenshotUrl = client.storage.from('screenshots').getPublicUrl(path);
    }

    await client.from('match_reports').upsert({
      'match_id': match.id,
      'reporter_id': reporterId,
      'claimed_winner_id': claimedWinnerId,
      'screenshot_url': screenshotUrl,
    }, onConflict: 'match_id,reporter_id');

    final now = DateTime.now();
    await client.from('matches').update({
      'status': 'awaiting_reports',
      'reports_open_at': (match.reportsOpenAt ?? now).toIso8601String(),
      'auto_resolve_at': (match.autoResolveAt ??
              now.add(Duration(minutes: Env.matchAutoResolveMinutes)))
          .toIso8601String(),
    }).eq('id', match.id);

    _refresh(match.competitionId, match.id);
  }

  // ── Manual resolution ────────────────────────────────────────
  Future<void> resolveNow(GameMatch match) async {
    final client = _client;
    if (client == null) {
      _ref.read(demoStoreProvider).resolveNow(match.id);
      return;
    }
    final repRows =
        await client.from('match_reports').select().eq('match_id', match.id);
    final winners = (repRows as List)
        .map((r) => r['claimed_winner_id'] as String?)
        .whereType<String>()
        .toSet();
    if (winners.isEmpty) return;
    if (winners.length == 1) {
      await _completeSupabase(client, match, winners.first);
    } else {
      await client.from('matches').update({'status': 'disputed'}).eq('id', match.id);
      await client
          .from('disputes')
          .upsert({'match_id': match.id}, onConflict: 'match_id');
    }
    _refresh(match.competitionId, match.id);
  }

  Future<void> resolveDispute(GameMatch match, String winnerId) async {
    final client = _client;
    if (client == null) {
      _ref.read(demoStoreProvider).resolveDispute(match.id, winnerId);
      return;
    }
    await _completeSupabase(client, match, winnerId);
    await client
        .from('disputes')
        .update({'status': 'resolved', 'resolution_note': 'Resolved by manager'})
        .eq('match_id', match.id);
    _refresh(match.competitionId, match.id);
  }

  Future<void> _completeSupabase(
      SupabaseClient client, GameMatch match, String winnerId) async {
    final winnerName =
        winnerId == match.player1Id ? match.player1Name : match.player2Name;
    await client.from('matches').update({
      'status': 'completed',
      'winner_id': winnerId,
    }).eq('id', match.id);

    if (match.nextMatchId != null && match.nextSlot != null) {
      final slot = match.nextSlot;
      await client.from('matches').update({
        'player${slot}_id': winnerId,
        'player${slot}_name': winnerName,
      }).eq('id', match.nextMatchId!);
    } else {
      await client
          .from('competitions')
          .update({'status': 'completed'}).eq('id', match.competitionId);
    }
  }
}
