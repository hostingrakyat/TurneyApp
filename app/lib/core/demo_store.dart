import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../features/matches/bracket.dart';
import '../features/matches/standings.dart';
import '../shared/models/competition.dart';
import '../shared/models/match.dart';
import '../shared/models/match_report.dart';
import '../shared/models/match_stream.dart';
import '../shared/models/notification.dart';
import '../shared/models/participant.dart';
import '../shared/models/payment_txn.dart';
import '../shared/models/payout.dart';
import '../shared/models/platform_account.dart';
import 'env.dart';

class _Reg {
  _Reg(this.competitionId, this.userId, this.userName, this.phone,
      {this.paid = true});
  final String competitionId;
  final String userId;
  final String userName;
  final String? phone;

  /// Manual transfers start unpaid and count only once an admin confirms.
  bool paid;
}

/// A participant with contact info, for organizer outreach.
class ParticipantContact {
  const ParticipantContact(this.userId, this.name, this.phone);
  final String userId;
  final String name;
  final String? phone;
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
  final List<Payout> _payouts = [];
  final List<AppNotification> _notifs = [];
  final List<PaymentTxn> _txns = [];
  int _botCounter = 0;

  // Platform receiving accounts for manual transfers (admin-managed). Seeded
  // with placeholders so the manual-payment flow is explorable out of the box.
  final Map<PayMethod, PlatformAccount> _platformAccounts = {
    PayMethod.bank: const PlatformAccount(
      id: 'pa-bank',
      method: PayMethod.bank,
      accountName: 'ProTourney Indonesia',
      accountNumber: '1234567890',
      bankName: 'BCA',
    ),
    PayMethod.ovo: const PlatformAccount(
      id: 'pa-ovo',
      method: PayMethod.ovo,
      accountName: 'ProTourney',
      accountNumber: '0812 3456 7890',
    ),
    PayMethod.dana: const PlatformAccount(
      id: 'pa-dana',
      method: PayMethod.dana,
      accountName: 'ProTourney',
      accountNumber: '0812 3456 7890',
    ),
    PayMethod.gopay: const PlatformAccount(
      id: 'pa-gopay',
      method: PayMethod.gopay,
      accountName: 'ProTourney',
      accountNumber: '0812 3456 7890',
    ),
  };

  // ── Admin-managed app settings ──
  Uint8List? appLogoBytes;
  bool demoMode = true;
  String? domain;
  bool qrisMock = true;
  String? qrisMerchantId;
  String? qrisStoreId;
  String? emailFrom;
  static const _seedIds = {'demo-1', 'demo-2', 'demo-3'};

  void setAppLogo(Uint8List? bytes) {
    appLogoBytes = bytes;
    notifyListeners();
  }

  void setDemoMode(bool value) {
    demoMode = value;
    notifyListeners();
  }

  void setConfig({
    String? domain,
    bool? qrisMock,
    String? qrisMerchantId,
    String? qrisStoreId,
    String? emailFrom,
  }) {
    if (domain != null) this.domain = domain;
    if (qrisMock != null) this.qrisMock = qrisMock;
    if (qrisMerchantId != null) this.qrisMerchantId = qrisMerchantId;
    if (qrisStoreId != null) this.qrisStoreId = qrisStoreId;
    if (emailFrom != null) this.emailFrom = emailFrom;
    notifyListeners();
  }

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
      .where((c) => demoMode || !_seedIds.contains(c.id))
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
      _regs.where((r) => r.competitionId == compId && r.paid).length;

  // ── Registrations ─────────────────────────────────────────────
  bool isRegistered(String compId, String userId) =>
      _regs.any((r) => r.competitionId == compId && r.userId == userId);

  List<Competition> registrationsFor(String userId) => _regs
      .where((r) => r.userId == userId)
      .map((r) => competition(r.competitionId))
      .whereType<Competition>()
      .toList();

