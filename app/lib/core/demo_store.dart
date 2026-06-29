import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../features/matches/bracket.dart';
import '../shared/models/competition.dart';
import '../shared/models/match.dart';
import '../shared/models/match_report.dart';
import '../shared/models/match_stream.dart';
import '../shared/models/participant.dart';
import 'env.dart';

class _Reg {
  _Reg(this.competitionId, this.userId, this.userName);
  final String competitionId;
  final String userId;
  final String userName;
}

/// Session-scoped, in-memory backend used when no Supabase is configured.
/// Drives the entire tournament loop offline: registrations, bracket
/// generation (padded with bot opponents), match reports, a periodic
/// auto-resolve, bracket advancement, and disputes.
class DemoStore extends ChangeNotifier {
  DemoStore() {
    _seed();
    _timer = Timer.periodic(const Duration(seconds: 10), (_) => _tick());
  }

  static const _uuid = Uuid();
  final _rng = Random();
  Timer? _timer;

  final Map<String, Competition> _comps = {};
  final List<_Reg> _regs = [];
  final List<GameMatch> _matches = [];
  final List<MatchStreamEntry> _streams = [];
  final List<MatchReport> _reports = [];
  int _botCounter = 0;

  static const _botNames = [
    'ShadowFox', 'Rapidz', 'NovaStrike', 'IronClad',
    'PhantomX', 'BlazeKing', 'Vortex', 'Cobalt',
    'Specter', 'Hydra', 'Riptide', 'Zenith',
  ];

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  // ── Competitions ──────────────────────────────────────────────
  List<Competition> get competitions => _comps.values
      .map((c) => c.copyWith(participantCount: _paidCount(c.id)))
      .toList()
    ..sort((a, b) =>
        (b.createdAt ?? DateTime(0)).compareTo(a.createdAt ?? DateTime(0)));

  Competition? competition(String id) {
    final c = _comps[id];
    return c?.copyWith(participantCount: _paidCount(id));
  }

  void addCompetition(Competition c) {
    _comps[c.id] = c;
    notifyListeners();
  }

  int _paidCount(String compId) =>
      _regs.where((r) => r.competitionId == compId).length;

  // ── Registrations ─────────────────────────────────────────────
  bool isRegistered(String compId, String userId) =>
      _regs.any((r) => r.competitionId == compId && r.userId == userId);

  List<Competition> registrationsFor(String userId) => _regs
      .where((r) => r.userId == userId)
      .map((r) => competition(r.competitionId))
      .whereType<Competition>()
      .toList();

  void register(String compId, String userId, String userName) {
    if (isRegistered(compId, userId)) return;
    _regs.add(_Reg(compId, userId, userName));
    notifyListeners();
  }

  // ── Matches ───────────────────────────────────────────────────
  List<GameMatch> matchesFor(String compId) =>
      _matches.where((m) => m.competitionId == compId).toList()
        ..sort((a, b) =>
            a.round != b.round ? a.round - b.round : a.position - b.position);

  GameMatch? matchById(String id) {
    for (final m in _matches) {
      if (m.id == id) return m;
    }
    return null;
  }

  List<GameMatch> get disputedMatches =>
      _matches.where((m) => m.status == MatchStatus.disputed).toList();

  List<MatchStreamEntry> streamsFor(String matchId) =>
      _streams.where((s) => s.matchId == matchId).toList();

  List<MatchReport> reportsFor(String matchId) =>
      _reports.where((r) => r.matchId == matchId).toList();

  bool hasBracket(String compId) =>
      _matches.any((m) => m.competitionId == compId);

  /// Closes registration and builds the bracket, padding with bot opponents so
  /// the demo is playable to a champion.
  void closeAndGenerate(String compId, String organizerId) {
    final comp = _comps[compId];
    if (comp == null) return;

    final participants = _regs
        .where((r) => r.competitionId == compId)
        .map((r) => Participant(id: r.userId, name: r.userName))
        .toList();

    final target =
        min(comp.maxParticipants, max(participants.length, 4)).clamp(2, 64);
    while (participants.length < target) {
      participants.add(Participant(
        id: 'bot-${_botCounter}',
        name: _botNames[_botCounter % _botNames.length],
        isBot: true,
      ));
      _botCounter++;
    }

    _matches.removeWhere((m) => m.competitionId == compId);
    _matches.addAll(BracketBuilder.generate(
      competitionId: compId,
      format: comp.format,
      players: participants,
    ));
    _comps[compId] = comp.copyWith(status: CompetitionStatus.ongoing);
    _autoPlayBots();
    notifyListeners();
  }

  bool _isBot(String? id) => id != null && id.startsWith('bot-');

  // ── Pre-match streams ─────────────────────────────────────────
  void addStream(
      String matchId, String userId, StreamPlatform platform, String url) {
    _streams.add(MatchStreamEntry(
      id: _uuid.v4(),
      matchId: matchId,
      userId: userId,
      platform: platform,
      url: url,
    ));
    notifyListeners();
  }

