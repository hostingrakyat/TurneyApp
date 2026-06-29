enum MatchStatus {
  scheduled,
  awaitingReports,
  autoResolving,
  completed,
  disputed;

  static MatchStatus fromString(String? v) => switch (v) {
        'scheduled' => MatchStatus.scheduled,
        'awaiting_reports' => MatchStatus.awaitingReports,
        'auto_resolving' => MatchStatus.autoResolving,
        'completed' => MatchStatus.completed,
        'disputed' => MatchStatus.disputed,
        _ => MatchStatus.scheduled,
      };

  String get value => switch (this) {
        MatchStatus.scheduled => 'scheduled',
        MatchStatus.awaitingReports => 'awaiting_reports',
        MatchStatus.autoResolving => 'auto_resolving',
        MatchStatus.completed => 'completed',
        MatchStatus.disputed => 'disputed',
      };

  String get label => switch (this) {
        MatchStatus.scheduled => 'Scheduled',
        MatchStatus.awaitingReports => 'Awaiting reports',
        MatchStatus.autoResolving => 'Resolving',
        MatchStatus.completed => 'Completed',
        MatchStatus.disputed => 'Disputed',
      };
}

/// A single bracket match. Named `GameMatch` to avoid clashing with Dart's
/// core `Match` (RegExp). Player display names are denormalized onto the row so
/// the UI never needs a join.
class GameMatch {
  const GameMatch({
    required this.id,
    required this.competitionId,
    required this.round,
    required this.position,
    this.player1Id,
    this.player1Name,
    this.player2Id,
    this.player2Name,
    this.status = MatchStatus.scheduled,
    this.winnerId,
    this.nextMatchId,
    this.nextSlot,
    this.reportsOpenAt,
    this.autoResolveAt,
  });

  final String id;
  final String competitionId;
  final int round;
  final int position;
  final String? player1Id;
  final String? player1Name;
  final String? player2Id;
  final String? player2Name;
  final MatchStatus status;
  final String? winnerId;

  /// Single-elimination linkage: where the winner advances to.
  final String? nextMatchId;
  final int? nextSlot; // 1 or 2
  final DateTime? reportsOpenAt;
  final DateTime? autoResolveAt;

  bool get bothPlayersPresent => player1Id != null && player2Id != null;
  bool get isBye =>
      (player1Id == null) != (player2Id == null); // exactly one present

  String? get winnerName {
    if (winnerId == null) return null;
    if (winnerId == player1Id) return player1Name;
    if (winnerId == player2Id) return player2Name;
    return null;
  }

  String nameFor(String slot) => slot == 'p1'
      ? (player1Name ?? 'TBD')
      : (player2Name ?? 'TBD');

  GameMatch copyWith({
    String? player1Id,
    String? player1Name,
    String? player2Id,
    String? player2Name,
    MatchStatus? status,
    String? winnerId,
    DateTime? reportsOpenAt,
    DateTime? autoResolveAt,
    bool clearWinner = false,
  }) =>
      GameMatch(
        id: id,
        competitionId: competitionId,
        round: round,
        position: position,
        player1Id: player1Id ?? this.player1Id,
        player1Name: player1Name ?? this.player1Name,
        player2Id: player2Id ?? this.player2Id,
        player2Name: player2Name ?? this.player2Name,
        status: status ?? this.status,
        winnerId: clearWinner ? null : (winnerId ?? this.winnerId),
        nextMatchId: nextMatchId,
        nextSlot: nextSlot,
        reportsOpenAt: reportsOpenAt ?? this.reportsOpenAt,
        autoResolveAt: autoResolveAt ?? this.autoResolveAt,
      );

  factory GameMatch.fromMap(Map<String, dynamic> m) => GameMatch(
        id: m['id'] as String,
        competitionId: m['competition_id'] as String,
        round: (m['round'] ?? 1) as int,
        position: (m['bracket_position'] ?? 0) as int,
        player1Id: m['player1_id'] as String?,
        player1Name: m['player1_name'] as String?,
        player2Id: m['player2_id'] as String?,
        player2Name: m['player2_name'] as String?,
        status: MatchStatus.fromString(m['status'] as String?),
        winnerId: m['winner_id'] as String?,
        nextMatchId: m['next_match_id'] as String?,
        nextSlot: m['next_slot'] as int?,
        reportsOpenAt: m['reports_open_at'] == null
            ? null
            : DateTime.parse(m['reports_open_at'] as String),
        autoResolveAt: m['auto_resolve_at'] == null
            ? null
            : DateTime.parse(m['auto_resolve_at'] as String),
      );

  Map<String, dynamic> toInsert() => {
        'id': id,
        'competition_id': competitionId,
        'round': round,
        'bracket_position': position,
        'player1_id': player1Id,
        'player1_name': player1Name,
        'player2_id': player2Id,
        'player2_name': player2Name,
        'status': status.value,
        'winner_id': winnerId,
        'next_match_id': nextMatchId,
        'next_slot': nextSlot,
        'reports_open_at': reportsOpenAt?.toIso8601String(),
        'auto_resolve_at': autoResolveAt?.toIso8601String(),
      };
}