  void register(String compId, String userId, String userName,
      [String? phone]) {
    if (isRegistered(compId, userId)) return;
    _regs.add(_Reg(compId, userId, userName, phone));
    final comp = _comps[compId];
    _txns.insert(
      0,
      PaymentTxn(
        id: _uuid.v4(),
        userId: userId,
        userName: userName,
        competitionId: compId,
        competitionTitle: comp?.title ?? 'Competition',
        amount: comp?.entryFee ?? 0,
        provider: (comp?.entryFee ?? 0) == 0 ? 'free' : 'qris',
        status: PaymentStatus.paid,
        createdAt: DateTime.now(),
      ),
    );
    _pushNotif(NotificationKind.payment, 'Registered',
        'You joined ${comp?.title ?? 'a competition'}.');
    notifyListeners();
  }

  /// Registers via a manual transfer (bank / e-wallet). The spot is held as
  /// pending until an admin confirms the payment in the transactions screen.
  void registerManual(String compId, String userId, String userName,
      String? phone, PayMethod method, String? reference) {
    if (isRegistered(compId, userId)) return;
    _regs.add(_Reg(compId, userId, userName, phone, paid: false));
    final comp = _comps[compId];
    _txns.insert(
      0,
      PaymentTxn(
        id: _uuid.v4(),
        userId: userId,
        userName: userName,
        competitionId: compId,
        competitionTitle: comp?.title ?? 'Competition',
        amount: comp?.entryFee ?? 0,
        provider: 'manual',
        method: method,
        status: PaymentStatus.pending,
        reference: reference,
        createdAt: DateTime.now(),
      ),
    );
    _pushNotif(NotificationKind.payment, 'Payment submitted',
        'We are verifying your ${method.label} transfer for ${comp?.title ?? 'a competition'}.');
    notifyListeners();
  }

  // ── Transactions (admin ledger) ───────────────────────────────
  List<PaymentTxn> get transactions => List.unmodifiable(_txns);

  /// Admin confirms a pending manual transfer → the registration becomes paid.
  void confirmManualPayment(String txnId) {
    final i = _txns.indexWhere((t) => t.id == txnId);
    if (i < 0) return;
    final t = _txns[i];
    if (t.status == PaymentStatus.paid) return;
    _txns[i] = t.copyWith(status: PaymentStatus.paid);
    for (final r in _regs) {
      if (r.competitionId == t.competitionId && r.userId == t.userId) {
        r.paid = true;
      }
    }
    _pushNotif(NotificationKind.payment, 'Payment confirmed',
        'Your entry to ${t.competitionTitle} is confirmed. Good luck!');
    notifyListeners();
  }

  /// Admin rejects a pending manual transfer → the held spot is released.
  void rejectManualPayment(String txnId) {
    final i = _txns.indexWhere((t) => t.id == txnId);
    if (i < 0) return;
    final t = _txns[i];
    _txns[i] = t.copyWith(status: PaymentStatus.failed);
    _regs.removeWhere((r) =>
        r.competitionId == t.competitionId && r.userId == t.userId && !r.paid);
    _pushNotif(NotificationKind.payment, 'Payment not verified',
        'We could not verify your transfer for ${t.competitionTitle}. Please contact the admin.');
    notifyListeners();
  }

  // ── Platform receiving accounts (manual transfers) ────────────
  List<PlatformAccount> get platformAccounts =>
      PayMethod.values.map((m) => _platformAccounts[m]!).toList();

  PlatformAccount platformAccount(PayMethod method) =>
      _platformAccounts[method]!;

  void savePlatformAccount(PlatformAccount account) {
    _platformAccounts[account.method] = account;
    notifyListeners();
  }

  /// A participant leaves before the bracket starts — frees the slot and (for
  /// paid entries) records a refund via a notification.
  void withdraw(String compId, String userId) {
    _regs.removeWhere(
        (r) => r.competitionId == compId && r.userId == userId);
    // Drop any still-pending manual transaction for this entry.
    for (var i = 0; i < _txns.length; i++) {
      final t = _txns[i];
      if (t.competitionId == compId &&
          t.userId == userId &&
          t.status == PaymentStatus.pending) {
        _txns[i] = t.copyWith(status: PaymentStatus.failed);
      }
    }
    final title = _comps[compId]?.title ?? 'a competition';
    final fee = _comps[compId]?.entryFee ?? 0;
    _pushNotif(
        NotificationKind.payment,
        'Withdrawn',
        fee > 0
            ? 'You left $title — your entry fee will be refunded.'
            : 'You left $title.');
    notifyListeners();
  }