  // ── Post-match reports ────────────────────────────────────────
  /// The human reports a result. When the opponent is a bot it auto-reports —
  /// agreeing by default, or disputing when [simulateDispute] is set (so the
  /// dispute flow can be demoed on demand).
  void reportResult({
    required String matchId,
    required String reporterId,
    required String reporterName,
    required String claimedWinnerId,
    Uint8List? screenshot,
    bool simulateDispute = false,
  }) {
    final idx = _matches.indexWhere((m) => m.id == matchId);
    if (idx < 0) return;
    final m = _matches[idx];

    _reports.removeWhere(
        (r) => r.matchId == matchId && r.reporterId == reporterId);
    _reports.add(MatchReport(
      id: _uuid.v4(),
      matchId: matchId,
      reporterId: reporterId,
      reporterName: reporterName,
      claimedWinnerId: claimedWinnerId,
      screenshotBytes: screenshot,
    ));

    // Bot opponent auto-reports.
    final opponentId = m.player1Id == reporterId ? m.player2Id : m.player1Id;
    final opponentName =
        m.player1Id == reporterId ? m.player2Name : m.player1Name;
    if (_isBot(opponentId) &&
        !_reports.any((r) => r.matchId == matchId && r.reporterId == opponentId)) {
      _reports.add(MatchReport(
        id: _uuid.v4(),
        matchId: matchId,
        reporterId: opponentId!,
        reporterName: opponentName ?? 'Opponent',
        claimedWinnerId: simulateDispute ? opponentId : claimedWinnerId,
      ));
    }

    final now = DateTime.now();
    _matches[idx] = m.copyWith(
      status: MatchStatus.awaitingReports,
      reportsOpenAt: m.reportsOpenAt ?? now,
      autoResolveAt: m.autoResolveAt ??
          now.add(Duration(minutes: Env.matchAutoResolveMinutes)),
    );
    notifyListeners();
  }

  // ── Resolution ────────────────────────────────────────────────
  /// Organizer/admin forces resolution of a match now (skips the 5-min wait).
  void resolveNow(String matchId) {
    final m = matchById(matchId);
    if (m == null) return;
    _applyResolution(m);
    _autoPlayBots();
    notifyListeners();
  }

  /// Organizer/admin resolves a dispute by choosing the winner.
  void resolveDispute(String matchId, String winnerId) {
    final idx = _matches.indexWhere((m) => m.id == matchId);
    if (idx < 0) return;
    _complete(idx, winnerId);
    _autoPlayBots();
    notifyListeners();
  }

  void _tick() {
    var changed = _resolveDue();
    changed = _autoPlayBots() || changed;
    if (changed) notifyListeners();
  }

  bool _resolveDue() {
    var changed = false;
    final now = DateTime.now();
    for (final m in List<GameMatch>.from(_matches)) {
      final due = m.autoResolveAt != null && !m.autoResolveAt!.isAfter(now);
      final active = m.status == MatchStatus.awaitingReports ||
          m.status == MatchStatus.autoResolving;
      if (active && due) {
        if (_applyResolution(m)) changed = true;
      }
    }
    return changed;
  }

  /// Auto-completes bot-vs-bot matches (looping until stable) so the bracket
  /// advances right up to where the human plays.
  bool _autoPlayBots() {
    var any = false;
    bool pass;
    do {
      pass = false;
      for (final snap in List<GameMatch>.from(_matches)) {
        final idx = _matches.indexWhere((x) => x.id == snap.id);
        final m = _matches[idx];
        if (m.status == MatchStatus.completed) continue;
        if (m.bothPlayersPresent && _isBot(m.player1Id) && _isBot(m.player2Id)) {
          _complete(idx, _rng.nextBool() ? m.player1Id! : m.player2Id!);
          pass = true;
          any = true;
        }
      }
    } while (pass);
    return any;
  }

  /// Applies report-based resolution rules to a single match.
  bool _applyResolution(GameMatch m) {
    final reports = reportsFor(m.id);
    if (reports.isEmpty) return false;
    final winners = reports.map((r) => r.claimedWinnerId).toSet();
    final idx = _matches.indexWhere((x) => x.id == m.id);
    if (winners.length == 1) {
      _complete(idx, winners.first);
      return true;
    }
    if (m.status != MatchStatus.disputed) {
      _matches[idx] = m.copyWith(status: MatchStatus.disputed);
      return true;
    }
    return false;
  }

  void _complete(int idx, String winnerId) {
    final m = _matches[idx];
    final winnerName = winnerId == m.player1Id ? m.player1Name : m.player2Name;
    _matches[idx] = m.copyWith(status: MatchStatus.completed, winnerId: winnerId);
    // Advance the winner in single-elim.
    if (m.nextMatchId != null && m.nextSlot != null) {
      final nIdx = _matches.indexWhere((x) => x.id == m.nextMatchId);
      if (nIdx >= 0) {
        _matches[nIdx] = m.nextSlot == 1
            ? _matches[nIdx]
                .copyWith(player1Id: winnerId, player1Name: winnerName)
            : _matches[nIdx]
                .copyWith(player2Id: winnerId, player2Name: winnerName);
      }
    } else {
      // Final match completed → competition done.
      final comp = _comps[m.competitionId];
      if (comp != null) {
        _comps[m.competitionId] =
            comp.copyWith(status: CompetitionStatus.completed);
      }
    }
  }

  // ── Seed data ─────────────────────────────────────────────────
  void _seed() {
    final now = DateTime.now();
    final seeds = [
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
        createdAt: now.subtract(const Duration(days: 2)),
      ),
    ];
    for (final c in seeds) {
      _comps[c.id] = c;
    }
  }
}