  void _pushNotif(NotificationKind kind, String title, [String? body]) {
    _notifs.insert(
      0,
      AppNotification(
        id: _uuid.v4(),
        kind: kind,
        title: title,
        body: body,
        createdAt: DateTime.now(),
      ),
    );
  }

  /// Participants (with phone) for organizer outreach.
  List<ParticipantContact> participantsFor(String compId) => _regs
      .where((r) => r.competitionId == compId)
      .map((r) => ParticipantContact(r.userId, r.userName, r.phone))
      .toList();

  // ── Matches ───────────────────────────────────────────────────
  List<GameMatch> matchesFor(String compId) =>
      _matches.where((m) => m.competitionId == compId).toList()
        ..sort((a, b) =>
            a.round != b.round ? a.round - b.round : a.position - b.position);

  /// Every match a given user is a participant in (their personal schedule),
  /// including free-for-all lobbies where they're in the roster.
  List<GameMatch> matchesForUser(String userId) =>
      _matches
          .where((m) =>
              m.player1Id == userId ||
              m.player2Id == userId ||
              m.players.any((p) => p.id == userId))
          .toList()
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
        .where((r) => r.competitionId == compId && r.paid)
        .map((r) => Participant(id: r.userId, name: r.userName))
        .toList();

    // Pad with practice bots only when demo mode is on.
    if (demoMode) {
      final target =
          min(comp.maxParticipants, max(participants.length, 4)).clamp(2, 64);
      while (participants.length < target) {
        participants.add(Participant(
          id: 'bot-$_botCounter',
          name: _botNames[_botCounter % _botNames.length],
          isBot: true,
        ));
        _botCounter++;
      }
    }
    if (participants.length < 2) return; // need at least two to run

    _matches.removeWhere((m) => m.competitionId == compId);
    _matches.addAll(BracketBuilder.generate(
      competitionId: compId,
      format: comp.format,
      players: participants,
      groupSize: comp.groupSize,
      lobbySize: comp.lobbySize,
    ));
    _comps[compId] = comp.copyWith(status: CompetitionStatus.ongoing);
    _autoPlayBots();
    notifyListeners();
  }

  /// True once every group-stage match for [compId] is completed.
  bool groupStageComplete(String compId) {
    final groupMatches = _matches.where(
        (m) => m.competitionId == compId && m.stage == 'group');
    return groupMatches.isNotEmpty &&
        groupMatches.every((m) => m.status == MatchStatus.completed);
  }

  bool hasPlayoffBracket(String compId) =>
      _matches.any((m) => m.competitionId == compId && m.stage == 'elim');

  /// Seeds the single-elimination playoff from group standings (top
  /// [Competition.advancePerGroup] of each group). Self-guards.
  void generatePlayoffs(String compId) {
    if (_runPlayoffGen(compId)) {
      _autoPlayBots();
      notifyListeners();
    }
  }

  bool _runPlayoffGen(String compId) {
    final comp = _comps[compId];
    if (comp == null || !comp.hasPlayoff) return false;
    if (hasPlayoffBracket(compId)) return false;
    if (!groupStageComplete(compId)) return false;
    final qualifiers = _qualifiers(compId, comp.advancePerGroup);
    if (qualifiers.length < 2) return false;
    _matches.addAll(BracketBuilder.playoff(compId, qualifiers));
    return true;
  }

  /// Top-N players per group, seeded A1, B1, A2, B2, … See [topQualifiers].
  List<Participant> _qualifiers(String compId, int topN) => topQualifiers(
        _matches.where(
            (m) => m.competitionId == compId && m.stage == 'group'),
        topN,
      );

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
    changed = _autoResolveFfaBots() || changed;
    // Generate playoffs / finish round-robins whose group stage just completed.
    for (final id in _comps.keys.toList()) {
      if (_runPlayoffGen(id)) changed = true;
      if (_finishRoundRobinIfDone(id)) changed = true;
      if (_runFfaAdvance(id)) changed = true;
    }
    changed = _autoPlayBots() || changed;
    if (changed) notifyListeners();
  }

  /// The organizer records the lobby finish order (1st, 2nd, …). The number
  /// they rank drives who advances (top [Competition.advancePerGroup]) and,
  /// in the final lobby, the podium ([Competition.finalWinners]).
  void setFfaResult(String matchId, List<String> orderedIds) {
    final i = _matches.indexWhere((m) => m.id == matchId);
    if (i < 0 || orderedIds.isEmpty) return;
    final m = _matches[i];
    final ranked = [
      for (final id in orderedIds)
        Participant(id: id, name: m.nameOf(id) ?? 'Player')
    ];
    _matches[i] = m.copyWith(
      status: MatchStatus.completed,
      winnerId: orderedIds.first,
      rankings: ranked,
    );
    _runFfaAdvance(m.competitionId);
    notifyListeners();
  }

  /// All-bot FFA lobbies auto-resolve so demos progress without the human
  /// having to touch every lobby. The roster order becomes the finish order.
  bool _autoResolveFfaBots() {
    var changed = false;
    for (var i = 0; i < _matches.length; i++) {
      final m = _matches[i];
      if (m.stage == 'ffa' &&
          m.status != MatchStatus.completed &&
          m.players.isNotEmpty &&
          m.players.every((p) => _isBot(p.id))) {
        _matches[i] = m.copyWith(
          status: MatchStatus.completed,
          winnerId: m.players.first.id,
          rankings: List<Participant>.from(m.players),
        );
        changed = true;
      }
    }
    return changed;
  }

  /// Top [perLobby] finishers of each lobby, seeded across lobbies by rank
  /// (all 1st places, then all 2nd places, …) so lobby winners spread out.
  List<Participant> _ffaAdvancers(List<GameMatch> lobbies, int perLobby) {
    final byLobby = [
      for (final m in lobbies)
        (m.rankings.isNotEmpty
            ? m.rankings
            : (m.winnerId != null
                ? [Participant(id: m.winnerId!, name: m.winnerName ?? 'Player')]
                : const <Participant>[]))
    ];
    final out = <Participant>[];
    for (var rank = 0; rank < perLobby; rank++) {
      for (final ranks in byLobby) {
        if (rank < ranks.length) out.add(ranks[rank]);
      }
    }
    return out;
  }

  /// Advances a free-for-all once every lobby in the current round is decided:
  /// seeds the next round from the top finishers, or crowns the champion.
  bool _runFfaAdvance(String compId) {
    final comp = _comps[compId];
    if (comp == null) return false;
    final ffa = _matches
        .where((m) => m.competitionId == compId && m.stage == 'ffa')
        .toList();
    if (ffa.isEmpty) return false;
    final maxRound = ffa.map((m) => m.round).reduce(max);
    final current = ffa.where((m) => m.round == maxRound).toList();
    if (current.any((m) => m.status != MatchStatus.completed)) return false;

    if (current.length == 1) {
      if (comp.status == CompetitionStatus.completed) return false;
      _comps[compId] = comp.copyWith(status: CompetitionStatus.completed);
      final champ = current.first.winnerName;
      final champId = current.first.winnerId;
      if (champId != null && comp.prizePool > 0) {
        _payouts.insert(
          0,
          Payout(
            id: _uuid.v4(),
            userId: champId,
            userName: champ ?? 'Player',
            competitionId: comp.id,
            competitionTitle: comp.title,
            amount: comp.prizePool,
          ),
        );
      }
      _pushNotif(NotificationKind.payout, 'Champion crowned',
          '${champ ?? 'A player'} won ${comp.title}.');
      return true;
    }

    if (ffa.any((m) => m.round == maxRound + 1)) return false;
    final advancers = _ffaAdvancers(current, max(1, comp.advancePerGroup));
    if (advancers.length < 2) return false;
    _matches.addAll(BracketBuilder.ffaRound(compId, advancers, maxRound + 1,
        lobbySize: comp.lobbySize));
    return true;
  }

  /// A round-robin with no playoff completes once all group matches are done;
  /// the standings leader is the champion (and gets the prize payout).
  bool _finishRoundRobinIfDone(String compId) {
    final comp = _comps[compId];
    if (comp == null) return false;
    if (comp.hasPlayoff) return false;
    if (comp.status != CompetitionStatus.ongoing) return false;
    if (!groupStageComplete(compId)) return false;
    final leaders = _qualifiers(compId, 1);
    _comps[compId] = comp.copyWith(status: CompetitionStatus.completed);
    if (leaders.isNotEmpty && comp.prizePool > 0) {
      _payouts.insert(
        0,
        Payout(
          id: _uuid.v4(),
          userId: leaders.first.id,
          userName: leaders.first.name,
          competitionId: comp.id,
          competitionTitle: comp.title,
          amount: comp.prizePool,
        ),
      );
    }
    _pushNotif(NotificationKind.payout, 'Champion crowned',
        '${leaders.isNotEmpty ? leaders.first.name : 'A player'} won ${comp.title}.');
    return true;
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
      // Final match completed → competition done + champion payout.
      final comp = _comps[m.competitionId];
      if (comp != null) {
        _comps[m.competitionId] =
            comp.copyWith(status: CompetitionStatus.completed);
        if (comp.prizePool > 0) {
          _payouts.insert(
            0,
            Payout(
              id: _uuid.v4(),
              userId: winnerId,
              userName: winnerName ?? 'Champion',
              competitionId: comp.id,
              competitionTitle: comp.title,
              amount: comp.prizePool,
            ),
          );
        }
        _pushNotif(NotificationKind.payout, 'Champion crowned',
            '${winnerName ?? 'A player'} won ${comp.title}.');
      }
    }
  }

  // ── Payouts ───────────────────────────────────────────────────
  List<Payout> get payouts => List.unmodifiable(_payouts);

  void markPayoutPaid(String id) {
    final i = _payouts.indexWhere((p) => p.id == id);
    if (i < 0) return;
    final p = _payouts[i];
    _payouts[i] = Payout(
      id: p.id,
      userId: p.userId,
      userName: p.userName,
      competitionId: p.competitionId,
      competitionTitle: p.competitionTitle,
      amount: p.amount,
      status: PayoutStatus.paid,
    );
    notifyListeners();
  }

  // ── Notifications ─────────────────────────────────────────────
  List<AppNotification> get notifications => List.unmodifiable(_notifs);
  int get unreadCount => _notifs.where((n) => !n.read).length;

  void markAllNotificationsRead() {
    for (var i = 0; i < _notifs.length; i++) {
      final n = _notifs[i];
      if (!n.read) {
        _notifs[i] = AppNotification(
          id: n.id,
          kind: n.kind,
          title: n.title,
          body: n.body,
          read: true,
          createdAt: n.createdAt,
        );
      }
    }
    notifyListeners();
  }

  // ── Refund / cancel ───────────────────────────────────────────
  void cancelCompetition(String compId) {
    final comp = _comps[compId];
    if (comp == null) return;
    _comps[compId] = comp.copyWith(status: CompetitionStatus.cancelled);
    _matches.removeWhere((m) => m.competitionId == compId);
    _pushNotif(NotificationKind.payment, 'Competition cancelled',
        '${comp.title} was cancelled — entry fees are refunded.');
    notifyListeners();
  }

  /// Admin moderation: permanently removes a competition and everything tied to
  /// it (registrations, matches, pending transactions).
  void deleteCompetition(String compId) {
    _comps.remove(compId);
    _regs.removeWhere((r) => r.competitionId == compId);
    _matches.removeWhere((m) => m.competitionId == compId);
    _txns.removeWhere((t) => t.competitionId == compId);
    notifyListeners();
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
